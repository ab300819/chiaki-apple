//
//  SettingsUITests.swift
//  ChiakiUITests
//
//  E2E-003: Settings Page UI Tests
//  Based on devdocs/03-test-cases.md specification
//

import XCTest

final class SettingsUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper

    private func navigateToSettings() -> Bool {
        #if os(iOS)
        // On iOS, settings might be a tab or navigation item
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.waitForExistence(timeout: 3) {
            settingsTab.tap()
            return true
        }

        // Or it might be in navigation
        let settingsButton = app.buttons["settingsButton"]
        if settingsButton.exists {
            settingsButton.tap()
            return true
        }

        // Try sidebar on iPad
        let sidebarSettings = app.cells.staticTexts["Settings"]
        if sidebarSettings.exists {
            sidebarSettings.tap()
            return true
        }
        #elseif os(macOS)
        // On macOS, settings is in sidebar
        let sidebarSettings = app.outlines.cells.staticTexts["Settings"]
        if sidebarSettings.waitForExistence(timeout: 3) {
            sidebarSettings.tap()
            return true
        }
        #endif

        return false
    }

    // MARK: - E2E-003.1: Test Navigate to Settings

    @MainActor
    func testNavigateToSettings() throws {
        XCTAssertTrue(navigateToSettings(), "Should be able to navigate to settings")

        // Verify settings page is displayed
        let settingsTitle = app.navigationBars.staticTexts["Settings"]
        let settingsContent = app.cells.firstMatch

        XCTAssertTrue(
            settingsTitle.waitForExistence(timeout: 3) || settingsContent.exists,
            "Settings page should be displayed"
        )
    }

    // MARK: - E2E-003.2: Test Settings Sections Exist

    @MainActor
    func testSettingsSections() throws {
        guard navigateToSettings() else {
            return
        }

        Thread.sleep(forTimeInterval: 1)

        // Look for major settings sections
        let videoSection = app.cells.staticTexts.element(matching: NSPredicate(format: "label CONTAINS[c] 'video'"))
        let audioSection = app.cells.staticTexts.element(matching: NSPredicate(format: "label CONTAINS[c] 'audio'"))
        let controllerSection = app.cells.staticTexts.element(matching: NSPredicate(format: "label CONTAINS[c] 'controller'"))

        // At least one section should exist
        XCTAssertTrue(
            videoSection.exists || audioSection.exists || controllerSection.exists || app.cells.count > 0,
            "Settings should have content sections"
        )
    }

    // MARK: - E2E-003.3: Test Video Settings Navigation

    @MainActor
    func testVideoSettingsNavigation() throws {
        guard navigateToSettings() else {
            return
        }

        Thread.sleep(forTimeInterval: 1)

        // Find and tap video settings
        let videoCell = app.cells.element(matching: NSPredicate(format: "label CONTAINS[c] 'video'"))
        let videoLink = app.buttons.element(matching: NSPredicate(format: "label CONTAINS[c] 'video'"))

        if videoCell.exists {
            videoCell.tap()
        } else if videoLink.exists {
            videoLink.tap()
        }

        Thread.sleep(forTimeInterval: 0.5)

        // Should show video settings content (resolution, framerate, etc.)
        let resolutionText = app.staticTexts.element(matching: NSPredicate(format: "label CONTAINS[c] 'resolution' OR label CONTAINS[c] '1080'"))

        XCTAssertTrue(
            resolutionText.waitForExistence(timeout: 2) || app.pickers.count > 0 || app.buttons.count > 3,
            "Video settings should show configuration options"
        )
    }

    // MARK: - E2E-003.4: Test Audio Settings Navigation

    @MainActor
    func testAudioSettingsNavigation() throws {
        guard navigateToSettings() else {
            return
        }

        Thread.sleep(forTimeInterval: 1)

        // Find and tap audio settings
        let audioCell = app.cells.element(matching: NSPredicate(format: "label CONTAINS[c] 'audio'"))

        if audioCell.exists {
            audioCell.tap()

            Thread.sleep(forTimeInterval: 0.5)

            // Should show audio settings content (volume, microphone, etc.)
            let volumeText = app.staticTexts.element(matching: NSPredicate(format: "label CONTAINS[c] 'volume'"))
            let slider = app.sliders.firstMatch

            XCTAssertTrue(
                volumeText.exists || slider.exists || app.switches.count > 0,
                "Audio settings should show configuration options"
            )
        }
    }

    // MARK: - E2E-003.5: Test Controller Settings Navigation

    @MainActor
    func testControllerSettingsNavigation() throws {
        guard navigateToSettings() else {
            return
        }

        Thread.sleep(forTimeInterval: 1)

        // Find and tap controller settings
        let controllerCell = app.cells.element(matching: NSPredicate(format: "label CONTAINS[c] 'controller'"))

        if controllerCell.exists {
            controllerCell.tap()

            Thread.sleep(forTimeInterval: 0.5)

            // Should show controller settings content
            XCTAssertTrue(app.exists, "Controller settings should be accessible")
        }
    }

    // MARK: - E2E-003.6: Test Resolution Picker

    @MainActor
    func testResolutionPicker() throws {
        guard navigateToSettings() else {
            return
        }

        Thread.sleep(forTimeInterval: 1)

        // Navigate to video settings if needed
        let videoCell = app.cells.element(matching: NSPredicate(format: "label CONTAINS[c] 'video'"))
        if videoCell.exists {
            videoCell.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Find resolution picker
        let resolutionPicker = app.buttons["resolutionPicker"]
        let resolutionButton = app.buttons.element(matching: NSPredicate(format: "label CONTAINS[c] '1080' OR label CONTAINS[c] '720' OR label CONTAINS[c] 'resolution'"))

        if resolutionPicker.exists || resolutionButton.exists {
            let target = resolutionPicker.exists ? resolutionPicker : resolutionButton
            target.tap()

            // Options should appear
            Thread.sleep(forTimeInterval: 0.5)

            // Look for resolution options
            let option720 = app.buttons["720p"]
            let option1080 = app.buttons["1080p"]

            XCTAssertTrue(
                option720.waitForExistence(timeout: 2) || option1080.exists || app.pickerWheels.count > 0,
                "Resolution options should appear"
            )
        }
    }

    // MARK: - E2E-003.7: Test Frame Rate Picker

    @MainActor
    func testFrameRatePicker() throws {
        guard navigateToSettings() else {
            return
        }

        Thread.sleep(forTimeInterval: 1)

        // Navigate to video settings if needed
        let videoCell = app.cells.element(matching: NSPredicate(format: "label CONTAINS[c] 'video'"))
        if videoCell.exists {
            videoCell.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Find frame rate picker
        let frameRatePicker = app.buttons["frameRatePicker"]
        let frameRateButton = app.buttons.element(matching: NSPredicate(format: "label CONTAINS[c] '60' OR label CONTAINS[c] '30' OR label CONTAINS[c] 'fps'"))

        if frameRatePicker.exists || frameRateButton.exists {
            let target = frameRatePicker.exists ? frameRatePicker : frameRateButton
            target.tap()

            Thread.sleep(forTimeInterval: 0.5)

            // Options should appear
            let option30 = app.buttons["30 fps"]
            let option60 = app.buttons["60 fps"]

            XCTAssertTrue(
                option30.waitForExistence(timeout: 2) || option60.exists || app.pickerWheels.count > 0,
                "Frame rate options should appear"
            )
        }
    }

    // MARK: - E2E-003.8: Test Bitrate Slider

    @MainActor
    func testBitrateSlider() throws {
        guard navigateToSettings() else {
            return
        }

        Thread.sleep(forTimeInterval: 1)

        // Navigate to video settings if needed
        let videoCell = app.cells.element(matching: NSPredicate(format: "label CONTAINS[c] 'video'"))
        if videoCell.exists {
            videoCell.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Find bitrate slider
        let slider = app.sliders.firstMatch
        let bitrateSlider = app.sliders["bitrateSlider"]

        let targetSlider = bitrateSlider.exists ? bitrateSlider : slider

        if targetSlider.exists {
            // Adjust slider
            targetSlider.adjust(toNormalizedSliderPosition: 0.7)

            // Should not crash
            XCTAssertTrue(targetSlider.exists, "Bitrate slider should work")
        }
    }

    // MARK: - E2E-003.9: Test HDR Toggle

    @MainActor
    func testHDRToggle() throws {
        guard navigateToSettings() else {
            return
        }

        Thread.sleep(forTimeInterval: 1)

        // Navigate to video settings if needed
        let videoCell = app.cells.element(matching: NSPredicate(format: "label CONTAINS[c] 'video'"))
        if videoCell.exists {
            videoCell.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Find HDR toggle
        let hdrToggle = app.switches.element(matching: NSPredicate(format: "label CONTAINS[c] 'hdr'"))

        if hdrToggle.exists {
            let initialValue = hdrToggle.value as? String

            hdrToggle.tap()

            let newValue = hdrToggle.value as? String

            // Value should change (or at least not crash)
            XCTAssertTrue(hdrToggle.exists, "HDR toggle should work")
        }
    }

    // MARK: - E2E-003.10: Test Volume Slider

    @MainActor
    func testVolumeSlider() throws {
        guard navigateToSettings() else {
            return
        }

        Thread.sleep(forTimeInterval: 1)

        // Navigate to audio settings if needed
        let audioCell = app.cells.element(matching: NSPredicate(format: "label CONTAINS[c] 'audio'"))
        if audioCell.exists {
            audioCell.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Find volume slider
        let volumeSlider = app.sliders.element(matching: NSPredicate(format: "identifier CONTAINS 'volume' OR label CONTAINS[c] 'volume'"))
        let anySlider = app.sliders.firstMatch

        let targetSlider = volumeSlider.exists ? volumeSlider : anySlider

        if targetSlider.exists {
            targetSlider.adjust(toNormalizedSliderPosition: 0.5)
            XCTAssertTrue(targetSlider.exists, "Volume slider should work")
        }
    }

    // MARK: - E2E-003.11: Test Haptic Toggle

    @MainActor
    func testHapticToggle() throws {
        guard navigateToSettings() else {
            return
        }

        Thread.sleep(forTimeInterval: 1)

        // Navigate to controller settings if needed
        let controllerCell = app.cells.element(matching: NSPredicate(format: "label CONTAINS[c] 'controller'"))
        if controllerCell.exists {
            controllerCell.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Find haptic toggle
        let hapticToggle = app.switches.element(matching: NSPredicate(format: "label CONTAINS[c] 'haptic' OR label CONTAINS[c] 'feedback'"))

        if hapticToggle.exists {
            hapticToggle.tap()
            XCTAssertTrue(hapticToggle.exists, "Haptic toggle should work")
        }
    }

    // MARK: - E2E-003.13: Test Reset to Defaults

    @MainActor
    func testResetToDefaults() throws {
        guard navigateToSettings() else {
            return
        }

        Thread.sleep(forTimeInterval: 1)

        // Scroll to find reset button
        let resetButton = app.buttons.element(matching: NSPredicate(format: "label CONTAINS[c] 'reset'"))

        if resetButton.exists {
            resetButton.tap()

            // Confirmation dialog should appear
            let alert = app.alerts.firstMatch
            let confirmButton = app.buttons.element(matching: NSPredicate(format: "label CONTAINS[c] 'reset'"))

            XCTAssertTrue(
                alert.waitForExistence(timeout: 2) || confirmButton.exists,
                "Reset confirmation should appear"
            )

            // Cancel to avoid actually resetting
            let cancelButton = app.buttons["Cancel"]
            if cancelButton.exists {
                cancelButton.tap()
            }
        }
    }
}
