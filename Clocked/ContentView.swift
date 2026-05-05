//
//  ContentView.swift
//  Clocked
//
//  Created by Joab Bastidas on 5/4/26.
//

import SwiftUI

enum ClockedAppTab: String, CaseIterable, Identifiable {
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

enum ClockedHomeMode: String, CaseIterable, Identifiable {
    case simple
    case advanced

    var id: String { rawValue }

    var title: String { rawValue.capitalized }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = ClockedStore()
    @State private var selectedTab: ClockedAppTab = .home
    @State private var selectedMode: ClockedHomeMode = .simple

    private let userInitials = "NA"

    var body: some View {
        ZStack {
            ClockedTheme.appBackground
                .ignoresSafeArea()

            currentTabView
        }
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
            ClockedHomeTabView(
                store: store,
                selectedMode: $selectedMode
            )
            .transition(.opacity.combined(with: .move(edge: .leading)))
        case .stats:
            ClockedStatsTabView(store: store)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        case .profile:
            ClockedProfileTabView(
                store: store,
                userInitials: userInitials
            )
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
    }

    private var appHeader: some View {
        HStack(spacing: 16) {
            Text("Clocked")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(ClockedTheme.primaryText)

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
        Text(userInitials)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(ClockedTheme.secondaryText)
            .frame(width: 56, height: 56)
            .background(
                Circle()
                    .fill(ClockedTheme.inputSurface)
            )
            .overlay(
                Circle()
                    .stroke(ClockedTheme.stroke, lineWidth: 1)
            )
    }

    private var bottomNavigation: some View {
        VStack(spacing: 12) {
            Divider()
                .background(ClockedTheme.navDivider)

            HStack(spacing: 0) {
                ForEach(ClockedAppTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: tab == .home ? 25 : 22, weight: selectedTab == tab ? .bold : .semibold))
                                .foregroundStyle(selectedTab == tab ? ClockedTheme.primaryText : ClockedTheme.subtleText)
                                .frame(height: 26)

                            Text(tab.title)
                                .font(.system(size: 14, weight: selectedTab == tab ? .bold : .medium, design: .rounded))
                                .foregroundStyle(selectedTab == tab ? ClockedTheme.primaryText : ClockedTheme.subtleText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(ClockedTheme.navSurface.opacity(0.96))
    }
}

private struct ClockedHomeTabView: View {
    @Bindable var store: ClockedStore
    @Binding var selectedMode: ClockedHomeMode

    var body: some View {
        VStack(spacing: 18) {
            ClockedModeSwitcher(selection: $selectedMode)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            Group {
                switch selectedMode {
                case .simple:
                    ClockedQuickStartView(store: store)
                case .advanced:
                    if store.activeSession != nil {
                        ClockedLiveView(store: store)
                    } else {
                        ClockedSetupView(store: store)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

private struct ClockedModeSwitcher: View {
    @Binding var selection: ClockedHomeMode

    var body: some View {
        GeometryReader { geometry in
            let pillWidth = max((geometry.size.width - 8) / 2, 0)

            ZStack(alignment: selection == .simple ? .leading : .trailing) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(ClockedTheme.pillTrack)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(ClockedTheme.stroke, lineWidth: 1)
                    )

                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .fill(ClockedTheme.pillSelection)
                    .frame(width: pillWidth, height: 44)
                    .padding(4)

                HStack(spacing: 0) {
                    ForEach(ClockedHomeMode.allCases) { mode in
                        Button {
                            selection = mode
                        } label: {
                            Text(mode.title.lowercased())
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(selection == mode ? ClockedTheme.primaryText : ClockedTheme.mutedText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(height: 52)
    }
}

private struct ClockedStatsTabView: View {
    let store: ClockedStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Your weekly view")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(ClockedTheme.primaryText)

                Text("Track the bigger picture with streaks, weekly earnings, milestones, and spending comparisons.")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(ClockedTheme.secondaryText)
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
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }
}

private struct ClockedProfileTabView: View {
    let store: ClockedStore
    let userInitials: String

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 18) {
                    Text(userInitials)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(ClockedTheme.primaryText)
                        .frame(width: 88, height: 88)
                        .background(
                            Circle()
                                .fill(ClockedTheme.inputSurface)
                        )
                        .overlay(
                            Circle()
                                .stroke(ClockedTheme.stroke, lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Not signed in")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(ClockedTheme.primaryText)

                        Text("Using local saved information on this device.")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(ClockedTheme.secondaryText)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    profileRow(title: "Current stream", value: store.selectedStreamName)
                    profileRow(title: "Location", value: store.configuration.location.name)
                    profileRow(title: "Schedule", value: store.workScheduleLabel)
                    profileRow(title: "Savings target", value: store.configuration.savingsGoalAmount > 0 ? store.configuration.savingsGoalAmount.currencyString : "Not set")
                }
                .padding(22)
                .clockedCard()

                Text("Sign-in, sync, and profile settings can slot into this tab later without changing the rest of the shell.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(ClockedTheme.subtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 40)
        }
    }

    private func profileRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(ClockedTheme.mutedText)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(ClockedTheme.primaryText)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview("Setup") {
    ContentView()
        .preferredColorScheme(.dark)
}
