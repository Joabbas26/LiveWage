//
//  ClockedStoreTests.swift
//  ClockedTests
//
//  Created by Codex on 5/5/26.
//

import XCTest
import SwiftUI
@testable import Clocked

@MainActor
final class ClockedStoreTests: XCTestCase {
    private var directoryURL: URL!
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!

    override func setUp() {
        super.setUp()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defaultsSuiteName = "ClockedStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
    }

    override func tearDown() {
        if let directoryURL {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        if let defaultsSuiteName {
            defaults?.removePersistentDomain(forName: defaultsSuiteName)
        }

        directoryURL = nil
        defaults = nil
        defaultsSuiteName = nil
        super.tearDown()
    }

    func testUnsupportedLocationShowsEstimateNotice() {
        let store = makeStore()

        store.setLocation(LocationOption(rawValue: "unknownPlace"))

        XCTAssertEqual(store.activeEstimateNotice?.title, "Location fallback")
        XCTAssertTrue(store.taxCatalogSummary.contains("federal income tax and FICA only"))
    }

    func testDarkModePreferencePersistsOnStore() {
        let store = makeStore()

        store.setDarkModeEnabled(false)

        XCTAssertFalse(store.isDarkModeEnabled)
        XCTAssertEqual(store.preferredColorScheme, .light)
    }

    func testSystemAppearanceUsesDeviceTheme() {
        let store = makeStore()

        store.setAppearancePreference(.system)

        XCTAssertEqual(store.appearancePreference, .system)
        XCTAssertNil(store.preferredColorScheme)
    }

    func testProfileNameUpdatesInitials() {
        let store = makeStore()

        store.updateProfileNameInput("Joab Bastidas")
        store.commitProfileNameInput()

        XCTAssertEqual(store.profileName, "Joab Bastidas")
        XCTAssertEqual(store.userInitials, "JB")
        XCTAssertEqual(store.profileNameDisplay, "Joab Bastidas")
    }

    func testClearStatsRemovesHistoryButKeepsSetup() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970

        let seededState = ClockedPersistedState(
            workspace: .default,
            history: [
                WorkdayRecord(
                    streamID: ClockedConstants.primaryStreamID,
                    streamName: "Main Income",
                    workDate: TestClockedCalendar.date(year: 2026, month: 5, day: 5, hour: 0, minute: 0),
                    completedAt: TestClockedCalendar.date(year: 2026, month: 5, day: 5, hour: 17, minute: 0),
                    configuration: .default,
                    grossEarned: 120,
                    netEarned: 90,
                    elapsedWorkSeconds: 14_400
                )
            ]
        )

        let stateURL = directoryURL.appendingPathComponent(ClockedPersistenceStore.stateFileName)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try encoder.encode(seededState).write(to: stateURL, options: .atomic)

        let seededStore = makeStore()
        let originalLocation = seededStore.configuration.location

        seededStore.clearStats()

        XCTAssertEqual(seededStore.historyCount, 0)
        XCTAssertEqual(seededStore.configuration.location, originalLocation)
    }

    private func makeStore() -> ClockedStore {
        ClockedStore(
            persistence: ClockedPersistenceStore(
                fileManager: .default,
                defaults: defaults,
                directoryURL: directoryURL
            ),
            calendar: TestClockedCalendar.make()
        )
    }
}
