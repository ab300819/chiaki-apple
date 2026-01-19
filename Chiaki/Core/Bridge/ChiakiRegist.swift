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
        logInfo("ChiakiRegistWrapper: Initialized")
    }
    
    deinit {
        cleanup()
        cleanupChiakiLog()
        logInfo("ChiakiRegistWrapper: Deinitialized")
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
        
        // Host
        let hostCString = host.cString(using: .utf8)!
        info.host = UnsafePointer(strdup(hostCString))
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
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        updateState(.registering)
        
        // Start registration
        let result: ChiakiErrorCode
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
            result = chiaki_regist_start(regist, chiakiLog, &info, registrationCallback, selfPointer)
        } else {
            result = CHIAKI_ERR_SUCCESS
        }
        
        // Free host string (it's copied in chiaki_regist_start)
        free(UnsafeMutablePointer(mutating: info.host))
        
        guard result == CHIAKI_ERR_SUCCESS else {
            cleanup()
            let error = ChiakiError.from(result) ?? .unknown
            updateState(.error(error.description))
            throw error
        }
        
        logInfo("ChiakiRegistWrapper: Registration started for \(host)")
    }
    
    /// Stop registration process
    func stop() {
        registLock.lock()
        defer { registLock.unlock() }
        
        guard let regist = regist else { return }
        
        chiaki_regist_stop(regist)
        cleanup()
        
        updateState(.idle)
        logInfo("ChiakiRegistWrapper: Registration stopped")
    }
    
    // MARK: - Private Methods
    
    private func setupChiakiLog() {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        chiakiLog = UnsafeMutablePointer<ChiakiLog>.allocate(capacity: 1)
        guard let log = chiakiLog else { return }
        
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
    
    private func updateState(_ newState: RegistrationState) {
        state = newState
        DispatchQueue.main.async { [weak self] in
            self?.onStateChanged?(newState)
        }
    }
    
    // MARK: - Event Handling
    
    fileprivate func handleEvent(_ event: ChiakiRegistEvent) {
        switch event.type {
        case CHIAKI_REGIST_EVENT_TYPE_FINISHED_SUCCESS:
            if let hostInfo = event.registered_host?.pointee {
                let registKey = withUnsafeBytes(of: hostInfo.rp_regist_key) { Data($0) }
                let rpKey = withUnsafeBytes(of: hostInfo.rp_key) { Data($0) }
                logInfo("ChiakiRegistWrapper: Registration successful")
                updateState(.success(registKey: registKey, rpKey: rpKey))
            } else {
                updateState(.error("Registration succeeded but host info is missing"))
            }
            
        case CHIAKI_REGIST_EVENT_TYPE_FINISHED_FAILED:
            logError("ChiakiRegistWrapper: Registration failed")
            updateState(.error("Registration failed. Please check your PIN and network connection."))
            
        case CHIAKI_REGIST_EVENT_TYPE_FINISHED_CANCELED:
            logInfo("ChiakiRegistWrapper: Registration canceled")
            updateState(.idle)
            
        default:
            logWarning("ChiakiRegistWrapper: Unknown event type: \(event.type)")
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
        logError("[libchiaki-regist] \(message)")
    case .warning:
        logWarning("[libchiaki-regist] \(message)")
    case .info:
        logInfo("[libchiaki-regist] \(message)")
    case .verbose:
        logVerbose("[libchiaki-regist] \(message)")
    case .debug:
        logDebug("[libchiaki-regist] \(message)")
    }
}
