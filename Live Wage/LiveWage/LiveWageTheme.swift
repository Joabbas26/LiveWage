//
//  LiveWageTheme.swift
//  LiveWage
//
//  Created by Codex on 5/4/26.
//

import SwiftUI
import UIKit

enum LiveWageTheme {
    static let appBackground = Color(lightHex: 0xF7F2EA, darkHex: 0x141312)

    static let surface = Color(lightHex: 0xFFFCF8, darkHex: 0x23211E)
    static let elevatedSurface = Color(lightHex: 0xF1EADF, darkHex: 0x2B2825)
    static let inputSurface = Color(lightHex: 0xF7F2EA, darkHex: 0x1C1A18)
    static let pillTrack = Color(lightHex: 0xEDE4D7, darkHex: 0x1C1A18)
    static let pillSelection = Color(lightHex: 0xFFFCF8, darkHex: 0x3A3530)
    static let stroke = Color(lightHex: 0xE6DCCF, darkHex: 0x3A3530)
    static let strongStroke = Color(lightHex: 0xD8CBBB, darkHex: 0x4A443D)
    static let divider = Color(lightHex: 0xEFE6DA, darkHex: 0x312D29)
    static let primaryText = Color(lightHex: 0x1F1812, darkHex: 0xF8F4ED)
    static let secondaryText = Color(lightHex: 0x54493D, darkHex: 0xD6CEC3)
    static let mutedText = Color(lightHex: 0x6E6255, darkHex: 0xB8B0A4)
    // Darker than the original 0x8A7B6B so small labels clear 4.5:1 on cards.
    static let subtleText = Color(lightHex: 0x75685A, darkHex: 0x9C9488)
    static let green = Color(lightHex: 0x4D7E0F, darkHex: 0x8CC63F)
    static let greenText = Color(lightHex: 0x3E6A08, darkHex: 0xA6D86A)
    static let greenSoft = Color(lightHex: 0xE4EDD6, darkHex: 0x24311A)
    static let amber = Color(lightHex: 0xB77D12, darkHex: 0xD7A43C)
    static let amberText = Color(lightHex: 0x8A5A00, darkHex: 0xE0B55A)
    static let amberSoft = Color(lightHex: 0xF6E7C8, darkHex: 0x3A2E16)
    static let blue = Color(lightHex: 0x356FCE, darkHex: 0x6FA8FF)
    static let progressTrack = Color(lightHex: 0xE6DCCF, darkHex: 0x3A3530)
    static let taxBar = Color(lightHex: 0xA89A8A, darkHex: 0x8F877C)
    static let lightButton = Color(lightHex: 0x1F1812, darkHex: 0xF5F1E9)
    static let lightButtonText = Color(lightHex: 0xF8F3EB, darkHex: 0x1F1812)
    static let stopButton = Color(lightHex: 0xF6E1DC, darkHex: 0x3A1F1B)
    static let stopButtonText = Color(lightHex: 0xA52B22, darkHex: 0xF2A398)
    static let heroSurface = Color(lightHex: 0x1F1812, darkHex: 0x2B2825)
    static let heroTile = Color(lightHex: 0x2E2620, darkHex: 0x36322D)
    static let heroText = Color(hex: 0xF8F4ED)
    static let heroSecondaryText = Color(hex: 0xCFC6B9)
    static let ringFill = Color(lightHex: 0xFFFCF8, darkHex: 0x181A16)
    static let ringTrack = Color(lightHex: 0xE6DCCF, darkHex: 0x23281F)
    static let ringTick = Color(lightHex: 0xD8CBBB, darkHex: 0x3B4136)
}

enum LiveWageLayout {
    static let horizontalPadding: CGFloat = 20
    // Gap between panes on wide screens; keeps content off a foldable's hinge.
    static let paneSpacing: CGFloat = 24
    static let wideBreakpoint: CGFloat = 700
    static let maxContentWidth: CGFloat = 1100
}

extension Font {
    static func liveWage(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

struct LiveWageCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LiveWageTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(LiveWageTheme.stroke, lineWidth: 1)
            )
    }
}

extension View {
    func liveWageCard() -> some View {
        modifier(LiveWageCardModifier())
    }
}

extension Color {
    init(hex: UInt64) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }

    init(lightHex: UInt64, darkHex: UInt64) {
        self.init(
            uiColor: UIColor { traits in
                UIColor(hex: traits.userInterfaceStyle == .dark ? darkHex : lightHex)
            }
        )
    }
}

extension UIColor {
    convenience init(hex: UInt64) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
