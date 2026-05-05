//
//  ClockedStore.swift
//  Clocked
//
//  Created by Codex on 5/4/26.
//

import Foundation
import Observation

private struct DayAggregate {
    let date: Date
    var netEarned: Double
    var grossEarned: Double
    var elapsedSeconds: Double
    var configuration: EarningsConfiguration
}

@MainActor
@Observable
final class ClockedStore {
    var streams: [IncomeStream]
    var selectedStreamID: UUID
    var configuration: EarningsConfiguration
    var salaryInput: String
    var bonusInput: String
    var benefitsInput: String
    var goalInput: String
    var streamNameInput: String
    var activeSession: WorkSession?
    private(set) var history: [WorkdayRecord]

    private let calendar: Calendar
    private let defaults: UserDefaults
    private let workspaceKey = "clocked.workspace.v1"
    private let historyKey = "clocked.history.v1"
    private let legacyConfigurationKey = "clocked.configuration.v2"
    private let sessionKey = "clocked.session.v2"

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) {
        self.defaults = defaults
        self.calendar = calendar

        let workspace = Self.loadWorkspace(from: defaults)
        let initialStreams = workspace.streams
        let initialSelectedStreamID = initialStreams.contains(where: { $0.id == workspace.selectedStreamID })
            ? workspace.selectedStreamID
            : initialStreams[0].id
        let initialSelectedStream = initialStreams.first(where: { $0.id == initialSelectedStreamID }) ?? initialStreams[0]

        streams = initialStreams
        selectedStreamID = initialSelectedStreamID
        configuration = initialSelectedStream.configuration
        salaryInput = initialSelectedStream.configuration.salaryAmount.groupedCurrencyInput
        bonusInput = initialSelectedStream.configuration.annualBonusAmount.groupedCurrencyInput
        benefitsInput = initialSelectedStream.configuration.monthlyPretaxBenefitsAmount.groupedCurrencyInput
        goalInput = initialSelectedStream.configuration.savingsGoalAmount.groupedCurrencyInput
        streamNameInput = initialSelectedStream.name

        if
            let data = defaults.data(forKey: historyKey),
            let decoded = try? Self.decoder.decode([WorkdayRecord].self, from: data)
        {
            history = decoded.sorted { $0.completedAt > $1.completedAt }
        } else {
            history = []
        }

        if
            let data = defaults.data(forKey: sessionKey),
            let decoded = try? Self.decoder.decode(WorkSession.self, from: data)
        {
            activeSession = decoded
        } else {
            activeSession = nil
        }

        ensureSessionStreamExists()
        ensureSelectionIsValid()
        refreshInputsFromSelection()
        refreshSessionStateIfNeeded()
        persistWorkspace()
        persistHistory()
    }

    var estimate: EarningsEstimate {
        ClockedTaxEngine.estimate(for: configuration)
    }

    var selectedStreamName: String {
        selectedStream?.name ?? "Income"
    }

    var canCommitSalary: Bool {
        parsedSalaryInput > 0 && salaryNeedsConfirmation
    }

    var canCommitBonus: Bool {
        bonusNeedsConfirmation
    }

    var canCommitBenefits: Bool {
        benefitsNeedsConfirmation
    }

    var canCommitGoal: Bool {
        goalNeedsConfirmation
    }

    var canCommitStreamName: Bool {
        streamNameNeedsConfirmation && !trimmedStreamNameInput.isEmpty
    }

    var salaryNeedsConfirmation: Bool {
        abs(parsedSalaryInput - configuration.salaryAmount) > 0.009
    }

    var bonusNeedsConfirmation: Bool {
        abs(parsedBonusInput - configuration.annualBonusAmount) > 0.009
    }

    var benefitsNeedsConfirmation: Bool {
        abs(parsedBenefitsInput - configuration.monthlyPretaxBenefitsAmount) > 0.009
    }

    var goalNeedsConfirmation: Bool {
        abs(parsedGoalInput - configuration.savingsGoalAmount) > 0.009
    }

    var streamNameNeedsConfirmation: Bool {
        trimmedStreamNameInput != selectedStreamName
    }

    var hasPendingInputChanges: Bool {
        salaryNeedsConfirmation
            || bonusNeedsConfirmation
            || benefitsNeedsConfirmation
            || goalNeedsConfirmation
            || streamNameNeedsConfirmation
    }

    var canQuickStartClock: Bool {
        configuration.salaryAmount > 0 && activeSession == nil
    }

    var canStartClock: Bool {
        configuration.salaryAmount > 0 && !hasPendingInputChanges && activeSession == nil
    }

    var canAddIncomeStream: Bool {
        streams.count < ClockedConstants.maxIncomeStreams && activeSession == nil
    }

    var canSwitchIncomeStreams: Bool {
        activeSession == nil
    }

    var pendingInputHints: [String] {
        var hints: [String] = []

        if streamNameNeedsConfirmation {
            hints.append("Confirm the stream name so Quick Start uses the right income label.")
        }

        if salaryNeedsConfirmation {
            hints.append("Tap OK or Done to apply your base pay change.")
        }

        if bonusNeedsConfirmation {
            hints.append("Confirm the annual bonus change before starting the clock.")
        }

        if benefitsNeedsConfirmation {
            hints.append("Confirm the monthly pre-tax benefits change before starting the clock.")
        }

        if goalNeedsConfirmation {
            hints.append("Confirm the savings goal change so the progress tracker updates.")
        }

        return hints
    }

    var assumptionsLabel: String {
        switch configuration.location {
        case .newYorkCity:
            return "Estimated take-home uses 2025 federal, FICA, New York State, and NYC resident tax rules."
        case .california:
            return "Estimated take-home uses 2025 federal, FICA, and California resident tax rules."
        case .illinois:
            return "Estimated take-home uses 2025 federal, FICA, and Illinois resident tax rules."
        case .massachusetts:
            return "Estimated take-home uses 2025 federal, FICA, and Massachusetts resident tax rules."
        case .colorado:
            return "Estimated take-home uses 2025 federal and FICA rules, with Colorado income tax modeled from federal taxable income."
        case .pennsylvania:
            return "Estimated take-home uses 2025 federal, FICA, and Pennsylvania resident tax rules."
        case .texas, .florida, .washington:
            return "Estimated take-home uses 2025 federal and FICA tax rules because the selected state does not levy personal wage income tax."
        }
    }

    var payrollAssumptionsLabel: String {
        var notes = [
            "Traditional retirement deferrals are capped at \(EarningsConfiguration.retirementDeferralLimit.currencyString) for 2025 before catch-up contributions.",
            "Savings goal progress is based on the recorded take-home you have tracked in this stream."
        ]

        if configuration.location != .newYorkCity {
            notes.append("Only New York City local resident tax is included right now; other city and county payroll taxes are not yet modeled.")
        }

        if configuration.location == .pennsylvania {
            notes.append("Pennsylvania retirement deferrals stay taxable for state income tax in this estimate.")
        }

        return notes.joined(separator: " ")
    }

    var workScheduleLabel: String {
        "\(configuration.workWeekSummary) · starts \(startTimeText)"
    }

    var startTimeText: String {
        configuration.startTimeDate(calendar: calendar)
            .formatted(date: .omitted, time: .shortened)
    }

    var currentStreak: Int {
        currentStreakValue(at: .now)
    }

    var bestStreak: Int {
        bestStreakValue(at: .now)
    }

    var weeklySummary: WeeklySummary {
        weeklySummarySnapshot(at: .now)
    }

    var goalProgress: SavingsGoalProgress? {
        goalProgressStatus(at: .now)
    }

    var achievements: [AchievementStatus] {
        achievementsStatus(at: .now)
    }

    var spendingComparisons: [SpendingComparison] {
        spendingComparisonsStatus(at: .now)
    }

    var todayNetEarned: Double {
        dayAggregate(on: .now, at: .now)?.netEarned ?? 0
    }

    func updateStreamNameInput(_ value: String) {
        streamNameInput = String(value.prefix(26))
    }

    func updateSalaryInput(_ value: String) {
        salaryInput = sanitizeCurrencyInput(value)
    }

    func updateBonusInput(_ value: String) {
        bonusInput = sanitizeCurrencyInput(value)
    }

    func updateBenefitsInput(_ value: String) {
        benefitsInput = sanitizeCurrencyInput(value)
    }

    func updateGoalInput(_ value: String) {
        goalInput = sanitizeCurrencyInput(value)
    }

    func commitStreamNameInput() {
        guard canCommitStreamName else { return }
        updateSelectedStreamName(trimmedStreamNameInput)
        streamNameInput = trimmedStreamNameInput
    }

    func commitSalaryInput() {
        guard parsedSalaryInput > 0 else { return }
        configuration.salaryAmount = parsedSalaryInput
        salaryInput = configuration.salaryAmount.groupedCurrencyInput
        persistSelectedStreamConfiguration()
    }

    func commitBonusInput() {
        configuration.annualBonusAmount = parsedBonusInput
        bonusInput = configuration.annualBonusAmount.groupedCurrencyInput
        persistSelectedStreamConfiguration()
    }

    func commitBenefitsInput() {
        configuration.monthlyPretaxBenefitsAmount = parsedBenefitsInput
        benefitsInput = configuration.monthlyPretaxBenefitsAmount.groupedCurrencyInput
        persistSelectedStreamConfiguration()
    }

    func commitGoalInput() {
        configuration.savingsGoalAmount = parsedGoalInput
        goalInput = configuration.savingsGoalAmount.groupedCurrencyInput
        persistSelectedStreamConfiguration()
    }

    func commitPendingInputs() {
        commitStreamNameInput()
        commitSalaryInput()
        commitBonusInput()
        commitBenefitsInput()
        commitGoalInput()
    }

    func setSelectedStream(_ streamID: UUID) {
        guard canSwitchIncomeStreams else { return }
        guard let stream = streams.first(where: { $0.id == streamID }) else { return }

        selectedStreamID = stream.id
        configuration = stream.configuration
        refreshInputsFromSelection()
        persistWorkspace()
    }

    func addIncomeStream() {
        guard canAddIncomeStream else { return }

        let stream = IncomeStream(
            name: nextIncomeStreamName(),
            configuration: configuration
        )
        streams.append(stream)
        selectedStreamID = stream.id
        configuration = stream.configuration
        refreshInputsFromSelection()
        persistWorkspace()
    }

    func setPayFrequency(_ frequency: PayFrequency) {
        configuration.payFrequency = frequency
        persistSelectedStreamConfiguration()
    }

    func setFilingStatus(_ filingStatus: FilingStatus) {
        configuration.filingStatus = filingStatus
        persistSelectedStreamConfiguration()
    }

    func setLocation(_ location: LocationOption) {
        configuration.location = location
        persistSelectedStreamConfiguration()
    }

    func adjustWorkHours(by delta: Int) {
        configuration.workHoursPerDay = min(max(configuration.workHoursPerDay + delta, 1), 16)
        persistSelectedStreamConfiguration()
    }

    func adjustWorkDays(by delta: Int) {
        configuration.workDaysPerWeek = min(max(configuration.workDaysPerWeek + delta, 1), 7)
        persistSelectedStreamConfiguration()
    }

    func adjustRetirementContribution(by delta: Int) {
        configuration.retirementContributionPercent = min(max(configuration.retirementContributionPercent + delta, 0), 40)
        persistSelectedStreamConfiguration()
    }

    func setWorkStartTime(_ date: Date) {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        configuration.workStartMinutes = (hour * 60) + minute
        persistSelectedStreamConfiguration()
    }

    func startClock() {
        guard canQuickStartClock else { return }
        guard let selectedStream else { return }

        let now = Date.now
        let workDate = configuration.nextWorkDate(from: now, calendar: calendar)
        activeSession = WorkSession(
            streamID: selectedStream.id,
            streamName: selectedStream.name,
            configuration: configuration,
            workDate: workDate,
            createdAt: now
        )
        persistWorkspace()
        persistSession()
    }

    func togglePause(at date: Date = .now) {
        guard var activeSession else { return }
        guard sessionSnapshot(at: date)?.status != .complete else { return }

        if let pausedAt = activeSession.pausedAt {
            activeSession.accumulatedPausedSeconds += date.timeIntervalSince(pausedAt)
            activeSession.pausedAt = nil
        } else {
            activeSession.pausedAt = date
        }

        self.activeSession = activeSession
        persistSession()
    }

    func stopClock(at date: Date = .now) {
        finalizeActiveSession(at: date)
        activeSession = nil
        persistSession()
    }

    func refreshSessionStateIfNeeded(at date: Date = .now) {
        guard activeSession != nil else { return }
        ensureSessionStreamExists()

        if let snapshot = sessionSnapshot(at: date), snapshot.status == .complete {
            finalizeActiveSession(at: date)
            activeSession = nil
            persistSession()
        } else {
            persistSession()
        }
    }

    func sessionSnapshot(at date: Date) -> SessionSnapshot? {
        guard let activeSession else { return nil }

        let estimate = ClockedTaxEngine.estimate(for: activeSession.configuration)
        let start = activeSession.configuration.scheduledStart(on: activeSession.workDate, calendar: calendar)
        let end = activeSession.configuration.scheduledEnd(on: activeSession.workDate, calendar: calendar)

        let effectiveNow = activeSession.pausedAt ?? date
        let rawElapsed = max(min(effectiveNow.timeIntervalSince(start), activeSession.configuration.workDaySeconds), 0)
        let elapsedWorkSeconds = max(rawElapsed - activeSession.accumulatedPausedSeconds, 0)
        let cappedElapsed = min(elapsedWorkSeconds, activeSession.configuration.workDaySeconds)
        let remainingSeconds = max(activeSession.configuration.workDaySeconds - cappedElapsed, 0)

        let status: SessionStatus
        if date < start {
            status = .scheduled
        } else if cappedElapsed >= activeSession.configuration.workDaySeconds || date >= end {
            status = .complete
        } else if activeSession.isPaused {
            status = .paused
        } else {
            status = .live
        }

        return SessionSnapshot(
            session: activeSession,
            estimate: estimate,
            status: status,
            now: date,
            scheduledStart: start,
            scheduledEnd: end,
            elapsedWorkSeconds: cappedElapsed,
            remainingSeconds: remainingSeconds,
            grossEarned: cappedElapsed * estimate.grossPerSecond,
            netEarned: cappedElapsed * estimate.netPerSecond
        )
    }

    func taxBreakdown(for estimate: EarningsEstimate) -> [TaxBreakdownRow] {
        var rows = [
            TaxBreakdownRow(id: "federal", title: "Federal income tax", amount: estimate.federalIncomeTax),
            TaxBreakdownRow(id: "fica", title: "Social Security + Medicare", amount: estimate.socialSecurityTax + estimate.medicareTax)
        ]

        switch configuration.location {
        case .newYorkCity:
            rows.append(TaxBreakdownRow(id: "ny-state", title: "NY state income tax", amount: estimate.stateIncomeTax))
            rows.append(TaxBreakdownRow(id: "nyc", title: "NYC resident tax", amount: estimate.localIncomeTax))
        case .california:
            rows.append(TaxBreakdownRow(id: "ca-state", title: "CA state income tax", amount: estimate.stateIncomeTax))
        case .illinois:
            rows.append(TaxBreakdownRow(id: "il-state", title: "IL state income tax", amount: estimate.stateIncomeTax))
        case .massachusetts:
            rows.append(TaxBreakdownRow(id: "ma-state", title: "MA state income tax", amount: estimate.stateIncomeTax))
        case .colorado:
            rows.append(TaxBreakdownRow(id: "co-state", title: "CO state income tax", amount: estimate.stateIncomeTax))
        case .pennsylvania:
            rows.append(TaxBreakdownRow(id: "pa-state", title: "PA state income tax", amount: estimate.stateIncomeTax))
        case .texas, .florida, .washington:
            rows.append(TaxBreakdownRow(id: "state", title: "State income tax", amount: 0))
        }

        return rows
    }

    func milestones(for snapshot: SessionSnapshot) -> [MilestoneStatus] {
        let dailyGoal = max(snapshot.estimate.netDaily, 1)

        return [
            MilestoneStatus(
                id: "coffee",
                title: "Morning coffee",
                targetAmount: 4.50,
                currentAmount: snapshot.netEarned,
                perSecond: snapshot.estimate.netPerSecond
            ),
            MilestoneStatus(
                id: "lunch",
                title: "Lunch",
                targetAmount: 18,
                currentAmount: snapshot.netEarned,
                perSecond: snapshot.estimate.netPerSecond
            ),
            MilestoneStatus(
                id: "goal",
                title: "Daily take-home goal",
                targetAmount: dailyGoal,
                currentAmount: snapshot.netEarned,
                perSecond: snapshot.estimate.netPerSecond
            )
        ]
    }

    func weeklySummarySnapshot(at date: Date) -> WeeklySummary {
        let interval = calendar.dateInterval(of: .weekOfYear, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 6 * 24 * 3600)
        let aggregates = selectedDayAggregates(at: date)
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

    func goalProgressStatus(at date: Date) -> SavingsGoalProgress? {
        let target = configuration.savingsGoalAmount
        guard target > 0 else { return nil }

        let currentAmount = selectedDayAggregates(at: date)
            .values
            .reduce(0) { $0 + $1.netEarned }

        return SavingsGoalProgress(
            targetAmount: target,
            currentAmount: currentAmount
        )
    }

    func achievementsStatus(at date: Date) -> [AchievementStatus] {
        let aggregates = Array(selectedDayAggregates(at: date).values)
        let bestDay = aggregates.map(\.netEarned).max() ?? 0
        let bestWeek = bestWeeklyNet(at: date)
        let bestStreak = bestStreakValue(at: date)

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

    func spendingComparisonsStatus(at date: Date) -> [SpendingComparison] {
        let todaysAmount = dayAggregate(on: date, at: date)?.netEarned ?? 0
        let perSecond = max(estimate.netPerSecond, 0)
        let catalog = [
            ("netflix", "Netflix subscription", 15.49),
            ("coffee", "coffee run", 6.50),
            ("groceries", "weekly groceries", 82.0),
            ("flight", "cheap flight", 249.0)
        ]

        return catalog.map { item in
            SpendingComparison(
                id: item.0,
                title: item.1,
                amount: item.2,
                timeToEarnSeconds: perSecond > 0 ? item.2 / perSecond : 0,
                currentAmountEarned: todaysAmount
            )
        }
    }

    private var selectedStream: IncomeStream? {
        streams.first(where: { $0.id == selectedStreamID })
    }

    private var selectedStreamIndex: Int? {
        streams.firstIndex(where: { $0.id == selectedStreamID })
    }

    private var parsedSalaryInput: Double {
        salaryInput.currencyNumber
    }

    private var parsedBonusInput: Double {
        bonusInput.currencyNumber
    }

    private var parsedBenefitsInput: Double {
        benefitsInput.currencyNumber
    }

    private var parsedGoalInput: Double {
        goalInput.currencyNumber
    }

    private var trimmedStreamNameInput: String {
        streamNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sanitizeCurrencyInput(_ value: String) -> String {
        var sanitized = ""
        var hasDecimalSeparator = false

        for character in value {
            if character.isNumber || character == "," {
                sanitized.append(character)
                continue
            }

            if character == ".", !hasDecimalSeparator {
                hasDecimalSeparator = true
                sanitized.append(character)
            }
        }

        return sanitized
    }

    private func refreshInputsFromSelection() {
        guard let selectedStream else { return }
        configuration = selectedStream.configuration
        salaryInput = configuration.salaryAmount.groupedCurrencyInput
        bonusInput = configuration.annualBonusAmount.groupedCurrencyInput
        benefitsInput = configuration.monthlyPretaxBenefitsAmount.groupedCurrencyInput
        goalInput = configuration.savingsGoalAmount.groupedCurrencyInput
        streamNameInput = selectedStream.name
    }

    private func persistSelectedStreamConfiguration() {
        guard let selectedStreamIndex else { return }
        streams[selectedStreamIndex].configuration = configuration
        persistWorkspace()
    }

    private func updateSelectedStreamName(_ name: String) {
        guard let selectedStreamIndex else { return }
        streams[selectedStreamIndex].name = name
        persistWorkspace()
    }

    private func ensureSelectionIsValid() {
        guard !streams.isEmpty else {
            streams = [IncomeStream.primary(configuration: .default)]
            selectedStreamID = streams[0].id
            return
        }

        if streams.contains(where: { $0.id == selectedStreamID }) {
            return
        }

        selectedStreamID = streams[0].id
    }

    private func ensureSessionStreamExists() {
        guard let activeSession else { return }

        if !streams.contains(where: { $0.id == activeSession.streamID }) {
            streams.append(
                IncomeStream(
                    id: activeSession.streamID,
                    name: activeSession.streamName,
                    configuration: activeSession.configuration
                )
            )
        }

        selectedStreamID = activeSession.streamID
        configuration = activeSession.configuration
    }

    private func nextIncomeStreamName() -> String {
        let existingNames = Set(streams.map(\.name))

        for index in 2...(ClockedConstants.maxIncomeStreams + 3) {
            let candidate = "Income \(index)"
            if !existingNames.contains(candidate) {
                return candidate
            }
        }

        return "Income \(streams.count + 1)"
    }

    private func finalizeActiveSession(at date: Date) {
        guard let snapshot = sessionSnapshot(at: date) else { return }
        guard snapshot.elapsedWorkSeconds > 0 else { return }

        let record = WorkdayRecord(
            streamID: snapshot.session.streamID,
            streamName: snapshot.session.streamName,
            workDate: snapshot.session.workDate,
            completedAt: date,
            configuration: snapshot.session.configuration,
            grossEarned: snapshot.grossEarned,
            netEarned: snapshot.netEarned,
            elapsedWorkSeconds: snapshot.elapsedWorkSeconds
        )

        upsert(record: record)
    }

    private func upsert(record: WorkdayRecord) {
        if let index = history.firstIndex(where: {
            $0.streamID == record.streamID && calendar.isDate($0.workDate, inSameDayAs: record.workDate)
        }) {
            let existing = history[index]
            history[index] = WorkdayRecord(
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
            history.append(record)
        }

        history.sort { $0.completedAt > $1.completedAt }
        persistHistory()
    }

    private func selectedDayAggregates(at date: Date) -> [Date: DayAggregate] {
        var aggregates: [Date: DayAggregate] = [:]

        for record in history where record.streamID == selectedStreamID {
            let day = calendar.startOfDay(for: record.workDate)

            if var aggregate = aggregates[day] {
                aggregate.netEarned += record.netEarned
                aggregate.grossEarned += record.grossEarned
                aggregate.elapsedSeconds += record.elapsedWorkSeconds
                aggregate.configuration = record.configuration
                aggregates[day] = aggregate
            } else {
                aggregates[day] = DayAggregate(
                    date: day,
                    netEarned: record.netEarned,
                    grossEarned: record.grossEarned,
                    elapsedSeconds: record.elapsedWorkSeconds,
                    configuration: record.configuration
                )
            }
        }

        if
            let snapshot = sessionSnapshot(at: date),
            snapshot.session.streamID == selectedStreamID,
            snapshot.elapsedWorkSeconds > 0
        {
            let day = calendar.startOfDay(for: snapshot.session.workDate)

            if var aggregate = aggregates[day] {
                aggregate.netEarned += snapshot.netEarned
                aggregate.grossEarned += snapshot.grossEarned
                aggregate.elapsedSeconds += snapshot.elapsedWorkSeconds
                aggregate.configuration = snapshot.session.configuration
                aggregates[day] = aggregate
            } else {
                aggregates[day] = DayAggregate(
                    date: day,
                    netEarned: snapshot.netEarned,
                    grossEarned: snapshot.grossEarned,
                    elapsedSeconds: snapshot.elapsedWorkSeconds,
                    configuration: snapshot.session.configuration
                )
            }
        }

        return aggregates
    }

    private func dayAggregate(on date: Date, at referenceDate: Date) -> DayAggregate? {
        selectedDayAggregates(at: referenceDate)[calendar.startOfDay(for: date)]
    }

    private func currentStreakValue(at date: Date) -> Int {
        let workedDays = Set(selectedDayAggregates(at: date).keys)
        guard let lastRequiredWorkday = scheduledWorkday(onOrBefore: date) else { return 0 }
        guard workedDays.contains(lastRequiredWorkday) else { return 0 }

        var streak = 0
        var cursor = lastRequiredWorkday

        while workedDays.contains(cursor) {
            streak += 1

            guard let previous = scheduledWorkday(before: cursor) else { break }
            cursor = previous
        }

        return streak
    }

    private func bestStreakValue(at date: Date) -> Int {
        let workedDays = Set(selectedDayAggregates(at: date).keys)
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

    private func bestWeeklyNet(at date: Date) -> Double {
        let aggregates = selectedDayAggregates(at: date)
        var totalsByWeek: [Date: Double] = [:]

        for aggregate in aggregates.values {
            let interval = calendar.dateInterval(of: .weekOfYear, for: aggregate.date)
                ?? DateInterval(start: calendar.startOfDay(for: aggregate.date), duration: 6 * 24 * 3600)
            totalsByWeek[interval.start, default: 0] += aggregate.netEarned
        }

        return totalsByWeek.values.max() ?? 0
    }

    private func scheduledWorkday(onOrBefore date: Date) -> Date? {
        let referenceDay = calendar.startOfDay(for: date)

        for offset in 0..<14 {
            guard let candidate = calendar.date(byAdding: .day, value: -offset, to: referenceDay) else { continue }
            if configuration.isWorkday(on: candidate, calendar: calendar) {
                return candidate
            }
        }

        return nil
    }

    private func scheduledWorkday(before date: Date) -> Date? {
        let referenceDay = calendar.startOfDay(for: date)

        for offset in 1..<14 {
            guard let candidate = calendar.date(byAdding: .day, value: -offset, to: referenceDay) else { continue }
            if configuration.isWorkday(on: candidate, calendar: calendar) {
                return candidate
            }
        }

        return nil
    }

    private func persistWorkspace() {
        let workspace = ClockedWorkspace(
            streams: streams,
            selectedStreamID: selectedStreamID
        )

        if let data = try? Self.encoder.encode(workspace) {
            defaults.set(data, forKey: workspaceKey)
        }
    }

    private func persistHistory() {
        if let data = try? Self.encoder.encode(history) {
            defaults.set(data, forKey: historyKey)
        }
    }

    private func persistSession() {
        guard let activeSession else {
            defaults.removeObject(forKey: sessionKey)
            return
        }

        if let data = try? Self.encoder.encode(activeSession) {
            defaults.set(data, forKey: sessionKey)
        }
    }

    private static func loadWorkspace(from defaults: UserDefaults) -> ClockedWorkspace {
        if
            let data = defaults.data(forKey: "clocked.workspace.v1"),
            let decoded = try? decoder.decode(ClockedWorkspace.self, from: data),
            !decoded.streams.isEmpty
        {
            let selectedStreamID = decoded.streams.contains(where: { $0.id == decoded.selectedStreamID })
                ? decoded.selectedStreamID
                : decoded.streams[0].id

            return ClockedWorkspace(
                streams: decoded.streams,
                selectedStreamID: selectedStreamID
            )
        }

        if
            let data = defaults.data(forKey: "clocked.configuration.v2"),
            let legacyConfiguration = try? decoder.decode(EarningsConfiguration.self, from: data)
        {
            let primaryStream = IncomeStream.primary(configuration: legacyConfiguration)
            return ClockedWorkspace(
                streams: [primaryStream],
                selectedStreamID: primaryStream.id
            )
        }

        let primaryStream = IncomeStream.primary(configuration: .default)
        return ClockedWorkspace(
            streams: [primaryStream],
            selectedStreamID: primaryStream.id
        )
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
}
