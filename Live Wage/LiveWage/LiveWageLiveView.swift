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
    var openSettings: () -> Void = {}

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let snapshot = store.sessionSnapshot(at: context.date) {
                LiveSessionContent(
                    store: store,
                    snapshot: snapshot,
                    now: context.date,
                    isWide: isWide,
                    openSettings: openSettings
                )
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
    let openSettings: () -> Void

    @State private var isConfirmingStop = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header

                LiveWageDivider()
                    .padding(.top, 8)

                if isWide {
                    HStack(alignment: .top, spacing: LiveWageLayout.paneSpacing) {
                        timerColumn
                            .frame(maxWidth: .infinity)

                        VStack(spacing: 16) {
                            breakdownCard
                            coverageCard
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                    }
                } else {
                    timerColumn

                    VStack(spacing: 16) {
                        coverageCard
                        breakdownCard
                    }
                    .padding(.top, 28)
                }
            }
            .padding(.horizontal, LiveWageLayout.horizontalPadding)
            .padding(.top, 4)
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

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 0) {
                Text("Live Wage")
                    .foregroundStyle(LiveWageTheme.primaryText)

                Text(".")
                    .foregroundStyle(LiveWageTheme.green)
            }
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Live Wage")
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 0)

            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(LiveWageTheme.secondaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
            .accessibilityHint("Opens your profile and settings")
        }
    }

    // MARK: - Timer

    private var timerColumn: some View {
        VStack(spacing: 0) {
            rateBlock
                .padding(.top, 24)

            LiveWageTimerRing(progress: snapshot.progress, isActive: snapshot.status == .live) {
                ringCenter
            }
            .frame(maxWidth: 300)
            .padding(.vertical, 28)

            LiveWageDivider()

            earningsBlock
                .padding(.top, 20)

            Button {
                isConfirmingStop = true
            } label: {
                Label("End day", systemImage: "stop.fill")
            }
            .buttonStyle(LiveWageButtonStyle(kind: .destructive))
            .padding(.top, 20)
            .accessibilityHint("Stops the timer and saves today to your stats")
        }
    }

    private var rateBlock: some View {
        VStack(spacing: 10) {
            Text("Earning per second")
                .font(.liveWage(.footnote, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(LiveWageTheme.mutedText)

            Text(perSecondText)
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(LiveWageTheme.green)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text("\(perMinute.currencyString) per minute")
                .font(.liveWage(.subheadline, weight: .semibold))
                .foregroundStyle(LiveWageTheme.greenText)
                .monospacedDigit()
                .padding(.horizontal, 16)
                .frame(minHeight: 34)
                .background(
                    Capsule(style: .continuous)
                        .fill(LiveWageTheme.greenSoft)
                )
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Earning per second")
        .accessibilityValue("\(perSecondText), \(perMinute.currencyString) per minute")
    }

    private var ringCenter: some View {
        VStack(spacing: 10) {
            Text(statusTitle)
                .font(.liveWage(.subheadline, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(LiveWageTheme.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(snapshot.elapsedClockText)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(LiveWageTheme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityLabel("Time worked")
                .accessibilityValue(spokenElapsedTime)

            Button {
                store.togglePause()
            } label: {
                Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                    .font(.liveWage(.subheadline, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(LiveWageTheme.greenText)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canTogglePause)
            .opacity(canTogglePause ? 1 : 0.4)
            .accessibilityLabel(isPaused ? "Resume timer" : "Pause timer")
        }
        .padding(.horizontal, 40)
    }

    private var earningsBlock: some View {
        VStack(spacing: 6) {
            Text("Earnings so far")
                .font(.liveWage(.footnote, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(LiveWageTheme.mutedText)

            Text(snapshot.netEarned.currencyString)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(LiveWageTheme.green)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText(value: snapshot.netEarned))
                .animation(.snappy(duration: 0.3), value: snapshot.netEarned)

            Text(dayFooter)
                .font(.liveWage(.footnote, weight: .medium))
                .foregroundStyle(LiveWageTheme.mutedText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Earnings so far")
        .accessibilityValue(snapshot.netEarned.currencyString)
        .accessibilityHint(dayFooter)
    }

    // MARK: - Cards

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

    // MARK: - Formatting

    private var isPaused: Bool {
        snapshot.status == .paused
    }

    private var canTogglePause: Bool {
        snapshot.status == .live || snapshot.status == .paused
    }

    private var perMinute: Double {
        snapshot.estimate.netPerSecond * 60
    }

    // Typical salaries earn well under a cent per second, so show enough digits to see it move.
    private var perSecondText: String {
        let value = snapshot.estimate.netPerSecond
        return value >= 0.01 ? value.currencyString : String(format: "$%.4f", value)
    }

    private var statusTitle: String {
        switch snapshot.status {
        case .scheduled:
            return "Starts \(snapshot.scheduledStart.formatted(date: .omitted, time: .shortened))"
        case .live:
            return "Working…"
        case .paused:
            return "Paused"
        case .complete:
            return "Day complete"
        }
    }

    private var dayFooter: String {
        let end = snapshot.scheduledEnd.formatted(date: .omitted, time: .shortened)

        switch snapshot.status {
        case .scheduled:
            return "\(snapshot.estimate.netDaily.currencyString) expected today"
        case .live, .paused:
            return "\(snapshot.remainingSeconds.shortDurationString) left · \(snapshot.estimate.netDaily.currencyString) by \(end)"
        case .complete:
            return "Workday complete · nice work"
        }
    }

    private var spokenElapsedTime: String {
        Duration.seconds(snapshot.elapsedWorkSeconds)
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
    }
}

private struct LiveWageTimerRing<Center: View>: View {
    let progress: Double
    let isActive: Bool
    let center: Center

    private let lineWidth: CGFloat = 14
    private let tickCount = 60

    init(progress: Double, isActive: Bool, @ViewBuilder center: () -> Center) {
        self.progress = progress
        self.isActive = isActive
        self.center = center()
    }

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            let clamped = min(max(progress, 0), 1)
            let litTicks = Int((clamped * Double(tickCount)).rounded(.down))
            let tickRadius = diameter / 2 - lineWidth - 14

            ZStack {
                Circle()
                    .fill(LiveWageTheme.ringFill)
                    .padding(lineWidth)

                Circle()
                    .stroke(LiveWageTheme.ringTrack, lineWidth: lineWidth)
                    .padding(lineWidth / 2)

                Circle()
                    .trim(from: 0, to: clamped)
                    .stroke(LiveWageTheme.green, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(lineWidth / 2)
                    .shadow(color: LiveWageTheme.green.opacity(isActive ? 0.45 : 0), radius: 10)

                ForEach(0..<tickCount, id: \.self) { index in
                    Capsule()
                        .fill(index < litTicks ? LiveWageTheme.green.opacity(0.75) : LiveWageTheme.ringTick)
                        .frame(width: 2, height: index % 5 == 0 ? 10 : 6)
                        .offset(y: -tickRadius)
                        .rotationEffect(.degrees(Double(index) * 360 / Double(tickCount)))
                }
                .accessibilityHidden(true)

                center
            }
            .frame(width: diameter, height: diameter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workday progress")
        .accessibilityValue("\(Int(min(max(progress, 0), 1) * 100)) percent")
    }
}

#Preview("Live") {
    let store = LiveWageStore()
    store.startClock()

    return LiveWageLiveView(store: store)
}
