//
//  LiveWageProfileView.swift
//  LiveWage
//
//  Local profile, appearance, badges and estimate details.
//

import SwiftUI

private enum ProfileInfoTopic: String, Identifiable {
    case estimates
    case privacy
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .estimates:
            return "How estimates are calculated"
        case .privacy:
            return "Privacy & storage"
        case .diagnostics:
            return "Diagnostics"
        }
    }
}

struct LiveWageProfileView: View {
    @Bindable var store: LiveWageStore
    var isWide = false

    @FocusState private var isNameFocused: Bool
    @State private var isEditingPayDetails = false
    @State private var showingClearStatsConfirmation = false
    @State private var selectedBadge: AchievementStatus?
    @State private var infoTopic: ProfileInfoTopic?

    private let appearanceOptions: [LiveWageAppearancePreference] = [.system, .light, .dark]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                LiveWageHeader(title: "Profile")
                identityCard
                workSection
                appearanceSection
                badgesSection
                aboutSection
                clearStatsSection
            }
            .padding(.horizontal, LiveWageLayout.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .frame(maxWidth: contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(LiveWageTheme.appBackground.ignoresSafeArea())
        .onChange(of: isNameFocused) { _, isFocused in
            if !isFocused {
                store.commitProfileNameInput()
            }
        }
        .sheet(isPresented: $isEditingPayDetails) {
            LiveWagePayDetailsView(store: store)
        }
        .sheet(item: $selectedBadge) { badge in
            LiveWageBadgeDetailSheet(badge: badge)
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $infoTopic) { topic in
            LiveWageInfoSheet(title: topic.title, paragraphs: paragraphs(for: topic))
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Clear saved stats?", isPresented: $showingClearStatsConfirmation) {
            Button("Clear", role: .destructive) {
                store.clearStats()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes saved weekly totals, streaks, achievements, and other history from past sessions. Your pay details stay saved on this device.")
        }
    }

    private var contentMaxWidth: CGFloat {
        isWide ? 680 : .infinity
    }

    private var hasName: Bool {
        !store.profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Sections

    private var identityCard: some View {
        HStack(spacing: 14) {
            LiveWageInitialsBadge(initials: hasName ? store.userInitials : nil, size: 60, isProminent: true)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                TextField(
                    "Add your name",
                    text: Binding(
                        get: { store.profileNameInput },
                        set: { store.updateProfileNameInput($0) }
                    )
                )
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($isNameFocused)
                .onSubmit {
                    store.commitProfileNameInput()
                }
                .font(.liveWage(.title3, weight: .bold))
                .foregroundStyle(LiveWageTheme.primaryText)
                .accessibilityLabel("Your name")

                Label("Saved only on this device", systemImage: "lock.fill")
                    .font(.liveWage(.footnote, weight: .semibold))
                    .foregroundStyle(LiveWageTheme.mutedText)
            }

            Spacer(minLength: 0)

            Button {
                isNameFocused.toggle()
            } label: {
                Text(isNameFocused ? "Save" : "Edit")
                    .font(.liveWage(.subheadline, weight: .bold))
                    .foregroundStyle(LiveWageTheme.primaryText)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(
                        Capsule(style: .continuous)
                            .fill(LiveWageTheme.elevatedSurface)
                    )
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isNameFocused ? "Save name" : "Edit name")
        }
        .padding(16)
        .liveWageCard()
    }

    private var workSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            LiveWageSectionLabel(title: "Work")

            VStack(spacing: 0) {
                navigationRow(title: "Pay details", value: store.configuration.payLabel, isEnabled: store.canEditPayDetails) {
                    isEditingPayDetails = true
                }

                LiveWageDivider()

                navigationRow(title: "Income streams", value: "\(store.streams.count)", isEnabled: store.canEditPayDetails) {
                    isEditingPayDetails = true
                }

                LiveWageDivider()

                navigationRow(title: "Savings target", value: savingsTargetValue, isEnabled: store.canEditPayDetails) {
                    isEditingPayDetails = true
                }
            }
            .padding(.horizontal, 16)
            .liveWageCard()

            if !store.canEditPayDetails {
                Text("Finish today's session to change pay details.")
                    .font(.liveWage(.footnote, weight: .medium))
                    .foregroundStyle(LiveWageTheme.mutedText)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            LiveWageSectionLabel(title: "Appearance")

            Picker(
                "Appearance",
                selection: Binding(
                    get: { store.appearancePreference },
                    set: { store.setAppearancePreference($0) }
                )
            ) {
                ForEach(appearanceOptions) { preference in
                    Text(preference.title).tag(preference)
                }
            }
            .pickerStyle(.segmented)
            .padding(12)
            .liveWageCard()
        }
    }

    private var badgesSection: some View {
        let unlocked = store.unlockedBadges

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                LiveWageSectionLabel(title: "Badges")

                Spacer()

                Text("\(unlocked.count) of \(store.achievements.count) earned")
                    .font(.liveWage(.footnote, weight: .bold))
                    .foregroundStyle(LiveWageTheme.mutedText)
            }

            if unlocked.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "seal")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(LiveWageTheme.mutedText)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(LiveWageTheme.elevatedSurface)
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No badges yet")
                            .font(.liveWage(.subheadline, weight: .bold))
                            .foregroundStyle(LiveWageTheme.primaryText)

                        Text("Clock in on your scheduled workdays and streaks and milestones will show up here.")
                            .font(.liveWage(.footnote, weight: .medium))
                            .foregroundStyle(LiveWageTheme.mutedText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .liveWageCard()
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(unlocked) { badge in
                        Button {
                            selectedBadge = badge
                        } label: {
                            badgeTile(badge)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(badge.title)
                        .accessibilityHint("Shows what this badge was earned for")
                    }
                }
            }
        }
    }

    private func badgeTile(_ badge: AchievementStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: badge.badgeSymbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(LiveWageTheme.greenText)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LiveWageTheme.greenSoft)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(badge.title)
                    .font(.liveWage(.subheadline, weight: .bold))
                    .foregroundStyle(LiveWageTheme.primaryText)
                    .multilineTextAlignment(.leading)

                Text("Earned")
                    .font(.liveWage(.footnote, weight: .bold))
                    .foregroundStyle(LiveWageTheme.greenText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .liveWageCard()
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            LiveWageSectionLabel(title: "About your estimates")

            VStack(spacing: 0) {
                navigationRow(title: ProfileInfoTopic.estimates.title) {
                    infoTopic = .estimates
                }

                LiveWageDivider()

                navigationRow(title: ProfileInfoTopic.privacy.title) {
                    infoTopic = .privacy
                }

                LiveWageDivider()

                navigationRow(title: ProfileInfoTopic.diagnostics.title) {
                    infoTopic = .diagnostics
                }

                LiveWageDivider()

                linkRow(title: "Privacy Policy", destination: URL(string: "https://example.com/privacy")!)

                LiveWageDivider()

                linkRow(title: "Terms of Service", destination: URL(string: "https://example.com/terms")!)
            }
            .padding(.horizontal, 16)
            .liveWageCard()
        }
    }

    private var clearStatsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                showingClearStatsConfirmation = true
            } label: {
                Text("Clear stats history")
                    .font(.liveWage(.subheadline, weight: .bold))
                    .foregroundStyle(LiveWageTheme.stopButtonText)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!store.canClearStats)
            .opacity(store.canClearStats ? 1 : 0.45)
            .padding(.horizontal, 16)
            .liveWageCard()
            .accessibilityHint("Removes saved stats history but keeps your pay details")

            Text("Removes streaks, weekly totals and badges. Your pay details stay saved.")
                .font(.liveWage(.footnote, weight: .medium))
                .foregroundStyle(LiveWageTheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Rows

    private func navigationRow(
        title: String,
        value: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.liveWage(.subheadline, weight: .bold))
                    .foregroundStyle(LiveWageTheme.primaryText)

                Spacer(minLength: 12)

                if let value {
                    Text(value)
                        .font(.liveWage(.subheadline, weight: .semibold))
                        .foregroundStyle(LiveWageTheme.secondaryText)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LiveWageTheme.mutedText)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }

    private func linkRow(title: String, destination: URL) -> some View {
        Link(destination: destination) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.liveWage(.subheadline, weight: .bold))
                    .foregroundStyle(LiveWageTheme.primaryText)

                Spacer(minLength: 12)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LiveWageTheme.mutedText)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens in your browser")
    }

    private var savingsTargetValue: String {
        let target = store.configuration.savingsGoalAmount
        return target > 0 ? target.wholeCurrencyString : "Not set"
    }

    private func paragraphs(for topic: ProfileInfoTopic) -> [String] {
        switch topic {
        case .estimates:
            return [store.taxCatalogSummary, store.assumptionsLabel, store.payrollAssumptionsLabel]
        case .privacy:
            return [store.privacySummary, store.localStorageSummary]
        case .diagnostics:
            return [store.diagnosticsSummary]
        }
    }
}

private struct LiveWageBadgeDetailSheet: View {
    let badge: AchievementStatus
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: badge.badgeSymbolName)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(LiveWageTheme.greenText)
                .frame(width: 72, height: 72)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LiveWageTheme.greenSoft)
                )
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(badge.title)
                    .font(.liveWage(.title2, weight: .bold))
                    .foregroundStyle(LiveWageTheme.primaryText)
                    .multilineTextAlignment(.center)

                Text(badge.detail)
                    .font(.liveWage(.subheadline, weight: .medium))
                    .foregroundStyle(LiveWageTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Close") {
                dismiss()
            }
            .buttonStyle(LiveWageButtonStyle(kind: .secondary))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LiveWageTheme.surface)
    }
}

private struct LiveWageInfoSheet: View {
    let title: String
    let paragraphs: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(paragraphs, id: \.self) { paragraph in
                        Text(paragraph)
                            .font(.liveWage(.body, weight: .medium))
                            .foregroundStyle(LiveWageTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(LiveWageTheme.appBackground.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview("Profile") {
    LiveWageProfileView(store: LiveWageStore())
}
