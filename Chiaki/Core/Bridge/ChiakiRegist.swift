// SPDX-License-Identifier: AGPL-3.0-only
//
// ChiakiRegist.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Swift wrapper for libchiaki host registration
// Handles the pairing flow between the client and a PlayStation console

import Foundation

// MARK: - Registration State

/// Registration state enumeration
enum RegistrationState: Equatable {
    case idle
    case registering
    case success(registKey: Data, rpKey: Data)
    case error(String)
}

// MARK: - Chiaki Registration Wrapper

/// Wrapper for libchiaki's registration API
@Observable
final class ChiakiRegistWrapper {
    // MARK: - Properties

    private(set) var state: RegistrationState = .idle
    
    private var regist: UnsafeMutablePointer<ChiakiRegist>?
    private var chiakiLog: UnsafeMutablePointer<ChiakiLog>?
    
    private let registLock = NSLock()
    
    // MARK: - Callbacks
    
    /// Called when registration state changes
    var onStateChanged: ((RegistrationState) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        setupChiakiLog()
        Logger.regist.info("ChiakiRegistWrapper: Initialized")
    }
    
    deinit {
        cleanup()
        cleanupChiakiLog()
        Logger.regist.info("ChiakiRegistWrapper: Deinitialized")
    }
    
    // MARK: - Registration Flow
    
    /// Start registration process
    /// - Parameters:
    ///   - host: IP address of the console
    ///   - isPS5: Whether it's a PS5
    ///   - pin: 8-digit PIN from the console
    ///   - psnAccountId: Optional PSN account ID (8 bytes)
    func start(host: String, isPS5: Bool, pin: String, psnAccountId: Data? = nil) throws {
        registLock.lock()
        defer { registLock.unlock() }
        
        let isErrorState: Bool
        if case .error = state {
            isErrorState = true
        } else {
            isErrorState = false
        }
        
        guard state == .idle || isErrorState else {
            throw ChiakiError.uninitialized // Or a better error
        }
        
        // Allocate regist
        regist = UnsafeMutablePointer<ChiakiRegist>.allocate(capacity: 1)
        
        // Setup regist info
        var info = ChiakiRegistInfo()
        
        // Target
        info.target = isPS5 ? CHIAKI_TARGET_PS5_1 : CHIAKI_TARGET_PS4_10 // Use sensible defaults
        
        /// Host - strdup + defer 确保所有退出路径释放
        /// @requirement F-038
        /// @satisfies AC-144 - 早退路径正确释放 strdup 分配的内存
        let hostCString = host.cString(using: .utf8)!
        guard let duplicatedHost = strdup(hostCString) else {
            cleanup()
            throw ChiakiError.memory
        }
        info.host = UnsafePointer(duplicatedHost)
        defer { free(duplicatedHost) }
        info.broadcast = false
        
        // PIN
        if let pinInt = UInt32(pin) {
            info.pin = pinInt
        } else {
            cleanup()
            throw ChiakiError.invalidData
        }
        
        // PSN Account ID
        if let accountId = psnAccountId, accountId.count == 8 {
            accountId.withUnsafeBytes { ptr in
                guard let baseAddress = ptr.baseAddress else { return }
                withUnsafeMutableBytes(of: &info.psn_account_id) { destPtr in
                    destPtr.copyMemory(from: UnsafeRawBufferPointer(start: baseAddress, count: 8))
                }
            }
        }
        
        // Callback
        // SAFETY: passUnretained is safe here because:
        // 1) registration callback lifetime is bounded by chiaki_regist_fini() in cleanup()/deinit
        // 2) self owns `regist` and remains alive while registration is active
        // 3) registLock protects teardown ordering for native pointer access
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        updateState(.registering)
        
        // Start registration
        let result: ChiakiErrorCode
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
            result = chiaki_regist_start(regist, chiakiLog, &info, registrationCallback, selfPointer)
        } else {
            result = CHIAKI_ERR_SUCCESS
        }
        
        guard result == CHIAKI_ERR_SUCCESS else {
            cleanup()
            let error = ChiakiError.from(result) ?? .unknown
            updateState(.error(error.description))
            throw error
        }
        
        Logger.regist.info("ChiakiRegistWrapper: Registration started for \(host)")
    }
    
    /// Stop registration process
    func stop() {
        registLock.lock()
        defer { registLock.unlock() }
        
        guard let regist = regist else { return }
        
        chiaki_regist_stop(regist)
        cleanup()
        
        updateState(.idle)
        Logger.regist.info("ChiakiRegistWrapper: Registration stopped")
    }
    
    // MARK: - Private Methods
    
    private func setupChiakiLog() {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        chiakiLog = UnsafeMutablePointer<ChiakiLog>.allocate(capacity: 1)
        guard let log = chiakiLog else { return }
        
        // SAFETY: passUnretained is safe here because:
        // 1) log callback lifetime is bounded by chiakiLog pointer lifetime on this wrapper
        // 2) self outlives chiaki_log_init registration and cleanup
        // 3) callback does not retain or transfer ownership of self
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        chiaki_log_init(log, ChiakiLogLevelMask.all.rawValue, chiakiRegistLogCallback, selfPointer)
    }
    
    private func cleanupChiakiLog() {
        guard let log = chiakiLog else { return }
        log.deallocate()
        chiakiLog = nil
    }
    
    private func cleanup() {
        if let regist = regist {
            chiaki_regist_fini(regist)
            regist.deallocate()
            self.regist = nil
        }
    }
    
    /// @requirement F-038
    /// @satisfies AC-145 - 属性写入统一到 MainActor，消除线程一致性隐患
    private func updateState(_ newState: RegistrationState) {
        let applyStateChange = { [weak self] in
            guard let self = self else { return }
            self.state = newState
            self.onStateChanged?(newState)
        }

        if Thread.isMainThread {
            applyStateChange()
        } else {
            DispatchQueue.main.async(execute: applyStateChange)
        }
    }
    
    // MARK: - Event Handling
    
    fileprivate func handleEvent(_ event: ChiakiRegistEvent) {
        switch event.type {
        case CHIAKI_REGIST_EVENT_TYPE_FINISHED_SUCCESS:
            if let hostInfo = event.registered_host?.pointee {
                let registKey = withUnsafeBytes(of: hostInfo.rp_regist_key) { Data($0) }
                let rpKey = withUnsafeBytes(of: hostInfo.rp_key) { Data($0) }
                Logger.regist.info("ChiakiRegistWrapper: Registration successful")
                updateState(.success(registKey: registKey, rpKey: rpKey))
            } else {
                updateState(.error("Registration succeeded but host info is missing"))
            }
            
        case CHIAKI_REGIST_EVENT_TYPE_FINISHED_FAILED:
            Logger.regist.error("ChiakiRegistWrapper: Registration failed")
            updateState(.error("Registration failed. Please check your PIN and network connection."))
            
        case CHIAKI_REGIST_EVENT_TYPE_FINISHED_CANCELED:
            Logger.regist.info("ChiakiRegistWrapper: Registration canceled")
            updateState(.idle)
            
        default:
            Logger.regist.warning("ChiakiRegistWrapper: Unknown event type: \(event.type)")
        }
        
        // Once finished, we can cleanup
        cleanup()
    }
}

// MARK: - C Callbacks

private func registrationCallback(
    event: UnsafeMutablePointer<ChiakiRegistEvent>?,
    userData: UnsafeMutableRawPointer?
) {
    guard let event = event, let userData = userData else { return }
    
    // SAFETY: userData was created via passUnretained(self) at registration start.
    // cleanup()/deinit calls chiaki_regist_fini() to stop callbacks before wrapper release.
    let wrapper = Unmanaged<ChiakiRegistWrapper>.fromOpaque(userData).takeUnretainedValue()
    
    // Process event - copy data if needed
    let eventCopy = event.pointee
    
    // Note: event.registered_host might point to memory that will be freed after callback.
    // However, chiaki_regist usually keeps it alive until fini or similar, but let's be safe.
    // In this case, we handle it in handleEvent which is called immediately.
    
    wrapper.handleEvent(eventCopy)
}

private func chiakiRegistLogCallback(
    level: ChiakiLogLevel,
    msg: UnsafePointer<CChar>?,
    userData: UnsafeMutableRawPointer?
) {
    guard let msg = msg else { return }
    
    let message = String(cString: msg)
    let severity = ChiakiLogSeverity.from(level)
    
    switch severity {
    case .error:
        Logger.regist.error("[libchiaki-regist] \(message)")
    case .warning:
        Logger.regist.warning("[libchiaki-regist] \(message)")
    case .info:
        Logger.regist.info("[libchiaki-regist] \(message)")
    case .verbose:
        Logger.regist.debug("[libchiaki-regist] \(message)")
    case .debug:
        Logger.regist.debug("[libchiaki-regist] \(message)")
    }
}
