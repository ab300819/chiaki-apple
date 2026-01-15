// SPDX-License-Identifier: AGPL-3.0-only
//
// CircularAudioBuffer.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Lock-free circular buffer for audio streaming
// Design based on chiaki-ng/android circular-buf.hpp SPSC model

import Foundation

// MARK: - Lock-free SPSC Queue

/// Simple Lock-free Single Producer Single Consumer queue
/// Used internally by CircularAudioBuffer for chunk management
final class LockFreeQueue<T> {
    private var buffer: [T?]
    private var head: Int  // Read index (consumer)
    private var tail: Int  // Write index (producer)
    private let capacity: Int

    init(capacity: Int) {
        // Need one extra slot to distinguish full/empty
        self.capacity = capacity + 1
        self.buffer = Array(repeating: nil, count: self.capacity)
        self.head = 0
        self.tail = 0
    }

    /// Push value to queue (producer thread)
    /// - Returns: true if successful, false if queue is full
    @discardableResult
    func push(_ value: T) -> Bool {
        let currentTail = tail
        let nextTail = (currentTail + 1) % capacity

        // Check if full (would overwrite head)
        if nextTail == head {
            return false
        }

        buffer[currentTail] = value
        // Memory barrier for visibility across threads
        OSMemoryBarrier()
        tail = nextTail
        return true
    }

    /// Pop value from queue (consumer thread)
    /// - Returns: value if available, nil if queue is empty
    func pop() -> T? {
        let currentHead = head

        // Check if empty
        if currentHead == tail {
            return nil
        }

        let value = buffer[currentHead]
        buffer[currentHead] = nil
        // Memory barrier for visibility across threads
        OSMemoryBarrier()
        head = (currentHead + 1) % capacity
        return value
    }

    /// Current number of items in queue
    var count: Int {
        let h = head
        let t = tail
        return t >= h ? t - h : capacity - h + t
    }

    /// Whether queue is empty
    var isEmpty: Bool {
        return head == tail
    }
}

// MARK: - Circular Audio Buffer

/// Lock-free circular buffer for audio streaming
/// Uses chunk-based allocation to minimize memory operations
/// Supports single producer (audio decoder) and single consumer (audio renderer)
final class CircularAudioBuffer<T> {
    // MARK: - Configuration

    private let chunkCount: Int
    private let chunkSize: Int

    // MARK: - Storage

    private var chunks: [UnsafeMutablePointer<T>]
    private var chunkIndices: [Int]  // Maps chunk pointer to index
    private let freeQueue: LockFreeQueue<Int>
    private let fullQueue: LockFreeQueue<Int>

    // Current chunk being written (producer)
    private var pushChunk: UnsafeMutablePointer<T>?
    private var pushChunkIndex: Int = -1
    private var pushChunkOffset: Int = 0

    // Current chunk being read (consumer)
    private var popChunk: UnsafeMutablePointer<T>?
    private var popChunkIndex: Int = -1
    private var popChunkOffset: Int = 0

    // Statistics
    private(set) var overrunCount: UInt64 = 0  // Buffer full, had to drop

    // MARK: - Initialization

    /// Initialize circular buffer
    /// - Parameters:
    ///   - chunkCount: Number of chunks (default 32)
    ///   - chunkSize: Elements per chunk (default 512, equals 1024 bytes for Int16)
    init(chunkCount: Int = 32, chunkSize: Int = 512) {
        self.chunkCount = chunkCount
        self.chunkSize = chunkSize

        // Allocate chunks
        self.chunks = (0..<chunkCount).map { _ in
            UnsafeMutablePointer<T>.allocate(capacity: chunkSize)
        }
        self.chunkIndices = Array(0..<chunkCount)

        // Initialize queues
        self.freeQueue = LockFreeQueue(capacity: chunkCount)
        self.fullQueue = LockFreeQueue(capacity: chunkCount)

        // All chunks start as free
        for i in 0..<chunkCount {
            freeQueue.push(i)
        }

        logInfo("CircularAudioBuffer: Created with \(chunkCount) chunks × \(chunkSize) elements")
    }

    deinit {
        for chunk in chunks {
            chunk.deallocate()
        }
        logInfo("CircularAudioBuffer: Deinitialized")
    }

    // MARK: - Producer Methods (Push)

    /// Push data to buffer (called from audio decoder thread)
    /// - Parameters:
    ///   - buffer: Source data pointer
    ///   - count: Number of elements to push
    /// - Returns: Number of elements actually written
    @discardableResult
    func push(_ buffer: UnsafePointer<T>, count: Int) -> Int {
        var pushed = 0

        while pushed < count {
            // Get a free chunk if we don't have one
            if pushChunk == nil {
                if let chunkIndex = freeQueue.pop() {
                    pushChunk = chunks[chunkIndex]
                    pushChunkIndex = chunkIndex
                    pushChunkOffset = 0
                } else if let oldIndex = fullQueue.pop() {
                    // Buffer full - overwrite oldest data
                    pushChunk = chunks[oldIndex]
                    pushChunkIndex = oldIndex
                    pushChunkOffset = 0
                    overrunCount += 1
                } else {
                    // Should not happen with proper queue sizing
                    break
                }
            }

            // Calculate how much we can write
            let toPush = min(count - pushed, chunkSize - pushChunkOffset)

            // Copy data
            pushChunk!.advanced(by: pushChunkOffset).update(
                from: buffer.advanced(by: pushed),
                count: toPush
            )

            pushed += toPush
            pushChunkOffset += toPush

            // Chunk full - move to full queue
            if pushChunkOffset == chunkSize {
                fullQueue.push(pushChunkIndex)
                pushChunk = nil
                pushChunkIndex = -1
                pushChunkOffset = 0
            }
        }

        return pushed
    }

    // MARK: - Consumer Methods (Pop)

    /// Pop data from buffer (called from audio render thread)
    /// - Parameters:
    ///   - buffer: Destination data pointer
    ///   - count: Number of elements to read
    /// - Returns: Number of elements actually read
    @discardableResult
    func pop(_ buffer: UnsafeMutablePointer<T>, count: Int) -> Int {
        var popped = 0

        while popped < count {
            // Get a full chunk if we don't have one
            if popChunk == nil {
                guard let chunkIndex = fullQueue.pop() else {
                    break  // Buffer empty
                }
                popChunk = chunks[chunkIndex]
                popChunkIndex = chunkIndex
                popChunkOffset = 0
            }

            // Calculate how much we can read
            let toPop = min(count - popped, chunkSize - popChunkOffset)

            // Copy data
            buffer.advanced(by: popped).update(
                from: popChunk!.advanced(by: popChunkOffset),
                count: toPop
            )

            popped += toPop
            popChunkOffset += toPop

            // Chunk consumed - return to free queue
            if popChunkOffset == chunkSize {
                freeQueue.push(popChunkIndex)
                popChunk = nil
                popChunkIndex = -1
                popChunkOffset = 0
            }
        }

        return popped
    }

    // MARK: - Control Methods

    /// Reset buffer (clear all data)
    func reset() {
        // Return all full chunks to free queue
        while let index = fullQueue.pop() {
            freeQueue.push(index)
        }

        // Return current working chunks
        if pushChunkIndex >= 0 {
            freeQueue.push(pushChunkIndex)
        }
        if popChunkIndex >= 0 {
            freeQueue.push(popChunkIndex)
        }

        pushChunk = nil
        pushChunkIndex = -1
        pushChunkOffset = 0
        popChunk = nil
        popChunkIndex = -1
        popChunkOffset = 0

        logInfo("CircularAudioBuffer: Reset")
    }

    /// Reset statistics
    func resetStatistics() {
        overrunCount = 0
    }

    // MARK: - Status

    /// Number of full chunks currently buffered
    var bufferedChunkCount: Int {
        fullQueue.count
    }

    /// Approximate number of elements currently buffered
    var bufferedElementCount: Int {
        fullQueue.count * chunkSize
    }

    /// Total buffer capacity in elements
    var totalCapacity: Int {
        chunkCount * chunkSize
    }

    /// Buffer fill ratio (0.0 - 1.0)
    var fillRatio: Double {
        Double(bufferedChunkCount) / Double(chunkCount)
    }

    /// Whether buffer is empty
    var isEmpty: Bool {
        fullQueue.isEmpty && popChunk == nil
    }
}

// MARK: - Convenience Extensions

extension CircularAudioBuffer where T == Float {
    /// Fill buffer with silence (zeros)
    func fillWithSilence(_ buffer: UnsafeMutablePointer<Float>, count: Int) {
        memset(buffer, 0, count * MemoryLayout<Float>.size)
    }
}

extension CircularAudioBuffer where T == Int16 {
    /// Fill buffer with silence (zeros)
    func fillWithSilence(_ buffer: UnsafeMutablePointer<Int16>, count: Int) {
        memset(buffer, 0, count * MemoryLayout<Int16>.size)
    }
}
