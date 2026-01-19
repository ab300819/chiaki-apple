//
//  ChiakiTests.swift
//  ChiakiTests
//
//  Unit tests for Chiaki core modules
//

import Testing
import Foundation
@testable import Chiaki

// MARK: - ConsoleHost Tests

struct ConsoleHostTests {

    @Test func testInitialization() {
        let host = ConsoleHost(
            nickname: "PlayStation 5",
            address: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            isPS5: true
        )

        #expect(host.nickname == "PlayStation 5")
        #expect(host.address == "192.168.1.100")
        #expect(host.macAddress == "AA:BB:CC:DD:EE:FF")
        #expect(host.isPS5 == true)
        #expect(host.consoleType == .ps5)
        #expect(host.state == .offline)
    }

    @Test func testDefaultValues() {
        let host = ConsoleHost(nickname: "Test", address: "127.0.0.1")

        #expect(host.macAddress == "")
        #expect(host.isPS5 == true)
        #expect(host.registKey.isEmpty)
        #expect(host.rpKey.isEmpty)
        #expect(host.rpKeyType == 0)
    }

    @Test func testIsRegistered() {
        var host = ConsoleHost(nickname: "Test", address: "127.0.0.1")
        #expect(host.isRegistered == false)

        host.registKey = Data([0x01, 0x02, 0x03])
        #expect(host.isRegistered == true)
    }

    @Test func testConsoleType() {
        let ps5 = ConsoleHost(nickname: "PS5", address: "127.0.0.1", isPS5: true)
        #expect(ps5.consoleType == .ps5)

        let ps4 = ConsoleHost(nickname: "PS4", address: "127.0.0.1", isPS5: false)
        #expect(ps4.consoleType == .ps4)
    }

    @Test func testCodable() throws {
        let original = ConsoleHost(
            nickname: "Test Console",
            address: "192.168.1.50",
            macAddress: "11:22:33:44:55:66",
            isPS5: false,
            registKey: Data([0xAA, 0xBB, 0xCC]),
            rpKey: Data([0xDD, 0xEE, 0xFF]),
            rpKeyType: 42
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ConsoleHost.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.nickname == original.nickname)
        #expect(decoded.address == original.address)
        #expect(decoded.macAddress == original.macAddress)
        #expect(decoded.isPS5 == original.isPS5)
        #expect(decoded.registKey == original.registKey)
        #expect(decoded.rpKey == original.rpKey)
        #expect(decoded.rpKeyType == original.rpKeyType)
    }

    @Test func testEquatable() {
        let id = UUID()
        let host1 = ConsoleHost(id: id, nickname: "Test", address: "127.0.0.1")
        let host2 = ConsoleHost(id: id, nickname: "Test", address: "127.0.0.1")
        let host3 = ConsoleHost(nickname: "Test", address: "127.0.0.1")

        #expect(host1 == host2)
        #expect(host1 != host3)
    }
}

// MARK: - HostState Tests

struct HostStateTests {

    @Test func testAllCases() {
        let cases = HostState.allCases
        #expect(cases.count == 4)
        #expect(cases.contains(.online))
        #expect(cases.contains(.standby))
        #expect(cases.contains(.offline))
        #expect(cases.contains(.unknown))
    }

    @Test func testCodable() throws {
        for state in HostState.allCases {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(HostState.self, from: data)
            #expect(decoded == state)
        }
    }
}

// MARK: - StreamSettings Tests

struct StreamSettingsTests {

    @Test func testDefaultValues() {
        let settings = StreamSettings()

        #expect(settings.localProfile.resolution == .r1080p)
        #expect(settings.localProfile.frameRate == .fps60)
        #expect(settings.localProfile.bitrate == 15000)
        #expect(settings.codec == .h265)
        #expect(settings.hdrEnabled == false)
        #expect(settings.volume == 1.0)
        #expect(settings.microphoneEnabled == false)
        #expect(settings.hapticFeedbackEnabled == true)
        #expect(settings.isTouchControllerEnabled == true)
    }

    @Test func testResolutionDimensions() {
        #expect(StreamSettings.Resolution.r540p.width == 960)
        #expect(StreamSettings.Resolution.r540p.height == 540)

        #expect(StreamSettings.Resolution.r720p.width == 1280)
        #expect(StreamSettings.Resolution.r720p.height == 720)

        #expect(StreamSettings.Resolution.r1080p.width == 1920)
        #expect(StreamSettings.Resolution.r1080p.height == 1080)

        #expect(StreamSettings.Resolution.r2160p.width == 3840)
        #expect(StreamSettings.Resolution.r2160p.height == 2160)
    }

    @Test func testFrameRateValues() {
        #expect(StreamSettings.FrameRate.fps30.rawValue == 30)
        #expect(StreamSettings.FrameRate.fps60.rawValue == 60)
    }

    @Test func testCodable() throws {
        var settings = StreamSettings()
        settings.localProfile.resolution = .r720p
        settings.localProfile.frameRate = .fps30
        settings.localProfile.bitrate = 10000
        settings.codec = .h264
        settings.hdrEnabled = true

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(StreamSettings.self, from: data)

        #expect(decoded == settings)
    }
}

// MARK: - SettingsStore Tests

@MainActor
struct SettingsStoreTests {

    @Test func testInitializationWithDefaults() {
        let defaults = UserDefaults(suiteName: "test.settings.init")!
        defaults.removePersistentDomain(forName: "test.settings.init")

        let store = SettingsStore(userDefaults: defaults)

        #expect(store.streamSettings.localProfile.resolution == .r1080p)
        #expect(store.streamSettings.localProfile.frameRate == .fps60)
    }

    @Test func testUpdateResolution() {
        let defaults = UserDefaults(suiteName: "test.settings.resolution")!
        defaults.removePersistentDomain(forName: "test.settings.resolution")

        let store = SettingsStore(userDefaults: defaults)
        store.updateResolution(.r720p)

        #expect(store.streamSettings.localProfile.resolution == .r720p)

        // Verify persistence
        let store2 = SettingsStore(userDefaults: defaults)
        #expect(store2.streamSettings.localProfile.resolution == .r720p)
    }

    @Test func testUpdateFrameRate() {
        let defaults = UserDefaults(suiteName: "test.settings.framerate")!
        defaults.removePersistentDomain(forName: "test.settings.framerate")

        let store = SettingsStore(userDefaults: defaults)
        store.updateFrameRate(.fps30)

        #expect(store.streamSettings.localProfile.frameRate == .fps30)
    }

    @Test func testUpdateBitrate() {
        let defaults = UserDefaults(suiteName: "test.settings.bitrate")!
        defaults.removePersistentDomain(forName: "test.settings.bitrate")

        let store = SettingsStore(userDefaults: defaults)
        store.updateBitrate(20000)

        #expect(store.streamSettings.localProfile.bitrate == 20000)
    }

    @Test func testUpdateCodec() {
        let defaults = UserDefaults(suiteName: "test.settings.codec")!
        defaults.removePersistentDomain(forName: "test.settings.codec")

        let store = SettingsStore(userDefaults: defaults)
        store.updateCodec(.h264)

        #expect(store.streamSettings.codec == .h264)
    }

    @Test func testUpdateHdr() {
        let defaults = UserDefaults(suiteName: "test.settings.hdr")!
        defaults.removePersistentDomain(forName: "test.settings.hdr")

        let store = SettingsStore(userDefaults: defaults)
        store.updateHdrEnabled(true)

        #expect(store.streamSettings.hdrEnabled == true)
    }
}

// MARK: - HostStore Tests

@MainActor
struct HostStoreTests {

    @Test func testAddHost() {
        let defaults = UserDefaults(suiteName: "test.hoststore.add")!
        defaults.removePersistentDomain(forName: "test.hoststore.add")

        let store = HostStore(userDefaults: defaults)
        let host = ConsoleHost(nickname: "Test PS5", address: "192.168.1.100")

        store.addHost(host)

        #expect(store.hosts.count == 1)
        #expect(store.hosts.first?.nickname == "Test PS5")
    }

    @Test func testUpdateHost() {
        let defaults = UserDefaults(suiteName: "test.hoststore.update")!
        defaults.removePersistentDomain(forName: "test.hoststore.update")

        let store = HostStore(userDefaults: defaults)
        var host = ConsoleHost(nickname: "Original", address: "192.168.1.100")

        store.addHost(host)

        host.nickname = "Updated"
        store.updateHost(host)

        #expect(store.hosts.count == 1)
        #expect(store.hosts.first?.nickname == "Updated")
    }

    @Test func testRemoveHost() {
        let defaults = UserDefaults(suiteName: "test.hoststore.remove")!
        defaults.removePersistentDomain(forName: "test.hoststore.remove")

        let store = HostStore(userDefaults: defaults)
        let host = ConsoleHost(nickname: "ToDelete", address: "192.168.1.100")

        store.addHost(host)
        #expect(store.hosts.count == 1)

        store.removeHost(host)
        #expect(store.hosts.count == 0)
    }

    @Test func testHostById() {
        let defaults = UserDefaults(suiteName: "test.hoststore.byid")!
        defaults.removePersistentDomain(forName: "test.hoststore.byid")

        let store = HostStore(userDefaults: defaults)
        let host = ConsoleHost(nickname: "FindMe", address: "192.168.1.100")

        store.addHost(host)

        let found = store.host(byId: host.id)
        #expect(found != nil)
        #expect(found?.nickname == "FindMe")

        let notFound = store.host(byId: UUID())
        #expect(notFound == nil)
    }

    @Test func testHostByAddress() {
        let defaults = UserDefaults(suiteName: "test.hoststore.byaddr")!
        defaults.removePersistentDomain(forName: "test.hoststore.byaddr")

        let store = HostStore(userDefaults: defaults)
        let host = ConsoleHost(nickname: "FindMe", address: "10.0.0.50")

        store.addHost(host)

        let found = store.host(byAddress: "10.0.0.50")
        #expect(found != nil)
        #expect(found?.nickname == "FindMe")

        let notFound = store.host(byAddress: "10.0.0.99")
        #expect(notFound == nil)
    }

    @Test func testPersistence() {
        let defaults = UserDefaults(suiteName: "test.hoststore.persist")!
        defaults.removePersistentDomain(forName: "test.hoststore.persist")

        let host = ConsoleHost(nickname: "Persistent", address: "172.16.0.1")

        // Add host in first store instance
        let store1 = HostStore(userDefaults: defaults)
        store1.addHost(host)

        // Verify in new store instance
        let store2 = HostStore(userDefaults: defaults)
        #expect(store2.hosts.count == 1)
        #expect(store2.hosts.first?.nickname == "Persistent")
    }

    @Test func testClearAll() {
        let defaults = UserDefaults(suiteName: "test.hoststore.clear")!
        defaults.removePersistentDomain(forName: "test.hoststore.clear")

        let store = HostStore(userDefaults: defaults)
        store.addHost(ConsoleHost(nickname: "Host1", address: "192.168.1.1"))
        store.addHost(ConsoleHost(nickname: "Host2", address: "192.168.1.2"))

        #expect(store.hosts.count == 2)

        store.clearAll()

        #expect(store.hosts.count == 0)
    }

    @Test func testUpdateRegistration() {
        let defaults = UserDefaults(suiteName: "test.hoststore.regist")!
        defaults.removePersistentDomain(forName: "test.hoststore.regist")

        let store = HostStore(userDefaults: defaults)
        let host = ConsoleHost(nickname: "Unregistered", address: "192.168.1.100")

        store.addHost(host)
        #expect(store.isRegistered(host) == false)

        let registKey = Data([0x01, 0x02, 0x03, 0x04])
        let rpKey = Data([0x05, 0x06, 0x07, 0x08])
        store.updateRegistration(for: host, registKey: registKey, rpKey: rpKey, rpKeyType: 1)

        let updated = store.host(byId: host.id)
        #expect(updated?.isRegistered == true)
        #expect(updated?.registKey == registKey)
        #expect(updated?.rpKey == rpKey)
        #expect(updated?.rpKeyType == 1)
    }
}

// MARK: - CircularAudioBuffer Tests

struct CircularAudioBufferTests {

    @Test func testInitialization() {
        let buffer = CircularAudioBuffer<Float>(chunkCount: 4, chunkSize: 128)

        #expect(buffer.isEmpty == true)
        #expect(buffer.bufferedChunkCount == 0)
        #expect(buffer.totalCapacity == 4 * 128)
        #expect(buffer.fillRatio == 0.0)
    }

    @Test func testPushAndPop() {
        let buffer = CircularAudioBuffer<Int32>(chunkCount: 4, chunkSize: 4)

        // Push some data
        var input: [Int32] = [1, 2, 3, 4]
        let pushed = input.withUnsafeBufferPointer { ptr in
            buffer.push(ptr.baseAddress!, count: 4)
        }
        #expect(pushed == 4)

        // Pop data
        var output = [Int32](repeating: 0, count: 4)
        let popped = output.withUnsafeMutableBufferPointer { ptr in
            buffer.pop(ptr.baseAddress!, count: 4)
        }
        #expect(popped == 4)
        #expect(output == [1, 2, 3, 4])
    }

    @Test func testPartialChunk() {
        let buffer = CircularAudioBuffer<Int32>(chunkCount: 4, chunkSize: 8)

        // Push less than chunk size
        var input: [Int32] = [10, 20, 30]
        _ = input.withUnsafeBufferPointer { ptr in
            buffer.push(ptr.baseAddress!, count: 3)
        }

        // Complete the chunk
        var input2: [Int32] = [40, 50, 60, 70, 80]
        _ = input2.withUnsafeBufferPointer { ptr in
            buffer.push(ptr.baseAddress!, count: 5)
        }

        // Pop all data
        var output = [Int32](repeating: 0, count: 8)
        let popped = output.withUnsafeMutableBufferPointer { ptr in
            buffer.pop(ptr.baseAddress!, count: 8)
        }
        #expect(popped == 8)
        #expect(output == [10, 20, 30, 40, 50, 60, 70, 80])
    }

    @Test func testEmptyPop() {
        let buffer = CircularAudioBuffer<Float>(chunkCount: 4, chunkSize: 128)

        var output = [Float](repeating: 0, count: 10)
        let popped = output.withUnsafeMutableBufferPointer { ptr in
            buffer.pop(ptr.baseAddress!, count: 10)
        }
        #expect(popped == 0)
    }

    @Test func testReset() {
        let buffer = CircularAudioBuffer<Int32>(chunkCount: 4, chunkSize: 4)

        // Push data
        var input: [Int32] = [1, 2, 3, 4, 5, 6, 7, 8]
        _ = input.withUnsafeBufferPointer { ptr in
            buffer.push(ptr.baseAddress!, count: 8)
        }
        #expect(buffer.bufferedChunkCount > 0)

        // Reset
        buffer.reset()
        #expect(buffer.isEmpty == true)
        #expect(buffer.bufferedChunkCount == 0)
    }

    @Test func testFillRatio() {
        let buffer = CircularAudioBuffer<Int32>(chunkCount: 4, chunkSize: 4)

        #expect(buffer.fillRatio == 0.0)

        // Fill one chunk
        var input: [Int32] = [1, 2, 3, 4]
        _ = input.withUnsafeBufferPointer { ptr in
            buffer.push(ptr.baseAddress!, count: 4)
        }
        #expect(buffer.fillRatio == 0.25)

        // Fill another chunk
        _ = input.withUnsafeBufferPointer { ptr in
            buffer.push(ptr.baseAddress!, count: 4)
        }
        #expect(buffer.fillRatio == 0.5)
    }

    @Test func testOverrun() {
        let buffer = CircularAudioBuffer<Int32>(chunkCount: 2, chunkSize: 4)

        #expect(buffer.overrunCount == 0)

        // Fill buffer completely
        var input: [Int32] = [1, 2, 3, 4]
        _ = input.withUnsafeBufferPointer { ptr in
            buffer.push(ptr.baseAddress!, count: 4)
        }
        _ = input.withUnsafeBufferPointer { ptr in
            buffer.push(ptr.baseAddress!, count: 4)
        }

        // Push more - should cause overrun
        _ = input.withUnsafeBufferPointer { ptr in
            buffer.push(ptr.baseAddress!, count: 4)
        }

        #expect(buffer.overrunCount > 0)
    }
}

// MARK: - LockFreeQueue Tests

struct LockFreeQueueTests {

    @Test func testPushAndPop() {
        let queue = LockFreeQueue<Int>(capacity: 4)

        #expect(queue.isEmpty == true)
        #expect(queue.count == 0)

        #expect(queue.push(1) == true)
        #expect(queue.push(2) == true)
        #expect(queue.count == 2)

        #expect(queue.pop() == 1)
        #expect(queue.pop() == 2)
        #expect(queue.pop() == nil)
        #expect(queue.isEmpty == true)
    }

    @Test func testFullQueue() {
        let queue = LockFreeQueue<Int>(capacity: 2)

        #expect(queue.push(1) == true)
        #expect(queue.push(2) == true)
        #expect(queue.push(3) == false) // Queue full

        #expect(queue.pop() == 1)
        #expect(queue.push(3) == true) // Space available now
    }
}
