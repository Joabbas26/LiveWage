//
//  LiveWageModels.swift
//  LiveWage
//
//  Created by Codex on 5/4/26.
//

import Foundation
import SwiftUI

enum LiveWageConstants {
    static let primaryStreamID = UUID(uuidString: "2E0A6EF2-3A84-4D3A-9B7A-6BC5A3B91111")!
    static let maxIncomeStreams = 3
    static let maxCurrencyWholeDigits = 9
    static let maxCurrencyFractionDigits = 2
}

enum LiveWageAppearancePreference: String, CaseIterable, Codable, Identifiable {
    case system
    case dark
    case light

    static let allCases: [LiveWageAppearancePreference] = [.dark, .light, .system]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .dark:
            return "Dark"
        case .light:
            return "Light"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .dark:
            return .dark
        case .light:
            return .light
        }
    }
}

struct LiveWageLocalSettings: Codable, Equatable {
    var appearancePreference: LiveWageAppearancePreference
    var profileName: String

    init(
        appearancePreference: LiveWageAppearancePreference = .system,
        profileName: String = ""
    ) {
        self.appearancePreference = appearancePreference
        self.profileName = profileName
    }

    private enum CodingKeys: String, CodingKey {
        case appearancePreference
        case profileName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appearancePreference = try container.decodeIfPresent(LiveWageAppearancePreference.self, forKey: .appearancePreference) ?? .system
        profileName = try container.decodeIfPresent(String.self, forKey: .profileName) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(appearancePreference, forKey: .appearancePreference)
        try container.encode(profileName, forKey: .profileName)
    }

    static let `default` = LiveWageLocalSettings()
}

enum PayFrequency: String, CaseIterable, Codable, Identifiable {
    case annual
    case monthly
    case hourly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .annual:
            return "Annual"
        case .monthly:
            return "Monthly"
        case .hourly:
            return "Hourly"
        }
    }

    var inputTitle: String {
        switch self {
        case .annual:
            return "Base salary"
        case .monthly:
            return "Base monthly pay"
        case .hourly:
            return "Base hourly rate"
        }
    }
}

enum FilingStatus: String, CaseIterable, Codable, Identifiable {
    case single
    case marriedJoint
    case headOfHousehold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .single:
            return "Single"
        case .marriedJoint:
            return "Married filing jointly"
        case .headOfHousehold:
            return "Head of household"
        }
    }

    var shortTitle: String {
        switch self {
        case .single:
            return "Single"
        case .marriedJoint:
            return "Joint"
        case .headOfHousehold:
            return "HOH"
        }
    }
}

struct LocationOption: RawRepresentable, CaseIterable, Codable, Identifiable, Equatable, Hashable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    static let newYorkCity = LocationOption(rawValue: "newYork")
    static let california = LocationOption(rawValue: "losAngeles")
    static let illinois = LocationOption(rawValue: "chicago")
    static let texas = LocationOption(rawValue: "austin")
    static let florida = LocationOption(rawValue: "miami")
    static let washington = LocationOption(rawValue: "seattle")
    static let massachusetts = LocationOption(rawValue: "massachusetts")
    static let colorado = LocationOption(rawValue: "colorado")
    static let pennsylvania = LocationOption(rawValue: "pennsylvania")

    static let bootstrapCases: [LocationOption] = [
        .newYorkCity,
        .california,
        .illinois,
        .texas,
        .florida,
        .washington,
        .massachusetts,
        .colorado,
        .pennsylvania,
        LocationOption(rawValue: "alaska"),
        LocationOption(rawValue: "arizona"),
        LocationOption(rawValue: "georgia"),
        LocationOption(rawValue: "idaho"),
        LocationOption(rawValue: "indiana"),
        LocationOption(rawValue: "iowa"),
        LocationOption(rawValue: "kentucky"),
        LocationOption(rawValue: "louisiana"),
        LocationOption(rawValue: "michigan"),
        LocationOption(rawValue: "mississippi"),
        LocationOption(rawValue: "nevada"),
        LocationOption(rawValue: "newHampshire"),
        LocationOption(rawValue: "northCarolina"),
        LocationOption(rawValue: "ohio"),
        LocationOption(rawValue: "southDakota"),
        LocationOption(rawValue: "tennessee"),
        LocationOption(rawValue: "utah"),
        LocationOption(rawValue: "virginia"),
        LocationOption(rawValue: "wyoming")
    ]

    static var allCases: [LocationOption] {
        LiveWageTaxCatalog.shared.availableLocations
    }

    var id: String { rawValue }

    var name: String {
        profile?.displayName ?? fallbackDisplayName
    }

    var shortName: String {
        profile?.shortName ?? fallbackShortName
    }

    var stateCode: String {
        profile?.stateCode ?? "--"
    }

    var taxLabel: String {
        profile?.taxLabel ?? "Resident tax estimate"
    }

    var localTaxTitle: String? {
        profile?.localTaxTitle
    }

    private var profile: LocationTaxProfile? {
        LiveWageTaxCatalog.shared.profileIfAvailable(for: self)
    }

    var fallbackDisplayName: String {
        rawValue
            .replacingOccurrences(
                of: "([a-z])([A-Z])",
                with: "$1 $2",
                options: .regularExpression
            )
            .capitalized
    }

    var fallbackShortName: String {
        let words = fallbackDisplayName
            .split(separator: " ")
            .map(String.init)

        let initials = words
            .prefix(3)
            .compactMap(\.first)
            .map { String($0).uppercased() }
            .joined()

        return initials.isEmpty ? rawValue.prefix(3).uppercased() : initials
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct EarningsConfiguration: Codable, Equatable {
    static let retirementDeferralLimit = 23_500.0

    var salaryAmount: Double
    var payFrequency: PayFrequency
    var filingStatus: FilingStatus
    var location: LocationOption
    var workHoursPerDay: Int
    var workDaysPerWeek: Int
    var workStartMinutes: Int
    var annualBonusAmount: Double
    var monthlyPretaxBenefitsAmount: Double
    var retirementContributionPercent: Int
    var savingsGoalAmount: Double

    static let `default` = EarningsConfiguration(
        salaryAmount: 85_000,
        payFrequency: .annual,
        filingStatus: .single,
        location: .newYorkCity,
        workHoursPerDay: 8,
        workDaysPerWeek: 5,
        workStartMinutes: 9 * 60,
        annualBonusAmount: 0,
        monthlyPretaxBenefitsAmount: 0,
        retirementContributionPercent: 0,
        savingsGoalAmount: 10_000
    )

    var annualBaseIncome: Double {
        switch payFrequency {
        case .annual:
            return salaryAmount
        case .monthly:
            return salaryAmount * 12
        case .hourly:
            return salaryAmount * Double(workHoursPerDay) * Double(workDaysPerWeek) * 52
        }
    }

    var annualGrossIncome: Double {
        annualBaseIncome + annualBonusAmount
    }

    var annualPretaxBenefits: Double {
        monthlyPretaxBenefitsAmount * 12
    }

    var annualRetirementContribution: Double {
        let uncapped = annualGrossIncome * (Double(retirementContributionPercent) / 100)
        return min(uncapped, min(annualGrossIncome, Self.retirementDeferralLimit))
    }

    var annualTaxableWagesForFederal: Double {
        max(annualGrossIncome - annualPretaxBenefits - annualRetirementContribution, 0)
    }

    var annualTaxableWagesForFICA: Double {
        max(annualGrossIncome - annualPretaxBenefits, 0)
    }

    var annualTaxableWagesForPennsylvania: Double {
        max(annualGrossIncome - annualPretaxBenefits, 0)
    }

    var workDaysPerYear: Double {
        Double(workDaysPerWeek) * 52
    }

    var workDaySeconds: Double {
        Double(workHoursPerDay) * 3600
    }

    var annualWorkSeconds: Double {
        workDaysPerYear * workDaySeconds
    }

    var compactSummary: String {
        "\(annualGrossIncome.compactCurrency) · \(location.shortName)"
    }

    var workWeekSummary: String {
        switch workDaysPerWeek {
        case 1:
            return "Monday only"
        case 2:
            return "Mon–Tue"
        case 3:
            return "Mon–Wed"
        case 4:
            return "Mon–Thu"
        case 5:
            return "Mon–Fri"
        case 6:
            return "Mon–Sat"
        default:
            return "Every day"
        }
    }

    func startTimeDate(anchor: Date = .now, calendar: Calendar) -> Date {
        let dayStart = calendar.startOfDay(for: anchor)
        return calendar.date(byAdding: .minute, value: workStartMinutes, to: dayStart) ?? dayStart
    }

    func startTimeDate(calendar: Calendar) -> Date {
        startTimeDate(anchor: .now, calendar: calendar)
    }

    func scheduledStart(on workDate: Date, calendar: Calendar) -> Date {
        let dayStart = calendar.startOfDay(for: workDate)
        return calendar.date(byAdding: .minute, value: workStartMinutes, to: dayStart) ?? dayStart
    }

    func scheduledEnd(on workDate: Date, calendar: Calendar) -> Date {
        scheduledStart(on: workDate, calendar: calendar)
            .addingTimeInterval(workDaySeconds)
    }

    func isWorkday(on date: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return orderedWorkdays.contains(weekday)
    }

    func nextWorkDate(from date: Date, calendar: Calendar) -> Date {
        let referenceDay = calendar.startOfDay(for: date)

        for offset in 0..<14 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: referenceDay) else { continue }
            guard isWorkday(on: candidate, calendar: calendar) else { continue }

            if offset == 0, date >= scheduledEnd(on: candidate, calendar: calendar) {
                continue
            }

            return calendar.startOfDay(for: candidate)
        }

        return calendar.startOfDay(for: date)
    }

    private var orderedWorkdays: [Int] {
        let mondayFirstWeekdays = [2, 3, 4, 5, 6, 7, 1]
        return Array(mondayFirstWeekdays.prefix(max(1, min(workDaysPerWeek, 7))))
    }

    private enum CodingKeys: String, CodingKey {
        case salaryAmount
        case payFrequency
        case filingStatus
        case location
        case workHoursPerDay
        case workDaysPerWeek
        case workStartMinutes
        case annualBonusAmount
        case monthlyPretaxBenefitsAmount
        case retirementContributionPercent
        case savingsGoalAmount
    }

    init(
        salaryAmount: Double,
        payFrequency: PayFrequency,
        filingStatus: FilingStatus,
        location: LocationOption,
        workHoursPerDay: Int,
        workDaysPerWeek: Int,
        workStartMinutes: Int,
        annualBonusAmount: Double,
        monthlyPretaxBenefitsAmount: Double,
        retirementContributionPercent: Int,
        savingsGoalAmount: Double
    ) {
        self.salaryAmount = salaryAmount
        self.payFrequency = payFrequency
        self.filingStatus = filingStatus
        self.location = location
        self.workHoursPerDay = workHoursPerDay
        self.workDaysPerWeek = workDaysPerWeek
        self.workStartMinutes = workStartMinutes
        self.annualBonusAmount = annualBonusAmount
        self.monthlyPretaxBenefitsAmount = monthlyPretaxBenefitsAmount
        self.retirementContributionPercent = retirementContributionPercent
        self.savingsGoalAmount = savingsGoalAmount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.default

        salaryAmount = try container.decodeIfPresent(Double.self, forKey: .salaryAmount) ?? defaults.salaryAmount
        payFrequency = try container.decodeIfPresent(PayFrequency.self, forKey: .payFrequency) ?? defaults.payFrequency
        filingStatus = try container.decodeIfPresent(FilingStatus.self, forKey: .filingStatus) ?? defaults.filingStatus
        location = try container.decodeIfPresent(LocationOption.self, forKey: .location) ?? defaults.location
        workHoursPerDay = try container.decodeIfPresent(Int.self, forKey: .workHoursPerDay) ?? defaults.workHoursPerDay
        workDaysPerWeek = try container.decodeIfPresent(Int.self, forKey: .workDaysPerWeek) ?? defaults.workDaysPerWeek
        workStartMinutes = try container.decodeIfPresent(Int.self, forKey: .workStartMinutes) ?? defaults.workStartMinutes
        annualBonusAmount = try container.decodeIfPresent(Double.self, forKey: .annualBonusAmount) ?? defaults.annualBonusAmount
        monthlyPretaxBenefitsAmount = try container.decodeIfPresent(Double.self, forKey: .monthlyPretaxBenefitsAmount) ?? defaults.monthlyPretaxBenefitsAmount
        retirementContributionPercent = try container.decodeIfPresent(Int.self, forKey: .retirementContributionPercent) ?? defaults.retirementContributionPercent
        savingsGoalAmount = try container.decodeIfPresent(Double.self, forKey: .savingsGoalAmount) ?? defaults.savingsGoalAmount
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(salaryAmount, forKey: .salaryAmount)
        try container.encode(payFrequency, forKey: .payFrequency)
        try container.encode(filingStatus, forKey: .filingStatus)
        try container.encode(location, forKey: .location)
        try container.encode(workHoursPerDay, forKey: .workHoursPerDay)
        try container.encode(workDaysPerWeek, forKey: .workDaysPerWeek)
        try container.encode(workStartMinutes, forKey: .workStartMinutes)
        try container.encode(annualBonusAmount, forKey: .annualBonusAmount)
        try container.encode(monthlyPretaxBenefitsAmount, forKey: .monthlyPretaxBenefitsAmount)
        try container.encode(retirementContributionPercent, forKey: .retirementContributionPercent)
        try container.encode(savingsGoalAmount, forKey: .savingsGoalAmount)
    }
}

struct IncomeStream: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var configuration: EarningsConfiguration

    init(
        id: UUID = UUID(),
        name: String,
        configuration: EarningsConfiguration
    ) {
        self.id = id
        self.name = name
        self.configuration = configuration
    }

    static func primary(configuration: EarningsConfiguration) -> IncomeStream {
        IncomeStream(
            id: LiveWageConstants.primaryStreamID,
            name: "Main Income",
            configuration: configuration
        )
    }
}

struct LiveWageWorkspace: Codable, Equatable {
    var streams: [IncomeStream]
    var selectedStreamID: UUID

    static let `default`: LiveWageWorkspace = {
        let primaryStream = IncomeStream.primary(configuration: .default)
        return LiveWageWorkspace(
            streams: [primaryStream],
            selectedStreamID: primaryStream.id
        )
    }()

    func normalized() -> LiveWageWorkspace {
        guard !streams.isEmpty else { return .default }

        let normalizedSelectedStreamID = streams.contains(where: { $0.id == selectedStreamID })
            ? selectedStreamID
            : streams[0].id

        return LiveWageWorkspace(
            streams: streams,
            selectedStreamID: normalizedSelectedStreamID
        )
    }
}

struct WorkSession: Codable, Equatable, Identifiable {
    let id: UUID
    let streamID: UUID
    let streamName: String
    let configuration: EarningsConfiguration
    let workDate: Date
    let createdAt: Date
    var pausedAt: Date?
    var accumulatedPausedSeconds: Double

    init(
        id: UUID = UUID(),
        streamID: UUID,
        streamName: String,
        configuration: EarningsConfiguration,
        workDate: Date,
        createdAt: Date = .now,
        pausedAt: Date? = nil,
        accumulatedPausedSeconds: Double = 0
    ) {
        self.id = id
        self.streamID = streamID
        self.streamName = streamName
        self.configuration = configuration
        self.workDate = workDate
        self.createdAt = createdAt
        self.pausedAt = pausedAt
        self.accumulatedPausedSeconds = accumulatedPausedSeconds
    }

    var isPaused: Bool {
        pausedAt != nil
    }

    func normalized(calendar: Calendar) -> WorkSession {
        let normalizedWorkDate = calendar.startOfDay(for: createdAt)
        guard normalizedWorkDate != workDate else { return self }

        return WorkSession(
            id: id,
            streamID: streamID,
            streamName: streamName,
            configuration: configuration,
            workDate: normalizedWorkDate,
            createdAt: createdAt,
            pausedAt: pausedAt,
            accumulatedPausedSeconds: accumulatedPausedSeconds
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case streamID
        case streamName
        case configuration
        case workDate
        case createdAt
        case pausedAt
        case accumulatedPausedSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        streamID = try container.decodeIfPresent(UUID.self, forKey: .streamID) ?? LiveWageConstants.primaryStreamID
        streamName = try container.decodeIfPresent(String.self, forKey: .streamName) ?? "Main Income"
        configuration = try container.decode(EarningsConfiguration.self, forKey: .configuration)
        workDate = try container.decode(Date.self, forKey: .workDate)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        pausedAt = try container.decodeIfPresent(Date.self, forKey: .pausedAt)
        accumulatedPausedSeconds = try container.decodeIfPresent(Double.self, forKey: .accumulatedPausedSeconds) ?? 0
    }
}

struct WorkdayRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let streamID: UUID
    let streamName: String
    let workDate: Date
    let completedAt: Date
    let configuration: EarningsConfiguration
    let grossEarned: Double
    let netEarned: Double
    let elapsedWorkSeconds: Double

    init(
        id: UUID = UUID(),
        streamID: UUID,
        streamName: String,
        workDate: Date,
        completedAt: Date = .now,
        configuration: EarningsConfiguration,
        grossEarned: Double,
        netEarned: Double,
        elapsedWorkSeconds: Double
    ) {
        self.id = id
        self.streamID = streamID
        self.streamName = streamName
        self.workDate = workDate
        self.completedAt = completedAt
        self.configuration = configuration
        self.grossEarned = grossEarned
        self.netEarned = netEarned
        self.elapsedWorkSeconds = elapsedWorkSeconds
    }
}

struct EarningsEstimate: Equatable {
    let annualBasePay: Double
    let annualBonus: Double
    let annualGross: Double
    let annualPretaxBenefits: Double
    let annualRetirementContribution: Double
    let annualNet: Double
    let grossDaily: Double
    let netDaily: Double
    let grossPerSecond: Double
    let netPerSecond: Double
    let taxableFederalIncome: Double
    let federalIncomeTax: Double
    let stateIncomeTax: Double
    let localIncomeTax: Double
    let socialSecurityTax: Double
    let medicareTax: Double
    let taxYear: Int

    var totalTax: Double {
        federalIncomeTax + stateIncomeTax + localIncomeTax + socialSecurityTax + medicareTax
    }

    var effectiveTaxRate: Double {
        guard annualGross > 0 else { return 0 }
        return totalTax / annualGross
    }
}

enum SessionStatus: Equatable {
    case scheduled
    case live
    case paused
    case complete
}

struct SessionSnapshot {
    let session: WorkSession
    let estimate: EarningsEstimate
    let status: SessionStatus
    let now: Date
    let scheduledStart: Date
    let scheduledEnd: Date
    let elapsedWorkSeconds: Double
    let remainingSeconds: Double
    let grossEarned: Double
    let netEarned: Double

    var progress: Double {
        guard session.configuration.workDaySeconds > 0 else { return 0 }
        return min(max(elapsedWorkSeconds / session.configuration.workDaySeconds, 0), 1)
    }

    var elapsedClockText: String {
        elapsedWorkSeconds.clockString
    }

    var remainingText: String {
        switch status {
        case .scheduled:
            return "Starts \(scheduledStart.formatted(date: .omitted, time: .shortened))"
        case .complete:
            return "Done"
        case .paused, .live:
            return "\(remainingSeconds.shortDurationString) left"
        }
    }

    var statusText: String {
        switch status {
        case .scheduled:
            return "Scheduled"
        case .live:
            return "Live"
        case .paused:
            return "Paused"
        case .complete:
            return "Complete"
        }
    }

    var statusColor: Color {
        switch status {
        case .scheduled:
            return LiveWageTheme.amber
        case .live:
            return LiveWageTheme.green
        case .paused:
            return LiveWageTheme.mutedText
        case .complete:
            return LiveWageTheme.blue
        }
    }

    var amountParts: CurrencyAmountParts {
        CurrencyAmountParts(amount: netEarned)
    }

    var workWindowLabel: String {
        let start = scheduledStart.formatted(date: .omitted, time: .shortened)
        let end = scheduledEnd.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    var dayLabel: String {
        session.workDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

struct WeeklySummary: Equatable {
    let streamName: String
    let weekStart: Date
    let weekEnd: Date
    let netTotal: Double
    let grossTotal: Double
    let daysWorked: Int
    let totalHours: Double

    var averageDailyNet: Double {
        guard daysWorked > 0 else { return 0 }
        return netTotal / Double(daysWorked)
    }

    var weekLabel: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: weekStart, to: weekEnd)
    }

    var shareText: String {
        "\(streamName) earned \(netTotal.currencyString) take-home this week across \(daysWorked) workdays."
    }
}

struct WeekDayTotal: Identifiable, Equatable {
    let date: Date
    let shortSymbol: String
    let netEarned: Double
    let expectedNet: Double
    let isToday: Bool
    let isFuture: Bool
    let isWorkday: Bool
    let isLive: Bool

    var id: Date { date }
}

struct SavingsGoalProgress: Equatable {
    let targetAmount: Double
    let currentAmount: Double

    var remainingAmount: Double {
        max(targetAmount - currentAmount, 0)
    }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(max(currentAmount / targetAmount, 0), 1)
    }

    var isComplete: Bool {
        currentAmount >= targetAmount && targetAmount > 0
    }
}

struct AchievementStatus: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let isUnlocked: Bool
    let progress: Double
    let progressText: String

    var badgeSymbolName: String {
        switch id {
        case "first-100-day":
            return "sun.max.fill"
        case "first-1000-week":
            return "banknote.fill"
        case "five-day-streak":
            return "flame.fill"
        case "thirty-day-streak":
            return "rosette"
        default:
            return "seal.fill"
        }
    }
}

struct SpendingComparison: Identifiable, Equatable {
    let id: String
    let title: String
    let amount: Double
    let timeToEarnSeconds: Double
    let currentAmountEarned: Double

    var isCoveredToday: Bool {
        currentAmountEarned >= amount
    }

    var headline: String {
        if isCoveredToday {
            return "Covered already today"
        }

        return "Earned in \(timeToEarnSeconds.shortDurationString)"
    }

    var detail: String {
        amount.currencyString
    }
}

struct MilestoneStatus: Identifiable {
    let id: String
    let title: String
    let targetAmount: Double
    let currentAmount: Double
    let perSecond: Double

    var statusText: String {
        guard perSecond > 0 else { return "--" }

        let secondsToReach = targetAmount / perSecond
        if currentAmount >= targetAmount {
            return "earned in \(secondsToReach.milestoneString)"
        }

        let remainingSeconds = max((targetAmount - currentAmount) / perSecond, 0)
        return "~\(remainingSeconds.milestoneString) away"
    }

    var tint: Color {
        currentAmount >= targetAmount ? LiveWageTheme.green : LiveWageTheme.mutedText
    }
}

struct CurrencyAmountParts {
    let major: String
    let minor: String

    init(amount: Double) {
        let totalCents = (amount * 100).safeRoundedInt
        let dollars = max(totalCents, 0) / 100
        let cents = max(totalCents, 0) % 100

        major = "$\(dollars.groupedNumber)"
        minor = String(format: ".%02d", cents)
    }
}

struct TaxBreakdownRow: Identifiable {
    let id: String
    let title: String
    let amount: Double

    var formattedAmount: String {
        amount.currencyString
    }
}

extension String {
    var currencyNumber: Double {
        let filtered = filter { ($0.isASCII && $0.isNumber) || $0 == "." }
        let value = Double(filtered) ?? 0
        return value.isFinite ? value : 0
    }
}

// Amounts are US dollars (the tax engine is US-only), so formatting is pinned to en_US rather than the
// device locale. This keeps "$" consistent across screens and keeps grouped input parseable by currencyNumber.
enum LiveWageFormatters {
    static let locale = Locale(identifier: "en_US")

    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    static let wholeNumber: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static let compactNumber: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        return formatter
    }()

    static let currencyInput: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}

extension Double {
    // Int(_:) traps on NaN, infinity, and values past Int.max, so clamp before converting.
    var safeRoundedInt: Int {
        guard isFinite else { return 0 }
        let limit = 1e15
        return Int(min(max(rounded(), -limit), limit))
    }

    var currencyString: String {
        LiveWageFormatters.currency.string(from: NSNumber(value: self)) ?? "$0.00"
    }

    var compactCurrency: String {
        if self >= 1000 {
            let value = self / 1000
            let formatter = LiveWageFormatters.compactNumber
            formatter.maximumFractionDigits = value < 10 ? 1 : 0
            let text = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
            return "$\(text)k"
        }

        return currencyString
    }

    var groupedCurrencyInput: String {
        let formatter = LiveWageFormatters.currencyInput
        formatter.minimumFractionDigits = floor(self) == self ? 0 : 2
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    var clockString: String {
        let totalSeconds = max(safeRoundedInt, 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    var shortDurationString: String {
        let totalSeconds = max(safeRoundedInt, 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }

        if minutes > 0 {
            return seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
        }

        return "\(seconds)s"
    }

    var milestoneString: String {
        shortDurationString
    }
}

extension Int {
    var groupedNumber: String {
        LiveWageFormatters.wholeNumber.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
