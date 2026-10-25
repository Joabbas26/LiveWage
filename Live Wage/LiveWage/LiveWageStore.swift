//
//  LiveWageStore.swift
//  LiveWage
//
//  Created by Codex on 5/4/26.
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class LiveWageStore {
    var streams: [IncomeStream]
    var selectedStreamID: UUID
    var configuration: EarningsConfiguration
    var localSettings: LiveWageLocalSettings
    var profileNameInput: String
    var salaryInput: String
    var bonusInput: String
    var benefitsInput: String
    var goalInput: String
    var streamNameInput: String
    var activeSession: WorkSession?
    private(set) var history: [WorkdayRecord]

    private let calendar: Calendar
    private let persistence: LiveWagePersistenceStore
    private let sessionCalculator = LiveWageSessionCalculator()
    private let insightsService: LiveWageInsightsService
    private let telemetry = LiveWageTelemetry.shared

    convenience init(
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) {
        self.init(
            persistence: LiveWagePersistenceStore(),
            calendar: calendar
        )
    }

    init(
        persistence: LiveWagePersistenceStore,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) {
        self.persistence = persistence
        self.calendar = calendar
        self.insightsService = LiveWageInsightsService(calendar: calendar)

        let state = persistence.loadState()
        let workspace = state.workspace
        let initialStreams = workspace.streams
        let initialSelectedStreamID = initialStreams.contains(where: { $0.id == workspace.selectedStreamID })
            ? workspace.selectedStreamID
            : initialStreams[0].id
        let initialSelectedStream = initialStreams.first(where: { $0.id == initialSelectedStreamID }) ?? initialStreams[0]

        streams = initialStreams
        selectedStreamID = initialSelectedStreamID
        configuration = initialSelectedStream.configuration
        localSettings = state.settings
        profileNameInput = state.settings.profileName
        salaryInput = initialSelectedStream.configuration.salaryAmount.groupedCurrencyInput
        bonusInput = initialSelectedStream.configuration.annualBonusAmount.groupedCurrencyInput
        benefitsInput = initialSelectedStream.configuration.monthlyPretaxBenefitsAmount.groupedCurrencyInput
        goalInput = initialSelectedStream.configuration.savingsGoalAmount.groupedCurrencyInput
        streamNameInput = initialSelectedStream.name

        history = state.history.sorted { $0.completedAt > $1.completedAt }
        activeSession = state.activeSession?.normalized(calendar: calendar)

        ensureSessionStreamExists()
        ensureSelectionIsValid()
        refreshInputsFromSelection()
        refreshSessionStateIfNeeded()
        persistWorkspace()
        persistHistory()
        telemetry.stateRestored(
            streamCount: streams.count,
            historyCount: history.count,
            hasActiveSession: activeSession != nil
        )
    }

    var estimate: EarningsEstimate {
        LiveWageTaxEngine.estimate(for: configuration)
    }

    var selectedStreamName: String {
        selectedStream?.name ?? "Income"
    }

    var profileName: String {
        localSettings.profileName
    }

    var profileNameDisplay: String {
        profileName.isEmpty ? "Not set" : profileName
    }

    var userInitials: String {
        let trimmedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else { return "NA" }

        let words = trimmedName.split(whereSeparator: \.isWhitespace)
        if words.count >= 2 {
            return String(words.prefix(2).compactMap(\.first)).uppercased()
        }

        return String(trimmedName.prefix(2)).uppercased()
    }

    var preferredColorScheme: ColorScheme? {
        localSettings.appearancePreference.colorScheme
    }

    var appearancePreference: LiveWageAppearancePreference {
        localSettings.appearancePreference
    }

    var isDarkModeEnabled: Bool {
        localSettings.appearancePreference == .dark
    }

    var canClearStats: Bool {
        !history.isEmpty
    }

    var historyCount: Int {
        history.count
    }

    var canCommitProfileName: Bool {
        profileNameNeedsConfirmation
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

    var profileNameNeedsConfirmation: Bool {
        trimmedProfileNameInput != profileName
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
        streams.count < LiveWageConstants.maxIncomeStreams && activeSession == nil
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
        LiveWageTaxEngine.assumptionsLabel(for: configuration)
    }

    var activeEstimateNotice: LiveWageEstimateNotice? {
        if let issue = LiveWageTaxEngine.loadingIssue {
            return LiveWageEstimateNotice(
                title: "Reduced estimate mode",
                message: "Bundled \(LiveWageTaxEngine.taxYear) tax data could not be loaded. Live Wage is temporarily using federal income tax and FICA only until that catalog is restored. \(issue.description)",
                tone: .warning
            )
        }

        if !LiveWageTaxEngine.hasBundledProfile(for: configuration.location) {
            return LiveWageEstimateNotice(
                title: "Location fallback",
                message: "\(configuration.location.name) is not in the bundled \(LiveWageTaxEngine.taxYear) tax catalog yet, so the estimate falls back to federal income tax and FICA only for that location.",
                tone: .warning
            )
        }

        return nil
    }

    var taxCatalogSummary: String {
        if let activeEstimateNotice {
            return activeEstimateNotice.message
        }

        if LiveWageTaxEngine.hasLocalIncomeTax(for: configuration.location) {
            return "Using bundled \(LiveWageTaxEngine.taxYear) federal, FICA, state, and supported local tax rules for \(configuration.location.name)."
        }

        return "Using bundled \(LiveWageTaxEngine.taxYear) federal, FICA, and state tax rules for \(configuration.location.name). Unsupported city and county taxes are still excluded."
    }

    var payrollAssumptionsLabel: String {
        var notes = [
            "Traditional retirement deferrals are capped at \(EarningsConfiguration.retirementDeferralLimit.currencyString) for 2025 before catch-up contributions.",
            "Savings goal progress is based on the recorded take-home you have tracked in this stream."
        ]

        if !LiveWageTaxEngine.hasLocalIncomeTax(for: configuration.location) {
            notes.append("Only the bundled local resident tax overlays are included right now; other city and county payroll taxes are not yet modeled.")
        }

        if configuration.location == .pennsylvania {
            notes.append("Pennsylvania retirement deferrals stay taxable for state income tax in this estimate.")
        }

        return notes.joined(separator: " ")
    }

    var privacySummary: String {
        "Live Wage saves your name, pay setup, location, schedule, savings goal, appearance preference, and stats history only on this device in local app storage. No login, account sync, or background upload is enabled."
    }

    var diagnosticsSummary: String {
        "Live Wage writes local OSLog diagnostics for session lifecycle events, legacy-data migration, and tax-data fallback issues. Remote analytics and crash reporting are not connected yet."
    }

    var localStorageSummary: String {
        "Your saved setup stays local: \(profileNameDisplay), \(selectedStreamName), \(configuration.location.name), \(configuration.workWeekSummary), and \(historyCount) tracked stat \(historyCount == 1 ? "entry" : "entries")."
    }

    var workScheduleLabel: String {
        "\(configuration.workWeekSummary) · usual start \(startTimeText)"
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

    var unlockedBadges: [AchievementStatus] {
        achievements.filter(\.isUnlocked)
    }

    var spendingComparisons: [SpendingComparison] {
        spendingComparisonsStatus(at: .now)
    }

    var todayNetEarned: Double {
        dayAggregate(on: .now, at: .now)?.netEarned ?? 0
    }

    var canEditPayDetails: Bool {
        activeSession == nil
    }

    // The saved configuration with any typed-but-uncommitted amounts applied, for live previews.
    var draftConfiguration: EarningsConfiguration {
        var draft = configuration
        if parsedSalaryInput > 0 {
            draft.salaryAmount = parsedSalaryInput
        }
        draft.annualBonusAmount = parsedBonusInput
        draft.monthlyPretaxBenefitsAmount = parsedBenefitsInput
        draft.savingsGoalAmount = parsedGoalInput
        return draft
    }

    var draftEstimate: EarningsEstimate {
        LiveWageTaxEngine.estimate(for: draftConfiguration)
    }

    func updateStreamNameInput(_ value: String) {
        streamNameInput = String(value.prefix(26))
    }

    func updateProfileNameInput(_ value: String) {
        profileNameInput = String(value.prefix(40))
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

    func commitProfileNameInput() {
        guard canCommitProfileName else { return }
        localSettings.profileName = trimmedProfileNameInput
        profileNameInput = localSettings.profileName
        persistState()
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

    // Applies every typed value when pay details close; anything that can't be applied snaps back to the saved value.
    func finishEditingPayDetails() {
        commitPendingInputs()
        salaryInput = configuration.salaryAmount.groupedCurrencyInput
        bonusInput = configuration.annualBonusAmount.groupedCurrencyInput
        benefitsInput = configuration.monthlyPretaxBenefitsAmount.groupedCurrencyInput
        goalInput = configuration.savingsGoalAmount.groupedCurrencyInput
        streamNameInput = selectedStreamName
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

    func setAppearancePreference(_ preference: LiveWageAppearancePreference) {
        guard localSettings.appearancePreference != preference else { return }
        localSettings.appearancePreference = preference
        persistState()
    }

    func setDarkModeEnabled(_ isEnabled: Bool) {
        setAppearancePreference(isEnabled ? .dark : .light)
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
        activeSession = sessionCalculator.makeSession(
            selectedStream: selectedStream,
            configuration: configuration,
            currentDate: now,
            calendar: calendar
        )
        telemetry.sessionStarted(
            streamID: selectedStream.id,
            scheduledWorkday: configuration.workDaysPerWeek
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
            telemetry.sessionResumed(streamID: activeSession.streamID)
        } else {
            activeSession.pausedAt = date
            telemetry.sessionPaused(streamID: activeSession.streamID)
        }

        self.activeSession = activeSession
        persistSession()
    }

    func stopClock(at date: Date = .now) {
        let streamID = activeSession?.streamID
        finalizeActiveSession(at: date)
        activeSession = nil
        persistSession()
        if let streamID {
            telemetry.sessionStopped(streamID: streamID, reason: "manual_stop")
        }
    }

    func refreshSessionStateIfNeeded(at date: Date = .now) {
        guard activeSession != nil else { return }
        ensureSessionStreamExists()

        if let snapshot = sessionSnapshot(at: date), snapshot.status == .complete {
            let streamID = activeSession?.streamID
            finalizeActiveSession(at: date)
            activeSession = nil
            persistSession()
            if let streamID {
                telemetry.sessionStopped(streamID: streamID, reason: "workday_complete")
            }
        } else {
            persistSession()
        }
    }

    func clearStats() {
        guard canClearStats else { return }
        history = []
        persistHistory()
    }

    func sessionSnapshot(at date: Date) -> SessionSnapshot? {
        guard let activeSession else { return nil }
        return sessionCalculator.snapshot(
            for: activeSession,
            at: date,
            calendar: calendar
        )
    }

    func taxBreakdown(for estimate: EarningsEstimate) -> [TaxBreakdownRow] {
        var rows = [
            TaxBreakdownRow(id: "federal", title: "Federal income tax", amount: estimate.federalIncomeTax),
            TaxBreakdownRow(id: "fica", title: "Social Security + Medicare", amount: estimate.socialSecurityTax + estimate.medicareTax)
        ]

        rows.append(
            TaxBreakdownRow(
                id: "state",
                title: LiveWageTaxEngine.stateTaxTitle(for: configuration.location),
                amount: estimate.stateIncomeTax
            )
        )

        if let localTaxTitle = LiveWageTaxEngine.localTaxTitle(for: configuration.location) {
            rows.append(
                TaxBreakdownRow(
                    id: "local",
                    title: localTaxTitle,
                    amount: estimate.localIncomeTax
                )
            )
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
        insightsService.weeklySummary(
            at: date,
            aggregates: selectedDayAggregates(at: date),
            selectedStreamName: selectedStreamName
        )
    }

    func weekDays(at date: Date) -> [WeekDayTotal] {
        let aggregates = selectedDayAggregates(at: date)
        let today = calendar.startOfDay(for: date)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? today
        let isLiveToday = sessionSnapshot(at: date).map { snapshot in
            snapshot.session.streamID == selectedStreamID
                && calendar.isDate(snapshot.session.workDate, inSameDayAs: date)
                && (snapshot.status == .live || snapshot.status == .paused)
        } ?? false
        let expectedNet = estimate.netDaily
        let symbols = calendar.veryShortWeekdaySymbols

        return (0..<7).compactMap { offset -> WeekDayTotal? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }

            let dayStart = calendar.startOfDay(for: day)
            let symbolIndex = calendar.component(.weekday, from: dayStart) - 1
            let isWorkday = configuration.isWorkday(on: dayStart, calendar: calendar)

            return WeekDayTotal(
                date: dayStart,
                shortSymbol: symbols.indices.contains(symbolIndex) ? symbols[symbolIndex] : "",
                netEarned: insightsService.dayAggregate(on: dayStart, aggregates: aggregates)?.netEarned ?? 0,
                expectedNet: isWorkday ? expectedNet : 0,
                isToday: dayStart == today,
                isFuture: dayStart > today,
                isWorkday: isWorkday,
                isLive: dayStart == today && isLiveToday
            )
        }
    }

    func goalProgressStatus(at date: Date) -> SavingsGoalProgress? {
        insightsService.goalProgress(
            targetAmount: configuration.savingsGoalAmount,
            aggregates: selectedDayAggregates(at: date)
        )
    }

    func achievementsStatus(at date: Date) -> [AchievementStatus] {
        insightsService.achievements(
            at: date,
            aggregates: selectedDayAggregates(at: date),
            configuration: configuration
        )
    }

    func spendingComparisonsStatus(at date: Date) -> [SpendingComparison] {
        insightsService.spendingComparisons(
            at: date,
            aggregates: selectedDayAggregates(at: date),
            netPerSecond: estimate.netPerSecond
        )
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

    private var trimmedProfileNameInput: String {
        profileNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedStreamNameInput: String {
        streamNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Keeps amounts small enough to format safely: at most 9 whole-dollar digits and 2 decimal places.
    private func sanitizeCurrencyInput(_ value: String) -> String {
        var sanitized = ""
        var hasDecimalSeparator = false
        var wholeDigits = 0
        var fractionDigits = 0

        for character in value {
            if character.isASCII, character.isNumber {
                if hasDecimalSeparator {
                    guard fractionDigits < LiveWageConstants.maxCurrencyFractionDigits else { continue }
                    fractionDigits += 1
                } else {
                    guard wholeDigits < LiveWageConstants.maxCurrencyWholeDigits else { continue }
                    wholeDigits += 1
                }
                sanitized.append(character)
                continue
            }

            if character == ",", !hasDecimalSeparator {
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

        for index in 2...(LiveWageConstants.maxIncomeStreams + 3) {
            let candidate = "Income \(index)"
            if !existingNames.contains(candidate) {
                return candidate
            }
        }

        return "Income \(streams.count + 1)"
    }

    private func finalizeActiveSession(at date: Date) {
        guard let snapshot = sessionSnapshot(at: date) else { return }
        guard let record = sessionCalculator.workdayRecord(from: snapshot, completedAt: date) else { return }
        upsert(record: record)
    }

    private func upsert(record: WorkdayRecord) {
        history = insightsService.upserting(record, into: history)
        persistHistory()
    }

    private func selectedDayAggregates(at date: Date) -> [Date: LiveWageDayAggregate] {
        insightsService.dayAggregates(
            history: history,
            selectedStreamID: selectedStreamID,
            activeSnapshot: sessionSnapshot(at: date)
        )
    }

    private func dayAggregate(on date: Date, at referenceDate: Date) -> LiveWageDayAggregate? {
        insightsService.dayAggregate(
            on: date,
            aggregates: selectedDayAggregates(at: referenceDate)
        )
    }

    private func currentStreakValue(at date: Date) -> Int {
        insightsService.currentStreak(
            at: date,
            aggregates: selectedDayAggregates(at: date),
            configuration: configuration
        )
    }

    private func bestStreakValue(at date: Date) -> Int {
        insightsService.bestStreak(
            at: date,
            aggregates: selectedDayAggregates(at: date),
            configuration: configuration
        )
    }

    private func persistWorkspace() {
        persistState()
    }

    private func persistHistory() {
        persistState()
    }

    private func persistSession() {
        persistState()
    }

    private func persistState() {
        persistence.saveState(
            LiveWagePersistedState(
                workspace: LiveWageWorkspace(
                    streams: streams,
                    selectedStreamID: selectedStreamID
                ),
                history: history,
                activeSession: activeSession,
                settings: localSettings
            )
        )
    }
}
