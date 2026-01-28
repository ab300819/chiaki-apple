// SPDX-License-Identifier: AGPL-3.0-only
//
// FileLogHandler.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// File logging handler with automatic rotation and cleanup
// @requirement F-019 - 完善日志系统

import Foundation

/// A log handler that writes messages to a file with rotation support
/// @requirement F-019 - 完善日志系统
/// @satisfies AC-049 - 日志写入 Documents/Logs
/// @satisfies AC-050 - 日志文件轮换与清理
final class FileLogHandler: LogHandler, @unchecked Sendable {
    private let fileManager = FileManager.default
    private let logDirectory: URL
    private let currentLogURL: URL
    private let maxFileSize: Int64 = 5 * 1024 * 1024 // 5MB
    private let maxFiles = 7
    
    // Serial queue for thread-safe file operations
    private let queue = DispatchQueue(label: "ltd.hotter.chiaki.filelogger", qos: .background)
    private var fileHandle: FileHandle?

    init() throws {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsURL = paths[0]
        self.logDirectory = documentsURL.appendingPathComponent("Logs")
        self.currentLogURL = logDirectory.appendingPathComponent("chiaki-current.log")
        
        if !fileManager.fileExists(atPath: logDirectory.path) {
            try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        }
        
        if !fileManager.fileExists(atPath: currentLogURL.path) {
            fileManager.createFile(atPath: currentLogURL.path, contents: nil)
        }
        
        self.fileHandle = try FileHandle(forWritingTo: currentLogURL)
        self.fileHandle?.seekToEndOfFile()
    }

    /// Logs a message to the file
    /// @satisfies AC-049 - 日志写入 Documents/Logs
    func log(level: ChiakiLogSeverity, message: String, category: String, file: String, function: String, line: Int) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.rotateIfNeeded()
            
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let fileName = (file as NSString).lastPathComponent
            let logLine = "[\(timestamp)] [\(level.symbol)] [\(category)] [\(fileName):\(line)] \(message)\n"
            
            if let data = logLine.data(using: .utf8) {
                self.fileHandle?.write(data)
            }
        }
    }

    /// Checks if rotation is needed and performs it
    /// @satisfies AC-050 - 日志文件轮换与清理
    private func rotateIfNeeded() {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: currentLogURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            if fileSize >= maxFileSize {
                fileHandle?.closeFile()
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd-HHmmss"
                let timestamp = formatter.string(from: Date())
                let archivedLogURL = logDirectory.appendingPathComponent("chiaki-\(timestamp).log")
                
                try fileManager.moveItem(at: currentLogURL, to: archivedLogURL)
                fileManager.createFile(atPath: currentLogURL.path, contents: nil)
                fileHandle = try FileHandle(forWritingTo: currentLogURL)
                
                cleanupOldLogs()
            }
        } catch {}
    }

    private func cleanupOldLogs() {
        do {
            let files = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            let logFiles = files.filter { $0.lastPathComponent.hasPrefix("chiaki-") && $0.lastPathComponent != "chiaki-current.log" }
            
            if logFiles.count > maxFiles {
                let sortedFiles = try logFiles.sorted {
                    let date1 = try $0.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                    let date2 = try $1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                    return date1 < date2
                }
                
                let filesToDelete = sortedFiles.prefix(logFiles.count - maxFiles)
                for fileURL in filesToDelete {
                    try fileManager.removeItem(at: fileURL)
                }
            }
        } catch {}
    }
}
