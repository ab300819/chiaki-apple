// SPDX-License-Identifier: AGPL-3.0-only
//
// DualShock4HIDProvider.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Direct IOKit HID communication with DualShock 4 controllers on macOS.
// Implements ControllerInputProvider + ControllerFeedbackOutput for PS button,
// rumble, and LED via raw HID reports.
//
// @requirement F-040 - 控制器架构分层重构
// @satisfies AC-156 - DualShock4HIDProvider 实现

#if os(macOS)

import Foundation
import IOKit
import IOKit.hid

// MARK: - Constants

private enum DS4Constants {
    static let vendorID: Int32 = 0x054C
    static let productIDv1: Int32 = 0x05C4   // CUH-ZCT1
    static let productIDv2: Int32 = 0x09CC   // CUH-ZCT2

    // HID report IDs
    static let usbOutputReportID: UInt8 = 0x05
    static let btOutputReportID: UInt8 = 0x11
    static let usbInputReportID: UInt8 = 0x01
    static let btInputReportID: UInt8 = 0x11

    // Report sizes
    static let usbOutputReportSize = 32
    static let btOutputReportSize = 78
    static let maxInputReportSize = 78

    // Button masks (from buttons[2] in USB input report, buttons[4] in BT)
    static let buttonPS: UInt8 = 0x01

    // CRC32 seed for BT output reports
    static let btCRC32Seed: UInt8 = 0xA2

    static let supportedProductIDs: [Int32] = [productIDv1, productIDv2]
}

// MARK: - Transport Type

private enum DS4Transport {
    case usb
    case bluetooth
}

// MARK: - HID Device Wrapper

private final class DS4HIDDevice {
    let device: IOHIDDevice
    let transport: DS4Transport
    let isV2: Bool
    var btSequence: UInt8 = 0
    var inputBuffer = [UInt8](repeating: 0, count: DS4Constants.maxInputReportSize)

    init(device: IOHIDDevice, transport: DS4Transport, isV2: Bool) {
        self.device = device
        self.transport = transport
        self.isV2 = isV2
    }
}

// MARK: - DualShock 4 HID Provider

/// Direct IOKit HID provider for DualShock 4 controllers on macOS.
/// Provides PS button input and rumble/LED output that the GameController
/// framework does not reliably deliver on macOS.
/// @requirement F-040 - 控制器架构分层重构
/// @satisfies AC-156 - DualShock4HIDProvider 实现
@MainActor
final class DualShock4HIDProvider: ControllerInputProvider, ControllerFeedbackOutput {

    // MARK: - ControllerInputProvider

    let providerId: String

    var displayName: String {
        guard let device = connectedDevices.values.first else { return "DualShock 4 (HID)" }
        return device.isV2 ? "DualShock 4 v2 (HID)" : "DualShock 4 (HID)"
    }

    var isConnected: Bool { !connectedDevices.isEmpty }

    let capabilities: ControllerCapabilities = .dualShock4HID

    /// PS button state is the only input from HID — other inputs come from GameControllerProvider
    private(set) var currentInput = ChiakiControllerInput()

    var onInputChanged: ((ChiakiControllerInput) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?

    // MARK: - Private Properties

    private var hidManager: IOHIDManager?
    private var connectedDevices: [IOHIDDevice: DS4HIDDevice] = [:]
    private var psButtonState: [IOHIDDevice: Bool] = [:]

    // MARK: - Singleton

    static let shared = DualShock4HIDProvider()

    // MARK: - Initialization

    private init() {
        self.providerId = "dualshock4-hid"
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

        let matchV1 = createMatchingDict(vendorID: DS4Constants.vendorID,
                                          productID: DS4Constants.productIDv1)
        let matchV2 = createMatchingDict(vendorID: DS4Constants.vendorID,
                                          productID: DS4Constants.productIDv2)

        IOHIDManagerSetDeviceMatchingMultiple(manager, [matchV1, matchV2] as CFArray)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            guard let context else { return }
            let provider = Unmanaged<DualShock4HIDProvider>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in provider.handleDeviceConnected(device) }
        }, selfPtr)

        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            let provider = Unmanaged<DualShock4HIDProvider>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in provider.handleDeviceDisconnected(device) }
        }, selfPtr)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openResult != kIOReturnSuccess {
            logError("DS4HID: Failed to open IOHIDManager: \(openResult)")
        } else {
            logInfo("DS4HID: Provider started, scanning for DualShock 4 controllers")
        }
    }

    private func createMatchingDict(vendorID: Int32, productID: Int32) -> CFDictionary {
        [kIOHIDVendorIDKey: NSNumber(value: vendorID),
         kIOHIDProductIDKey: NSNumber(value: productID)] as CFDictionary
    }

    // MARK: - Device Lifecycle

    private func handleDeviceConnected(_ device: IOHIDDevice) {
        let transport = detectTransport(device)
        let isV2 = detectIsV2(device)
        let ds4Device = DS4HIDDevice(device: device, transport: transport, isV2: isV2)
        connectedDevices[device] = ds4Device

        let transportStr = transport == .bluetooth ? "Bluetooth" : "USB"
        let model = isV2 ? "DualShock 4 v2" : "DualShock 4"
        logInfo("DS4HID: \(model) connected via \(transportStr)")

        registerInputCallback(ds4Device)
        onConnectionChanged?(true)
    }

    private func handleDeviceDisconnected(_ device: IOHIDDevice) {
        if let ds4Device = connectedDevices.removeValue(forKey: device) {
            psButtonState.removeValue(forKey: device)
            let model = ds4Device.isV2 ? "DualShock 4 v2" : "DualShock 4"
            logInfo("DS4HID: \(model) disconnected")
            onConnectionChanged?(connectedDevices.isEmpty ? false : true)
        }
    }

    private func detectTransport(_ device: IOHIDDevice) -> DS4Transport {
        if let ref = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String {
            if ref.lowercased().contains("bluetooth") || ref.lowercased() == "bluetoothlow" {
                return .bluetooth
            }
        }
        return .usb
    }

    private func detectIsV2(_ device: IOHIDDevice) -> Bool {
        if let pid = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? NSNumber {
            return pid.int32Value == DS4Constants.productIDv2
        }
        return false
    }

    // MARK: - Input Report Handling

    private func registerInputCallback(_ ds4Device: DS4HIDDevice) {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        ds4Device.inputBuffer.withUnsafeMutableBufferPointer { bufferPtr in
            guard let baseAddress = bufferPtr.baseAddress else { return }
            IOHIDDeviceRegisterInputReportCallback(
                ds4Device.device, baseAddress, DS4Constants.maxInputReportSize,
                { context, _, sender, _, reportID, report, reportLength in
                    guard let context, let sender else { return }
                    let provider = Unmanaged<DualShock4HIDProvider>.fromOpaque(context).takeUnretainedValue()
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
        guard connectedDevices[device] != nil else { return }
        let ds4Device = connectedDevices[device]!

        let psPressed: Bool?

        if ds4Device.transport == .usb && reportID == UInt32(DS4Constants.usbInputReportID) {
            // USB: buttons[2] is at byte offset 7 in the input report
            guard data.count > 7 else { return }
            psPressed = (data[7] & DS4Constants.buttonPS) != 0
        } else if ds4Device.transport == .bluetooth && reportID == UInt32(DS4Constants.btInputReportID) {
            // BT: input data offset by 2 bytes, buttons[2] at byte offset 9
            guard data.count > 9 else { return }
            psPressed = (data[9] & DS4Constants.buttonPS) != 0
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
        guard let ds4Device = connectedDevices.values.first else { return }
        switch ds4Device.transport {
        case .usb: sendUSBOutput(ds4Device, rumbleLeft: left, rumbleRight: right)
        case .bluetooth: sendBTOutput(ds4Device, rumbleLeft: left, rumbleRight: right)
        }
    }

    func applyAdaptiveTrigger(effect: AdaptiveTriggerEffect, side: TriggerSide) {
        // DualShock 4 does not support adaptive triggers — no-op
    }

    func setLEDColor(red: UInt8, green: UInt8, blue: UInt8) {
        guard let ds4Device = connectedDevices.values.first else { return }
        switch ds4Device.transport {
        case .usb: sendUSBOutput(ds4Device, ledRed: red, ledGreen: green, ledBlue: blue)
        case .bluetooth: sendBTOutput(ds4Device, ledRed: red, ledGreen: green, ledBlue: blue)
        }
    }

    func supportsFeedback(_ type: FeedbackType) -> Bool {
        switch type {
        case .rumble: return true
        case .adaptiveTrigger: return false
        case .ledColor: return true
        }
    }

    // MARK: - USB Output Report

    private func sendUSBOutput(_ ds4Device: DS4HIDDevice,
                               rumbleLeft: UInt8 = 0, rumbleRight: UInt8 = 0,
                               ledRed: UInt8? = nil, ledGreen: UInt8? = nil, ledBlue: UInt8? = nil) {
        var report = [UInt8](repeating: 0, count: DS4Constants.usbOutputReportSize)

        report[0] = DS4Constants.usbOutputReportID
        // Flags: bit 0 = rumble, bit 1 = LED
        var flags: UInt8 = 0x01  // rumble
        if ledRed != nil { flags |= 0x02 }
        report[1] = flags

        // Padding
        report[2] = 0x00
        report[3] = 0x00

        // Rumble motors
        report[4] = rumbleRight  // light motor (high frequency)
        report[5] = rumbleLeft   // heavy motor (low frequency)

        // LED color
        report[6] = ledRed ?? 0
        report[7] = ledGreen ?? 0
        report[8] = ledBlue ?? 0

        IOHIDDeviceSetReport(ds4Device.device, kIOHIDReportTypeOutput,
                             CFIndex(DS4Constants.usbOutputReportID), report, report.count)
    }

    // MARK: - Bluetooth Output Report

    private func sendBTOutput(_ ds4Device: DS4HIDDevice,
                              rumbleLeft: UInt8 = 0, rumbleRight: UInt8 = 0,
                              ledRed: UInt8? = nil, ledGreen: UInt8? = nil, ledBlue: UInt8? = nil) {
        var report = [UInt8](repeating: 0, count: DS4Constants.btOutputReportSize)

        report[0] = DS4Constants.btOutputReportID

        // BT header: transaction type + flags
        report[1] = 0x80  // HID output
        report[2] = 0x00

        // Flags
        var flags: UInt8 = 0x01  // rumble
        if ledRed != nil { flags |= 0x02 }
        report[3] = flags

        // Padding
        report[4] = 0x00
        report[5] = 0x00

        // Rumble motors
        report[6] = rumbleRight  // light motor
        report[7] = rumbleLeft   // heavy motor

        // LED color
        report[8] = ledRed ?? 0
        report[9] = ledGreen ?? 0
        report[10] = ledBlue ?? 0

        // Flash on/off timing (keep LEDs solid)
        report[11] = 0x00
        report[12] = 0x00

        // CRC32
        let crc = computeBTCRC32(report: report)
        let crcOffset = report.count - 4
        report[crcOffset + 0] = UInt8(crc & 0xFF)
        report[crcOffset + 1] = UInt8((crc >> 8) & 0xFF)
        report[crcOffset + 2] = UInt8((crc >> 16) & 0xFF)
        report[crcOffset + 3] = UInt8((crc >> 24) & 0xFF)

        IOHIDDeviceSetReport(ds4Device.device, kIOHIDReportTypeOutput,
                             CFIndex(DS4Constants.btOutputReportID), report, report.count)
    }

    // MARK: - CRC32

    private func computeBTCRC32(report: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        crc = crc32UpdateByte(crc, byte: DS4Constants.btCRC32Seed)
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
        logInfo("DS4HID: Provider shut down")
    }

    /// Whether a DualShock 4 is connected via HID
    var hasConnectedDevice: Bool { !connectedDevices.isEmpty }
}

#endif
