//
//  LiveWageTheme.swift
//  LiveWage
//
//  Created by Codex on 5/4/26.
//

import SwiftUI
import UIKit

enum LiveWageTheme {
    static let appBackground = LinearGradient(
        colors: [
            Color(lightHex: 0xF7F2EA, darkHex: 0x141312),
            Color(lightHex: 0xF1EADF, darkHex: 0x1A1816),
            Color(lightHex: 0xE8DED1, darkHex: 0x201D1A)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let surface = Color(lightHex: 0xFFFCF8, darkHex: 0x23211E)
    static let elevatedSurface = Color(lightHex: 0xF4EDE4, darkHex: 0x2B2825)
    static let inputSurface = Color(lightHex: 0xF7F1E7, darkHex: 0x1C1A18)
    static let navSurface = Color(lightHex: 0xFBF7F1, darkHex: 0x26231F)
    static let pillTrack = Color(lightHex: 0xEAE1D5, darkHex: 0x24211E)
    static let pillSelection = Color(lightHex: 0xFFFDF9, darkHex: 0x312D29)
    static let stroke = Color(lightHex: 0xDCCFC0, darkHex: 0x403B35)
    static let navDivider = Color(lightHex: 0xD3C6B7, darkHex: 0x4A443D)
    static let frameStroke = Color(lightHex: 0xC9BAA9, darkHex: 0x564F48)
    static let primaryText = Color(lightHex: 0x1F1812, darkHex: 0xF8F4ED)
    static let secondaryText = Color(lightHex: 0x54493D, darkHex: 0xD6CEC3)
    static let mutedText = Color(lightHex: 0x6E6255, darkHex: 0xB8B0A4)
    static let subtleText = Color(lightHex: 0x8A7B6B, darkHex: 0x8F877C)
    static let green = Color(lightHex: 0x4D7E0F, darkHex: 0x6AA51A)
    static let amber = Color(lightHex: 0xB77D12, darkHex: 0xD7A43C)
    static let blue = Color(lightHex: 0x356FCE, darkHex: 0x6FA8FF)
    static let progressTrack = Color(lightHex: 0xDED4C7, darkHex: 0x131210)
    static let lightButton = Color(lightHex: 0x2A211B, darkHex: 0xF5F1E9)
    static let lightButtonText = Color(lightHex: 0xF8F3EB, darkHex: 0x262320)
    static let stopButton = Color(lightHex: 0xF5DEDA, darkHex: 0xF2DEDB)
    static let stopButtonText = Color(lightHex: 0xA52B22, darkHex: 0xB03024)
}

struct LiveWageCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LiveWageTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(LiveWageTheme.stroke, lineWidth: 1)
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
