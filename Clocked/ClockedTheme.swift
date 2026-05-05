//
//  ClockedTheme.swift
//  Clocked
//
//  Created by Codex on 5/4/26.
//

import SwiftUI

enum ClockedTheme {
    static let appBackground = LinearGradient(
        colors: [
            Color(hex: 0x141312),
            Color(hex: 0x1A1816),
            Color(hex: 0x201D1A)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let surface = Color(hex: 0x23211E)
    static let elevatedSurface = Color(hex: 0x2B2825)
    static let inputSurface = Color(hex: 0x1C1A18)
    static let navSurface = Color(hex: 0x26231F)
    static let pillTrack = Color(hex: 0x24211E)
    static let pillSelection = Color(hex: 0x312D29)
    static let stroke = Color(hex: 0x403B35)
    static let navDivider = Color(hex: 0x4A443D)
    static let frameStroke = Color(hex: 0x564F48)
    static let primaryText = Color(hex: 0xF8F4ED)
    static let secondaryText = Color(hex: 0xD6CEC3)
    static let mutedText = Color(hex: 0xB8B0A4)
    static let subtleText = Color(hex: 0x8F877C)
    static let green = Color(hex: 0x6AA51A)
    static let amber = Color(hex: 0xD7A43C)
    static let blue = Color(hex: 0x6FA8FF)
    static let progressTrack = Color(hex: 0x131210)
    static let lightButton = Color(hex: 0xF5F1E9)
    static let lightButtonText = Color(hex: 0x262320)
    static let stopButton = Color(hex: 0xF2DEDB)
    static let stopButtonText = Color(hex: 0xB03024)
}

struct ClockedCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(ClockedTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(ClockedTheme.stroke, lineWidth: 1)
            )
    }
}

extension View {
    func clockedCard() -> some View {
        modifier(ClockedCardModifier())
    }
}

extension Color {
    init(hex: UInt64) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
