// SPDX-License-Identifier: AGPL-3.0-only
//
// DiagnosticsExporter.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Utility to export diagnostic information with sensitive data anonymized
// @requirement F-019 - 完善日志系统

import Foundation
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

/// Exporter for diagnostic information
/// @requirement F-019 - 完善日志系统
/// @satisfies AC-051 - 诊断包生成
/// @satisfies AC-053 - 诊断包数据脱敏
final class DiagnosticsExporter: Sendable {
    
    /// Export all diagnostic data to a single file/package
    /// @satisfies AC-051 - 诊断包生成
    func export() async throws -> URL {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ChiakiDiagnostics-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // 1. Gather Logs
        let logsDir = tempDir.appendingPathComponent("logs")
        try fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true)
        if let sourceLogsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Logs") {
            if let logFiles = try? fileManager.contentsOfDirectory(at: sourceLogsDir, includingPropertiesForKeys: nil) {
                for logFile in logFiles {
                    let destFile = logsDir.appendingPathComponent(logFile.lastPathComponent)
                    if let content = try? String(contentsOf: logFile) {
                        let anonymized = anonymizeLogContent(content)
                        try? anonymized.write(to: destFile, atomically: true, encoding: .utf8)
                    }
                }
            }
        }
        
        // 2. Gather System Info
        let infoDir = tempDir.appendingPathComponent("info")
        try fileManager.createDirectory(at: infoDir, withIntermediateDirectories: true)
        let deviceInfo = gatherDeviceInfo()
        if let data = try? JSONEncoder().encode(deviceInfo) {
            try? data.write(to: infoDir.appendingPathComponent("device.json"))
        }
        
        // 3. Gather Config (Anonymized)
        let configDir = tempDir.appendingPathComponent("config")
        try fileManager.createDirectory(at: configDir, withIntermediateDirectories: true)
        
        if CrashReporter.shared.hasCrashReport() {
            if let crashReport = try? CrashReporter.shared.readCrashReport() {
                try? crashReport.write(to: infoDir.appendingPathComponent("crash_report.log"), atomically: true, encoding: .utf8)
            }
        }
        
        let hostsData = await MainActor.run { try? HostStore.shared.exportHosts() }
        if let hostsData = hostsData,
           let hosts = try? JSONSerialization.jsonObject(with: hostsData) as? [[String: Any]] {
            let anonymizedHosts = hosts.map { host in
                var h = host
                if let ip = h["address"] as? String { h["address"] = anonymizeIP(ip) }
                if let mac = h["macAddress"] as? String { h["macAddress"] = anonymizeMAC(mac) }
                h["registKey"] = "[REDACTED]"
                h["rpKey"] = "[REDACTED]"
                return h
            }
            if let data = try? JSONSerialization.data(withJSONObject: anonymizedHosts, options: [.prettyPrinted]) {
                try? data.write(to: configDir.appendingPathComponent("hosts.json"))
            }
        }
        
        // Settings
        let settingsData = await MainActor.run { try? SettingsStore.shared.exportSettings() }
        if let settingsData = settingsData {
            try? settingsData.write(to: configDir.appendingPathComponent("settings.json"))
        }
        
        // 4. Create ZIP
        return try await withCheckedThrowingContinuation { continuation in
            let coordinator = NSFileCoordinator()
            var error: NSError?
            
            coordinator.coordinate(readingItemAt: tempDir, options: .forUploading, error: &error) { zipURL in
                let finalZipURL = fileManager.temporaryDirectory.appendingPathComponent("Chiaki-Diagnostics-\(Int(Date().timeIntervalSince1970)).zip")
                do {
                    if fileManager.fileExists(atPath: finalZipURL.path) {
                        try fileManager.removeItem(at: finalZipURL)
                    }
                    try fileManager.copyItem(at: zipURL, to: finalZipURL)
                    continuation.resume(returning: finalZipURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            if let error = error {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func anonymizeLogContent(_ content: String) -> String {
        var result = content
        
        let ipRegex = try? NSRegularExpression(pattern: "\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b")
        if let matches = ipRegex?.matches(in: result, range: NSRange(result.startIndex..., in: result)) {
            for match in matches.reversed() {
                if let range = Range(match.range, in: result) {
                    let ip = String(result[range])
                    result.replaceSubrange(range, with: anonymizeIP(ip))
                }
            }
        }
        
        let macRegex = try? NSRegularExpression(pattern: "\\b(?:[0-9A-Fa-f]{2}[:-]){5}(?:[0-9A-Fa-f]{2})\\b")
        if let matches = macRegex?.matches(in: result, range: NSRange(result.startIndex..., in: result)) {
            for match in matches.reversed() {
                if let range = Range(match.range, in: result) {
                    let mac = String(result[range])
                    result.replaceSubrange(range, with: anonymizeMAC(mac))
                }
            }
        }
        
        let keyRegex = try? NSRegularExpression(pattern: "\\b[0-9A-Fa-f]{16,}\\b")
        if let matches = keyRegex?.matches(in: result, range: NSRange(result.startIndex..., in: result)) {
            for match in matches.reversed() {
                if let range = Range(match.range, in: result) {
                    result.replaceSubrange(range, with: "[REDACTED]")
                }
            }
        }
        
        return result
    }
    
    private func gatherDeviceInfo() -> [String: String] {
        #if os(iOS) || os(tvOS)
        let device = UIDevice.current
        return [
            "model": device.model,
            "systemName": device.systemName,
            "systemVersion": device.systemVersion,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]
        #elseif os(macOS)
        return [
            "model": "Mac",
            "systemVersion": ProcessInfo.processInfo.operatingSystemVersionString,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]
        #endif
    }
    
    // MARK: - Anonymization Methods
    
    /// Anonymizes an IP address: 192.168.1.100 -> 192.168.xxx.xxx
    /// @satisfies AC-053 - 诊断包数据脱敏
    func anonymizeIP(_ ip: String) -> String {
        let components = ip.components(separatedBy: ".")
        if components.count == 4 {
            return "\(components[0]).\(components[1]).xxx.xxx"
        }
        return "xxx.xxx.xxx.xxx"
    }
    
    /// Anonymizes a token: abcdefghijkl -> abcd...
    /// @satisfies AC-053 - 诊断包数据脱敏
    func anonymizeToken(_ token: String) -> String {
        if token.count > 8 {
            let prefix = token.prefix(8)
            return "\(prefix)..."
        }
        return "..."
    }
    
    /// Anonymizes a user ID: SHA256 hash then prefix
    /// @satisfies AC-053 - 诊断包数据脱敏
    func anonymizeUserID(_ userID: String) -> String {
        guard let data = userID.data(using: .utf8) else { return "xxxxxxxx" }
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        return String(hashString.prefix(16))
    }
    
    /// Anonymizes a MAC address: AA:BB:CC:DD:EE:FF -> AA:BB:CC:xx:xx:xx
    /// @satisfies AC-053 - 诊断包数据脱敏
    func anonymizeMAC(_ mac: String) -> String {
        let components = mac.components(separatedBy: ":")
        if components.count == 6 {
            return "\(components[0]):\(components[1]):\(components[2]):xx:xx:xx"
        }
        return "xx:xx:xx:xx:xx:xx"
    }
    
    /// Redacts a registration key entirely
    /// @satisfies AC-053 - 诊断包数据脱敏
    func redactKey(_ key: String) -> String {
        return "[REDACTED]"
    }
}
