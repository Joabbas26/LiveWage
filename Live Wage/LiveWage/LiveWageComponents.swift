//
//  LiveWageComponents.swift
//  LiveWage
//
//  Shared building blocks for the redesigned screens.
//

import SwiftUI

struct LiveWageHeader<Trailing: View>: View {
    let caption: String?
    let title: String
    let trailing: Trailing

    init(caption: String? = nil, title: String, @ViewBuilder trailing: () -> Trailing) {
        self.caption = caption
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if let caption {
                    Text(caption)
                        .font(.liveWage(.subheadline, weight: .semibold))
                        .foregroundStyle(LiveWageTheme.mutedText)
                }

                Text(title)
                    .font(.liveWage(.largeTitle, weight: .bold))
                    .foregroundStyle(LiveWageTheme.primaryText)
                    .accessibilityAddTraits(.isHeader)
            }

            Spacer(minLength: 0)

            trailing
        }
    }
}

extension LiveWageHeader where Trailing == EmptyView {
    init(caption: String? = nil, title: String) {
        self.init(caption: caption, title: title) {
            EmptyView()
        }
    }
}

struct LiveWageSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.liveWage(.footnote, weight: .bold))
            .textCase(.uppercase)
            .tracking(0.4)
            .foregroundStyle(LiveWageTheme.mutedText)
            .padding(.leading, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

struct LiveWageDivider: View {
    var body: some View {
        Rectangle()
            .fill(LiveWageTheme.divider)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

struct LiveWageButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case destructive
        case hero
    }

    var kind: Kind = .primary

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.liveWage(.headline, weight: .bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(background)
            )
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(LiveWageTheme.strongStroke, lineWidth: 1)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary:
            return LiveWageTheme.lightButtonText
        case .secondary:
            return LiveWageTheme.primaryText
        case .destructive:
            return LiveWageTheme.stopButtonText
        case .hero:
            return Color(hex: 0x1F1812)
        }
    }

    private var background: Color {
        switch kind {
        case .primary:
            return LiveWageTheme.lightButton
        case .secondary:
            return LiveWageTheme.surface
        case .destructive:
            return LiveWageTheme.stopButton
        case .hero:
            return LiveWageTheme.heroText
        }
    }
}

struct LiveWageStatusPill: View {
    let status: SessionStatus

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Text(title)
        }
        .font(.liveWage(.subheadline, weight: .bold))
        .foregroundStyle(textColor)
        .padding(.horizontal, 14)
        .frame(minHeight: 32)
        .background(
            Capsule(style: .continuous)
                .fill(fillColor)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status")
        .accessibilityValue(title)
    }

    private var title: String {
        switch status {
        case .scheduled:
            return "Scheduled"
        case .live:
            return "Live"
        case .paused:
            return "Paused"
        case .complete:
            return "Done"
        }
    }

    private var dotColor: Color {
        switch status {
        case .scheduled:
            return LiveWageTheme.amber
        case .live:
            return LiveWageTheme.green
        case .paused:
            return LiveWageTheme.mutedText
        case .complete:
            return LiveWageTheme.blue
        }
    }

    private var textColor: Color {
        switch status {
        case .scheduled:
            return LiveWageTheme.amberText
        case .live:
            return LiveWageTheme.greenText
        case .paused, .complete:
            return LiveWageTheme.secondaryText
        }
    }

    private var fillColor: Color {
        switch status {
        case .scheduled:
            return LiveWageTheme.amberSoft
        case .live:
            return LiveWageTheme.greenSoft
        case .paused, .complete:
            return LiveWageTheme.elevatedSurface
        }
    }
}

struct LiveWageProgressBar: View {
    let progress: Double
    var tint: Color = LiveWageTheme.green
    var height: CGFloat = 8
    var showsThumb = false

    private let thumbSize: CGFloat = 18

    var body: some View {
        GeometryReader { geometry in
            let clamped = min(max(progress, 0), 1)
            let fillWidth = clamped > 0 ? max(geometry.size.width * clamped, height) : 0

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(LiveWageTheme.progressTrack)
                    .frame(height: height)

                Capsule(style: .continuous)
                    .fill(tint)
                    .frame(width: fillWidth, height: height)

                if showsThumb {
                    Circle()
                        .fill(LiveWageTheme.surface)
                        .overlay(
                            Circle()
                                .strokeBorder(tint, lineWidth: 4)
                        )
                        .frame(width: thumbSize, height: thumbSize)
                        .offset(x: min(max(geometry.size.width * clamped - thumbSize / 2, 0), geometry.size.width - thumbSize))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
        }
        .frame(height: showsThumb ? thumbSize : height)
        .accessibilityHidden(true)
    }
}

struct LiveWageMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.liveWage(.caption, weight: .semibold))
                .foregroundStyle(LiveWageTheme.mutedText)

            Text(value)
                .font(.liveWage(.headline, weight: .bold))
                .foregroundStyle(LiveWageTheme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

struct LiveWageStepperRow: View {
    let title: String
    var subtitle: String? = nil
    let value: String
    let canDecrease: Bool
    let canIncrease: Bool
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.liveWage(.subheadline, weight: .bold))
                    .foregroundStyle(LiveWageTheme.primaryText)

                if let subtitle {
                    Text(subtitle)
                        .font(.liveWage(.footnote, weight: .medium))
                        .foregroundStyle(LiveWageTheme.mutedText)
                }
            }

            Spacer(minLength: 8)

            stepButton(symbol: "minus", isEnabled: canDecrease, action: onDecrease)

            Text(value)
                .font(.liveWage(.body, weight: .bold))
                .foregroundStyle(LiveWageTheme.primaryText)
                .monospacedDigit()
                .frame(minWidth: 44)

            stepButton(symbol: "plus", isEnabled: canIncrease, action: onIncrease)
        }
        .frame(minHeight: 60)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .accessibilityHint(subtitle ?? "Swipe up or down to adjust")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                if canIncrease { onIncrease() }
            case .decrement:
                if canDecrease { onDecrease() }
            @unknown default:
                break
            }
        }
    }

    private func stepButton(symbol: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(LiveWageTheme.primaryText)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LiveWageTheme.elevatedSurface)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

struct LiveWageInitialsBadge: View {
    let initials: String?
    var size: CGFloat = 44
    var isProminent = false

    var body: some View {
        ZStack {
            Circle()
                .fill(isProminent ? LiveWageTheme.lightButton : LiveWageTheme.elevatedSurface)

            if let initials {
                Text(initials)
                    .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                    .foregroundStyle(isProminent ? LiveWageTheme.lightButtonText : LiveWageTheme.secondaryText)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(isProminent ? LiveWageTheme.lightButtonText : LiveWageTheme.secondaryText)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .strokeBorder(LiveWageTheme.stroke, lineWidth: isProminent ? 0 : 1)
        )
    }
}

struct LiveWageDetailRow: View {
    let systemImage: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(LiveWageTheme.secondaryText)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LiveWageTheme.elevatedSurface)
                )
                .accessibilityHidden(true)

            Text(title)
                .font(.liveWage(.subheadline, weight: .semibold))
                .foregroundStyle(LiveWageTheme.mutedText)

            Spacer(minLength: 12)

            Text(value)
                .font(.liveWage(.subheadline, weight: .bold))
                .foregroundStyle(LiveWageTheme.primaryText)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 52)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

extension Double {
    // Small rates read better in cents: 0.0081 becomes "0.81¢".
    var friendlyRateString: String {
        guard self < 1 else { return currencyString }
        let cents = self * 100
        return cents >= 10 ? String(format: "%.0f¢", cents) : String(format: "%.2f¢", cents)
    }

    var wholeCurrencyString: String {
        "$\(Int(rounded()).groupedNumber)"
    }

    var percentString: String {
        formatted(.percent.precision(.fractionLength(1)))
    }
}

extension EarningsConfiguration {
    var payLabel: String {
        switch payFrequency {
        case .annual:
            return "\(salaryAmount.wholeCurrencyString) / yr"
        case .monthly:
            return "\(salaryAmount.wholeCurrencyString) / mo"
        case .hourly:
            return "\(salaryAmount.currencyString) / hr"
        }
    }
}

extension String {
    var sentenceCased: String {
        guard let first else { return self }
        return first.uppercased() + String(dropFirst())
    }
}
