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
                .foregroundStyle(notice.tone == .warning ? LiveWageTheme.amberText : LiveWageTheme.blue)
                .padding(.top, 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(notice.title)
                    .font(.liveWage(.subheadline, weight: .bold))
                    .foregroundStyle(LiveWageTheme.primaryText)

                Text(notice.message)
                    .font(.liveWage(.footnote, weight: .medium))
                    .foregroundStyle(LiveWageTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(notice.tone == .warning ? LiveWageTheme.amberSoft : LiveWageTheme.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(notice.tone == .warning ? LiveWageTheme.amber.opacity(0.5) : LiveWageTheme.blue.opacity(0.45), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(notice.title). \(notice.message)")
    }
}
