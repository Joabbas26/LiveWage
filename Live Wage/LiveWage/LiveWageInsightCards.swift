//
//  LiveWageInsightCards.swift
//  LiveWage
//
//  Created by Codex on 5/5/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct WeeklySummaryCard: View {
    let summary: WeeklySummary
    let days: [WeekDayTotal]

    @State private var shareItems: [Any] = []
    @State private var isShareSheetPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Take-home this week")
                        .font(.liveWage(.subheadline, weight: .bold))
                        .foregroundStyle(LiveWageTheme.secondaryText)
                        .accessibilityAddTraits(.isHeader)

                    Text(summary.netTotal.currencyString)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(LiveWageTheme.primaryText)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    if let today = days.first(where: \.isToday), today.netEarned > 0 {
                        Text("+\(today.netEarned.currencyString) \(today.isLive ? "so far today" : "today")")
                            .font(.liveWage(.subheadline, weight: .bold))
                            .foregroundStyle(LiveWageTheme.greenText)
                    }
                }

                Spacer(minLength: 0)

                Button(action: prepareShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(LiveWageTheme.primaryText)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(LiveWageTheme.inputSurface)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(LiveWageTheme.strongStroke, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share weekly summary")
                .accessibilityHint("Creates a shareable weekly earnings card")
            }

            WeekBarChart(days: days)
                .padding(.top, 20)

            LiveWageDivider()
                .padding(.vertical, 16)

            HStack(spacing: 8) {
                LiveWageMetric(title: "Days worked", value: "\(summary.daysWorked)")
                LiveWageMetric(title: "Hours", value: String(format: "%.1f", summary.totalHours))
                LiveWageMetric(title: "Avg day", value: summary.averageDailyNet.currencyString)
            }

            if summary.daysWorked == 0 {
                Text("No tracked workdays yet this week. Your first session will show up here automatically.")
                    .font(.liveWage(.footnote, weight: .medium))
                    .foregroundStyle(LiveWageTheme.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }
        }
        .padding(20)
        .liveWageCard()
        .sheet(isPresented: $isShareSheetPresented) {
            ShareSheet(items: shareItems)
        }
    }

    private func prepareShare() {
        let renderer = ImageRenderer(
            content: WeeklyShareGraphic(summary: summary)
                .frame(width: 1080, height: 1350)
        )
        #if canImport(UIKit)
        if let image = renderer.uiImage {
            shareItems = [image, summary.shareText]
        } else {
            shareItems = [summary.shareText]
        }
        #else
        shareItems = [summary.shareText]
        #endif

        LiveWageTelemetry.shared.weeklySummaryShared(
            daysWorked: summary.daysWorked,
            hasEarnings: summary.netTotal > 0
        )
        isShareSheetPresented = true
    }
}

struct WeekBarChart: View {
    let days: [WeekDayTotal]

    private let plotHeight: CGFloat = 140
    private let barWidth: CGFloat = 26

    var body: some View {
        let peak = max(days.map { max($0.netEarned, showsExpected($0) ? $0.expectedNet : 0) }.max() ?? 0, 1)

        HStack(alignment: .bottom, spacing: 2) {
            ForEach(days) { day in
                column(for: day, peak: peak)
            }
        }
    }

    private func column(for day: WeekDayTotal, peak: Double) -> some View {
        VStack(spacing: 8) {
            VStack(spacing: 4) {
                Spacer(minLength: 0)

                if day.isLive {
                    Text(day.netEarned.wholeCurrencyString)
                        .font(.liveWage(.caption, weight: .bold))
                        .foregroundStyle(LiveWageTheme.greenText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else if showsExpected(day) {
                    Text("est.")
                        .font(.liveWage(.caption, weight: .semibold))
                        .foregroundStyle(LiveWageTheme.mutedText)
                }

                bar(for: day, peak: peak)
            }
            .frame(height: plotHeight + 22)

            Text(day.shortSymbol)
                .font(.liveWage(.footnote, weight: day.isToday ? .heavy : .semibold))
                .foregroundStyle(day.isToday ? LiveWageTheme.primaryText : LiveWageTheme.mutedText)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide)))
        .accessibilityValue(accessibilityValue(for: day))
    }

    @ViewBuilder
    private func bar(for day: WeekDayTotal, peak: Double) -> some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4, style: .continuous)

        if day.netEarned > 0 {
            shape
                .fill(LiveWageTheme.green.opacity(day.isLive ? 0.6 : 1))
                .frame(width: barWidth, height: barHeight(for: day.netEarned, peak: peak))
        } else if showsExpected(day) {
            shape
                .stroke(LiveWageTheme.subtleText, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .frame(width: barWidth, height: barHeight(for: day.expectedNet, peak: peak))
        } else {
            Capsule(style: .continuous)
                .fill(LiveWageTheme.progressTrack)
                .frame(width: barWidth, height: 2)
        }
    }

    private func showsExpected(_ day: WeekDayTotal) -> Bool {
        day.isWorkday && day.netEarned == 0 && (day.isFuture || day.isToday)
    }

    private func barHeight(for value: Double, peak: Double) -> CGFloat {
        max(CGFloat(value / peak) * plotHeight, 4)
    }

    private func accessibilityValue(for day: WeekDayTotal) -> String {
        if day.netEarned > 0 {
            return day.isLive ? "\(day.netEarned.currencyString) so far" : day.netEarned.currencyString
        }

        if showsExpected(day) {
            return "About \(day.expectedNet.currencyString) expected"
        }

        return "No earnings"
    }
}

struct SavingsTargetCard: View {
    let goalProgress: SavingsGoalProgress?
    let netDaily: Double
    var onAddTarget: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Savings target")
                    .font(.liveWage(.subheadline, weight: .bold))
                    .foregroundStyle(LiveWageTheme.secondaryText)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                if let goalProgress {
                    Text(goalProgress.progress.formatted(.percent.precision(.fractionLength(0))))
                        .font(.liveWage(.subheadline, weight: .bold))
                        .foregroundStyle(LiveWageTheme.greenText)
                }
            }

            if let goalProgress {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(goalProgress.currentAmount.wholeCurrencyString)
                        .font(.liveWage(.title2, weight: .bold))
                        .foregroundStyle(LiveWageTheme.primaryText)
                        .monospacedDigit()

                    Text("of \(goalProgress.targetAmount.wholeCurrencyString)")
                        .font(.liveWage(.subheadline, weight: .semibold))
                        .foregroundStyle(LiveWageTheme.mutedText)
                }

                LiveWageProgressBar(progress: goalProgress.progress, tint: LiveWageTheme.green, height: 10)
                    .padding(.vertical, 4)

                Text(paceText(for: goalProgress))
                    .font(.liveWage(.footnote, weight: .medium))
                    .foregroundStyle(LiveWageTheme.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Add a target in Pay details to see how many workdays it takes to reach it.")
                    .font(.liveWage(.footnote, weight: .medium))
                    .foregroundStyle(LiveWageTheme.mutedText)
                    .fixedSize(horizontal: false, vertical: true)

                if let onAddTarget {
                    Button(action: onAddTarget) {
                        Text("Add a savings target")
                            .font(.liveWage(.subheadline, weight: .bold))
                            .foregroundStyle(LiveWageTheme.greenText)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .liveWageCard()
        .accessibilityElement(children: .combine)
    }

    private func paceText(for progress: SavingsGoalProgress) -> String {
        if progress.isComplete {
            return "Target reached — nice work."
        }

        let remaining = progress.remainingAmount.wholeCurrencyString
        guard netDaily > 0 else { return "\(remaining) to go" }

        let workdays = Int((progress.remainingAmount / netDaily).rounded(.up))
        return "\(remaining) to go — about \(workdays) \(workdays == 1 ? "workday" : "workdays") at your current pace"
    }
}

struct StreaksCard: View {
    let currentStreak: Int
    let bestStreak: Int

    var body: some View {
        HStack(spacing: 12) {
            tile(title: "Current streak", value: currentStreak, symbol: "flame.fill", tint: LiveWageTheme.amberText)
            tile(title: "Best streak", value: bestStreak, symbol: "trophy.fill", tint: LiveWageTheme.secondaryText)
        }
    }

    private func tile(title: String, value: Int, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.liveWage(.footnote, weight: .semibold))
                .foregroundStyle(LiveWageTheme.mutedText)
                .labelStyle(TintedIconLabelStyle(tint: tint))

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(value)")
                    .font(.liveWage(.title, weight: .bold))
                    .foregroundStyle(LiveWageTheme.primaryText)
                    .monospacedDigit()

                Text(value == 1 ? "workday" : "workdays")
                    .font(.liveWage(.subheadline, weight: .semibold))
                    .foregroundStyle(LiveWageTheme.mutedText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .liveWageCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value) \(value == 1 ? "workday" : "workdays")")
    }
}

private struct TintedIconLabelStyle: LabelStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
                .foregroundStyle(tint)
            configuration.title
        }
    }
}

struct AchievementsCard: View {
    let achievements: [AchievementStatus]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Achievements")
                    .font(.liveWage(.subheadline, weight: .bold))
                    .foregroundStyle(LiveWageTheme.secondaryText)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Text("\(achievements.filter(\.isUnlocked).count) of \(achievements.count)")
                    .font(.liveWage(.footnote, weight: .bold))
                    .foregroundStyle(LiveWageTheme.mutedText)
            }
            .padding(.bottom, 6)

            ForEach(Array(achievements.enumerated()), id: \.element.id) { index, achievement in
                if index > 0 {
                    LiveWageDivider()
                }

                row(for: achievement)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .liveWageCard()
    }

    private func row(for achievement: AchievementStatus) -> some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.badgeSymbolName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(achievement.isUnlocked ? LiveWageTheme.greenText : LiveWageTheme.mutedText)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(achievement.isUnlocked ? LiveWageTheme.greenSoft : LiveWageTheme.elevatedSurface)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(achievement.title)
                        .font(.liveWage(.subheadline, weight: .bold))
                        .foregroundStyle(LiveWageTheme.primaryText)

                    Spacer(minLength: 0)

                    if achievement.isUnlocked {
                        Label("Done", systemImage: "checkmark")
                            .font(.liveWage(.footnote, weight: .bold))
                            .foregroundStyle(LiveWageTheme.greenText)
                    } else {
                        Text(achievement.progressText)
                            .font(.liveWage(.footnote, weight: .bold))
                            .foregroundStyle(LiveWageTheme.mutedText)
                            .monospacedDigit()
                    }
                }

                Text(achievement.detail)
                    .font(.liveWage(.footnote, weight: .medium))
                    .foregroundStyle(LiveWageTheme.mutedText)
                    .fixedSize(horizontal: false, vertical: true)

                if !achievement.isUnlocked {
                    LiveWageProgressBar(progress: achievement.progress, tint: LiveWageTheme.primaryText, height: 6)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(achievement.title)
        .accessibilityValue(achievement.isUnlocked ? "Done" : achievement.progressText)
        .accessibilityHint(achievement.detail)
    }
}

struct SpendingCoverageCard: View {
    let comparisons: [SpendingComparison]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today's pay already covers")
                .font(.liveWage(.subheadline, weight: .bold))
                .foregroundStyle(LiveWageTheme.secondaryText)
                .padding(.bottom, 4)
                .accessibilityAddTraits(.isHeader)

            ForEach(comparisons) { comparison in
                row(for: comparison)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .liveWageCard()
    }

    private func row(for comparison: SpendingComparison) -> some View {
        let progress = comparison.amount > 0 ? min(comparison.currentAmountEarned / comparison.amount, 1) : 1
        let percent = Int(progress * 100)

        return HStack(spacing: 12) {
            if comparison.isCoveredToday {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(LiveWageTheme.green)
                    .frame(width: 24, height: 24)
            } else {
                Circle()
                    .strokeBorder(LiveWageTheme.subtleText, style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                    .frame(width: 24, height: 24)
            }

            Text(comparison.title.sentenceCased)
                .font(.liveWage(.subheadline, weight: .bold))
                .foregroundStyle(LiveWageTheme.primaryText)

            Spacer(minLength: 8)

            if comparison.isCoveredToday {
                Text(comparison.amount.currencyString)
                    .font(.liveWage(.subheadline, weight: .semibold))
                    .foregroundStyle(LiveWageTheme.mutedText)
                    .monospacedDigit()
            } else {
                LiveWageProgressBar(progress: progress, tint: LiveWageTheme.primaryText, height: 6)
                    .frame(width: 48)

                Text("\(percent)% of \(comparison.amount.wholeCurrencyString)")
                    .font(.liveWage(.subheadline, weight: .semibold))
                    .foregroundStyle(LiveWageTheme.mutedText)
                    .monospacedDigit()
            }
        }
        .frame(minHeight: 36)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(comparison.title.sentenceCased)
        .accessibilityValue(
            comparison.isCoveredToday
                ? "Covered, \(comparison.amount.currencyString)"
                : "\(percent) percent of \(comparison.amount.currencyString) earned"
        )
    }
}

enum PayBreakdownPeriod: String, CaseIterable, Identifiable {
    case hour
    case day
    case year

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var phrase: String {
        switch self {
        case .hour:
            return "an hour"
        case .day:
            return "a workday"
        case .year:
            return "a year"
        }
    }
}

struct PayBreakdownCard: View {
    let estimate: EarningsEstimate
    let taxRows: [TaxBreakdownRow]
    let configuration: EarningsConfiguration

    @State private var period: PayBreakdownPeriod = .hour

    private struct Line: Identifiable {
        let id: String
        let title: String
        let annualAmount: Double
        let isTakeHome: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Where your pay goes")
                .font(.liveWage(.title3, weight: .bold))
                .foregroundStyle(LiveWageTheme.primaryText)
                .accessibilityAddTraits(.isHeader)

            Picker("Time period", selection: $period) {
                ForEach(PayBreakdownPeriod.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Text("\(formatted(estimate.annualGross)) gross \(period.phrase) · \(estimate.effectiveTaxRate.percentString) goes to tax")
                .font(.liveWage(.subheadline, weight: .semibold))
                .foregroundStyle(LiveWageTheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                ForEach(lines) { line in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(line.title)
                                .font(.liveWage(.subheadline, weight: .semibold))
                                .foregroundStyle(LiveWageTheme.secondaryText)

                            Spacer(minLength: 12)

                            Text(formatted(line.annualAmount))
                                .font(.liveWage(.subheadline, weight: .bold))
                                .foregroundStyle(LiveWageTheme.primaryText)
                                .monospacedDigit()
                        }

                        LiveWageProgressBar(
                            progress: estimate.annualGross > 0 ? line.annualAmount / estimate.annualGross : 0,
                            tint: line.isTakeHome ? LiveWageTheme.green : LiveWageTheme.taxBar,
                            height: 8
                        )
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(20)
        .liveWageCard()
    }

    private var lines: [Line] {
        var lines = [
            Line(id: "net", title: "Take-home", annualAmount: estimate.annualNet, isTakeHome: true)
        ]

        lines += taxRows.map { row in
            Line(id: row.id, title: row.title, annualAmount: row.amount, isTakeHome: false)
        }

        if estimate.annualRetirementContribution > 0 {
            lines.append(Line(id: "retirement", title: "Retirement savings", annualAmount: estimate.annualRetirementContribution, isTakeHome: false))
        }

        if estimate.annualPretaxBenefits > 0 {
            lines.append(Line(id: "benefits", title: "Pre-tax benefits", annualAmount: estimate.annualPretaxBenefits, isTakeHome: false))
        }

        return lines
    }

    private var divisor: Double {
        switch period {
        case .hour:
            return max(configuration.workDaysPerYear * Double(configuration.workHoursPerDay), 1)
        case .day:
            return max(configuration.workDaysPerYear, 1)
        case .year:
            return 1
        }
    }

    private func formatted(_ annualAmount: Double) -> String {
        let value = annualAmount / divisor
        return period == .year ? value.wholeCurrencyString : value.currencyString
    }
}

private struct WeeklyShareGraphic: View {
    let summary: WeeklySummary

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x171513),
                    Color(hex: 0x26211B),
                    Color(hex: 0x365126)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 42) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Live Wage")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(LiveWageTheme.green)

                    Text("Weekly earnings summary")
                        .font(.system(size: 82, weight: .bold, design: .rounded))
                        .foregroundStyle(LiveWageTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(summary.weekLabel)
                        .font(.system(size: 38, weight: .medium, design: .rounded))
                        .foregroundStyle(LiveWageTheme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 18) {
                    Text(summary.streamName)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(LiveWageTheme.secondaryText)

                    Text(summary.netTotal.currencyString)
                        .font(.system(size: 144, weight: .bold, design: .rounded))
                        .foregroundStyle(LiveWageTheme.primaryText)
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    Text("take-home this week")
                        .font(.system(size: 44, weight: .medium, design: .rounded))
                        .foregroundStyle(LiveWageTheme.secondaryText)
                }

                HStack(spacing: 24) {
                    shareMetric(title: "Workdays", value: "\(summary.daysWorked)")
                    shareMetric(title: "Average day", value: summary.averageDailyNet.compactCurrency)
                    shareMetric(title: "Hours", value: String(format: "%.1f", summary.totalHours))
                }

                Spacer()

                Text("Live Wage")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(LiveWageTheme.secondaryText.opacity(0.7))
            }
            .padding(72)
        }
        .preferredColorScheme(.dark)
    }

    private func shareMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(LiveWageTheme.subtleText)

            Text(value)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(LiveWageTheme.primaryText)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

#if canImport(UIKit)
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
private struct ShareSheet: View {
    let items: [Any]
    var body: some View { EmptyView() }
}
#endif

#Preview("Insight cards") {
    ScrollView {
        VStack(spacing: 16) {
            SavingsTargetCard(
                goalProgress: SavingsGoalProgress(targetAmount: 5_000, currentAmount: 3_240),
                netDaily: 234.61
            )
            StreaksCard(currentStreak: 12, bestStreak: 18)
            AchievementsCard(
                achievements: [
                    AchievementStatus(
                        id: "first-100-day",
                        title: "First $100 day",
                        detail: "Hit $100 take-home in a single tracked day.",
                        isUnlocked: true,
                        progress: 1,
                        progressText: "Unlocked"
                    ),
                    AchievementStatus(
                        id: "first-1000-week",
                        title: "$1,000 week",
                        detail: "Bring home $1,000 across one tracked calendar week.",
                        isUnlocked: false,
                        progress: 0.8,
                        progressText: "$802 / $1,000"
                    )
                ]
            )
            SpendingCoverageCard(
                comparisons: [
                    SpendingComparison(
                        id: "coffee",
                        title: "coffee run",
                        amount: 6.50,
                        timeToEarnSeconds: 800,
                        currentAmountEarned: 111
                    ),
                    SpendingComparison(
                        id: "flight",
                        title: "cheap flight",
                        amount: 249,
                        timeToEarnSeconds: 30_500,
                        currentAmountEarned: 111
                    )
                ]
            )
        }
        .padding(20)
    }
    .background(LiveWageTheme.appBackground.ignoresSafeArea())
}
