// SPDX-License-Identifier: AGPL-3.0-only
//
// ChiakiDiscovery.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Swift wrapper for libchiaki discovery service
// Handles PlayStation console discovery on local network

import Foundation
import Combine
import Network
import Darwin

// MARK: - Discovered Host

struct DiscoveredHost: Identifiable, Equatable, Hashable {
    let id: String
    let address: String
    let state: HostState
    let isPS5: Bool
    let hostName: String
    let systemVersion: String?
    let runningApp: String?
    let runningAppId: String?

    init?(from native: ChiakiDiscoveryHost) {
        guard let hostIdPtr = native.host_id else { return nil }
        self.id = String(cString: hostIdPtr)
        self.address = native.host_addr != nil ? String(cString: native.host_addr!) : ""
        
        var mutableNative = native
        self.isPS5 = chiaki_discovery_host_is_ps5(&mutableNative)
        
        self.hostName = native.host_name != nil ? String(cString: native.host_name!) : "PlayStation"
        self.systemVersion = native.system_version != nil ? String(cString: native.system_version!) : nil
        self.runningApp = native.running_app_name != nil ? String(cString: native.running_app_name!) : nil
        self.runningAppId = native.running_app_titleid != nil ? String(cString: native.running_app_titleid!) : nil
        
        switch native.state {
        case CHIAKI_DISCOVERY_HOST_STATE_READY:
            self.state = .online
        case CHIAKI_DISCOVERY_HOST_STATE_STANDBY:
            self.state = .standby
        default:
            self.state = .unknown
        }
    }

    func toConsoleHost(mergedWith existing: ConsoleHost? = nil) -> ConsoleHost {
        var host = existing ?? ConsoleHost(
            nickname: hostName,
            address: address,
            isPS5: isPS5
        )
        host.state = state
        if host.address != address {
            host.address = address
        }
        return host
    }
}

// MARK: - Discovery Service

@MainActor
final class DiscoveryService: ObservableObject {
    @Published private(set) var discoveredHosts: [DiscoveredHost] = []
    @Published private(set) var isDiscovering: Bool = false
    @Published private(set) var lastError: String?

    private var nativeService = chiaki_discovery_service_t()
    private var isInitialized = false

    init() {
        Logger.discovery.info("DiscoveryService initialized")
    }

    deinit {
    }

    func startDiscovery() {
        guard !isDiscovering else { return }

        lastError = nil
        
        var options = ChiakiDiscoveryServiceOptions()
        options.hosts_max = 64
        options.host_drop_pings = 5
        options.ping_ms = 5000
        options.ping_initial_ms = 1000
        options.cb = { hosts, count, user in
            guard let user = user else { return }
            let service = Unmanaged<DiscoveryService>.fromOpaque(user).takeUnretainedValue()
            
            var discovered: [DiscoveredHost] = []
            if let hosts = hosts {
                for i in 0..<count {
                    if let host = DiscoveredHost(from: hosts[i]) {
                        discovered.append(host)
                    }
                }
            }
            
            Task { @MainActor in
                service.updateDiscoveredHosts(discovered)
            }
        }
        options.cb_user = Unmanaged.passUnretained(self).toOpaque()
        
        var sendAddr = sockaddr_in()
        sendAddr.sin_family = sa_family_t(AF_INET)
        sendAddr.sin_addr.s_addr = 0xffffffff
        sendAddr.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
        
        let result: ChiakiErrorCode = withUnsafePointer(to: &sendAddr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr_storage.self, capacity: 1) { storagePtr in
                options.send_addr = UnsafeMutablePointer(mutating: storagePtr)
                options.send_addr_size = MemoryLayout<sockaddr_in>.size
                return chiaki_discovery_service_init(&nativeService, &options, ChiakiLogBridge.shared.getLogPointer())
            }
        }

        if result == CHIAKI_ERR_SUCCESS {
            isInitialized = true
            isDiscovering = true
            Logger.discovery.info("Discovery started")
        } else {
            let error = ChiakiError.from(result) ?? .unknown
            lastError = "Failed to initialize discovery: \(error.description)"
            Logger.discovery.error("Discovery failed to start: \(error.description)")
        }
    }

    func stopDiscovery() {
        guard isDiscovering else { return }

        if isInitialized {
            chiaki_discovery_service_fini(&nativeService)
            isInitialized = false
        }
        
        isDiscovering = false
        Logger.discovery.info("Discovery stopped")
    }

    func wakeUp(host: ConsoleHost) async throws {
        guard !host.address.isEmpty else {
            throw DiscoveryError.invalidAddress
        }
        guard !host.registKey.isEmpty else {
            throw DiscoveryError.notRegistered
        }

        Logger.discovery.info("Sending wake-up to \(host.nickname) at \(host.address)")

        guard let registKeyStr = String(data: host.registKey.prefix(while: { $0 != 0 }), encoding: .utf8),
              let credential = UInt64(registKeyStr, radix: 16) else {
            Logger.discovery.error("Invalid registration key for wake-up")
            throw DiscoveryError.invalidRegistrationKey
        }

        let result = chiaki_discovery_wakeup(
            ChiakiLogBridge.shared.getLogPointer(),
            isInitialized ? &nativeService.discovery : nil,
            host.address.cString(using: .utf8),
            credential,
            host.isPS5
        )

        if result != CHIAKI_ERR_SUCCESS {
            let error = ChiakiError.from(result) ?? .unknown
            Logger.discovery.error("Wake-up failed: \(error.description)")
            throw DiscoveryError.wakeUpFailed
        }

        Logger.discovery.info("Wake-up packet sent")
    }

    func updateDiscoveredHosts(_ hosts: [DiscoveredHost]) {
        self.discoveredHosts = hosts
    }
}

// MARK: - Discovery Error

enum DiscoveryError: Error, LocalizedError {
    case invalidAddress
    case notRegistered
    case invalidRegistrationKey
    case notInitialized
    case initializationFailed
    case wakeUpFailed

    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "Invalid host address"
        case .notRegistered:
            return "Host is not registered"
        case .invalidRegistrationKey:
            return "Invalid registration key"
        case .notInitialized:
            return "Discovery service not initialized"
        case .initializationFailed:
            return "Failed to initialize discovery"
        case .wakeUpFailed:
            return "Failed to send wake-up packet"
        }
    }
}


