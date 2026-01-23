// SPDX-License-Identifier: AGPL-3.0-only
//
// RegistrationViewModel.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// ViewModel for the host registration (pairing) process

import Foundation
import Observation

@Observable
final class RegistrationViewModel {
    // MARK: - Properties

    var hostAddress: String = ""
    var pin: String = ""
    var psnAccountId: String = ""
    var isPS5: Bool = true

    private(set) var state: RegistrationState = .idle
    private let registWrapper = ChiakiRegistWrapper()
    private let hostManager: HostManager

    // MARK: - Initialization

    init(hostManager: HostManager) {
        self.hostManager = hostManager
        
        registWrapper.onStateChanged = { [weak self] state in
            self?.state = state
            
            if case .success(let registKey, let rpKey) = state {
                self?.saveHost(registKey: registKey, rpKey: rpKey)
            }
        }
    }
    
    // MARK: - Actions
    
    func startRegistration() {
        guard !hostAddress.isEmpty, !pin.isEmpty else {
            state = .error("Host address and PIN are required")
            return
        }
        
        guard pin.count == 8, CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: pin)) else {
            state = .error("PIN must be exactly 8 digits")
            return
        }
        
        var psnIdData: Data? = nil
        if !psnAccountId.isEmpty {
            // PSN Account ID can be in multiple formats:
            // 1. Base64 encoded (most common from PSN tools, e.g., "GIsaQUzezzA=")
            // 2. Hex string (16 characters, e.g., "188b1a414cdecf30")
            // 3. Decimal integer (e.g., "1774920234836856624")
            // libchiaki expects exactly 8 bytes.

            // Try Base64 first (most common format)
            if let data = Data(base64Encoded: psnAccountId), data.count == 8 {
                psnIdData = data
            }
            // Try hex string
            else if let data = Data(hexString: psnAccountId), data.count == 8 {
                psnIdData = data
            }
            // Try decimal
            else if let val = UInt64(psnAccountId) {
                var bigEndian = val.bigEndian
                psnIdData = withUnsafeBytes(of: &bigEndian) { Data($0) }
            }
        }
        
        do {
            try registWrapper.start(host: hostAddress, isPS5: isPS5, pin: pin, psnAccountId: psnIdData)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    func cancelRegistration() {
        registWrapper.stop()
    }
    
    // MARK: - Private Methods
    
    private func saveHost(registKey: Data, rpKey: Data) {
        Task { @MainActor in
            let host = ConsoleHost(
                nickname: isPS5 ? "PlayStation 5" : "PlayStation 4",
                address: hostAddress,
                isPS5: isPS5,
                registKey: registKey,
                rpKey: rpKey,
                rpKeyType: isPS5 ? 2 : 1 // Typical values
            )
            // Use HostManager to ensure proper synchronization with UI
            hostManager.addHost(host)
        }
    }
}

// MARK: - Hex Helper

extension Data {
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        for i in 0..<len {
            let j = hexString.index(hexString.startIndex, offsetBy: i * 2)
            let k = hexString.index(j, offsetBy: 2)
            let bytes = hexString[j..<k]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
        }
        self = data
    }
}
