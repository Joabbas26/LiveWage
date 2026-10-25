//
//  LiveWageInsightsView.swift
//  LiveWage
//
//  Weekly totals, savings progress, streaks and achievements.
//

import SwiftUI

struct LiveWageInsightsView: View {
    @Bindable var store: LiveWageStore
    var isWide = false

    @State private var isEditingPayDetails = false

    var body: some View {
        // Refresh while a session is running so this week's total keeps up with the timer.
        TimelineView(.periodic(from: .now, by: 5)) { context in
            content(at: context.date)
        }
        .background(LiveWageTheme.appBackground.ignoresSafeArea())
        .sheet(isPresented: $isEditingPayDetails) {
            LiveWagePayDetailsView(store: store)
        }
    }

    private func content(at date: Date) -> some View {
        let summary = store.weeklySummarySnapshot(at: date)
        let days = store.weekDays(at: date)

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LiveWageHeader(caption: summary.weekLabel, title: "Insights")

                if isWide {
                    HStack(alignment: .top, spacing: LiveWageLayout.paneSpacing) {
                        WeeklySummaryCard(summary: summary, days: days)
                            .frame(maxWidth: .infinity)

                        VStack(spacing: 16) {
                            savingsCard(at: date)
                            StreaksCard(currentStreak: store.currentStreak, bestStreak: store.bestStreak)
                            AchievementsCard(achievements: store.achievementsStatus(at: date))
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    WeeklySummaryCard(summary: summary, days: days)
                    savingsCard(at: date)
                    StreaksCard(currentStreak: store.currentStreak, bestStreak: store.bestStreak)
                    AchievementsCard(achievements: store.achievementsStatus(at: date))
                }
            }
            .padding(.horizontal, LiveWageLayout.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .frame(maxWidth: LiveWageLayout.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private func savingsCard(at date: Date) -> some View {
        SavingsTargetCard(
            goalProgress: store.goalProgressStatus(at: date),
            netDaily: store.estimate.netDaily,
            onAddTarget: addTargetAction
        )
    }

    private var addTargetAction: (() -> Void)? {
        guard store.canEditPayDetails else { return nil }
        return { isEditingPayDetails = true }
    }
}

#Preview("Insights") {
    LiveWageInsightsView(store: LiveWageStore())
}
