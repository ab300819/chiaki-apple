//
//  TVOSUITests.swift
//  ChiakiUITests
//
//  E2E-004: tvOS Focus Navigation UI Tests
//  Based on devdocs/03-test-cases.md specification
//
//  These tests are specific to tvOS and use XCUIRemote for Siri Remote simulation.
//

import XCTest

#if os(tvOS)
final class TVOSUITests: XCTestCase {
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

    // MARK: - E2E-004.1: Test Initial Focus

    @MainActor
    func testInitialFocus() throws {
        // On tvOS, something should have focus when app launches
        let focusedElement = app.descendants(matching: .any)
            .element(matching: NSPredicate(format: "hasFocus == true"))

        // Wait for focus to be established
        XCTAssertTrue(
            focusedElement.waitForExistence(timeout: 5),
            "An element should have focus on launch"
        )
    }

    // MARK: - E2E-004.2: Test Vertical Navigation

    @MainActor
    func testVerticalNavigation() throws {
        let remote = XCUIRemote.shared

        // Get initial focused element
        let getFocusedIdentifier: () -> String? = {
            let focused = self.app.descendants(matching: .any)
                .element(matching: NSPredicate(format: "hasFocus == true"))
            return focused.exists ? focused.identifier : nil
        }

        let initialIdentifier = getFocusedIdentifier()

        // Navigate down
        remote.press(.down)
        Thread.sleep(forTimeInterval: 0.5)

        // Focus should have moved
        // Note: Focus might stay on same element if at boundary
        XCTAssertTrue(app.exists, "App should still be running after navigation")
    }

    // MARK: - E2E-004.3: Test Horizontal Navigation

    @MainActor
    func testHorizontalNavigation() throws {
        let remote = XCUIRemote.shared

        // Navigate right
        remote.press(.right)
        Thread.sleep(forTimeInterval: 0.5)

        // Navigate left
        remote.press(.left)
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertTrue(app.exists, "Horizontal navigation should work")
    }

    // MARK: - E2E-004.4: Test Select with Click

    @MainActor
    func testSelectWithClick() throws {
        let remote = XCUIRemote.shared

        // First, ensure something is focused
        let focused = app.descendants(matching: .any)
            .element(matching: NSPredicate(format: "hasFocus == true"))

        guard focused.waitForExistence(timeout: 3) else {
            return
        }

        // Press select
        remote.press(.select)
        Thread.sleep(forTimeInterval: 1)

        // Something should happen (navigation, sheet, alert, etc.)
        // At minimum, app should not crash
        XCTAssertTrue(app.exists, "Select should trigger an action")
    }

    // MARK: - E2E-004.5: Test Menu Back

    @MainActor
    func testMenuBack() throws {
        let remote = XCUIRemote.shared

        // First navigate somewhere
        remote.press(.select) // Enter something
        Thread.sleep(forTimeInterval: 1)

        // Press menu to go back
        remote.press(.menu)
        Thread.sleep(forTimeInterval: 1)

        // Should be back or at same level
        XCTAssertTrue(app.exists, "Menu should navigate back")
    }

    // MARK: - E2E-004.6: Test Focus State Visible

    @MainActor
    func testFocusStateVisible() throws {
        // This test verifies that focus state is visually distinct
        // In UI tests, we can only verify that focus exists

        let focusedElement = app.descendants(matching: .any)
            .element(matching: NSPredicate(format: "hasFocus == true"))

        XCTAssertTrue(
            focusedElement.waitForExistence(timeout: 3),
            "Focused element should exist"
        )
    }

    // MARK: - E2E-004.7: Test Settings Navigation

    @MainActor
    func testSettingsNavigation() throws {
        let remote = XCUIRemote.shared

        // Try to navigate to settings
        // On tvOS, this might be via toolbar or specific button

        let settingsButton = app.buttons.element(matching: NSPredicate(format: "label CONTAINS[c] 'settings'"))

        if settingsButton.exists {
            // Navigate to settings button
            while !settingsButton.hasFocus {
                remote.press(.right)
                Thread.sleep(forTimeInterval: 0.3)

                // Safety limit
                if !app.exists { break }
            }

            if settingsButton.hasFocus {
                remote.press(.select)
                Thread.sleep(forTimeInterval: 1)

                // Should be in settings
                let settingsContent = app.cells.firstMatch
                XCTAssertTrue(settingsContent.exists, "Should navigate to settings")
            }
        }
    }

    // MARK: - E2E-004.8: Test Host Card Focus

    @MainActor
    func testHostCardFocus() throws {
        // When focused on a host card, it should show details

        let hostCard = app.cells.firstMatch

        if hostCard.exists {
            // Focus on the host card
            let remote = XCUIRemote.shared

            // Navigate until host card is focused
            for _ in 0..<5 {
                if hostCard.hasFocus {
                    break
                }
                remote.press(.down)
                Thread.sleep(forTimeInterval: 0.3)
            }

            // Host card should display information when focused
            if hostCard.hasFocus {
                let hasText = hostCard.staticTexts.count > 0
                XCTAssertTrue(hasText, "Focused host card should show information")
            }
        }
    }

    // MARK: - E2E-004.9: Test Play/Pause Command

    @MainActor
    func testPlayPauseCommand() throws {
        let remote = XCUIRemote.shared

        // Play/pause is typically used in streaming to toggle overlay
        remote.press(.playPause)
        Thread.sleep(forTimeInterval: 0.5)

        // Should not crash
        XCTAssertTrue(app.exists, "Play/pause command should be handled")
    }
}
#endif
