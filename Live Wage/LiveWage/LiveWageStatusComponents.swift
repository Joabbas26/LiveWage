//
//  LiveWageStatusComponents.swift
//  LiveWage
//
//  Created by Codex on 5/5/26.
//

import SwiftUI

enum LiveWageNoticeTone: Equatable {
    case info
    case warning
}

struct LiveWageEstimateNotice: Equatable {
    let title: String
    let message: String
    let tone: LiveWageNoticeTone
}

struct LiveWageNoticeBanner: View {
    let notice: LiveWageEstimateNotice

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: notice.tone == .warning ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(notice.tone == .warning ? LiveWageTheme.amber : LiveWageTheme.blue)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(notice.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(LiveWageTheme.primaryText)

                Text(notice.message)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(LiveWageTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LiveWageTheme.elevatedSurface.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(notice.tone == .warning ? LiveWageTheme.amber.opacity(0.5) : LiveWageTheme.blue.opacity(0.45), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(notice.title). \(notice.message)")
    }
}
