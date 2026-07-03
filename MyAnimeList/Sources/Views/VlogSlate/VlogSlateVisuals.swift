//
//  VlogSlateVisuals.swift
//  VlogSlate
//
//  Created by OpenAI Codex on behalf of hole on 2026/6/20.
//

import SwiftUI
import UIKit
import PhotosUI
import Foundation

struct VlogSlatePosterBlock: View {
    var scene: Int
    var take: Int
    var style: Style = .row

    enum Style {
        case row
        case hero

        var cornerRadius: CGFloat {
            switch self {
            case .row: 14
            case .hero: 28
            }
        }

        var labelFont: Font {
            switch self {
            case .row: .title2.weight(.black)
            case .hero: .system(size: 56, weight: .black, design: .rounded)
            }
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Default gradient background
            LinearGradient(
                colors: [
                    .black.opacity(0.96),
                    .blue.opacity(0.34),
                    .black.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // If a thumbnail image is provided via environment, it'll be drawn by overlaying Image
            VStack(alignment: .leading, spacing: style == .row ? 4 : 8) {
                Text("S\(scene) T\(take)")
                    .font(style.labelFont)
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.45)
                    .lineLimit(1)
                    .monospacedDigit()

                Text("SCENE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.62))
            }
            .padding(style == .row ? 12 : 24)
        }
        .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(style == .row ? 0.22 : 0.16), radius: style == .row ? 10 : 18, y: style == .row ? 6 : 10)
    }
}

struct VlogSlateStatusBadge: View {
    var status: FootageItem.Status

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.tintColor)
                .frame(width: 5, height: 5)
            Text(status.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(status.tintColor.opacity(0.92))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule(style: .continuous)
                .fill(status.tintColor.opacity(0.09))
        }
    }
}

struct VlogSlateNavigationTitleCapsule: View {
    var count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("\(count)")
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(count)))
            Text("镜头")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.identity)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .frame(minWidth: 90)
        .animation(.bouncy, value: count)
    }
}

struct VlogSlateFilterSummaryCapsule: View {
    var title: String
    var count: Int
    var systemImage: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .padding(.trailing, 8)
            .animation(.bouncy, value: count)
    }
}

struct VlogSlateStatCard: View {
    var title: String
    var value: String
    var systemImage: String
    var tint: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

struct VlogSlateCircleActionButton: View {
    var systemImage: String
    var tint: Color = .primary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 20, height: 20)
                .padding(10)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .tint(tint)
    }
}

extension FootageItem.Status {
    var title: String {
        switch self {
        case .good: "完美"
        case .backup: "备用"
        case .bad: "废镜"
        }
    }

    var tintColor: Color {
        switch self {
        case .good: .green
        case .backup: .yellow
        case .bad: .red
        }
    }
}
