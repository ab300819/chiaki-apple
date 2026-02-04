//
// PinManagingTests.swift
// ChiakiTests
//
// @verifies AC-095 - 协议抽象

import Foundation
import Testing
@testable import Chiaki

@Suite("PinManaging Tests")
struct PinManagingTests {
    private func makeHost() -> ConsoleHost {
        ConsoleHost(nickname: "Test Host", address: "127.0.0.1")
    }

    /**
     * @verifies AC-095 - 协议抽象
     * @testcase UT-039.1
     */
    @Test("ConsolePinManager conforms to PinManaging")
    func testConsolePinManagerConformsToProtocol() {
        let pinManager: PinManaging = ConsolePinManager.shared
        #expect(pinManager is PinManaging)
    }

    /**
     * @verifies AC-095 - 协议抽象
     * @testcase UT-039.2
     */
    @Test("Set and get PIN")
    func testSetAndGetPin() {
        let host = makeHost()
        let pinManager = ConsolePinManager.shared
        pinManager.setPin("1234", for: host)
        #expect(pinManager.getPin(for: host) == "1234")
        pinManager.clearPin(for: host)
    }

    /**
     * @verifies AC-095 - 协议抽象
     * @testcase UT-039.3
     */
    @Test("Clear PIN")
    func testClearPin() {
        let host = makeHost()
        let pinManager = ConsolePinManager.shared
        pinManager.setPin("1234", for: host)
        pinManager.clearPin(for: host)
        #expect(!pinManager.hasPin(for: host))
    }

    /**
     * @verifies AC-095 - 协议抽象
     * @testcase UT-039.4
     */
    @Test("Requires PIN entry reflects stored PIN")
    func testRequiresPinEntry() {
        let host = makeHost()
        let pinManager = ConsolePinManager.shared
        pinManager.clearPin(for: host)
        #expect(!pinManager.requiresPinEntry(for: host))
        pinManager.setPin("1234", for: host)
        #expect(pinManager.requiresPinEntry(for: host))
        pinManager.clearPin(for: host)
    }
}
