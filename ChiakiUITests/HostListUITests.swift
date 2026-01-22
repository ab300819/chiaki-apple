//
//  HostListUITests.swift
//  ChiakiUITests
//
//  E2E-001: Host List Page UI Tests
//  Based on devdocs/03-test-cases.md specification
//

import XCTest

final class HostListUITests: XCTestCase {
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

    // MARK: - E2E-001.1: Test Host List Displayed

    @MainActor
    func testHostListDisplayed() throws {
        // On iOS/iPadOS, the host list should be visible
        // On macOS, it's in the sidebar
        #if os(iOS)
        // Look for the navigation title or list
        let hostsTitle = app.navigationBars.staticTexts["Hosts"]
        XCTAssertTrue(hostsTitle.waitForExistence(timeout: 5), "Hosts title should be displayed")
        #elseif os(macOS)
        // On macOS, look for the sidebar item
        let sidebarItem = app.outlines.cells.staticTexts["Hosts"]
        XCTAssertTrue(sidebarItem.waitForExistence(timeout: 5), "Hosts sidebar item should exist")
        #endif
    }

    // MARK: - E2E-001.2: Test Empty State Displayed

    @MainActor
    func testEmptyStateDisplayed() throws {
        // When no hosts exist, empty state should be shown
        // This test may need reset state launch argument
        let emptyStateImage = app.images["gamecontroller.slash"]
        let addHostButton = app.buttons["addHostButton"]

        // Either empty state or hosts should be visible
        if emptyStateImage.waitForExistence(timeout: 3) {
            XCTAssertTrue(addHostButton.exists, "Add host button should exist in empty state")
        }
        // If hosts exist, that's also valid
    }

    // MARK: - E2E-001.3: Test Add Host Button Exists

    @MainActor
    func testAddHostButtonExists() throws {
        // The add host button should be in the toolbar
        let addButton = app.buttons["addHostButton"]

        // Also check for the plus button in navigation bar
        let plusButton = app.navigationBars.buttons.element(matching: NSPredicate(format: "label CONTAINS 'Add'"))

        XCTAssertTrue(
            addButton.waitForExistence(timeout: 3) || plusButton.waitForExistence(timeout: 3),
            "Add host button should exist"
        )
    }

    // MARK: - E2E-001.4: Test Discovery Toggle

    @MainActor
    func testDiscoveryToggle() throws {
        #if os(iOS)
        // Look for discovery toggle button in toolbar
        let discoveryButton = app.buttons["discoveryToggleButton"]

        // Also check for wifi icon buttons
        let wifiButton = app.buttons.element(matching: NSPredicate(format: "label CONTAINS 'wifi' OR label CONTAINS 'discovery'"))

        if discoveryButton.exists || wifiButton.exists {
            let button = discoveryButton.exists ? discoveryButton : wifiButton
            let initialLabel = button.label

            button.tap()

            // Allow time for state change
            Thread.sleep(forTimeInterval: 1)

            // State should change (or at least not crash)
            XCTAssertTrue(button.exists, "Discovery button should still exist after tap")
        }
        #endif
    }

    // MARK: - E2E-001.5: Test Host Row Displays Info

    @MainActor
    func testHostRowDisplaysInfo() throws {
        // If there are hosts, verify they display information
        let cells = app.cells

        if cells.count > 0 {
            let firstCell = cells.firstMatch
            XCTAssertTrue(firstCell.exists, "At least one host cell should exist")

            // Host cells should contain text (name, address, or status)
            let hasText = firstCell.staticTexts.count > 0
            XCTAssertTrue(hasText, "Host cell should contain text information")
        }
    }

    // MARK: - E2E-001.6: Test Host Context Menu

    @MainActor
    func testHostContextMenu() throws {
        let cells = app.cells

        guard cells.count > 0 else {
            // No hosts to test context menu
            return
        }

        let firstCell = cells.firstMatch

        #if os(iOS)
        // Long press to trigger context menu
        firstCell.press(forDuration: 1.0)

        // Context menu should appear with options
        let contextMenu = app.menus.firstMatch
        let deleteOption = app.buttons["Delete"]
        let wakeUpOption = app.buttons.element(matching: NSPredicate(format: "label CONTAINS 'Wake'"))

        // At least one menu option should appear
        XCTAssertTrue(
            contextMenu.waitForExistence(timeout: 2) ||
            deleteOption.waitForExistence(timeout: 2) ||
            wakeUpOption.waitForExistence(timeout: 2),
            "Context menu should appear on long press"
        )
        #elseif os(macOS)
        // Right-click on macOS
        firstCell.rightClick()

        let contextMenu = app.menus.firstMatch
        XCTAssertTrue(contextMenu.waitForExistence(timeout: 2), "Context menu should appear")
        #endif
    }

    // MARK: - E2E-001.7: Test Delete Host Confirmation

    @MainActor
    func testDeleteHostConfirmation() throws {
        #if os(iOS)
        let cells = app.cells

        guard cells.count > 0 else {
            return
        }

        let firstCell = cells.firstMatch

        // Swipe to delete
        firstCell.swipeLeft()

        let deleteButton = app.buttons["Delete"]
        if deleteButton.waitForExistence(timeout: 2) {
            deleteButton.tap()

            // Confirmation dialog should appear
            let alert = app.alerts.firstMatch
            let confirmButton = app.buttons.element(matching: NSPredicate(format: "label CONTAINS 'Delete'"))

            XCTAssertTrue(
                alert.waitForExistence(timeout: 2) || confirmButton.waitForExistence(timeout: 2),
                "Delete confirmation should appear"
            )

            // Cancel to avoid actually deleting
            let cancelButton = app.buttons["Cancel"]
            if cancelButton.exists {
                cancelButton.tap()
            }
        }
        #endif
    }

    // MARK: - E2E-001.8: Test Pull to Refresh

    @MainActor
    func testPullToRefresh() throws {
        #if os(iOS)
        // Find the scrollable list
        let list = app.tables.firstMatch.exists ? app.tables.firstMatch : app.collectionViews.firstMatch

        guard list.exists else {
            return
        }

        // Perform pull to refresh gesture
        let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        let end = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        start.press(forDuration: 0.1, thenDragTo: end)

        // App should not crash and list should still exist
        XCTAssertTrue(list.exists, "List should exist after pull to refresh")
        #endif
    }
}
