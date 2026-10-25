//
//  LiveWageSetupView.swift
//  LiveWage
//
//  Created by Codex on 5/4/26.
//

import SwiftUI

struct LiveWageSetupView: View {
    private enum FocusField: Hashable {
        case streamName
        case salary
        case bonus
        case benefits
        case goal
    }

    @Bindable var store: LiveWageStore
    @FocusState private var focusedField: FocusField?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                introCard
                streamsCard
                compensationCard
                workDetailsCard
                previewCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    commitFocusedField()
                    focusedField = nil
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
            }
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Update saved information before you start")
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(LiveWageTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Advanced keeps the longer input flow so you can refine compensation, location, schedule, and goal details before starting the timer.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(LiveWageTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var streamsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("Income streams")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.streams) { stream in
                        selectablePill(
                            title: stream.name,
                            isSelected: store.selectedStreamID == stream.id
                        ) {
                            store.setSelectedStream(stream.id)
                        }
                        .frame(width: max(122, CGFloat(stream.name.count * 11)))
                    }

                    Button(action: store.addIncomeStream) {
                        Label("Add", systemImage: "plus")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(store.canAddIncomeStream ? LiveWageTheme.primaryText : LiveWageTheme.subtleText)
                            .frame(height: 52)
                            .padding(.horizontal, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(LiveWageTheme.inputSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(LiveWageTheme.stroke, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!store.canAddIncomeStream)
                    .accessibilityLabel("Add income stream")
                    .accessibilityHint("Creates another saved income stream in this editor")
                }
            }

            plainInputRow(
                title: "Stream name",
                text: Binding(
                    get: { store.streamNameInput },
                    set: { store.updateStreamNameInput($0) }
                ),
                focusField: .streamName,
                canCommit: store.canCommitStreamName,
                action: {
                    store.commitStreamNameInput()
                    focusedField = nil
                }
            )
        }
        .padding(22)
        .liveWageCard()
    }

    private var compensationCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("Compensation")

            currencyInputRow(
                title: store.configuration.payFrequency.inputTitle,
                text: Binding(
                    get: { store.salaryInput },
                    set: { store.updateSalaryInput($0) }
                ),
                focusField: .salary,
                canCommit: store.canCommitSalary,
                action: {
                    store.commitSalaryInput()
                    focusedField = nil
                }
            )

            HStack(spacing: 10) {
                ForEach(PayFrequency.allCases) { frequency in
                    selectablePill(
                        title: frequency.title,
                        isSelected: store.configuration.payFrequency == frequency
                    ) {
                        store.setPayFrequency(frequency)
                    }
                }
            }

            currencyInputRow(
                title: "Annual bonus",
                text: Binding(
                    get: { store.bonusInput },
                    set: { store.updateBonusInput($0) }
                ),
                focusField: .bonus,
                canCommit: store.canCommitBonus,
                action: {
                    store.commitBonusInput()
                    focusedField = nil
                }
            )

            currencyInputRow(
                title: "Monthly pre-tax benefits",
                text: Binding(
                    get: { store.benefitsInput },
                    set: { store.updateBenefitsInput($0) }
                ),
                focusField: .benefits,
                canCommit: store.canCommitBenefits,
                action: {
                    store.commitBenefitsInput()
                    focusedField = nil
                }
            )

            if !store.pendingInputHints.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(store.pendingInputHints, id: \.self) { hint in
                        Text(hint)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(LiveWageTheme.amber)
                    }
                }
            }
        }
        .padding(22)
        .liveWageCard()
    }

    private var workDetailsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("Work details")

            Menu {
                ForEach(LocationOption.allCases) { location in
                    Button(location.name) {
                        store.setLocation(location)
                    }
                }
            } label: {
                settingsRow(label: "Residence tax location", value: store.configuration.location.name)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Residence tax location")
            .accessibilityValue(store.configuration.location.name)
            .accessibilityHint("Opens the saved tax location list")

            Menu {
                ForEach(FilingStatus.allCases) { status in
                    Button(status.title) {
                        store.setFilingStatus(status)
                    }
                }
            } label: {
                settingsRow(label: "Filing status", value: store.configuration.filingStatus.title)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Filing status")
            .accessibilityValue(store.configuration.filingStatus.title)
            .accessibilityHint("Opens the filing status list")

            HStack(spacing: 14) {
                stepperCard(
                    title: "Hours per day",
                    valueText: "\(store.configuration.workHoursPerDay)",
                    onMinus: { store.adjustWorkHours(by: -1) },
                    onPlus: { store.adjustWorkHours(by: 1) }
                )

                stepperCard(
                    title: "Days per week",
                    valueText: "\(store.configuration.workDaysPerWeek)",
                    onMinus: { store.adjustWorkDays(by: -1) },
                    onPlus: { store.adjustWorkDays(by: 1) }
                )
            }

            DatePicker(
                "Typical start time",
                selection: Binding(
                    get: { store.configuration.startTimeDate(calendar: Calendar(identifier: .gregorian)) },
                    set: { store.setWorkStartTime($0) }
                ),
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.compact)
            .tint(LiveWageTheme.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LiveWageTheme.inputSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(LiveWageTheme.stroke, lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                Text("Typical start time")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(LiveWageTheme.subtleText)
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
            }

            stepperCard(
                title: "Traditional retirement savings",
                subtitle: "401(k) / 403(b) style deferral",
                valueText: "\(store.configuration.retirementContributionPercent)%",
                onMinus: { store.adjustRetirementContribution(by: -1) },
                onPlus: { store.adjustRetirementContribution(by: 1) }
            )

            currencyInputRow(
                title: "Savings target",
                text: Binding(
                    get: { store.goalInput },
                    set: { store.updateGoalInput($0) }
                ),
                focusField: .goal,
                canCommit: store.canCommitGoal,
                action: {
                    store.commitGoalInput()
                    focusedField = nil
                }
            )
        }
        .padding(22)
        .liveWageCard()
    }

    private var previewCard: some View {
        let estimate = store.estimate

        return VStack(alignment: .leading, spacing: 18) {
            sectionTitle("Preview")

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(estimate.netPerSecond.currencyString)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(LiveWageTheme.primaryText)

                Text("/ sec")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(LiveWageTheme.secondaryText)
            }
            .monospacedDigit()

            summaryRow(title: "Annual take-home", value: estimate.annualNet.currencyString)
            summaryRow(title: "Daily take-home", value: estimate.netDaily.currencyString)
            summaryRow(title: "Work week", value: store.configuration.workWeekSummary)
            summaryRow(title: "Goal", value: store.configuration.savingsGoalAmount > 0 ? store.configuration.savingsGoalAmount.currencyString : "Not set")

            VStack(alignment: .leading, spacing: 8) {
                Text("Estimate assumptions")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(LiveWageTheme.subtleText)

                Text(store.taxCatalogSummary)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(LiveWageTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(store.payrollAssumptionsLabel)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(LiveWageTheme.subtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: store.startClock) {
                Text("Start timer")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(LiveWageTheme.lightButtonText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(LiveWageTheme.lightButton)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!store.canStartClock)
            .opacity(store.canStartClock ? 1 : 0.45)
            .accessibilityLabel("Start timer")
            .accessibilityHint("Starts a workday timer with the saved advanced settings")
        }
        .padding(22)
        .liveWageCard()
    }

    private func commitFocusedField() {
        switch focusedField {
        case .streamName:
            store.commitStreamNameInput()
        case .salary:
            store.commitSalaryInput()
        case .bonus:
            store.commitBonusInput()
        case .benefits:
            store.commitBenefitsInput()
        case .goal:
            store.commitGoalInput()
        case nil:
            break
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(LiveWageTheme.secondaryText)
    }

    private func selectablePill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? LiveWageTheme.primaryText : LiveWageTheme.mutedText)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LiveWageTheme.inputSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            isSelected ? LiveWageTheme.primaryText : LiveWageTheme.stroke,
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func settingsRow(label: String, value: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(LiveWageTheme.subtleText)

                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(LiveWageTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.down")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(LiveWageTheme.subtleText)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LiveWageTheme.inputSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LiveWageTheme.stroke, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    private func plainInputRow(
        title: String,
        text: Binding<String>,
        focusField: FocusField,
        canCommit: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(LiveWageTheme.subtleText)

            HStack(spacing: 12) {
                TextField("", text: text)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(LiveWageTheme.primaryText)
                    .focused($focusedField, equals: focusField)
                    .padding(.horizontal, 20)
                    .frame(height: 62)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(LiveWageTheme.inputSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                focusedField == focusField ? LiveWageTheme.primaryText : LiveWageTheme.stroke,
                                lineWidth: focusedField == focusField ? 1.5 : 1
                            )
                    )
                    .accessibilityLabel(title)

                Button(action: action) {
                    Text("OK")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(canCommit ? LiveWageTheme.lightButtonText : LiveWageTheme.subtleText)
                        .frame(width: 62, height: 62)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(canCommit ? LiveWageTheme.lightButton : LiveWageTheme.elevatedSurface)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canCommit)
                .accessibilityLabel("Confirm \(title.lowercased())")
                .accessibilityHint("Saves this value into the form")
            }
        }
    }

    private func currencyInputRow(
        title: String,
        text: Binding<String>,
        focusField: FocusField,
        canCommit: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(LiveWageTheme.subtleText)

            HStack(spacing: 12) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LiveWageTheme.inputSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    focusedField == focusField ? LiveWageTheme.primaryText : LiveWageTheme.stroke,
                                    lineWidth: focusedField == focusField ? 1.5 : 1
                                )
                        )

                    Text("$")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(LiveWageTheme.subtleText)
                        .padding(.leading, 20)

                    TextField("", text: text)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(LiveWageTheme.primaryText)
                        .focused($focusedField, equals: focusField)
                        .padding(.leading, 42)
                        .padding(.trailing, 20)
                        .accessibilityLabel(title)
                }
                .frame(height: 62)

                Button(action: action) {
                    Text("OK")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(canCommit ? LiveWageTheme.lightButtonText : LiveWageTheme.subtleText)
                        .frame(width: 62, height: 62)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(canCommit ? LiveWageTheme.lightButton : LiveWageTheme.elevatedSurface)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canCommit)
                .accessibilityLabel("Confirm \(title.lowercased())")
                .accessibilityHint("Saves this value into the form")
            }
        }
    }

    private func stepperCard(
        title: String,
        subtitle: String? = nil,
        valueText: String,
        onMinus: @escaping () -> Void,
        onPlus: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(LiveWageTheme.subtleText)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(LiveWageTheme.mutedText)
            }

            HStack {
                StepperButton(
                    symbol: "minus",
                    accessibilityLabel: "Decrease \(title.lowercased())",
                    action: onMinus
                )

                Spacer()

                Text(valueText)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(LiveWageTheme.primaryText)
                    .monospacedDigit()

                Spacer()

                StepperButton(
                    symbol: "plus",
                    accessibilityLabel: "Increase \(title.lowercased())",
                    action: onPlus
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LiveWageTheme.inputSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LiveWageTheme.stroke, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(valueText)
        .accessibilityHint(subtitle ?? "Adjust with the plus and minus buttons")
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack {
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
}

private struct StepperButton: View {
    let symbol: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(LiveWageTheme.primaryText)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LiveWageTheme.elevatedSurface)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview("Advanced Setup") {
    LiveWageSetupView(store: LiveWageStore())
        .preferredColorScheme(.dark)
}
