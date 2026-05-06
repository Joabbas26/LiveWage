//
//  ClockedInsightsServiceTests.swift
//  ClockedTests
//
//  Created by Codex on 5/5/26.
//

import XCTest
@testable import Clocked

final class ClockedInsightsServiceTests: XCTestCase {
    func testUpsertingSameDayRecordCombinesTotals() {
        let calendar = TestClockedCalendar.make()
        let service = ClockedInsightsService(calendar: calendar)
        let workDate = TestClockedCalendar.date(year: 2026, month: 5, day: 5, hour: 0, minute: 0)
        let streamID = ClockedConstants.primaryStreamID
        let configuration = EarningsConfiguration.default

        let morning = WorkdayRecord(
            streamID: streamID,
            streamName: "Main Income",
            workDate: workDate,
            completedAt: TestClockedCalendar.date(year: 2026, month: 5, day: 5, hour: 12, minute: 0),
            configuration: configuration,
            grossEarned: 120,
            netEarned: 90,
            elapsedWorkSeconds: 10_800
        )
        let afternoon = WorkdayRecord(
            streamID: streamID,
            streamName: "Main Income",
            workDate: workDate,
            completedAt: TestClockedCalendar.date(year: 2026, month: 5, day: 5, hour: 17, minute: 0),
            configuration: configuration,
            grossEarned: 80,
            netEarned: 60,
            elapsedWorkSeconds: 7_200
        )

        let history = service.upserting(afternoon, into: [morning])

        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].grossEarned, 200, accuracy: 0.01)
        XCTAssertEqual(history[0].netEarned, 150, accuracy: 0.01)
        XCTAssertEqual(history[0].elapsedWorkSeconds, 18_000, accuracy: 0.01)
    }

    func testCurrentStreakCountsScheduledWorkdays() {
        let calendar = TestClockedCalendar.make()
        let service = ClockedInsightsService(calendar: calendar)
        let configuration = EarningsConfiguration.default
        let streamID = ClockedConstants.primaryStreamID

        let history = [
            makeRecord(day: 4, net: 100, streamID: streamID, configuration: configuration),
            makeRecord(day: 5, net: 105, streamID: streamID, configuration: configuration),
            makeRecord(day: 6, net: 110, streamID: streamID, configuration: configuration)
        ]

        let aggregates = service.dayAggregates(
            history: history,
            selectedStreamID: streamID,
            activeSnapshot: nil
        )
        let referenceDate = TestClockedCalendar.date(year: 2026, month: 5, day: 6, hour: 18, minute: 0)

        XCTAssertEqual(
            service.currentStreak(at: referenceDate, aggregates: aggregates, configuration: configuration),
            3
        )
        XCTAssertEqual(
            service.bestStreak(at: referenceDate, aggregates: aggregates, configuration: configuration),
            3
        )
    }

    func testWeeklySummaryIncludesActiveSession() {
        let calendar = TestClockedCalendar.make()
        let service = ClockedInsightsService(calendar: calendar)
        let configuration = EarningsConfiguration.default
        let streamID = ClockedConstants.primaryStreamID
        let history = [
            makeRecord(day: 4, net: 100, gross: 130, streamID: streamID, configuration: configuration),
            makeRecord(day: 5, net: 120, gross: 150, streamID: streamID, configuration: configuration)
        ]

        let activeSession = WorkSession(
            streamID: streamID,
            streamName: "Main Income",
            configuration: configuration,
            workDate: TestClockedCalendar.date(year: 2026, month: 5, day: 6, hour: 0, minute: 0),
            createdAt: TestClockedCalendar.date(year: 2026, month: 5, day: 6, hour: 8, minute: 55)
        )
        let activeSnapshot = SessionSnapshot(
            session: activeSession,
            estimate: ClockedTaxEngine.estimate(for: configuration),
            status: .live,
            now: TestClockedCalendar.date(year: 2026, month: 5, day: 6, hour: 12, minute: 0),
            scheduledStart: TestClockedCalendar.date(year: 2026, month: 5, day: 6, hour: 9, minute: 0),
            scheduledEnd: TestClockedCalendar.date(year: 2026, month: 5, day: 6, hour: 17, minute: 0),
            elapsedWorkSeconds: 10_800,
            remainingSeconds: 18_000,
            grossEarned: 140,
            netEarned: 95
        )

        let aggregates = service.dayAggregates(
            history: history,
            selectedStreamID: streamID,
            activeSnapshot: activeSnapshot
        )
        let summary = service.weeklySummary(
            at: TestClockedCalendar.date(year: 2026, month: 5, day: 6, hour: 12, minute: 0),
            aggregates: aggregates,
            selectedStreamName: "Main Income"
        )

        XCTAssertEqual(summary.netTotal, 315, accuracy: 0.01)
        XCTAssertEqual(summary.grossTotal, 420, accuracy: 0.01)
        XCTAssertEqual(summary.daysWorked, 3)
        XCTAssertEqual(summary.totalHours, 11, accuracy: 0.01)
    }

    private func makeRecord(
        day: Int,
        net: Double,
        gross: Double = 130,
        streamID: UUID,
        configuration: EarningsConfiguration
    ) -> WorkdayRecord {
        WorkdayRecord(
            streamID: streamID,
            streamName: "Main Income",
            workDate: TestClockedCalendar.date(year: 2026, month: 5, day: day, hour: 0, minute: 0),
            completedAt: TestClockedCalendar.date(year: 2026, month: 5, day: day, hour: 17, minute: 0),
            configuration: configuration,
            grossEarned: gross,
            netEarned: net,
            elapsedWorkSeconds: 14_400
        )
    }
}
