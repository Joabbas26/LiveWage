//
//  LiveWageInsightsServiceTests.swift
//  LiveWageTests
//
//  Created by Codex on 5/5/26.
//

import XCTest
@testable import LiveWage

final class LiveWageInsightsServiceTests: XCTestCase {
    func testUpsertingSameDayRecordCombinesTotals() {
        let calendar = TestLiveWageCalendar.make()
        let service = LiveWageInsightsService(calendar: calendar)
        let workDate = TestLiveWageCalendar.date(year: 2026, month: 5, day: 5, hour: 0, minute: 0)
        let streamID = LiveWageConstants.primaryStreamID
        let configuration = EarningsConfiguration.default

        let morning = WorkdayRecord(
            streamID: streamID,
            streamName: "Main Income",
            workDate: workDate,
            completedAt: TestLiveWageCalendar.date(year: 2026, month: 5, day: 5, hour: 12, minute: 0),
            configuration: configuration,
            grossEarned: 120,
            netEarned: 90,
            elapsedWorkSeconds: 10_800
        )
        let afternoon = WorkdayRecord(
            streamID: streamID,
            streamName: "Main Income",
            workDate: workDate,
            completedAt: TestLiveWageCalendar.date(year: 2026, month: 5, day: 5, hour: 17, minute: 0),
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
        let calendar = TestLiveWageCalendar.make()
        let service = LiveWageInsightsService(calendar: calendar)
        let configuration = EarningsConfiguration.default
        let streamID = LiveWageConstants.primaryStreamID

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
        let referenceDate = TestLiveWageCalendar.date(year: 2026, month: 5, day: 6, hour: 18, minute: 0)

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
        let calendar = TestLiveWageCalendar.make()
        let service = LiveWageInsightsService(calendar: calendar)
        let configuration = EarningsConfiguration.default
        let streamID = LiveWageConstants.primaryStreamID
        let history = [
            makeRecord(day: 4, net: 100, gross: 130, streamID: streamID, configuration: configuration),
            makeRecord(day: 5, net: 120, gross: 150, streamID: streamID, configuration: configuration)
        ]

        let activeSession = WorkSession(
            streamID: streamID,
            streamName: "Main Income",
            configuration: configuration,
            workDate: TestLiveWageCalendar.date(year: 2026, month: 5, day: 6, hour: 0, minute: 0),
            createdAt: TestLiveWageCalendar.date(year: 2026, month: 5, day: 6, hour: 8, minute: 55)
        )
        let activeSnapshot = SessionSnapshot(
            session: activeSession,
            estimate: LiveWageTaxEngine.estimate(for: configuration),
            status: .live,
            now: TestLiveWageCalendar.date(year: 2026, month: 5, day: 6, hour: 12, minute: 0),
            scheduledStart: TestLiveWageCalendar.date(year: 2026, month: 5, day: 6, hour: 9, minute: 0),
            scheduledEnd: TestLiveWageCalendar.date(year: 2026, month: 5, day: 6, hour: 17, minute: 0),
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
            at: TestLiveWageCalendar.date(year: 2026, month: 5, day: 6, hour: 12, minute: 0),
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
            workDate: TestLiveWageCalendar.date(year: 2026, month: 5, day: day, hour: 0, minute: 0),
            completedAt: TestLiveWageCalendar.date(year: 2026, month: 5, day: day, hour: 17, minute: 0),
            configuration: configuration,
            grossEarned: gross,
            netEarned: net,
            elapsedWorkSeconds: 14_400
        )
    }
}
