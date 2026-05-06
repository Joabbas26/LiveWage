//
//  ClockedInsightsService.swift
//  Clocked
//
//  Created by Codex on 5/5/26.
//

import Foundation

struct ClockedDayAggregate {
    let date: Date
    var netEarned: Double
    var grossEarned: Double
    var elapsedSeconds: Double
    var configuration: EarningsConfiguration
}

struct ClockedInsightsService {
    private let calendar: Calendar
    private let spendingCatalog = [
        ("netflix", "Netflix subscription", 15.49),
        ("coffee", "coffee run", 6.50),
        ("groceries", "weekly groceries", 82.0),
        ("flight", "cheap flight", 249.0)
    ]

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    func upserting(
        _ record: WorkdayRecord,
        into history: [WorkdayRecord]
    ) -> [WorkdayRecord] {
        var updatedHistory = history

        if let index = updatedHistory.firstIndex(where: {
            $0.streamID == record.streamID && calendar.isDate($0.workDate, inSameDayAs: record.workDate)
        }) {
            let existing = updatedHistory[index]
            updatedHistory[index] = WorkdayRecord(
                id: existing.id,
                streamID: existing.streamID,
                streamName: record.streamName,
                workDate: existing.workDate,
                completedAt: max(existing.completedAt, record.completedAt),
                configuration: record.configuration,
                grossEarned: existing.grossEarned + record.grossEarned,
                netEarned: existing.netEarned + record.netEarned,
                elapsedWorkSeconds: existing.elapsedWorkSeconds + record.elapsedWorkSeconds
            )
        } else {
            updatedHistory.append(record)
        }

        return updatedHistory.sorted { $0.completedAt > $1.completedAt }
    }

    func dayAggregates(
        history: [WorkdayRecord],
        selectedStreamID: UUID,
        activeSnapshot: SessionSnapshot?
    ) -> [Date: ClockedDayAggregate] {
        var aggregates: [Date: ClockedDayAggregate] = [:]

        for record in history where record.streamID == selectedStreamID {
            let day = calendar.startOfDay(for: record.workDate)
            merge(
                amount: (record.netEarned, record.grossEarned, record.elapsedWorkSeconds),
                configuration: record.configuration,
                into: &aggregates,
                on: day
            )
        }

        if
            let activeSnapshot,
            activeSnapshot.session.streamID == selectedStreamID,
            activeSnapshot.elapsedWorkSeconds > 0
        {
            let day = calendar.startOfDay(for: activeSnapshot.session.workDate)
            merge(
                amount: (activeSnapshot.netEarned, activeSnapshot.grossEarned, activeSnapshot.elapsedWorkSeconds),
                configuration: activeSnapshot.session.configuration,
                into: &aggregates,
                on: day
            )
        }

        return aggregates
    }

    func dayAggregate(
        on date: Date,
        aggregates: [Date: ClockedDayAggregate]
    ) -> ClockedDayAggregate? {
        aggregates[calendar.startOfDay(for: date)]
    }

    func weeklySummary(
        at date: Date,
        aggregates: [Date: ClockedDayAggregate],
        selectedStreamName: String
    ) -> WeeklySummary {
        let interval = calendar.dateInterval(of: .weekOfYear, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 6 * 24 * 3600)
        let values = aggregates.values.filter { interval.contains($0.date) }

        let netTotal = values.reduce(0) { $0 + $1.netEarned }
        let grossTotal = values.reduce(0) { $0 + $1.grossEarned }
        let totalHours = values.reduce(0) { $0 + ($1.elapsedSeconds / 3600) }

        return WeeklySummary(
            streamName: selectedStreamName,
            weekStart: interval.start,
            weekEnd: interval.end.addingTimeInterval(-1),
            netTotal: netTotal,
            grossTotal: grossTotal,
            daysWorked: values.count,
            totalHours: totalHours
        )
    }

    func goalProgress(
        targetAmount: Double,
        aggregates: [Date: ClockedDayAggregate]
    ) -> SavingsGoalProgress? {
        guard targetAmount > 0 else { return nil }

        let currentAmount = aggregates.values.reduce(0) { $0 + $1.netEarned }
        return SavingsGoalProgress(
            targetAmount: targetAmount,
            currentAmount: currentAmount
        )
    }

    func currentStreak(
        at date: Date,
        aggregates: [Date: ClockedDayAggregate],
        configuration: EarningsConfiguration
    ) -> Int {
        let workedDays = Set(aggregates.keys)
        guard let lastRequiredWorkday = scheduledWorkday(onOrBefore: date, configuration: configuration) else { return 0 }
        guard workedDays.contains(lastRequiredWorkday) else { return 0 }

        var streak = 0
        var cursor = lastRequiredWorkday

        while workedDays.contains(cursor) {
            streak += 1

            guard let previous = scheduledWorkday(before: cursor, configuration: configuration) else { break }
            cursor = previous
        }

        return streak
    }

    func bestStreak(
        at date: Date,
        aggregates: [Date: ClockedDayAggregate],
        configuration: EarningsConfiguration
    ) -> Int {
        let workedDays = Set(aggregates.keys)
        guard let firstWorkedDay = workedDays.min(), let lastWorkedDay = workedDays.max() else { return 0 }

        var best = 0
        var current = 0
        var cursor = calendar.startOfDay(for: firstWorkedDay)
        let end = calendar.startOfDay(for: lastWorkedDay)

        while cursor <= end {
            if configuration.isWorkday(on: cursor, calendar: calendar) {
                if workedDays.contains(cursor) {
                    current += 1
                    best = max(best, current)
                } else {
                    current = 0
                }
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return best
    }

    func achievements(
        at date: Date,
        aggregates: [Date: ClockedDayAggregate],
        configuration: EarningsConfiguration
    ) -> [AchievementStatus] {
        let bestDay = aggregates.values.map(\.netEarned).max() ?? 0
        let bestWeek = bestWeeklyNet(aggregates: aggregates)
        let bestStreak = bestStreak(at: date, aggregates: aggregates, configuration: configuration)

        return [
            AchievementStatus(
                id: "first-100-day",
                title: "First $100 day",
                detail: "Hit \(100.0.currencyString) take-home in a single tracked day.",
                isUnlocked: bestDay >= 100,
                progress: min(bestDay / 100, 1),
                progressText: bestDay >= 100 ? "Unlocked" : "Best day \(bestDay.currencyString)"
            ),
            AchievementStatus(
                id: "first-1000-week",
                title: "$1,000 week",
                detail: "Bring home \(1_000.0.currencyString) across one tracked calendar week.",
                isUnlocked: bestWeek >= 1_000,
                progress: min(bestWeek / 1_000, 1),
                progressText: bestWeek >= 1_000 ? "Unlocked" : "Best week \(bestWeek.currencyString)"
            ),
            AchievementStatus(
                id: "five-day-streak",
                title: "5-day streak",
                detail: "Clock in for every scheduled workday five times in a row.",
                isUnlocked: bestStreak >= 5,
                progress: min(Double(bestStreak) / 5, 1),
                progressText: bestStreak >= 5 ? "Unlocked" : "\(bestStreak)/5 days"
            ),
            AchievementStatus(
                id: "thirty-day-streak",
                title: "30-day streak",
                detail: "Hold a 30-workday streak on this income stream.",
                isUnlocked: bestStreak >= 30,
                progress: min(Double(bestStreak) / 30, 1),
                progressText: bestStreak >= 30 ? "Unlocked" : "\(bestStreak)/30 days"
            )
        ]
    }

    func spendingComparisons(
        at date: Date,
        aggregates: [Date: ClockedDayAggregate],
        netPerSecond: Double
    ) -> [SpendingComparison] {
        let todaysAmount = dayAggregate(on: date, aggregates: aggregates)?.netEarned ?? 0
        let perSecond = max(netPerSecond, 0)

        return spendingCatalog.map { item in
            SpendingComparison(
                id: item.0,
                title: item.1,
                amount: item.2,
                timeToEarnSeconds: perSecond > 0 ? item.2 / perSecond : 0,
                currentAmountEarned: todaysAmount
            )
        }
    }

    private func merge(
        amount: (net: Double, gross: Double, elapsed: Double),
        configuration: EarningsConfiguration,
        into aggregates: inout [Date: ClockedDayAggregate],
        on day: Date
    ) {
        if var aggregate = aggregates[day] {
            aggregate.netEarned += amount.net
            aggregate.grossEarned += amount.gross
            aggregate.elapsedSeconds += amount.elapsed
            aggregate.configuration = configuration
            aggregates[day] = aggregate
        } else {
            aggregates[day] = ClockedDayAggregate(
                date: day,
                netEarned: amount.net,
                grossEarned: amount.gross,
                elapsedSeconds: amount.elapsed,
                configuration: configuration
            )
        }
    }

    private func bestWeeklyNet(aggregates: [Date: ClockedDayAggregate]) -> Double {
        var totalsByWeek: [Date: Double] = [:]

        for aggregate in aggregates.values {
            let interval = calendar.dateInterval(of: .weekOfYear, for: aggregate.date)
                ?? DateInterval(start: calendar.startOfDay(for: aggregate.date), duration: 6 * 24 * 3600)
            totalsByWeek[interval.start, default: 0] += aggregate.netEarned
        }

        return totalsByWeek.values.max() ?? 0
    }

    private func scheduledWorkday(
        onOrBefore date: Date,
        configuration: EarningsConfiguration
    ) -> Date? {
        let referenceDay = calendar.startOfDay(for: date)

        for offset in 0..<14 {
            guard let candidate = calendar.date(byAdding: .day, value: -offset, to: referenceDay) else { continue }
            if configuration.isWorkday(on: candidate, calendar: calendar) {
                return candidate
            }
        }

        return nil
    }

    private func scheduledWorkday(
        before date: Date,
        configuration: EarningsConfiguration
    ) -> Date? {
        let referenceDay = calendar.startOfDay(for: date)

        for offset in 1..<14 {
            guard let candidate = calendar.date(byAdding: .day, value: -offset, to: referenceDay) else { continue }
            if configuration.isWorkday(on: candidate, calendar: calendar) {
                return candidate
            }
        }

        return nil
    }
}
