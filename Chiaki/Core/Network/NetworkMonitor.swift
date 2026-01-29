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

/**
 * 网络状态监控器
 * @requirement F-016 - 网络弹性与自动重连
 * @satisfies AC-045 - 自动重连机制
 */
@Observable
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
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.isCellular = path.isExpensive || path.usesInterfaceType(.cellular)
                
                if path.usesInterfaceType(.wifi) {
                    self?.currentInterfaceType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.currentInterfaceType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.currentInterfaceType = .wiredEthernet
                } else {
                    self?.currentInterfaceType = .other
                }
                
                Logger.network.info("Network status changed: isConnected=\(path.status == .satisfied), type=\(self?.currentInterfaceType ?? .other), isCellular=\(self?.isCellular ?? false)")
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}
