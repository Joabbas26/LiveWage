//
//  ClockedStatusComponents.swift
//  Clocked
//
//  Created by Codex on 5/5/26.
//

import SwiftUI

enum ClockedNoticeTone: Equatable {
    case info
    case warning
}

struct ClockedEstimateNotice: Equatable {
    let title: String
    let message: String
    let tone: ClockedNoticeTone
}

struct ClockedNoticeBanner: View {
    let notice: ClockedEstimateNotice

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: notice.tone == .warning ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(notice.tone == .warning ? ClockedTheme.amber : ClockedTheme.blue)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(notice.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(ClockedTheme.primaryText)

                Text(notice.message)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(ClockedTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(ClockedTheme.elevatedSurface.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(notice.tone == .warning ? ClockedTheme.amber.opacity(0.5) : ClockedTheme.blue.opacity(0.45), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(notice.title). \(notice.message)")
    }
}
