// SPDX-License-Identifier: AGPL-3.0-only
//
// VideoSettingsViewModelTests.swift
// ChiakiTests
//
// @requirement F-027 - UI 层 MVVM 合规重构
// @verifies AC-093 - VideoSettingsViewModel

import Foundation
import Testing
@testable import Chiaki

@Suite("VideoSettingsViewModel Tests")
@MainActor
struct VideoSettingsViewModelTests {

    // MARK: - UT-037.1: Dependency Injection

    /**
     * @verifies AC-093 - VideoSettingsViewModel
     * @testcase UT-037.1
     */
    @Test("ViewModel accepts SettingsStore via constructor")
    func testDependencyInjection() {
        let store = SettingsStore.shared
        let viewModel = VideoSettingsViewModel(settingsStore: store)
        #expect(viewModel != nil)
    }

    // MARK: - UT-037.2: HDR Enabled State

    /**
     * @verifies AC-093 - VideoSettingsViewModel
     * @testcase UT-037.2
     */
    @Test("hdrEnabled reflects and updates store")
    func testHDREnabled() {
        let store = SettingsStore.shared
        let viewModel = VideoSettingsViewModel(settingsStore: store)

        // Set via ViewModel
        viewModel.hdrEnabled = true
        #expect(store.streamSettings.hdrEnabled == true)

        viewModel.hdrEnabled = false
        #expect(store.streamSettings.hdrEnabled == false)
    }

    // MARK: - UT-037.3: Peak Nits Double/Int Conversion

    /**
     * @verifies AC-093 - VideoSettingsViewModel
     * @testcase UT-037.3
     */
    @Test("hdrPeakNits correctly converts Double to Int")
    func testPeakNitsConversion() {
        let store = SettingsStore.shared
        let viewModel = VideoSettingsViewModel(settingsStore: store)

        // Set peak nits via ViewModel (Double)
        viewModel.hdrPeakNits = 1500.0
        #expect(store.streamSettings.hdrTargetPeakNits == 1500)

        // Read back as Double
        store.streamSettings.hdrTargetPeakNits = 2000
        #expect(viewModel.hdrPeakNits == 2000.0)
    }

    // MARK: - UT-037.4: Peak Mode Auto/Manual

    /**
     * @verifies AC-093 - VideoSettingsViewModel
     * @testcase UT-037.4
     */
    @Test("hdrPeakMode reflects auto/manual state")
    func testPeakMode() {
        let store = SettingsStore.shared
        let viewModel = VideoSettingsViewModel(settingsStore: store)

        // Auto mode: peakNits = 0
        store.streamSettings.hdrTargetPeakNits = 0
        #expect(viewModel.hdrPeakMode == .auto)

        // Manual mode: peakNits > 0
        store.streamSettings.hdrTargetPeakNits = 1000
        #expect(viewModel.hdrPeakMode == .manual)

        // Set mode via ViewModel
        viewModel.hdrPeakMode = .auto
        #expect(store.streamSettings.hdrTargetPeakNits == 0)

        viewModel.hdrPeakMode = .manual
        #expect(store.streamSettings.hdrTargetPeakNits > 0)
    }

    // MARK: - UT-037.5: Conditional Display

    /**
     * @verifies AC-093 - VideoSettingsViewModel
     * @testcase UT-037.5
     */
    @Test("shouldShowEDRIntensity depends on HDR enabled")
    func testShouldShowEDRIntensity() {
        let store = SettingsStore.shared
        let viewModel = VideoSettingsViewModel(settingsStore: store)

        store.streamSettings.hdrEnabled = false
        #expect(viewModel.shouldShowEDRIntensity == false)

        store.streamSettings.hdrEnabled = true
        #expect(viewModel.shouldShowEDRIntensity == true)
    }

    // MARK: - UT-037.6: Validation

    /**
     * @verifies AC-093 - VideoSettingsViewModel
     * @testcase UT-037.6
     */
    @Test("validateSettings returns validation result")
    func testValidateSettings() {
        let store = SettingsStore.shared
        let viewModel = VideoSettingsViewModel(settingsStore: store)

        // Valid settings
        store.streamSettings.hdrEnabled = true
        store.streamSettings.hdrTargetPeakNits = 1000
        #expect(viewModel.validateSettings() == true)

        // Invalid: peak nits too high
        store.streamSettings.hdrTargetPeakNits = 50000
        #expect(viewModel.validateSettings() == false)
    }
}
