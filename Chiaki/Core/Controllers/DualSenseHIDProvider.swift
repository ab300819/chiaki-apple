// SPDX-License-Identifier: AGPL-3.0-only
//
// DualSenseHIDProvider.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Direct IOKit HID communication with DualSense controllers on macOS.
// Implements ControllerInputProvider + ControllerFeedbackOutput for PS button,
// rumble, adaptive triggers, and LED via raw HID reports.

#if os(macOS)

import Foundation
import IOKit
import IOKit.hid

// MARK: - Constants

private enum DualSenseConstants {
    static let vendorID: Int32 = 0x054C
    static let productID: Int32 = 0x0CE6
    static let edgeProductID: Int32 = 0x0DF2

    // HID report IDs
    static let usbOutputReportID: UInt8 = 0x02
    static let btOutputReportID: UInt8 = 0x31
    static let usbInputReportID: UInt8 = 0x01
    static let btInputReportID: UInt8 = 0x31

    // Report sizes
    static let usbOutputReportSize = 63
    static let btOutputReportSize = 78
    static let maxInputReportSize = 78

    // Feature report IDs for enabling enhanced BT mode
    static let featurePairingInfo: UInt8 = 0x09
    static let featureFirmwareInfo: UInt8 = 0x20

    // Output report flags
    static let flagCompatibleVibration: UInt8 = 0x01
    static let flagHapticsSelect: UInt8 = 0x02
    static let flag2CompatibleVibration2: UInt8 = 0x04
    static let flag1Unknown: UInt8 = 0x40
    // LED control flag
    static let flagLED: UInt8 = 0x04

    // CRC32 seed for BT output reports
    static let btCRC32Seed: UInt8 = 0xA2

    // Button masks (from buttons[2] in input report)
    static let buttonPS: UInt8 = 0x01
    static let buttonTouchpad: UInt8 = 0x02
    static let buttonMicMute: UInt8 = 0x04

    /// Supported product IDs
    static let supportedProductIDs: [Int32] = [productID, edgeProductID]
}

// MARK: - Transport Type

private enum DualSenseTransport {
    case usb
    case bluetooth
}

// MARK: - HID Device Wrapper

private final class DualSenseHIDDevice {
    let device: IOHIDDevice
    let transport: DualSenseTransport
    let isEdge: Bool
    var btSequence: UInt8 = 0
    var inputBuffer = [UInt8](repeating: 0, count: DualSenseConstants.maxInputReportSize)
    var enhancedModeActive: Bool = false

    init(device: IOHIDDevice, transport: DualSenseTransport, isEdge: Bool) {
        self.device = device
        self.transport = transport
        self.isEdge = isEdge
    }
}

// MARK: - DualSense HID Provider

/// Direct IOKit HID provider for DualSense controllers on macOS.
/// Provides PS button input and rumble/LED/adaptive trigger output that
/// the GameController framework does not reliably deliver.
/// @requirement F-040 - 控制器架構分层重構
/// @satisfies AC-152 - HID 優先 GC fallback
/// @satisfies AC-153 - 非排他共存
@MainActor
final class DualSenseHIDProvider: ControllerInputProvider, ControllerFeedbackOutput {

    // MARK: - ControllerInputProvider

    let providerId: String

    var displayName: String {
        guard let device = connectedDevices.values.first else { return "DualSense (HID)" }
        return device.isEdge ? "DualSense Edge (HID)" : "DualSense (HID)"
    }

    var isConnected: Bool { !connectedDevices.isEmpty }

    let capabilities: ControllerCapabilities = .dualSenseHID

    /// PS button state is the only input from HID — other inputs come from GameControllerProvider
    private(set) var currentInput = ChiakiControllerInput()

    var onInputChanged: ((ChiakiControllerInput) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?

    // MARK: - Private Properties

    private var hidManager: IOHIDManager?
    private var connectedDevices: [IOHIDDevice: DualSenseHIDDevice] = [:]
    private var psButtonState: [IOHIDDevice: Bool] = [:]

    // MARK: - Singleton

    static let shared = DualSenseHIDProvider()

    // MARK: - Initialization

    private init() {
        self.providerId = "dualsense-hid"
    }

    // MARK: - ControllerInputProvider

    func start() {
        guard hidManager == nil else { return }
        setupHIDManager()
    }

    func stop() {
        shutdown()
    }

    // MARK: - HID Manager Setup

    private func setupHIDManager() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        hidManager = manager

        let matchDualSense = createMatchingDict(vendorID: DualSenseConstants.vendorID,
                                                 productID: DualSenseConstants.productID)
        let matchEdge = createMatchingDict(vendorID: DualSenseConstants.vendorID,
                                           productID: DualSenseConstants.edgeProductID)

        IOHIDManagerSetDeviceMatchingMultiple(manager, [matchDualSense, matchEdge] as CFArray)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            guard let context else { return }
            let provider = Unmanaged<DualSenseHIDProvider>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in provider.handleDeviceConnected(device) }
        }, selfPtr)

        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            let provider = Unmanaged<DualSenseHIDProvider>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in provider.handleDeviceDisconnected(device) }
        }, selfPtr)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openResult != kIOReturnSuccess {
            logError("DualSenseHID: Failed to open IOHIDManager: \(openResult)")
        } else {
            logInfo("DualSenseHID: Provider started, scanning for DualSense controllers")
        }
    }

    private func createMatchingDict(vendorID: Int32, productID: Int32) -> CFDictionary {
        [kIOHIDVendorIDKey: NSNumber(value: vendorID),
         kIOHIDProductIDKey: NSNumber(value: productID)] as CFDictionary
    }

    // MARK: - Device Lifecycle

    private func handleDeviceConnected(_ device: IOHIDDevice) {
        let transport = detectTransport(device)
        let isEdge = detectIsEdge(device)
        let dsDevice = DualSenseHIDDevice(device: device, transport: transport, isEdge: isEdge)
        connectedDevices[device] = dsDevice

        let transportStr = transport == .bluetooth ? "Bluetooth" : "USB"
        let model = isEdge ? "DualSense Edge" : "DualSense"
        logInfo("DualSenseHID: \(model) connected via \(transportStr)")

        if transport == .bluetooth {
            activateEnhancedBTMode(dsDevice)
        }
        registerInputCallback(dsDevice)
        onConnectionChanged?(true)
    }

    private func handleDeviceDisconnected(_ device: IOHIDDevice) {
        if let dsDevice = connectedDevices.removeValue(forKey: device) {
            psButtonState.removeValue(forKey: device)
            let model = dsDevice.isEdge ? "DualSense Edge" : "DualSense"
            logInfo("DualSenseHID: \(model) disconnected")
            onConnectionChanged?(connectedDevices.isEmpty ? false : true)
        }
    }

    private func detectTransport(_ device: IOHIDDevice) -> DualSenseTransport {
        if let ref = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String {
            if ref.lowercased().contains("bluetooth") || ref.lowercased() == "bluetoothlow" {
                return .bluetooth
            }
        }
        return .usb
    }

    private func detectIsEdge(_ device: IOHIDDevice) -> Bool {
        if let pid = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? NSNumber {
            return pid.int32Value == DualSenseConstants.edgeProductID
        }
        return false
    }

    // MARK: - Enhanced Bluetooth Mode

    private func activateEnhancedBTMode(_ dsDevice: DualSenseHIDDevice) {
        var reportBuffer = [UInt8](repeating: 0, count: 64)
        var reportLength: CFIndex

        reportBuffer[0] = DualSenseConstants.featurePairingInfo
        reportLength = CFIndex(reportBuffer.count)
        let result1 = IOHIDDeviceGetReport(dsDevice.device, kIOHIDReportTypeFeature,
                                           CFIndex(DualSenseConstants.featurePairingInfo),
                                           &reportBuffer, &reportLength)
        if result1 == kIOReturnSuccess {
            logDebug("DualSenseHID: Read pairing info feature report (\(reportLength) bytes)")
        } else {
            logWarning("DualSenseHID: Failed to read pairing info: \(result1)")
        }

        reportBuffer = [UInt8](repeating: 0, count: 64)
        reportBuffer[0] = DualSenseConstants.featureFirmwareInfo
        reportLength = CFIndex(reportBuffer.count)
        let result2 = IOHIDDeviceGetReport(dsDevice.device, kIOHIDReportTypeFeature,
                                           CFIndex(DualSenseConstants.featureFirmwareInfo),
                                           &reportBuffer, &reportLength)
        if result2 == kIOReturnSuccess {
            logDebug("DualSenseHID: Read firmware info feature report (\(reportLength) bytes)")
            dsDevice.enhancedModeActive = true
        } else {
            logWarning("DualSenseHID: Failed to read firmware info: \(result2)")
        }
    }

    // MARK: - Input Report Handling

    private func registerInputCallback(_ dsDevice: DualSenseHIDDevice) {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        dsDevice.inputBuffer.withUnsafeMutableBufferPointer { bufferPtr in
            guard let baseAddress = bufferPtr.baseAddress else { return }
            IOHIDDeviceRegisterInputReportCallback(
                dsDevice.device, baseAddress, DualSenseConstants.maxInputReportSize,
                { context, _, sender, _, reportID, report, reportLength in
                    guard let context, let sender else { return }
                    let provider = Unmanaged<DualSenseHIDProvider>.fromOpaque(context).takeUnretainedValue()
                    let device = Unmanaged<IOHIDDevice>.fromOpaque(sender).takeUnretainedValue()
                    let reportData = Array(UnsafeBufferPointer(start: report, count: reportLength))
                    Task { @MainActor in
                        provider.handleInputReport(device: device, reportID: UInt32(reportID), data: reportData)
                    }
                },
                selfPtr
            )
        }
    }

    func handleInputReport(device: IOHIDDevice, reportID: UInt32, data: [UInt8]) {
        guard let dsDevice = connectedDevices[device] else { return }

        let psPressed: Bool?

        if dsDevice.transport == .usb && reportID == UInt32(DualSenseConstants.usbInputReportID) {
            guard data.count > 10 else { return }
            psPressed = (data[10] & DualSenseConstants.buttonPS) != 0
        } else if dsDevice.transport == .bluetooth && reportID == UInt32(DualSenseConstants.btInputReportID) {
            guard data.count > 12 else { return }
            psPressed = (data[12] & DualSenseConstants.buttonPS) != 0
        } else {
            return
        }

        guard let pressed = psPressed else { return }

        let previousState = psButtonState[device] ?? false
        if pressed != previousState {
            psButtonState[device] = pressed
            if pressed {
                currentInput.buttons.insert(.ps)
            } else {
                currentInput.buttons.remove(.ps)
            }
            onInputChanged?(currentInput)
        }
    }

    // MARK: - ControllerFeedbackOutput

    func sendRumble(left: UInt8, right: UInt8) {
        guard let dsDevice = connectedDevices.values.first else { return }
        switch dsDevice.transport {
        case .usb: sendUSBOutput(dsDevice, rumbleLeft: left, rumbleRight: right)
        case .bluetooth: sendBTOutput(dsDevice, rumbleLeft: left, rumbleRight: right)
        }
    }

    func applyAdaptiveTrigger(effect: AdaptiveTriggerEffect, side: TriggerSide) {
        // Adaptive triggers via HID require specific output report bytes.
        // DualSense output report: bytes 11-22 control adaptive triggers.
        // For now, delegate to GameControllerProvider which uses GCDualSenseAdaptiveTrigger API.
        // Full HID implementation can be added later if needed.
    }

    func setLEDColor(red: UInt8, green: UInt8, blue: UInt8) {
        guard let dsDevice = connectedDevices.values.first else { return }
        switch dsDevice.transport {
        case .usb: sendUSBOutput(dsDevice, ledRed: red, ledGreen: green, ledBlue: blue)
        case .bluetooth: sendBTOutput(dsDevice, ledRed: red, ledGreen: green, ledBlue: blue)
        }
    }

    func supportsFeedback(_ type: FeedbackType) -> Bool {
        switch type {
        case .rumble: return true
        case .adaptiveTrigger: return false  // Delegated to GC for now
        case .ledColor: return true
        }
    }

    // MARK: - USB Output Report

    private func sendUSBOutput(_ dsDevice: DualSenseHIDDevice,
                               rumbleLeft: UInt8 = 0, rumbleRight: UInt8 = 0,
                               ledRed: UInt8? = nil, ledGreen: UInt8? = nil, ledBlue: UInt8? = nil) {
        var report = [UInt8](repeating: 0, count: DualSenseConstants.usbOutputReportSize)

        report[0] = DualSenseConstants.usbOutputReportID
        let p = 1  // payload offset

        // Flags
        var flag0: UInt8 = DualSenseConstants.flagCompatibleVibration | DualSenseConstants.flagHapticsSelect
        var flag1: UInt8 = DualSenseConstants.flag1Unknown

        // Rumble
        report[p + 2] = rumbleRight
        report[p + 3] = rumbleLeft

        // LED
        if let r = ledRed, let g = ledGreen, let b = ledBlue {
            flag1 |= DualSenseConstants.flagLED
            report[p + 44] = r  // LED red
            report[p + 45] = g  // LED green
            report[p + 46] = b  // LED blue
        }

        report[p + 0] = flag0
        report[p + 1] = flag1
        report[p + 38] = DualSenseConstants.flag2CompatibleVibration2

        IOHIDDeviceSetReport(dsDevice.device, kIOHIDReportTypeOutput,
                             CFIndex(DualSenseConstants.usbOutputReportID), report, report.count)
    }

    // MARK: - Bluetooth Output Report

    private func sendBTOutput(_ dsDevice: DualSenseHIDDevice,
                              rumbleLeft: UInt8 = 0, rumbleRight: UInt8 = 0,
                              ledRed: UInt8? = nil, ledGreen: UInt8? = nil, ledBlue: UInt8? = nil) {
        var report = [UInt8](repeating: 0, count: DualSenseConstants.btOutputReportSize)

        report[0] = DualSenseConstants.btOutputReportID
        report[1] = (dsDevice.btSequence << 4) | 0x00
        dsDevice.btSequence = (dsDevice.btSequence + 1) & 0x0F
        report[2] = 0x10

        let p = 3  // payload offset

        var flag0: UInt8 = DualSenseConstants.flagCompatibleVibration | DualSenseConstants.flagHapticsSelect
        var flag1: UInt8 = DualSenseConstants.flag1Unknown

        report[p + 2] = rumbleRight
        report[p + 3] = rumbleLeft

        if let r = ledRed, let g = ledGreen, let b = ledBlue {
            flag1 |= DualSenseConstants.flagLED
            report[p + 44] = r
            report[p + 45] = g
            report[p + 46] = b
        }

        report[p + 0] = flag0
        report[p + 1] = flag1
        report[p + 38] = DualSenseConstants.flag2CompatibleVibration2

        // CRC32
        let crc = computeBTCRC32(report: report)
        let crcOffset = report.count - 4
        report[crcOffset + 0] = UInt8(crc & 0xFF)
        report[crcOffset + 1] = UInt8((crc >> 8) & 0xFF)
        report[crcOffset + 2] = UInt8((crc >> 16) & 0xFF)
        report[crcOffset + 3] = UInt8((crc >> 24) & 0xFF)

        IOHIDDeviceSetReport(dsDevice.device, kIOHIDReportTypeOutput,
                             CFIndex(DualSenseConstants.btOutputReportID), report, report.count)
    }

    // MARK: - CRC32

    private func computeBTCRC32(report: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        crc = crc32UpdateByte(crc, byte: DualSenseConstants.btCRC32Seed)
        let dataLen = report.count - 4
        for i in 0..<dataLen {
            crc = crc32UpdateByte(crc, byte: report[i])
        }
        return ~crc
    }

    private func crc32UpdateByte(_ crc: UInt32, byte: UInt8) -> UInt32 {
        var c = crc ^ UInt32(byte)
        for _ in 0..<8 {
            if c & 1 != 0 {
                c = (c >> 1) ^ 0xEDB88320
            } else {
                c >>= 1
            }
        }
        return c
    }

    // MARK: - Cleanup

    func shutdown() {
        if let manager = hidManager {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        connectedDevices.removeAll()
        psButtonState.removeAll()
        hidManager = nil
        logInfo("DualSenseHID: Provider shut down")
    }

    /// Whether a DualSense is connected via HID (backward compat)
    var hasConnectedDevice: Bool { !connectedDevices.isEmpty }
}

#endif
