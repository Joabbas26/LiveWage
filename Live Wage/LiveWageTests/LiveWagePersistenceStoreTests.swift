//
//  LiveWagePersistenceStoreTests.swift
//  LiveWageTests
//
//  Created by Codex on 5/5/26.
//

import XCTest
@testable import LiveWage

final class LiveWagePersistenceStoreTests: XCTestCase {
    private var directoryURL: URL!
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!

    override func setUp() {
        super.setUp()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defaultsSuiteName = "LiveWagePersistenceStoreTests.\(UUID().uuidString)"
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
            streamID: LiveWageConstants.primaryStreamID,
            streamName: "Main Income",
            configuration: .default,
            workDate: TestLiveWageCalendar.date(year: 2026, month: 5, day: 5, hour: 0, minute: 0),
            createdAt: TestLiveWageCalendar.date(year: 2026, month: 5, day: 5, hour: 8, minute: 55)
        )
        let state = LiveWagePersistedState(
            workspace: .default,
            history: [
                WorkdayRecord(
                    streamID: LiveWageConstants.primaryStreamID,
                    streamName: "Main Income",
                    workDate: TestLiveWageCalendar.date(year: 2026, month: 5, day: 5, hour: 0, minute: 0),
                    completedAt: TestLiveWageCalendar.date(year: 2026, month: 5, day: 5, hour: 17, minute: 0),
                    configuration: .default,
                    grossEarned: 130,
                    netEarned: 100,
                    elapsedWorkSeconds: 14_400
                )
            ],
            activeSession: activeSession,
            settings: LiveWageLocalSettings(
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
                    .appendingPathComponent(LiveWagePersistenceStore.stateFileName)
                    .path
            )
        )
    }

    func testLoadMigratesLegacyDefaultsIntoFileStore() throws {
        let encoder = Self.makeEncoder()
        let workspace = LiveWageWorkspace.default
        let history = [
            WorkdayRecord(
                streamID: LiveWageConstants.primaryStreamID,
                streamName: "Main Income",
                workDate: TestLiveWageCalendar.date(year: 2026, month: 5, day: 4, hour: 0, minute: 0),
                completedAt: TestLiveWageCalendar.date(year: 2026, month: 5, day: 4, hour: 17, minute: 0),
                configuration: .default,
                grossEarned: 120,
                netEarned: 90,
                elapsedWorkSeconds: 14_400
            )
        ]
        let activeSession = WorkSession(
            streamID: LiveWageConstants.primaryStreamID,
            streamName: "Main Income",
            configuration: .default,
            workDate: TestLiveWageCalendar.date(year: 2026, month: 5, day: 5, hour: 0, minute: 0),
            createdAt: TestLiveWageCalendar.date(year: 2026, month: 5, day: 5, hour: 8, minute: 55)
        )

        defaults.set(try encoder.encode(workspace), forKey: "liveWage.workspace.v1")
        defaults.set(try encoder.encode(history), forKey: "liveWage.history.v1")
        defaults.set(try encoder.encode(activeSession), forKey: "liveWage.session.v2")

        let store = makeStore()
        let migratedState = store.loadState()

        XCTAssertEqual(migratedState.workspace, workspace)
        XCTAssertEqual(migratedState.history, history)
        XCTAssertEqual(migratedState.activeSession, activeSession)
        XCTAssertNil(defaults.data(forKey: "liveWage.workspace.v1"))
        XCTAssertNil(defaults.data(forKey: "liveWage.history.v1"))
        XCTAssertNil(defaults.data(forKey: "liveWage.session.v2"))
    }

    func testCorruptDiskStateFallsBackToDefaultState() throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let badFileURL = directoryURL.appendingPathComponent(LiveWagePersistenceStore.stateFileName)
        try Data("not valid json".utf8).write(to: badFileURL, options: .atomic)

        let store = makeStore()
        let loadedState = store.loadState()

        XCTAssertEqual(loadedState, .default)
    }

    private func makeStore() -> LiveWagePersistenceStore {
        LiveWagePersistenceStore(
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
