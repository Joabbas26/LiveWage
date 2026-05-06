//
//  ClockedPersistenceStoreTests.swift
//  ClockedTests
//
//  Created by Codex on 5/5/26.
//

import XCTest
@testable import Clocked

final class ClockedPersistenceStoreTests: XCTestCase {
    private var directoryURL: URL!
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!

    override func setUp() {
        super.setUp()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defaultsSuiteName = "ClockedPersistenceStoreTests.\(UUID().uuidString)"
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

    func testSaveAndLoadRoundTripsState() {
        let store = makeStore()
        let activeSession = WorkSession(
            streamID: ClockedConstants.primaryStreamID,
            streamName: "Main Income",
            configuration: .default,
            workDate: TestClockedCalendar.date(year: 2026, month: 5, day: 5, hour: 0, minute: 0),
            createdAt: TestClockedCalendar.date(year: 2026, month: 5, day: 5, hour: 8, minute: 55)
        )
        let state = ClockedPersistedState(
            workspace: .default,
            history: [
                WorkdayRecord(
                    streamID: ClockedConstants.primaryStreamID,
                    streamName: "Main Income",
                    workDate: TestClockedCalendar.date(year: 2026, month: 5, day: 5, hour: 0, minute: 0),
                    completedAt: TestClockedCalendar.date(year: 2026, month: 5, day: 5, hour: 17, minute: 0),
                    configuration: .default,
                    grossEarned: 130,
                    netEarned: 100,
                    elapsedWorkSeconds: 14_400
                )
            ],
            activeSession: activeSession,
            settings: ClockedLocalSettings(
                appearancePreference: .light,
                profileName: "Nina Alvarez"
            )
        )

        store.saveState(state)
        let loadedState = store.loadState()

        XCTAssertEqual(loadedState, state.normalized())
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: directoryURL
                    .appendingPathComponent(ClockedPersistenceStore.stateFileName)
                    .path
            )
        )
    }

    func testLoadMigratesLegacyDefaultsIntoFileStore() throws {
        let encoder = Self.makeEncoder()
        let workspace = ClockedWorkspace.default
        let history = [
            WorkdayRecord(
                streamID: ClockedConstants.primaryStreamID,
                streamName: "Main Income",
                workDate: TestClockedCalendar.date(year: 2026, month: 5, day: 4, hour: 0, minute: 0),
                completedAt: TestClockedCalendar.date(year: 2026, month: 5, day: 4, hour: 17, minute: 0),
                configuration: .default,
                grossEarned: 120,
                netEarned: 90,
                elapsedWorkSeconds: 14_400
            )
        ]
        let activeSession = WorkSession(
            streamID: ClockedConstants.primaryStreamID,
            streamName: "Main Income",
            configuration: .default,
            workDate: TestClockedCalendar.date(year: 2026, month: 5, day: 5, hour: 0, minute: 0),
            createdAt: TestClockedCalendar.date(year: 2026, month: 5, day: 5, hour: 8, minute: 55)
        )

        defaults.set(try encoder.encode(workspace), forKey: "clocked.workspace.v1")
        defaults.set(try encoder.encode(history), forKey: "clocked.history.v1")
        defaults.set(try encoder.encode(activeSession), forKey: "clocked.session.v2")

        let store = makeStore()
        let migratedState = store.loadState()

        XCTAssertEqual(migratedState.workspace, workspace)
        XCTAssertEqual(migratedState.history, history)
        XCTAssertEqual(migratedState.activeSession, activeSession)
        XCTAssertNil(defaults.data(forKey: "clocked.workspace.v1"))
        XCTAssertNil(defaults.data(forKey: "clocked.history.v1"))
        XCTAssertNil(defaults.data(forKey: "clocked.session.v2"))
    }

    func testCorruptDiskStateFallsBackToDefaultState() throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let badFileURL = directoryURL.appendingPathComponent(ClockedPersistenceStore.stateFileName)
        try Data("not valid json".utf8).write(to: badFileURL, options: .atomic)

        let store = makeStore()
        let loadedState = store.loadState()

        XCTAssertEqual(loadedState, .default)
    }

    private func makeStore() -> ClockedPersistenceStore {
        ClockedPersistenceStore(
            fileManager: .default,
            defaults: defaults,
            directoryURL: directoryURL
        )
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }
}
