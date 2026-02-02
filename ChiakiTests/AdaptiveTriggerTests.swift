// SPDX-License-Identifier: AGPL-3.0-only
//
// AdaptiveTriggerTests.swift
// ChiakiTests
//
// Tests for DualSense adaptive trigger effects
// @verifies AC-061 - DualSense 自适应扳机支持

import Testing
@testable import Chiaki

@Suite("Adaptive Trigger Tests")
struct AdaptiveTriggerTests {

    // MARK: - UT-013.1: TriggerEffect Enum Cases

    /**
     * @verifies AC-061
     * @testcase UT-013.1
     */
    @Test("AdaptiveTriggerEffect enum contains all required cases")
    func testTriggerEffectEnumCases() {
        // Create all effect types to verify they exist
        let effects: [AdaptiveTriggerEffect] = [
            .off,
            .feedback(startPosition: 0.2, strength: 0.5),
            .weapon(startPosition: 0.1, endPosition: 0.6, strength: 0.8),
            .vibration(position: 0.5, amplitude: 0.7, frequency: 0.3)
        ]

        #expect(effects.count == 4)

        // Verify off effect
        #expect(effects[0] == .off)
        #expect(!effects[0].isActive)

        // Verify other effects are active
        #expect(effects[1].isActive)
        #expect(effects[2].isActive)
        #expect(effects[3].isActive)
    }

    // MARK: - UT-013.2: Feedback Effect Parameters

    /**
     * @verifies AC-061
     * @testcase UT-013.2
     */
    @Test("Feedback effect stores startPosition and strength correctly")
    func testFeedbackEffectParameters() {
        let effect = AdaptiveTriggerEffect.feedback(startPosition: 0.25, strength: 0.75)

        if case let .feedback(start, strength) = effect {
            #expect(start == 0.25)
            #expect(strength == 0.75)
        } else {
            Issue.record("Expected feedback effect")
        }
    }

    // MARK: - UT-013.3: Weapon Effect Parameters

    /**
     * @verifies AC-061
     * @testcase UT-013.3
     */
    @Test("Weapon effect stores start/end/strength correctly")
    func testWeaponEffectParameters() {
        let effect = AdaptiveTriggerEffect.weapon(startPosition: 0.1, endPosition: 0.6, strength: 0.9)

        if case let .weapon(start, end, strength) = effect {
            #expect(start == 0.1)
            #expect(end == 0.6)
            #expect(strength == 0.9)
        } else {
            Issue.record("Expected weapon effect")
        }
    }

    // MARK: - UT-013.4: Vibration Effect Parameters

    /**
     * @verifies AC-061
     * @testcase UT-013.4
     */
    @Test("Vibration effect stores position/amplitude/frequency correctly")
    func testVibrationEffectParameters() {
        let effect = AdaptiveTriggerEffect.vibration(position: 0.5, amplitude: 0.6, frequency: 0.4)

        if case let .vibration(pos, amp, freq) = effect {
            #expect(pos == 0.5)
            #expect(amp == 0.6)
            #expect(freq == 0.4)
        } else {
            Issue.record("Expected vibration effect")
        }
    }

    // MARK: - UT-013.5: TriggerSide Enum

    /**
     * @verifies AC-061
     * @testcase UT-013.5
     */
    @Test("TriggerSide enum contains left and right")
    func testTriggerSideEnum() {
        let sides = TriggerSide.allCases
        #expect(sides.count == 2)
        #expect(sides.contains(.left))
        #expect(sides.contains(.right))
    }

    // MARK: - Additional Tests

    @Test("AdaptiveTriggerEffect description is human readable")
    func testEffectDescription() {
        let offEffect = AdaptiveTriggerEffect.off
        #expect(offEffect.description == "off")

        let feedbackEffect = AdaptiveTriggerEffect.feedback(startPosition: 0.25, strength: 0.50)
        #expect(feedbackEffect.description.contains("feedback"))
        #expect(feedbackEffect.description.contains("0.25"))
        #expect(feedbackEffect.description.contains("0.50"))
    }

    @Test("AdaptiveTriggerEffect Equatable conformance")
    func testEffectEquatable() {
        let effect1 = AdaptiveTriggerEffect.feedback(startPosition: 0.5, strength: 0.5)
        let effect2 = AdaptiveTriggerEffect.feedback(startPosition: 0.5, strength: 0.5)
        let effect3 = AdaptiveTriggerEffect.feedback(startPosition: 0.5, strength: 0.6)

        #expect(effect1 == effect2)
        #expect(effect1 != effect3)
        #expect(AdaptiveTriggerEffect.off == AdaptiveTriggerEffect.off)
    }

    @Test("AdaptiveTriggerState tracks both triggers")
    func testTriggerState() {
        var state = AdaptiveTriggerState()

        // Initially both off
        #expect(!state.hasActiveEffect)
        #expect(state.leftEffect == .off)
        #expect(state.rightEffect == .off)

        // Set left trigger
        state.leftEffect = .feedback(startPosition: 0.2, strength: 0.8)
        #expect(state.hasActiveEffect)

        // Set right trigger
        state.rightEffect = .weapon(startPosition: 0.1, endPosition: 0.5, strength: 0.9)
        #expect(state.hasActiveEffect)

        // Reset
        state.reset()
        #expect(!state.hasActiveEffect)
        #expect(state.leftEffect == .off)
        #expect(state.rightEffect == .off)
    }
}
