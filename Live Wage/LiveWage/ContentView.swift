//
//  ContentView.swift
//  LiveWage
//
//  Created by Joab Bastidas on 5/4/26.
//

import SwiftUI

enum LiveWageAppTab: String, CaseIterable, Identifiable, Hashable {
    case today
    case insights
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:
            return "Today"
        case .insights:
            return "Insights"
        case .profile:
            return "Profile"
        }
    }

    var iconName: String {
        switch self {
        case .today:
            return "clock"
        case .insights:
            return "chart.bar"
        case .profile:
            return "person.crop.circle"
        }
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = LiveWageStore()
    @State private var selectedTab: LiveWageAppTab = .today

    var body: some View {
        // Wide windows (an unfolded iPhone Duo, iPad, large landscape phones) get two panes.
        GeometryReader { proxy in
            let isWide = proxy.size.width >= LiveWageLayout.wideBreakpoint

            TabView(selection: $selectedTab) {
                Tab(LiveWageAppTab.today.title, systemImage: LiveWageAppTab.today.iconName, value: LiveWageAppTab.today) {
                    LiveWageTodayTab(store: store, isWide: isWide) {
                        selectedTab = .profile
                    }
                }

                Tab(LiveWageAppTab.insights.title, systemImage: LiveWageAppTab.insights.iconName, value: LiveWageAppTab.insights) {
                    LiveWageInsightsView(store: store, isWide: isWide)
                }

                Tab(LiveWageAppTab.profile.title, systemImage: LiveWageAppTab.profile.iconName, value: LiveWageAppTab.profile) {
                    LiveWageProfileView(store: store, isWide: isWide)
                }
            }
            .tint(LiveWageTheme.primaryText)
        }
        .preferredColorScheme(store.preferredColorScheme)
        .onAppear {
            store.refreshSessionStateIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            store.refreshSessionStateIfNeeded()
        }
    }
}

#Preview("Light") {
    ContentView()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ContentView()
        .preferredColorScheme(.dark)
}
