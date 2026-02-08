// SPDX-License-Identifier: AGPL-3.0-only
//
// NetworkMonitor.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Monitoring network connectivity for auto-reconnection (F-016)
//

import Foundation
import Network
import Observation

/// 网络状态监控器
/// [requirement] F-016, F-029
/// [satisfies] AC-045, AC-054, AC-103
@Observable
@MainActor
final class NetworkMonitor {
    // MARK: - Singleton
    
    static let shared = NetworkMonitor()
    
    // MARK: - Properties
    
    private(set) var isConnected: Bool = true
    private(set) var isCellular: Bool = false
    private(set) var currentInterfaceType: NWInterface.InterfaceType = .wifi
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.chiaki.network-monitor")
    
    // MARK: - Initialization
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }

            let isConnected = path.status == .satisfied
            let isCellular = path.isExpensive || path.usesInterfaceType(.cellular)
            let interfaceType: NWInterface.InterfaceType
            if path.usesInterfaceType(.wifi) {
                interfaceType = .wifi
            } else if path.usesInterfaceType(.cellular) {
                interfaceType = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                interfaceType = .wiredEthernet
            } else {
                interfaceType = .other
            }

            Task { @MainActor [self, isConnected, isCellular, interfaceType] in
                self.isConnected = isConnected
                self.isCellular = isCellular
                self.currentInterfaceType = interfaceType

                Logger.network.info("Network status changed: isConnected=\(isConnected), type=\(interfaceType), isCellular=\(isCellular)")
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}
