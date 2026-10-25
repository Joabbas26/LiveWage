//
//  LiveWagePayDetailsView.swift
//  LiveWage
//
//  Created by Codex on 5/4/26.
//

import SwiftUI

struct LiveWagePayDetailsView: View {
    private enum Field: Hashable {
        case streamName
        case salary
        case bonus
        case benefits
        case goal
    }

    @Bindable var store: LiveWageStore

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            // Measured here rather than passed in: on iPad the sheet is narrower than the window.
            GeometryReader { proxy in
                if proxy.size.width >= LiveWageLayout.wideBreakpoint {
                    HStack(alignment: .top, spacing: LiveWageLayout.paneSpacing) {
                        ScrollView {
                            form
                                .padding(.vertical, 8)
                        }
                        .frame(maxWidth: .infinity)

                        ScrollView {
                            previewPanel
                                .padding(.vertical, 8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, LiveWageLayout.horizontalPadding)
                } else {
                    ScrollView {
                        form
                            .padding(.horizontal, LiveWageLayout.horizontalPadding)
                            .padding(.vertical, 8)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        previewFooter
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(LiveWageTheme.appBackground.ignoresSafeArea())
            .navigationTitle("Pay details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: finish)
                        .fontWeight(.bold)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()

                    Button("Done") {
                        focusedField = nil
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .onChange(of: focusedField) { oldValue, _ in
            commit(oldValue)
        }
        .onDisappear {
            store.finishEditingPayDetails()
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Form

    private var form: some View {
        VStack(alignment: .leading, spacing: 22) {
            streamSection
            paySection
            taxSection
            scheduleSection

            Label {
                Text(store.taxCatalogSummary)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "info.circle")
            }
            .font(.liveWage(.footnote, weight: .medium))
            .foregroundStyle(LiveWageTheme.mutedText)
            .padding(.horizontal, 4)
        }
    }

    private var streamSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            LiveWageSectionLabel(title: "Income stream")

            VStack(alignment: .leading, spacing: 14) {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(store.streams) { stream in
                            streamChip(stream)
                        }

                        if store.canAddIncomeStream {
                            Button(action: addStream) {
                                Label("Add", systemImage: "plus")
                                    .font(.liveWage(.subheadline, weight: .bold))
                                    .foregroundStyle(LiveWageTheme.secondaryText)
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 44)
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .strokeBorder(LiveWageTheme.subtleText, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                                    )
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add income stream")
                        }
                    }
                }
                .scrollIndicators(.hidden)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Stream name")
                        .font(.liveWage(.footnote, weight: .semibold))
                        .foregroundStyle(LiveWageTheme.mutedText)

                    TextField(
                        "Main Income",
                        text: Binding(
                            get: { store.streamNameInput },
                            set: { store.updateStreamNameInput($0) }
                        )
                    )
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .streamName)
                    .onSubmit {
                        focusedField = nil
                    }
                    .font(.liveWage(.body, weight: .bold))
                    .foregroundStyle(LiveWageTheme.primaryText)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(inputBackground(isFocused: focusedField == .streamName))
                    .accessibilityLabel("Stream name")
                }
            }
            .padding(14)
            .liveWageCard()
        }
    }

    private func streamChip(_ stream: IncomeStream) -> some View {
        let isSelected = stream.id == store.selectedStreamID

        return Button {
            selectStream(stream.id)
        } label: {
            Text(stream.name)
                .font(.liveWage(.subheadline, weight: .bold))
                .foregroundStyle(isSelected ? LiveWageTheme.lightButtonText : LiveWageTheme.primaryText)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? LiveWageTheme.lightButton : LiveWageTheme.elevatedSurface)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!store.canSwitchIncomeStreams)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var paySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            LiveWageSectionLabel(title: "Pay")

            VStack(alignment: .leading, spacing: 0) {
                Picker(
                    "Pay frequency",
                    selection: Binding(
                        get: { store.configuration.payFrequency },
                        set: { store.setPayFrequency($0) }
                    )
                ) {
                    ForEach(PayFrequency.allCases) { frequency in
                        Text(frequency.title).tag(frequency)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 6) {
                    Text(salaryTitle)
                        .font(.liveWage(.footnote, weight: .semibold))
                        .foregroundStyle(LiveWageTheme.mutedText)

                    HStack(spacing: 6) {
                        Text("$")
                            .font(.liveWage(.title2, weight: .bold))
                            .foregroundStyle(LiveWageTheme.mutedText)
                            .accessibilityHidden(true)

                        TextField(
                            "0",
                            text: Binding(
                                get: { store.salaryInput },
                                set: { store.updateSalaryInput($0) }
                            )
                        )
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .salary)
                        .font(.liveWage(.title, weight: .bold))
                        .foregroundStyle(LiveWageTheme.primaryText)
                        .monospacedDigit()
                        .accessibilityLabel(salaryTitle)

                        Text(salaryUnit)
                            .font(.liveWage(.subheadline, weight: .semibold))
                            .foregroundStyle(LiveWageTheme.mutedText)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 60)
                    .background(inputBackground(isFocused: focusedField == .salary, cornerRadius: 16))

                    if store.salaryInput.currencyNumber <= 0 {
                        Text("Enter an amount above $0 to estimate your take-home.")
                            .font(.liveWage(.footnote, weight: .semibold))
                            .foregroundStyle(LiveWageTheme.amberText)
                    }
                }
                .padding(.vertical, 14)

                LiveWageDivider()

                amountRow(
                    title: "Annual bonus",
                    text: Binding(
                        get: { store.bonusInput },
                        set: { store.updateBonusInput($0) }
                    ),
                    field: .bonus
                )

                LiveWageDivider()

                amountRow(
                    title: "Pre-tax benefits",
                    subtitle: "Per month · health, FSA, commuter",
                    text: Binding(
                        get: { store.benefitsInput },
                        set: { store.updateBenefitsInput($0) }
                    ),
                    field: .benefits
                )
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 4)
            .liveWageCard()
        }
    }

    private var taxSection: some View {
        let retirementPercent = store.configuration.retirementContributionPercent

        return VStack(alignment: .leading, spacing: 8) {
            LiveWageSectionLabel(title: "Taxes")

            if let notice = store.activeEstimateNotice {
                LiveWageNoticeBanner(notice: notice)
            }

            VStack(spacing: 0) {
                pickerRow(title: "Tax location") {
                    Picker(
                        "Tax location",
                        selection: Binding(
                            get: { store.configuration.location },
                            set: { store.setLocation($0) }
                        )
                    ) {
                        ForEach(LocationOption.allCases) { location in
                            Text(location.name).tag(location)
                        }
                    }
                }

                LiveWageDivider()

                pickerRow(title: "Filing status") {
                    Picker(
                        "Filing status",
                        selection: Binding(
                            get: { store.configuration.filingStatus },
                            set: { store.setFilingStatus($0) }
                        )
                    ) {
                        ForEach(FilingStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                }

                LiveWageDivider()

                LiveWageStepperRow(
                    title: "Retirement savings",
                    subtitle: "401(k) / 403(b), pre-tax",
                    value: "\(retirementPercent)%",
                    canDecrease: retirementPercent > 0,
                    canIncrease: retirementPercent < 40,
                    onDecrease: { store.adjustRetirementContribution(by: -1) },
                    onIncrease: { store.adjustRetirementContribution(by: 1) }
                )
            }
            .padding(.horizontal, 14)
            .liveWageCard()
        }
    }

    private var scheduleSection: some View {
        let configuration = store.configuration

        return VStack(alignment: .leading, spacing: 8) {
            LiveWageSectionLabel(title: "Schedule & goal")

            VStack(spacing: 0) {
                LiveWageStepperRow(
                    title: "Hours per day",
                    value: "\(configuration.workHoursPerDay)",
                    canDecrease: configuration.workHoursPerDay > 1,
                    canIncrease: configuration.workHoursPerDay < 16,
                    onDecrease: { store.adjustWorkHours(by: -1) },
                    onIncrease: { store.adjustWorkHours(by: 1) }
                )

                LiveWageDivider()

                LiveWageStepperRow(
                    title: "Days per week",
                    subtitle: configuration.workWeekSummary,
                    value: "\(configuration.workDaysPerWeek)",
                    canDecrease: configuration.workDaysPerWeek > 1,
                    canIncrease: configuration.workDaysPerWeek < 7,
                    onDecrease: { store.adjustWorkDays(by: -1) },
                    onIncrease: { store.adjustWorkDays(by: 1) }
                )

                LiveWageDivider()

                HStack(spacing: 12) {
                    Text("Usual start time")
                        .font(.liveWage(.subheadline, weight: .bold))
                        .foregroundStyle(LiveWageTheme.primaryText)

                    Spacer(minLength: 12)

                    DatePicker(
                        "Usual start time",
                        selection: Binding(
                            get: { store.configuration.startTimeDate(calendar: Calendar(identifier: .gregorian)) },
                            set: { store.setWorkStartTime($0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(LiveWageTheme.primaryText)
                }
                .frame(minHeight: 60)

                LiveWageDivider()

                amountRow(
                    title: "Savings target",
                    subtitle: "Shows how many workdays to go",
                    text: Binding(
                        get: { store.goalInput },
                        set: { store.updateGoalInput($0) }
                    ),
                    field: .goal
                )
            }
            .padding(.horizontal, 14)
            .liveWageCard()
        }
    }

    private func pickerRow<PickerContent: View>(
        title: String,
        @ViewBuilder picker: () -> PickerContent
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.liveWage(.subheadline, weight: .bold))
                .foregroundStyle(LiveWageTheme.primaryText)

            Spacer(minLength: 12)

            picker()
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(LiveWageTheme.secondaryText)
        }
        .frame(minHeight: 56)
    }

    private func amountRow(
        title: String,
        subtitle: String? = nil,
        text: Binding<String>,
        field: Field
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.liveWage(.subheadline, weight: .bold))
                    .foregroundStyle(LiveWageTheme.primaryText)

                if let subtitle {
                    Text(subtitle)
                        .font(.liveWage(.footnote, weight: .medium))
                        .foregroundStyle(LiveWageTheme.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            HStack(spacing: 2) {
                Text("$")
                    .foregroundStyle(LiveWageTheme.mutedText)
                    .accessibilityHidden(true)

                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: field)
                    .foregroundStyle(LiveWageTheme.primaryText)
                    .accessibilityLabel(title)
            }
            .font(.liveWage(.body, weight: .bold))
            .monospacedDigit()
            .padding(.horizontal, 12)
            .frame(width: 136, height: 44)
            .background(inputBackground(isFocused: focusedField == field, cornerRadius: 12))
        }
        .frame(minHeight: 60)
    }

    private func inputBackground(isFocused: Bool, cornerRadius: CGFloat = 14) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(LiveWageTheme.inputSurface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        isFocused ? LiveWageTheme.primaryText : LiveWageTheme.strongStroke,
                        lineWidth: isFocused ? 2 : 1
                    )
            )
    }

    // MARK: - Preview

    private var previewFooter: some View {
        let estimate = store.draftEstimate

        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Estimated take-home")
                    .font(.liveWage(.footnote, weight: .semibold))
                    .foregroundStyle(LiveWageTheme.mutedText)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(estimate.netDaily.currencyString)
                        .font(.liveWage(.title2, weight: .bold))
                        .foregroundStyle(LiveWageTheme.primaryText)
                        .monospacedDigit()

                    Text("/ workday")
                        .font(.liveWage(.footnote, weight: .semibold))
                        .foregroundStyle(LiveWageTheme.mutedText)
                }

                Text("\((estimate.netPerSecond * 3600).friendlyRateString)/hr · \(estimate.effectiveTaxRate.percentString) total tax")
                    .font(.liveWage(.footnote, weight: .medium))
                    .foregroundStyle(LiveWageTheme.mutedText)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)

            Button("Done", action: finish)
                .buttonStyle(LiveWageButtonStyle(kind: .primary))
                .frame(width: 112)
        }
        .padding(.horizontal, LiveWageLayout.horizontalPadding)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(LiveWageTheme.surface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            LiveWageDivider()
        }
    }

    private var previewPanel: some View {
        let estimate = store.draftEstimate
        let amount = CurrencyAmountParts(amount: estimate.netDaily)
        let perHour = estimate.netPerSecond * 3600

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Circle()
                    .fill(LiveWageTheme.green)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)

                Text("Live preview · updates as you type")
                    .font(.liveWage(.footnote, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(LiveWageTheme.mutedText)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("You'll take home")
                    .font(.liveWage(.subheadline, weight: .semibold))
                    .foregroundStyle(LiveWageTheme.mutedText)

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(amount.major)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(LiveWageTheme.primaryText)

                    Text(amount.minor)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(LiveWageTheme.mutedText)

                    Text(" / workday")
                        .font(.liveWage(.headline, weight: .semibold))
                        .foregroundStyle(LiveWageTheme.mutedText)
                }
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Take-home per workday")
            .accessibilityValue(estimate.netDaily.currencyString)

            HStack(spacing: 8) {
                rateTile(title: "Per hour", value: perHour.friendlyRateString)
                rateTile(title: "Per minute", value: (perHour / 60).friendlyRateString)
                rateTile(title: "Per second", value: estimate.netPerSecond.friendlyRateString)
            }

            VStack(spacing: 0) {
                summaryRow(title: "Gross pay", value: estimate.annualGross.wholeCurrencyString)
                LiveWageDivider()
                summaryRow(title: "Taxes · \(estimate.effectiveTaxRate.percentString)", value: "−\(estimate.totalTax.wholeCurrencyString)")
                LiveWageDivider()
                summaryRow(
                    title: "Pre-tax deductions",
                    value: "−\((estimate.annualPretaxBenefits + estimate.annualRetirementContribution).wholeCurrencyString)"
                )
                LiveWageDivider()
                summaryRow(title: "Take-home a year", value: estimate.annualNet.wholeCurrencyString, isEmphasized: true)
            }
            .padding(.horizontal, 18)
            .liveWageCard()

            Button("Done", action: finish)
                .buttonStyle(LiveWageButtonStyle(kind: .primary))
        }
    }

    private func rateTile(title: String, value: String) -> some View {
        LiveWageMetric(title: title, value: value)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LiveWageTheme.inputSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(LiveWageTheme.divider, lineWidth: 1)
            )
    }

    private func summaryRow(title: String, value: String, isEmphasized: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.liveWage(.subheadline, weight: isEmphasized ? .bold : .semibold))
                .foregroundStyle(isEmphasized ? LiveWageTheme.primaryText : LiveWageTheme.secondaryText)

            Spacer(minLength: 12)

            Text(value)
                .font(.liveWage(isEmphasized ? .headline : .subheadline, weight: .bold))
                .foregroundStyle(isEmphasized ? LiveWageTheme.greenText : LiveWageTheme.primaryText)
                .monospacedDigit()
        }
        .frame(minHeight: isEmphasized ? 48 : 44)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions

    private var salaryTitle: String {
        switch store.configuration.payFrequency {
        case .annual:
            return "Annual salary, before tax"
        case .monthly:
            return "Monthly pay, before tax"
        case .hourly:
            return "Hourly rate, before tax"
        }
    }

    private var salaryUnit: String {
        switch store.configuration.payFrequency {
        case .annual:
            return "/ year"
        case .monthly:
            return "/ month"
        case .hourly:
            return "/ hour"
        }
    }

    private func commit(_ field: Field?) {
        switch field {
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

    private func selectStream(_ streamID: UUID) {
        commit(focusedField)
        focusedField = nil
        store.setSelectedStream(streamID)
    }

    private func addStream() {
        commit(focusedField)
        focusedField = nil
        store.addIncomeStream()
    }

    private func finish() {
        focusedField = nil
        store.finishEditingPayDetails()
        dismiss()
    }
}

#Preview("Pay details") {
    LiveWagePayDetailsView(store: LiveWageStore())
}
