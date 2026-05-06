//
//  ClockedLiveView.swift
//  Clocked
//
//  Created by Codex on 5/4/26.
//

import SwiftUI

struct ClockedLiveView: View {
    @Bindable var store: ClockedStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let snapshot = store.sessionSnapshot(at: context.date) {
                AdvancedLiveContent(
                    store: store,
                    snapshot: snapshot,
                    taxBreakdown: store.taxBreakdown(for: snapshot.estimate)
                )
            } else {
                ClockedSetupView(store: store)
            }
        }
    }
}

private struct AdvancedLiveContent: View {
    let store: ClockedStore
    let snapshot: SessionSnapshot
    let taxBreakdown: [TaxBreakdownRow]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
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
                            .accessibilityHidden(true)

                        Text(statusLine)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(snapshot.status == .scheduled ? ClockedTheme.secondaryText : ClockedTheme.green)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 18)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Earned today")
                .accessibilityValue(snapshot.netEarned.currencyString)
                .accessibilityHint(statusLine)

                primaryStatusCard
                savedDetailsCard
                payrollTaxCard
                controls
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    private var primaryStatusCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("work day")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(ClockedTheme.secondaryText)

                Spacer()

                Text("\(Int(snapshot.progress * 100))% · \(remainingLabel)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(ClockedTheme.secondaryText)
            }

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
            .accessibilityLabel("Work day progress")
            .accessibilityValue("\(Int(snapshot.progress * 100)) percent complete")

            HStack(spacing: 12) {
                metric(title: "rate", value: snapshot.estimate.netPerSecond.currencyString)
                metric(title: "streak", value: "\(store.currentStreak) days")
                metric(title: "goal", value: "$\(Int(snapshot.estimate.netDaily.rounded()).groupedNumber)")
            }
        }
        .padding(22)
        .clockedCard()
    }

    private var savedDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Saved details")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(ClockedTheme.secondaryText)

            summaryRow(title: "income stream", value: snapshot.session.streamName)
            summaryRow(title: "location", value: snapshot.session.configuration.location.name)
            summaryRow(title: "schedule", value: snapshot.workWindowLabel)
            summaryRow(title: "savings goal", value: snapshot.session.configuration.savingsGoalAmount > 0 ? snapshot.session.configuration.savingsGoalAmount.currencyString : "Not set")
        }
        .padding(22)
        .clockedCard()
    }

    private var payrollTaxCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payroll + tax estimate")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(ClockedTheme.secondaryText)

            summaryRow(title: "annual take-home", value: snapshot.estimate.annualNet.currencyString)
            summaryRow(title: "gross compensation", value: snapshot.estimate.annualGross.currencyString)
            summaryRow(title: "retirement savings", value: snapshot.estimate.annualRetirementContribution.currencyString)
            summaryRow(title: "pre-tax benefits", value: snapshot.estimate.annualPretaxBenefits.currencyString)

            Divider()
                .background(ClockedTheme.stroke)

            ForEach(taxBreakdown.prefix(3)) { row in
                summaryRow(title: row.title.lowercased(), value: row.formattedAmount)
            }

            Divider()
                .background(ClockedTheme.stroke)

            Text(store.taxCatalogSummary)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(ClockedTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(store.payrollAssumptionsLabel)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(ClockedTheme.subtleText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .clockedCard()
    }

    private var controls: some View {
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
            .accessibilityLabel(snapshot.status == .paused ? "Resume timer" : "Pause timer")
            .accessibilityHint("Pauses or resumes the active workday timer")

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
            .accessibilityLabel("Stop timer")
            .accessibilityHint("Stops the current workday and saves it to history")
        }
    }

    private var statusLine: String {
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

    private var remainingLabel: String {
        switch snapshot.status {
        case .scheduled:
            return "queued"
        case .live, .paused:
            return "\(snapshot.remainingSeconds.shortDurationString) left"
        case .complete:
            return "done"
        }
    }

    private func metric(title: String, value: String) -> some View {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private func summaryRow(title: String, value: String) -> some View {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

#Preview("Advanced Live") {
    let store = ClockedStore()
    store.startClock()

    return ClockedLiveView(store: store)
        .preferredColorScheme(.dark)
}
