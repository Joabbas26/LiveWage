//
//  LiveWageTodayView.swift
//  LiveWage
//
//  Created by Codex on 5/4/26.
//

import SwiftUI

struct LiveWageTodayTab: View {
    @Bindable var store: LiveWageStore
    var isWide = false
    let openProfile: () -> Void

    var body: some View {
        Group {
            if store.activeSession != nil {
                LiveWageLiveView(store: store, isWide: isWide, openSettings: openProfile)
                    .transition(.opacity)
            } else {
                LiveWageReadyView(store: store, isWide: isWide, openProfile: openProfile)
                    .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.35, extraBounce: 0.02), value: store.activeSession?.id)
    }
}

struct LiveWageReadyView: View {
    @Bindable var store: LiveWageStore
    var isWide = false
    let openProfile: () -> Void

    @State private var isEditingPayDetails = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LiveWageHeader(
                    caption: Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()),
                    title: "Today"
                ) {
                    Button(action: openProfile) {
                        LiveWageInitialsBadge(initials: hasProfileName ? store.userInitials : nil)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Profile")
                    .accessibilityHint("Opens your profile and settings")
                }

                if let notice = store.activeEstimateNotice {
                    LiveWageNoticeBanner(notice: notice)
                }

                if isWide {
                    HStack(alignment: .top, spacing: LiveWageLayout.paneSpacing) {
                        heroCard
                            .frame(maxWidth: .infinity)

                        VStack(spacing: 16) {
                            setupCard
                            streakCard
                            estimateFootnote
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    heroCard
                    setupCard
                    streakCard
                    estimateFootnote
                }
            }
            .padding(.horizontal, LiveWageLayout.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .frame(maxWidth: LiveWageLayout.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(LiveWageTheme.appBackground.ignoresSafeArea())
        .sheet(isPresented: $isEditingPayDetails) {
            LiveWagePayDetailsView(store: store)
        }
    }

    private var hasProfileName: Bool {
        !store.profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var heroCard: some View {
        let estimate = store.estimate
        let amount = CurrencyAmountParts(amount: estimate.netDaily)
        let hours = max(store.configuration.workHoursPerDay, 1)
        let perHour = estimate.netPerSecond * 3600

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 13, weight: .bold))
                    .accessibilityHidden(true)

                Text("\(hours)-hour day · usual start \(store.startTimeText)")
            }
            .font(.liveWage(.subheadline, weight: .semibold))
            .foregroundStyle(LiveWageTheme.heroSecondaryText)

            VStack(alignment: .leading, spacing: 4) {
                Text("You'll take home per workday")
                    .font(.liveWage(.subheadline, weight: .semibold))
                    .foregroundStyle(LiveWageTheme.heroSecondaryText)

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(amount.major)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(LiveWageTheme.heroText)

                    Text(amount.minor)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(LiveWageTheme.heroSecondaryText)
                }
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Take-home per workday")
                .accessibilityValue(estimate.netDaily.currencyString)
            }

            HStack(spacing: 8) {
                heroTile(title: "Per hour", value: perHour.friendlyRateString)
                heroTile(title: "Per minute", value: (perHour / 60).friendlyRateString)
                heroTile(title: "Per second", value: estimate.netPerSecond.friendlyRateString)
            }

            Button(action: store.startClock) {
                Label("Start workday", systemImage: "play.fill")
            }
            .buttonStyle(LiveWageButtonStyle(kind: .hero))
            .disabled(!store.canQuickStartClock)
            .accessibilityHint("Starts a \(hours)-hour timer using your saved pay details")
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LiveWageTheme.heroSurface)
        )
    }

    private func heroTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.liveWage(.caption, weight: .semibold))
                .foregroundStyle(LiveWageTheme.heroSecondaryText)

            Text(value)
                .font(.liveWage(.headline, weight: .bold))
                .foregroundStyle(LiveWageTheme.heroText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LiveWageTheme.heroTile)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Using your saved setup")
                    .font(.liveWage(.subheadline, weight: .bold))
                    .foregroundStyle(LiveWageTheme.secondaryText)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Button {
                    isEditingPayDetails = true
                } label: {
                    Text("Edit")
                        .font(.liveWage(.subheadline, weight: .bold))
                        .foregroundStyle(LiveWageTheme.greenText)
                        .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit pay details")
            }

            LiveWageDivider()
            LiveWageDetailRow(systemImage: "briefcase", title: "Income stream", value: store.selectedStreamName)
            LiveWageDivider()
            LiveWageDetailRow(systemImage: "dollarsign.circle", title: "Pay", value: store.configuration.payLabel)
            LiveWageDivider()
            LiveWageDetailRow(systemImage: "mappin.and.ellipse", title: "Tax location", value: store.configuration.location.name)
            LiveWageDivider()
            LiveWageDetailRow(systemImage: "calendar", title: "Schedule", value: store.configuration.workWeekSummary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
        .liveWageCard()
    }

    private var streakCard: some View {
        let streak = store.currentStreak

        return HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(LiveWageTheme.amberText)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(LiveWageTheme.amberSoft)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(streak > 0 ? "\(streak)-day streak" : "Start a streak")
                    .font(.liveWage(.subheadline, weight: .bold))
                    .foregroundStyle(LiveWageTheme.primaryText)

                Text(streak > 0 ? "Clock in on your next workday to keep it going" : "Clock in on each scheduled workday to build one")
                    .font(.liveWage(.footnote, weight: .medium))
                    .foregroundStyle(LiveWageTheme.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .liveWageCard()
        .accessibilityElement(children: .combine)
    }

    private var estimateFootnote: some View {
        Text("Estimates use bundled \(String(LiveWageTaxEngine.taxYear)) tax rules and stay on this device.")
            .font(.liveWage(.footnote, weight: .medium))
            .foregroundStyle(LiveWageTheme.mutedText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }
}

#Preview("Today") {
    LiveWageTodayTab(store: LiveWageStore()) {}
}
