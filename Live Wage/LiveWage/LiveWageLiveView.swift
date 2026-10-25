//
//  LiveWageLiveView.swift
//  LiveWage
//
//  Created by Codex on 5/4/26.
//

import SwiftUI

struct LiveWageLiveView: View {
    @Bindable var store: LiveWageStore
    var isWide = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let snapshot = store.sessionSnapshot(at: context.date) {
                LiveSessionContent(store: store, snapshot: snapshot, now: context.date, isWide: isWide)
            } else {
                LiveWageTheme.appBackground
                    .ignoresSafeArea()
            }
        }
    }
}

private struct LiveSessionContent: View {
    let store: LiveWageStore
    let snapshot: SessionSnapshot
    let now: Date
    let isWide: Bool

    @State private var isConfirmingStop = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LiveWageHeader(caption: snapshot.dayLabel, title: "Today") {
                    LiveWageStatusPill(status: snapshot.status)
                }

                if isWide {
                    HStack(alignment: .top, spacing: LiveWageLayout.paneSpacing) {
                        VStack(spacing: 16) {
                            ticker
                            progressCard
                            controls
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 16) {
                            breakdownCard
                            coverageCard
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    ticker
                    progressCard
                    coverageCard
                    controls
                    breakdownCard
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
        .confirmationDialog("End your workday?", isPresented: $isConfirmingStop, titleVisibility: .visible) {
            Button("End day and save", role: .destructive) {
                store.stopClock()
            }

            Button("Keep going", role: .cancel) {}
        } message: {
            Text("\(snapshot.netEarned.currencyString) earned so far will be saved to your stats.")
        }
    }

    private var perHour: Double {
        snapshot.estimate.netPerSecond * 3600
    }

    private var ticker: some View {
        VStack(spacing: 4) {
            Text("Earned so far · \(snapshot.elapsedClockText)")
                .font(.liveWage(.subheadline, weight: .semibold))
                .foregroundStyle(LiveWageTheme.mutedText)
                .monospacedDigit()

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(snapshot.amountParts.major)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(LiveWageTheme.primaryText)

                Text(snapshot.amountParts.minor)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(LiveWageTheme.mutedText)
            }
            .monospacedDigit()
            .contentTransition(.numericText(value: snapshot.netEarned))
            .animation(.snappy(duration: 0.3), value: snapshot.netEarned)
            .lineLimit(1)
            .minimumScaleFactor(0.5)

            Text(statusLine)
                .font(.liveWage(.subheadline, weight: .bold))
                .foregroundStyle(snapshot.status == .live ? LiveWageTheme.greenText : LiveWageTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Earned so far")
        .accessibilityValue(snapshot.netEarned.currencyString)
        .accessibilityHint(statusLine)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(snapshot.scheduledStart.formatted(date: .omitted, time: .shortened))
                Spacer()
                Text(snapshot.scheduledEnd.formatted(date: .omitted, time: .shortened))
            }
            .font(.liveWage(.footnote, weight: .semibold))
            .foregroundStyle(LiveWageTheme.mutedText)

            LiveWageProgressBar(
                progress: snapshot.progress,
                tint: LiveWageTheme.green,
                height: 10,
                showsThumb: true
            )

            HStack {
                Text("\(Int(snapshot.progress * 100))% of your day")
                    .foregroundStyle(LiveWageTheme.primaryText)
                Spacer()
                Text(remainingLabel)
                    .foregroundStyle(LiveWageTheme.secondaryText)
            }
            .font(.liveWage(.subheadline, weight: .bold))
            .monospacedDigit()

            LiveWageDivider()
                .padding(.vertical, 4)

            HStack(spacing: 8) {
                LiveWageMetric(
                    title: "By \(snapshot.scheduledEnd.formatted(date: .omitted, time: .shortened))",
                    value: snapshot.estimate.netDaily.currencyString
                )
                LiveWageMetric(title: "Per hour", value: perHour.friendlyRateString)
                LiveWageMetric(title: "Streak", value: "\(store.currentStreak) \(store.currentStreak == 1 ? "day" : "days")")
            }
        }
        .padding(18)
        .liveWageCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workday progress, \(Int(snapshot.progress * 100)) percent")
    }

    private var coverageCard: some View {
        SpendingCoverageCard(comparisons: store.spendingComparisonsStatus(at: now))
    }

    private var breakdownCard: some View {
        PayBreakdownCard(
            estimate: snapshot.estimate,
            taxRows: store.taxBreakdown(for: snapshot.estimate),
            configuration: snapshot.session.configuration
        )
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                store.togglePause()
            } label: {
                Label(
                    snapshot.status == .paused ? "Resume" : "Pause",
                    systemImage: snapshot.status == .paused ? "play.fill" : "pause.fill"
                )
            }
            .buttonStyle(LiveWageButtonStyle(kind: .secondary))
            .disabled(snapshot.status == .scheduled || snapshot.status == .complete)
            .accessibilityLabel(snapshot.status == .paused ? "Resume timer" : "Pause timer")

            Button {
                isConfirmingStop = true
            } label: {
                Label("End day", systemImage: "stop.fill")
            }
            .buttonStyle(LiveWageButtonStyle(kind: .destructive))
            .accessibilityHint("Stops the timer and saves today to your stats")
        }
    }

    private var statusLine: String {
        switch snapshot.status {
        case .scheduled:
            return "Starts at \(snapshot.scheduledStart.formatted(date: .omitted, time: .shortened))"
        case .live:
            return "+\(perHour.friendlyRateString) an hour · \(snapshot.estimate.netPerSecond.friendlyRateString) every second"
        case .paused:
            return "Paused — the clock picks up when you resume"
        case .complete:
            return "Workday complete · nice work"
        }
    }

    private var remainingLabel: String {
        switch snapshot.status {
        case .scheduled:
            return "Not started"
        case .live, .paused:
            return "\(snapshot.remainingSeconds.shortDurationString) left"
        case .complete:
            return "Done"
        }
    }
}

#Preview("Live") {
    let store = LiveWageStore()
    store.startClock()

    return LiveWageLiveView(store: store)
}
