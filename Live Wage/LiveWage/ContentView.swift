//
//  ContentView.swift
//  LiveWage
//
//  Created by Joab Bastidas on 5/4/26.
//

import SwiftUI

enum LiveWageAppTab: String, CaseIterable, Identifiable {
    case home
    case stats
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "home"
        case .stats:
            return "stats"
        case .profile:
            return "profile"
        }
    }

    var iconName: String {
        switch self {
        case .home:
            return "chart.bar.fill"
        case .stats:
            return "chart.line.uptrend.xyaxis"
        case .profile:
            return "person"
        }
    }
}

enum LiveWageHomeMode: String, CaseIterable, Identifiable {
    case simple
    case advanced

    var id: String { rawValue }

    var title: String { rawValue.capitalized }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = LiveWageStore()
    @State private var selectedTab: LiveWageAppTab = .home
    @State private var selectedMode: LiveWageHomeMode = .simple

    var body: some View {
        ZStack {
            LiveWageTheme.appBackground
                .ignoresSafeArea()

            currentTabView
        }
        .preferredColorScheme(store.preferredColorScheme)
        .safeAreaInset(edge: .top) {
            appHeader
        }
        .safeAreaInset(edge: .bottom) {
            bottomNavigation
        }
        .animation(.snappy(duration: 0.35, extraBounce: 0.02), value: selectedTab)
        .animation(.snappy(duration: 0.35, extraBounce: 0.02), value: selectedMode)
        .animation(.snappy(duration: 0.35, extraBounce: 0.02), value: store.activeSession?.id)
        .onAppear {
            store.refreshSessionStateIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            store.refreshSessionStateIfNeeded()
        }
    }

    @ViewBuilder
    private var currentTabView: some View {
        switch selectedTab {
        case .home:
            LiveWageHomeTabView(
                store: store,
                selectedMode: $selectedMode
            )
            .transition(.opacity.combined(with: .move(edge: .leading)))
        case .stats:
            LiveWageStatsTabView(store: store)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        case .profile:
            LiveWageProfileTabView(store: store)
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
    }

    private var appHeader: some View {
        HStack(spacing: 16) {
            Text("Live Wage")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(LiveWageTheme.primaryText)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 0)

            initialsBadge
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.22),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var initialsBadge: some View {
        Text(store.userInitials)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(LiveWageTheme.secondaryText)
            .frame(width: 56, height: 56)
            .background(
                Circle()
                    .fill(LiveWageTheme.inputSurface)
            )
            .overlay(
                Circle()
                    .stroke(LiveWageTheme.stroke, lineWidth: 1)
            )
            .accessibilityLabel("Profile")
            .accessibilityValue("Initials \(store.userInitials)")
            .accessibilityHint("Shows the current local profile state")
    }

    private var bottomNavigation: some View {
        VStack(spacing: 12) {
            Divider()
                .background(LiveWageTheme.navDivider)

            HStack(spacing: 0) {
                ForEach(LiveWageAppTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: tab == .home ? 25 : 22, weight: selectedTab == tab ? .bold : .semibold))
                                .foregroundStyle(selectedTab == tab ? LiveWageTheme.primaryText : LiveWageTheme.subtleText)
                                .frame(height: 26)

                            Text(tab.title)
                                .font(.system(size: 14, weight: selectedTab == tab ? .bold : .medium, design: .rounded))
                                .foregroundStyle(selectedTab == tab ? LiveWageTheme.primaryText : LiveWageTheme.subtleText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(tab.title.capitalized)
                    .accessibilityHint("Opens the \(tab.title) tab")
                    .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(LiveWageTheme.navSurface.opacity(0.96))
    }
}

private struct LiveWageHomeTabView: View {
    @Bindable var store: LiveWageStore
    @Binding var selectedMode: LiveWageHomeMode

    var body: some View {
        VStack(spacing: 18) {
            LiveWageModeSwitcher(selection: $selectedMode)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            if let notice = store.activeEstimateNotice {
                LiveWageNoticeBanner(notice: notice)
                    .padding(.horizontal, 20)
            }

            Group {
                switch selectedMode {
                case .simple:
                    LiveWageQuickStartView(store: store)
                case .advanced:
                    if store.activeSession != nil {
                        LiveWageLiveView(store: store)
                    } else {
                        LiveWageSetupView(store: store)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

private struct LiveWageModeSwitcher: View {
    @Binding var selection: LiveWageHomeMode

    var body: some View {
        GeometryReader { geometry in
            let pillWidth = max((geometry.size.width - 8) / 2, 0)

            ZStack(alignment: selection == .simple ? .leading : .trailing) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LiveWageTheme.pillTrack)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(LiveWageTheme.stroke, lineWidth: 1)
                    )

                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .fill(LiveWageTheme.pillSelection)
                    .frame(width: pillWidth, height: 44)
                    .padding(4)

                HStack(spacing: 0) {
                    ForEach(LiveWageHomeMode.allCases) { mode in
                        Button {
                            selection = mode
                        } label: {
                            Text(mode.title.lowercased())
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(selection == mode ? LiveWageTheme.primaryText : LiveWageTheme.mutedText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(mode.title)
                        .accessibilityHint("Switches home mode to \(mode.title.lowercased())")
                        .accessibilityAddTraits(selection == mode ? .isSelected : [])
                    }
                }
            }
        }
        .frame(height: 52)
    }
}

private struct LiveWageStatsTabView: View {
    let store: LiveWageStore

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Your weekly view")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(LiveWageTheme.primaryText)

                    Text("Track the bigger picture with streaks, weekly earnings, milestones, and spending comparisons.")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(LiveWageTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    WeeklySummaryCard(summary: store.weeklySummary)
                    MomentumCard(
                        currentStreak: store.currentStreak,
                        bestStreak: store.bestStreak,
                        goalProgress: store.goalProgress
                    )
                    AchievementsCard(achievements: store.achievements)
                    SpendingComparisonsCard(comparisons: store.spendingComparisons)
                }
                .frame(width: geometry.size.width - 40, alignment: .topLeading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
    }
}

private struct LiveWageProfileTabView: View {
    @Bindable var store: LiveWageStore
    @State private var showingClearStatsConfirmation = false
    @State private var selectedBadge: AchievementStatus?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 18) {
                    Text(store.userInitials)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(LiveWageTheme.primaryText)
                        .frame(width: 88, height: 88)
                        .background(
                            Circle()
                                .fill(LiveWageTheme.inputSurface)
                        )
                        .overlay(
                            Circle()
                                .stroke(LiveWageTheme.stroke, lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Local only")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(LiveWageTheme.primaryText)

                        Text("Your job, finance, and app settings are saved only on this device.")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(LiveWageTheme.secondaryText)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    profileRow(title: "Name", value: store.profileNameDisplay)
                    profileRow(title: "Current stream", value: store.selectedStreamName)
                    profileRow(title: "Location", value: store.configuration.location.name)
                    profileRow(title: "Schedule", value: store.workScheduleLabel)
                    profileRow(title: "Savings target", value: store.configuration.savingsGoalAmount > 0 ? store.configuration.savingsGoalAmount.currencyString : "Not set")
                    profileRow(title: "Saved stats", value: "\(store.historyCount)")
                }
                .padding(22)
                .liveWageCard()

                localSettingsCard

                legalLinksCard

                badgesCard

                profileInfoCard(
                    title: "Saved locally",
                    body: store.localStorageSummary
                )

                profileInfoCard(
                    title: "Estimate transparency",
                    body: "\(store.taxCatalogSummary) \(store.assumptionsLabel) \(store.payrollAssumptionsLabel)"
                )

                profileInfoCard(
                    title: "Privacy and storage",
                    body: store.privacySummary
                )

                profileInfoCard(
                    title: "Diagnostics",
                    body: store.diagnosticsSummary
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 40)
        }
        .alert("Clear saved stats?", isPresented: $showingClearStatsConfirmation) {
            Button("Clear", role: .destructive) {
                store.clearStats()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes saved weekly totals, streaks, achievements, and other history derived from past sessions. Your job and finance setup will stay saved on this device.")
        }
        .sheet(item: $selectedBadge) { badge in
            LiveWageBadgeDetailSheet(badge: badge)
                .presentationDetents([.height(250)])
                .presentationDragIndicator(.visible)
        }
    }

    private func profileRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(LiveWageTheme.mutedText)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(LiveWageTheme.primaryText)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private func profileInfoCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(LiveWageTheme.secondaryText)

            Text(body)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(LiveWageTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .liveWageCard()
        .accessibilityElement(children: .combine)
    }

    private var localSettingsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("App settings")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(LiveWageTheme.secondaryText)

            VStack(alignment: .leading, spacing: 10) {
                Text("Your name")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(LiveWageTheme.primaryText)

                Text("Saved only on this device and used for the initials badge in the header.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(LiveWageTheme.subtleText)
                    .fixedSize(horizontal: false, vertical: true)

                TextField(
                    "Add your name",
                    text: Binding(
                        get: { store.profileNameInput },
                        set: { store.updateProfileNameInput($0) }
                    )
                )
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(LiveWageTheme.primaryText)
                .padding(.horizontal, 18)
                .frame(height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LiveWageTheme.inputSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(LiveWageTheme.stroke, lineWidth: 1)
                )
                .onSubmit {
                    store.commitProfileNameInput()
                }

                Button {
                    store.commitProfileNameInput()
                } label: {
                    Text(store.profileNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Clear name" : "Save name")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(LiveWageTheme.lightButtonText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(LiveWageTheme.lightButton)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!store.canCommitProfileName)
                .opacity(store.canCommitProfileName ? 1 : 0.45)
            }

            Divider()
                .background(LiveWageTheme.stroke)

            VStack(alignment: .leading, spacing: 10) {
                Text("Appearance")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(LiveWageTheme.primaryText)

                Text("Choose a fixed appearance or let Live Wage follow your iPhone setting.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(LiveWageTheme.subtleText)
                    .fixedSize(horizontal: false, vertical: true)

                Picker(
                    "Appearance",
                    selection: Binding(
                        get: { store.appearancePreference },
                        set: { store.setAppearancePreference($0) }
                    )
                ) {
                    ForEach(LiveWageAppearancePreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()
                .background(LiveWageTheme.stroke)

            VStack(alignment: .leading, spacing: 4) {
                Text("Current appearance")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(LiveWageTheme.subtleText)

                Text(store.appearancePreference.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(LiveWageTheme.primaryText)
            }

            Divider()
                .background(LiveWageTheme.stroke)

            VStack(alignment: .leading, spacing: 10) {
                Text("Clear stats history")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(LiveWageTheme.primaryText)

                Text("Deletes saved streaks, weekly summaries, and achievement progress while keeping your job and finance setup intact.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(LiveWageTheme.subtleText)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    showingClearStatsConfirmation = true
                } label: {
                    Text("Clear stats")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(LiveWageTheme.stopButtonText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(LiveWageTheme.stopButton)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!store.canClearStats)
                .opacity(store.canClearStats ? 1 : 0.45)
                .accessibilityHint("Removes saved stats history but keeps your setup information")
            }
        }
        .padding(22)
        .liveWageCard()
    }

    private var legalLinksCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Legal")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(LiveWageTheme.secondaryText)

            Link(destination: URL(string: "https://example.com/privacy")!) {
                legalLinkRow(title: "Privacy Policy")
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the privacy policy link")

            Divider()
                .background(LiveWageTheme.stroke)

            Link(destination: URL(string: "https://example.com/terms")!) {
                legalLinkRow(title: "Terms of Service")
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the terms of service link")
        }
        .padding(22)
        .liveWageCard()
    }

    private func legalLinkRow(title: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(LiveWageTheme.primaryText)

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(LiveWageTheme.subtleText)
        }
    }

    private var badgesCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Badges")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(LiveWageTheme.secondaryText)

                Spacer()

                Text("\(store.unlockedBadges.count) completed")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(LiveWageTheme.subtleText)
            }

            if store.unlockedBadges.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "seal")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(LiveWageTheme.subtleText)
                        .frame(width: 54, height: 54)
                        .background(
                            Circle()
                                .fill(LiveWageTheme.inputSurface)
                        )

                    Text("No badges yet")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(LiveWageTheme.primaryText)

                    Text("Keep clocking in on your scheduled workdays and completed streaks or milestones will show up here.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(LiveWageTheme.subtleText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(store.unlockedBadges) { badge in
                        Button {
                            selectedBadge = badge
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: badge.badgeSymbolName)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(LiveWageTheme.green)
                                    .frame(width: 54, height: 54)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(LiveWageTheme.inputSurface)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(LiveWageTheme.stroke, lineWidth: 1)
                                    )

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(badge.title)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundStyle(LiveWageTheme.primaryText)
                                        .multilineTextAlignment(.leading)

                                    Text("Completed")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(LiveWageTheme.green)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(LiveWageTheme.elevatedSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(LiveWageTheme.stroke, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(badge.title)
                        .accessibilityHint("Shows what this badge was earned for")
                    }
                }
            }
        }
        .padding(22)
        .liveWageCard()
    }
}

private struct LiveWageBadgeDetailSheet: View {
    let badge: AchievementStatus
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LiveWageTheme.inputSurface)
                .frame(width: 70, height: 70)
                .overlay(
                    Image(systemName: badge.badgeSymbolName)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(LiveWageTheme.green)
                )

            VStack(spacing: 8) {
                Text(badge.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(LiveWageTheme.primaryText)
                    .multilineTextAlignment(.center)

                Text(badge.detail)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(LiveWageTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Close") {
                dismiss()
            }
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .buttonStyle(.plain)
            .foregroundStyle(LiveWageTheme.primaryText)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LiveWageTheme.surface)
    }
}

#Preview("Setup") {
    ContentView()
        .preferredColorScheme(.dark)
}
