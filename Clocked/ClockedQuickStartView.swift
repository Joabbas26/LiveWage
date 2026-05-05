//
//  ClockedQuickStartView.swift
//  Clocked
//
//  Created by Codex on 5/4/26.
//

import SwiftUI

struct ClockedQuickStartView: View {
    @Bindable var store: ClockedStore

    var body: some View {
        Group {
            if store.activeSession != nil {
                SimpleModeLiveView(store: store)
            } else {
                SimpleModeStartView(store: store)
            }
        }
    }
}

private struct SimpleModeStartView: View {
    let store: ClockedStore

    private var estimate: EarningsEstimate {
        store.estimate
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("simple mode")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(ClockedTheme.subtleText)

                    Text("Start timer with saved information")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(ClockedTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("This will use your last confirmed pay, location, and schedule settings so you can jump in immediately.")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(ClockedTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 20) {
                    summaryRow(title: "income stream", value: store.selectedStreamName)
                    summaryRow(title: "location", value: store.configuration.location.shortName)
                    summaryRow(title: "schedule", value: store.workScheduleLabel)
                    summaryRow(title: "take-home rate", value: "\(estimate.netPerSecond.currencyString)/s")

                    Button(action: store.startClock) {
                        Text("Start")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(ClockedTheme.lightButtonText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 62)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(ClockedTheme.lightButton)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!store.canQuickStartClock)
                    .opacity(store.canQuickStartClock ? 1 : 0.45)
                }
                .padding(22)
                .clockedCard()

                if store.hasPendingInputChanges {
                    Text("Unconfirmed advanced edits stay separate until you tap OK or Done in Advanced.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(ClockedTheme.subtleText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 40)
        }
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(ClockedTheme.mutedText)

            Spacer()

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(ClockedTheme.primaryText)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct SimpleModeLiveView: View {
    let store: ClockedStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let snapshot = store.sessionSnapshot(at: context.date) {
                SimpleLiveContent(store: store, snapshot: snapshot)
            } else {
                SimpleModeStartView(store: store)
            }
        }
    }
}

private struct SimpleLiveContent: View {
    let store: ClockedStore
    let snapshot: SessionSnapshot

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Text("earned today")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(ClockedTheme.secondaryText)

                    HStack(alignment: .lastTextBaseline, spacing: 0) {
                        Text(snapshot.amountParts.major)
                            .font(.system(size: 76, weight: .bold, design: .rounded))
                            .foregroundStyle(ClockedTheme.primaryText)

                        Text(snapshot.amountParts.minor)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(ClockedTheme.secondaryText)
                            .baselineOffset(-5)
                    }
                    .monospacedDigit()
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)

                    HStack(spacing: 8) {
                        Circle()
                            .fill(snapshot.statusColor)
                            .frame(width: 9, height: 9)

                        Text(simpleStatusLine)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(snapshot.status == .scheduled ? ClockedTheme.secondaryText : ClockedTheme.green)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 22)

                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("work day")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(ClockedTheme.secondaryText)

                        Spacer()

                        Text("\(Int(snapshot.progress * 100))% · \(simpleRemainingLabel)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(ClockedTheme.secondaryText)
                    }

                    simpleProgressBar

                    HStack(spacing: 12) {
                        simpleMetric(title: "rate", value: snapshot.estimate.netPerSecond.currencyString)
                        simpleMetric(title: "streak", value: "\(store.currentStreak) days")
                        simpleMetric(title: "goal", value: dailyGoalLabel)
                    }
                }
                .padding(22)
                .clockedCard()

                HStack(spacing: 14) {
                    Button {
                        store.togglePause()
                    } label: {
                        Text(snapshot.status == .paused ? "Resume" : "Pause")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(ClockedTheme.primaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 66)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(ClockedTheme.inputSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(ClockedTheme.stroke, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(snapshot.status == .scheduled || snapshot.status == .complete)
                    .opacity(snapshot.status == .scheduled || snapshot.status == .complete ? 0.45 : 1)

                    Button {
                        store.stopClock()
                    } label: {
                        Text("Stop")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(ClockedTheme.stopButtonText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 66)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(ClockedTheme.stopButton)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    private var simpleStatusLine: String {
        switch snapshot.status {
        case .scheduled:
            return "starts at \(snapshot.scheduledStart.formatted(date: .omitted, time: .shortened))"
        case .live:
            return "\(snapshot.estimate.netPerSecond.currencyString)/s · \(snapshot.elapsedClockText)"
        case .paused:
            return "paused · \(snapshot.elapsedClockText)"
        case .complete:
            return "finished · \(snapshot.elapsedClockText)"
        }
    }

    private var simpleRemainingLabel: String {
        switch snapshot.status {
        case .scheduled:
            return "queued"
        case .live, .paused:
            return "\(snapshot.remainingSeconds.shortDurationString) left"
        case .complete:
            return "done"
        }
    }

    private var dailyGoalLabel: String {
        "$\(Int(snapshot.estimate.netDaily.rounded()).groupedNumber)"
    }

    private var simpleProgressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(ClockedTheme.progressTrack)

                Capsule(style: .continuous)
                    .fill(ClockedTheme.primaryText)
                    .frame(width: geometry.size.width * snapshot.progress)
            }
        }
        .frame(height: 8)
    }

    private func simpleMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(ClockedTheme.subtleText)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(ClockedTheme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Simple Mode") {
    ClockedQuickStartView(store: ClockedStore())
        .preferredColorScheme(.dark)
}
