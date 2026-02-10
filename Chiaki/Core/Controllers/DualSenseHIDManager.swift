// SPDX-License-Identifier: AGPL-3.0-only
//
// DualSenseHIDManager.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Direct IOKit HID communication with DualSense controllers on macOS.
// Bypasses GameController framework limitations for PS button and rumble.

#if os(macOS)

import Foundation
import IOKit
import IOKit.hid

// MARK: - Constants

private enum DualSenseConstants {
    // Sony vendor ID
    static let vendorID: Int32 = 0x054C
    // DualSense product ID
    static let productID: Int32 = 0x0CE6
    // DualSense Edge product ID
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

    // CRC32 seed for BT output reports
    static let btCRC32Seed: UInt8 = 0xA2

    // Button masks (from buttons[2] in input report)
    static let buttonPS: UInt8 = 0x01
    static let buttonTouchpad: UInt8 = 0x02
    static let buttonMicMute: UInt8 = 0x04
}

// MARK: - Transport Type

private enum DualSenseTransport {
    case usb
    case bluetooth
}

// MARK: - DualSense HID Device

private final class DualSenseHIDDevice {
    let device: IOHIDDevice
    let transport: DualSenseTransport
    let isEdge: Bool

    /// Bluetooth sequence counter (0-15)
    var btSequence: UInt8 = 0

    /// Input report buffer
    var inputBuffer = [UInt8](repeating: 0, count: DualSenseConstants.maxInputReportSize)

    /// Whether enhanced BT mode has been activated
    var enhancedModeActive: Bool = false

    init(device: IOHIDDevice, transport: DualSenseTransport, isEdge: Bool) {
        self.device = device
        self.transport = transport
        self.isEdge = isEdge
    }
}

// MARK: - DualSense HID Manager

/// Manages direct IOKit HID communication with DualSense controllers on macOS.
/// Used to bypass GameController framework limitations for:
/// - PS button input (not reliably delivered via GCExtendedGamepad.buttonHome)
/// - Rumble output (GCDeviceHaptics may not work on macOS)
/// @requirement F-004
@MainActor
final class DualSenseHIDManager {

    // MARK: - Callbacks

    /// Called when PS button state changes (true = pressed, false = released)
    var onPSButtonChanged: ((Bool) -> Void)?

    // MARK: - Properties

    private var hidManager: IOHIDManager?
    private var connectedDevices: [IOHIDDevice: DualSenseHIDDevice] = [:]

    /// Track PS button state per device to detect edges
    private var psButtonState: [IOHIDDevice: Bool] = [:]

    // MARK: - Singleton

    static let shared = DualSenseHIDManager()

    // MARK: - Initialization

    private init() {
        setupHIDManager()
    }

    // MARK: - Setup

    private func setupHIDManager() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        hidManager = manager

        // Create matching dictionaries for DualSense and DualSense Edge
        let matchDualSense = createMatchingDict(vendorID: DualSenseConstants.vendorID,
                                                 productID: DualSenseConstants.productID)
        let matchEdge = createMatchingDict(vendorID: DualSenseConstants.vendorID,
                                           productID: DualSenseConstants.edgeProductID)

        let matchArray = [matchDualSense, matchEdge] as CFArray
        IOHIDManagerSetDeviceMatchingMultiple(manager, matchArray)

        // Register callbacks — must use static C functions
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, result, sender, device in
            guard let context = context else { return }
            let manager = Unmanaged<DualSenseHIDManager>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in
                manager.handleDeviceConnected(device)
            }
        }, selfPtr)

        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, result, sender, device in
            guard let context = context else { return }
            let manager = Unmanaged<DualSenseHIDManager>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in
                manager.handleDeviceDisconnected(device)
            }
        }, selfPtr)

        // Schedule on main run loop
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        // Open manager (non-exclusive — coexists with GameController framework)
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openResult != kIOReturnSuccess {
            logError("DualSenseHID: Failed to open IOHIDManager: \(openResult)")
        } else {
            logInfo("DualSenseHID: IOHIDManager initialized, scanning for DualSense controllers")
        }
    }

    private func createMatchingDict(vendorID: Int32, productID: Int32) -> CFDictionary {
        let vid = vendorID
        let pid = productID
        let dict: [String: Any] = [
            kIOHIDVendorIDKey: NSNumber(value: vid),
            kIOHIDProductIDKey: NSNumber(value: pid)
        ]
        return dict as CFDictionary
    }

    // MARK: - Device Lifecycle

    private func handleDeviceConnected(_ device: IOHIDDevice) {
        // Determine transport
        let transport = detectTransport(device)
        let isEdge = detectIsEdge(device)

        let dsDevice = DualSenseHIDDevice(device: device, transport: transport, isEdge: isEdge)
        connectedDevices[device] = dsDevice

        let transportStr = transport == .bluetooth ? "Bluetooth" : "USB"
        let model = isEdge ? "DualSense Edge" : "DualSense"
        logInfo("DualSenseHID: \(model) connected via \(transportStr)")

        // For Bluetooth, activate enhanced mode
        if transport == .bluetooth {
            activateEnhancedBTMode(dsDevice)
        }

        // Register input report callback
        registerInputCallback(dsDevice)
    }

    private func handleDeviceDisconnected(_ device: IOHIDDevice) {
        if let dsDevice = connectedDevices.removeValue(forKey: device) {
            psButtonState.removeValue(forKey: device)
            let model = dsDevice.isEdge ? "DualSense Edge" : "DualSense"
            logInfo("DualSenseHID: \(model) disconnected")
        }
    }

    private func detectTransport(_ device: IOHIDDevice) -> DualSenseTransport {
        if let transportRef = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) {
            let transport = transportRef as? String ?? ""
            if transport.lowercased().contains("bluetooth") || transport.lowercased() == "bluetoothlow" {
                return .bluetooth
            }
        }
        return .usb
    }

    private func detectIsEdge(_ device: IOHIDDevice) -> Bool {
        if let pidRef = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? NSNumber {
            return pidRef.int32Value == DualSenseConstants.edgeProductID
        }
        return false
    }

    // MARK: - Enhanced Bluetooth Mode

    /// Activate enhanced BT mode by reading feature reports.
    /// In basic BT mode, the DualSense sends 10-byte simple reports without PS button data.
    /// Reading feature reports triggers a switch to enhanced 78-byte reports.
    private func activateEnhancedBTMode(_ dsDevice: DualSenseHIDDevice) {
        var reportBuffer = [UInt8](repeating: 0, count: 64)
        var reportLength: CFIndex

        // Read pairing info (triggers enhanced mode)
        reportBuffer[0] = DualSenseConstants.featurePairingInfo
        reportLength = CFIndex(reportBuffer.count)
        let result1 = IOHIDDeviceGetReport(dsDevice.device,
                                           kIOHIDReportTypeFeature,
                                           CFIndex(DualSenseConstants.featurePairingInfo),
                                           &reportBuffer,
                                           &reportLength)
        if result1 == kIOReturnSuccess {
            logDebug("DualSenseHID: Read pairing info feature report (\(reportLength) bytes)")
        } else {
            logWarning("DualSenseHID: Failed to read pairing info: \(result1)")
        }

        // Read firmware info
        reportBuffer = [UInt8](repeating: 0, count: 64)
        reportBuffer[0] = DualSenseConstants.featureFirmwareInfo
        reportLength = CFIndex(reportBuffer.count)
        let result2 = IOHIDDeviceGetReport(dsDevice.device,
                                           kIOHIDReportTypeFeature,
                                           CFIndex(DualSenseConstants.featureFirmwareInfo),
                                           &reportBuffer,
                                           &reportLength)
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
                dsDevice.device,
                baseAddress,
                DualSenseConstants.maxInputReportSize,
                { context, result, sender, type, reportID, report, reportLength in
                    guard let context = context, let sender = sender else { return }
                    let manager = Unmanaged<DualSenseHIDManager>.fromOpaque(context).takeUnretainedValue()
                    let device = Unmanaged<IOHIDDevice>.fromOpaque(sender).takeUnretainedValue()
                    // Copy report data before dispatching to main thread
                    let reportData = Array(UnsafeBufferPointer(start: report, count: reportLength))
                    Task { @MainActor in
                        manager.handleInputReport(device: device, reportID: UInt32(reportID),
                                                  data: reportData)
                    }
                },
                selfPtr
            )
        }
    }

    func handleInputReport(device: IOHIDDevice, reportID: UInt32, data: [UInt8]) {
        guard let dsDevice = connectedDevices[device] else { return }

        // Parse PS button state based on transport and report ID
        let psPressed: Bool?

        if dsDevice.transport == .usb && reportID == UInt32(DualSenseConstants.usbInputReportID) {
            // USB input: buttons[2] is at byte offset 8 (relative to payload start at byte 1)
            // Report layout: [reportID(1), ...gamepadState...]
            // buttons[0] at offset 8, buttons[1] at offset 9, buttons[2] at offset 10
            guard data.count > 10 else { return }
            psPressed = (data[10] & DualSenseConstants.buttonPS) != 0

        } else if dsDevice.transport == .bluetooth && reportID == UInt32(DualSenseConstants.btInputReportID) {
            // BT enhanced mode input: gamepad state starts at offset 2
            // [reportID(1), unknown(1), ...gamepadState...]
            // buttons[2] at offset 2 + 8 = 10
            guard data.count > 12 else { return }
            psPressed = (data[12] & DualSenseConstants.buttonPS) != 0

        } else {
            return // Unknown report format
        }

        guard let pressed = psPressed else { return }

        // Detect state change
        let previousState = psButtonState[device] ?? false
        if pressed != previousState {
            psButtonState[device] = pressed
            onPSButtonChanged?(pressed)
        }
    }

    // MARK: - Rumble Output

    /// Send rumble command to the first connected DualSense
    /// - Parameters:
    ///   - left: Left motor intensity (0-255, low frequency / heavy)
    ///   - right: Right motor intensity (0-255, high frequency / light)
    func sendRumble(left: UInt8, right: UInt8) {
        guard let dsDevice = connectedDevices.values.first else { return }

        switch dsDevice.transport {
        case .usb:
            sendUSBRumble(dsDevice, left: left, right: right)
        case .bluetooth:
            sendBTRumble(dsDevice, left: left, right: right)
        }
    }

    /// Whether a DualSense is connected via HID
    var hasConnectedDevice: Bool {
        !connectedDevices.isEmpty
    }

    // MARK: - USB Output Report

    private func sendUSBRumble(_ dsDevice: DualSenseHIDDevice, left: UInt8, right: UInt8) {
        var report = [UInt8](repeating: 0, count: DualSenseConstants.usbOutputReportSize)

        report[0] = DualSenseConstants.usbOutputReportID  // Report ID

        // Common payload starts at offset 1
        let payloadOffset = 1
        // valid_flag0: enable compatible vibration + haptics select
        report[payloadOffset + 0] = DualSenseConstants.flagCompatibleVibration | DualSenseConstants.flagHapticsSelect
        // valid_flag1: required unknown bit
        report[payloadOffset + 1] = DualSenseConstants.flag1Unknown
        // motor_right (high frequency)
        report[payloadOffset + 2] = right
        // motor_left (low frequency)
        report[payloadOffset + 3] = left

        // valid_flag2: enhanced vibration
        report[payloadOffset + 38] = DualSenseConstants.flag2CompatibleVibration2

        let result = IOHIDDeviceSetReport(dsDevice.device,
                                          kIOHIDReportTypeOutput,
                                          CFIndex(DualSenseConstants.usbOutputReportID),
                                          report,
                                          report.count)
        if result != kIOReturnSuccess {
            logDebug("DualSenseHID: USB rumble send failed: \(result)")
        }
    }

    // MARK: - Bluetooth Output Report

    private func sendBTRumble(_ dsDevice: DualSenseHIDDevice, left: UInt8, right: UInt8) {
        var report = [UInt8](repeating: 0, count: DualSenseConstants.btOutputReportSize)

        report[0] = DualSenseConstants.btOutputReportID  // Report ID 0x31

        // Sequence tag: upper nibble = sequence (0-15), lower nibble = 0
        report[1] = (dsDevice.btSequence << 4) | 0x00
        dsDevice.btSequence = (dsDevice.btSequence + 1) & 0x0F

        // Tag byte
        report[2] = 0x10

        // Common payload starts at offset 3
        let payloadOffset = 3
        // valid_flag0: enable compatible vibration + haptics select
        report[payloadOffset + 0] = DualSenseConstants.flagCompatibleVibration | DualSenseConstants.flagHapticsSelect
        // valid_flag1: required unknown bit
        report[payloadOffset + 1] = DualSenseConstants.flag1Unknown
        // motor_right (high frequency)
        report[payloadOffset + 2] = right
        // motor_left (low frequency)
        report[payloadOffset + 3] = left

        // valid_flag2: enhanced vibration
        report[payloadOffset + 38] = DualSenseConstants.flag2CompatibleVibration2

        // Calculate CRC32 with seed 0xA2
        let crc = computeBTCRC32(report: report)
        let crcOffset = report.count - 4
        report[crcOffset + 0] = UInt8(crc & 0xFF)
        report[crcOffset + 1] = UInt8((crc >> 8) & 0xFF)
        report[crcOffset + 2] = UInt8((crc >> 16) & 0xFF)
        report[crcOffset + 3] = UInt8((crc >> 24) & 0xFF)

        let result = IOHIDDeviceSetReport(dsDevice.device,
                                          kIOHIDReportTypeOutput,
                                          CFIndex(DualSenseConstants.btOutputReportID),
                                          report,
                                          report.count)
        if result != kIOReturnSuccess {
            logDebug("DualSenseHID: BT rumble send failed: \(result)")
        }
    }

    // MARK: - CRC32

    /// Compute CRC32 for Bluetooth output report.
    /// CRC covers seed byte 0xA2 + all report bytes except the last 4 (CRC) bytes.
    private func computeBTCRC32(report: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF

        // Process seed byte first
        crc = crc32UpdateByte(crc, byte: DualSenseConstants.btCRC32Seed)

        // Process all report bytes except last 4 (CRC placeholder)
        let dataLen = report.count - 4
        for i in 0..<dataLen {
            crc = crc32UpdateByte(crc, byte: report[i])
        }

        return ~crc
    }

    /// Standard CRC32 (ISO 3309) single byte update
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
        logInfo("DualSenseHID: Manager shut down")
    }
}

#endif
