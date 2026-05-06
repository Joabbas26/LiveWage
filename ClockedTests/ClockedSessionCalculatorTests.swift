//
//  ClockedSessionCalculatorTests.swift
//  ClockedTests
//
//  Created by Codex on 5/5/26.
//

import XCTest
@testable import Clocked

final class ClockedSessionCalculatorTests: XCTestCase {
    func testSnapshotReflectsPausedSession() {
        let calendar = TestClockedCalendar.make()
        let workDate = TestClockedCalendar.date(year: 2026, month: 5, day: 5, hour: 0, minute: 0)
        let pausedAt = TestClockedCalendar.date(year: 2026, month: 5, day: 5, hour: 10, minute: 30)
        let now = TestClockedCalendar.date(year: 2026, month: 5, day: 5, hour: 11, minute: 15)
        let configuration = EarningsConfiguration.default

        let session = WorkSession(
            streamID: ClockedConstants.primaryStreamID,
            streamName: "Main Income",
            configuration: configuration,
            workDate: workDate,
            createdAt: TestClockedCalendar.date(year: 2026, month: 5, day: 5, hour: 8, minute: 50),
            pausedAt: pausedAt,
            accumulatedPausedSeconds: 900
        )

        let snapshot = ClockedSessionCalculator().snapshot(
            for: session,
            at: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.status, .paused)
        XCTAssertEqual(snapshot.elapsedWorkSeconds, 5_100, accuracy: 0.01)
        XCTAssertEqual(snapshot.remainingSeconds, 23_700, accuracy: 0.01)
        XCTAssertEqual(snapshot.progress, 0.1770833333, accuracy: 0.00001)
    }

    func testWorkdayRecordUsesSnapshotValues() throws {
        let calendar = TestClockedCalendar.make()
        let workDate = TestClockedCalendar.date(year: 2026, month: 5, day: 5, hour: 0, minute: 0)
        let finishTime = TestClockedCalendar.date(year: 2026, month: 5, day: 5, hour: 12, minute: 0)
        let configuration = EarningsConfiguration.default

        let session = WorkSession(
            streamID: ClockedConstants.primaryStreamID,
            streamName: "Main Income",
            configuration: configuration,
            workDate: workDate,
            createdAt: TestClockedCalendar.date(year: 2026, month: 5, day: 5, hour: 8, minute: 55)
        )

        let calculator = ClockedSessionCalculator()
        let snapshot = calculator.snapshot(for: session, at: finishTime, calendar: calendar)
        let record = try XCTUnwrap(calculator.workdayRecord(from: snapshot, completedAt: finishTime))

        XCTAssertEqual(record.streamID, session.streamID)
        XCTAssertEqual(record.elapsedWorkSeconds, 11_100, accuracy: 0.01)
        XCTAssertEqual(record.netEarned, snapshot.netEarned, accuracy: 0.01)
        XCTAssertEqual(record.grossEarned, snapshot.grossEarned, accuracy: 0.01)
    }

    func testSnapshotStartsFromButtonPressTime() {
        let calendar = TestClockedCalendar.make()
        let workDate = TestClockedCalendar.date(year: 2026, month: 5, day: 5, hour: 0, minute: 0)
        var configuration = EarningsConfiguration.default
        configuration.workStartMinutes = 8 * 60

        let session = WorkSession(
            streamID: ClockedConstants.primaryStreamID,
            streamName: "Main Income",
            configuration: configuration,
            workDate: workDate,
            createdAt: TestClockedCalendar.date(year: 2026, month: 5, day: 5, hour: 9, minute: 40)
        )

        let snapshot = ClockedSessionCalculator().snapshot(
            for: session,
            at: TestClockedCalendar.date(year: 2026, month: 5, day: 5, hour: 9, minute: 40),
            calendar: calendar
        )

        XCTAssertEqual(snapshot.status, .live)
        XCTAssertEqual(snapshot.elapsedWorkSeconds, 0, accuracy: 0.01)
        XCTAssertEqual(snapshot.scheduledStart, session.createdAt)
    }
}
