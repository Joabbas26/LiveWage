//
//  ClockedInsightCards.swift
//  Clocked
//
//  Created by Codex on 5/5/26.
//

import SwiftUI
import UIKit

struct MomentumCard: View {
    let currentStreak: Int
    let bestStreak: Int
    let goalProgress: SavingsGoalProgress?
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Momentum")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(ClockedTheme.secondaryText)

            HStack(spacing: 12) {
                metricTile(
                    title: "Current streak",
                    value: "\(currentStreak)",
                    subtitle: currentStreak == 1 ? "workday" : "workdays"
                )

                metricTile(
                    title: "Best streak",
                    value: "\(bestStreak)",
                    subtitle: bestStreak == 1 ? "workday" : "workdays"
                )
            }

            if let goalProgress {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Savings target")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(ClockedTheme.primaryText)

                            Text(goalProgress.isComplete ? "Goal reached" : "\(goalProgress.remainingAmount.currencyString) left")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(goalProgress.isComplete ? ClockedTheme.green : ClockedTheme.subtleText)
                        }

                        Spacer()

                        Text("\(goalProgress.currentAmount.compactCurrency) / \(goalProgress.targetAmount.compactCurrency)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(ClockedTheme.primaryText)
                            .monospacedDigit()
                    }

                    ProgressTrack(progress: goalProgress.progress, tint: goalProgress.isComplete ? ClockedTheme.green : ClockedTheme.primaryText)
                }
            } else if !compact {
                Text("Set a savings target in Advanced to watch your take-home progress fill in real time.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(ClockedTheme.subtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .clockedCard()
    }

    private func metricTile(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(ClockedTheme.subtleText)

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(ClockedTheme.primaryText)
                .monospacedDigit()

            Text(subtitle)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(ClockedTheme.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ClockedTheme.inputSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ClockedTheme.stroke, lineWidth: 1)
        )
    }
}

struct WeeklySummaryCard: View {
    let summary: WeeklySummary
    var compact: Bool = false

    @State private var shareItems: [Any] = []
    @State private var isShareSheetPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("This week")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(ClockedTheme.secondaryText)

                    Text(summary.weekLabel)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(ClockedTheme.subtleText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button(action: prepareShare) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(ClockedTheme.primaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(ClockedTheme.inputSurface)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(ClockedTheme.stroke, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(summary.netTotal.currencyString)
                    .font(.system(size: compact ? 34 : 40, weight: .bold, design: .rounded))
                    .foregroundStyle(ClockedTheme.primaryText)
                    .monospacedDigit()

                Text("take-home")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(ClockedTheme.secondaryText)
            }

            HStack(spacing: 12) {
                summaryTile(title: "Days worked", value: "\(summary.daysWorked)")
                summaryTile(title: "Avg day", value: summary.averageDailyNet.compactCurrency)
                if !compact {
                    summaryTile(title: "Hours", value: String(format: "%.1f", summary.totalHours))
                }
            }

            if summary.daysWorked == 0 {
                Text("No tracked workdays yet this week. Your first completed session will show up here automatically.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(ClockedTheme.subtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .clockedCard()
        .sheet(isPresented: $isShareSheetPresented) {
            ShareSheet(items: shareItems)
        }
    }

    private func summaryTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(ClockedTheme.subtleText)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(ClockedTheme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ClockedTheme.inputSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ClockedTheme.stroke, lineWidth: 1)
        )
    }

    private func prepareShare() {
        let renderer = ImageRenderer(
            content: WeeklyShareGraphic(summary: summary)
                .frame(width: 1080, height: 1350)
        )
        if let image = renderer.uiImage {
            shareItems = [image, summary.shareText]
        } else {
            shareItems = [summary.shareText]
        }

        isShareSheetPresented = true
    }
}

struct AchievementsCard: View {
    let achievements: [AchievementStatus]
    var maxItems: Int = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Achievements")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(ClockedTheme.secondaryText)

            ForEach(Array(achievements.prefix(maxItems))) { achievement in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(achievement.title)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(ClockedTheme.primaryText)

                            Text(achievement.detail)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(ClockedTheme.subtleText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Text(achievement.progressText)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(achievement.isUnlocked ? ClockedTheme.green : ClockedTheme.secondaryText)
                            .multilineTextAlignment(.trailing)
                    }

                    ProgressTrack(progress: achievement.progress, tint: achievement.isUnlocked ? ClockedTheme.green : ClockedTheme.primaryText)
                }
            }
        }
        .padding(22)
        .clockedCard()
    }
}

struct SpendingComparisonsCard: View {
    let comparisons: [SpendingComparison]
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Spending comparisons")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(ClockedTheme.secondaryText)

            ForEach(Array(comparisons.prefix(compact ? 2 : 4))) { comparison in
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(comparison.title.capitalized)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(ClockedTheme.primaryText)

                        Text(comparison.detail)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(ClockedTheme.subtleText)
                    }

                    Spacer()

                    Text(comparisonText(for: comparison))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(comparison.isCoveredToday ? ClockedTheme.green : ClockedTheme.secondaryText)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(22)
        .clockedCard()
    }

    private func comparisonText(for comparison: SpendingComparison) -> String {
        let timeText = comparison.timeToEarnSeconds > 0 ? comparison.timeToEarnSeconds.shortDurationString : "--"

        if comparison.isCoveredToday {
            return "You earned this in \(timeText) today"
        }

        return "\(timeText) of work"
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
                    Text("Clocked")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(ClockedTheme.green)

                    Text("Weekly earnings summary")
                        .font(.system(size: 82, weight: .bold, design: .rounded))
                        .foregroundStyle(ClockedTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(summary.weekLabel)
                        .font(.system(size: 38, weight: .medium, design: .rounded))
                        .foregroundStyle(ClockedTheme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 18) {
                    Text(summary.streamName)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(ClockedTheme.secondaryText)

                    Text(summary.netTotal.currencyString)
                        .font(.system(size: 144, weight: .bold, design: .rounded))
                        .foregroundStyle(ClockedTheme.primaryText)
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    Text("take-home this week")
                        .font(.system(size: 44, weight: .medium, design: .rounded))
                        .foregroundStyle(ClockedTheme.secondaryText)
                }

                HStack(spacing: 24) {
                    shareMetric(title: "Workdays", value: "\(summary.daysWorked)")
                    shareMetric(title: "Average day", value: summary.averageDailyNet.compactCurrency)
                    shareMetric(title: "Hours", value: String(format: "%.1f", summary.totalHours))
                }

                Spacer()

                Text("clocked")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(ClockedTheme.secondaryText.opacity(0.7))
            }
            .padding(72)
        }
        .preferredColorScheme(.dark)
    }

    private func shareMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(ClockedTheme.subtleText)

            Text(value)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(ClockedTheme.primaryText)
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

private struct ProgressTrack: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(ClockedTheme.progressTrack)

                Capsule(style: .continuous)
                    .fill(tint)
                    .frame(width: geometry.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 8)
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview("Insights") {
    ScrollView {
        VStack(spacing: 16) {
            MomentumCard(
                currentStreak: 4,
                bestStreak: 9,
                goalProgress: SavingsGoalProgress(targetAmount: 10_000, currentAmount: 3_240)
            )
            WeeklySummaryCard(
                summary: WeeklySummary(
                    streamName: "Main Income",
                    weekStart: .now,
                    weekEnd: .now,
                    netTotal: 824.12,
                    grossTotal: 1_020.64,
                    daysWorked: 3,
                    totalHours: 19.5
                )
            )
            AchievementsCard(
                achievements: [
                    AchievementStatus(
                        id: "1",
                        title: "First $100 day",
                        detail: "Hit $100 take-home in a single tracked day.",
                        isUnlocked: true,
                        progress: 1,
                        progressText: "Unlocked"
                    )
                ]
            )
            SpendingComparisonsCard(
                comparisons: [
                    SpendingComparison(
                        id: "netflix",
                        title: "Netflix subscription",
                        amount: 15.49,
                        timeToEarnSeconds: 240,
                        currentAmountEarned: 40
                    )
                ]
            )
        }
        .padding(20)
    }
    .background(ClockedTheme.appBackground.ignoresSafeArea())
    .preferredColorScheme(.dark)
}
