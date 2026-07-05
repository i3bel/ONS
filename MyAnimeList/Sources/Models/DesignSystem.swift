import SwiftUI

// MARK: - Design Tokens (iOS 26 Native Style)

/// Standard spacing constants following Apple HIG.
enum Spacing {
    static let xsmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let standard: CGFloat = 16
    static let large: CGFloat = 20
    static let xlarge: CGFloat = 24
}

/// Standard corner radii following iOS system conventions.
enum CornerRadius {
    /// 10 — standard card / list row
    static let standard: CGFloat = 10
    /// 13 — sheet, popover
    static let sheet: CGFloat = 13
    /// Capsule — pills, badges, primary buttons
    static let pill: CGFloat = 999
}

// MARK: - Color Extensions (thin wrappers around system colors)

extension Color {
    /// Page / grouped background.
    static let pageBg = Color(.systemGroupedBackground)
    /// Card / secondary grouped background.
    static let cardBg = Color(.secondarySystemGroupedBackground)
    /// Tertiary background for thin emphasis.
    static let tertiaryBg = Color(.tertiarySystemGroupedBackground)

    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary = Color(.tertiaryLabel)

    static let dividerColor = Color(.separator)

    static let brandBlue = Color.accentColor
    static let brandedLightBlue = Color(.systemFill)

    static let accentGreen = Color(.systemGreen)
    static let accentRed = Color(.systemRed)
    static let accentOrange = Color(.systemOrange)

    static let disabledBg = Color(.systemFill)
    static let disabledText = Color(.tertiaryLabel)
}

// MARK: - Standard Button Styles

/// Primary action button — filled capsule, matches Apple's `.borderedProminent` + `.capsule`.
struct PrimaryButton: ButtonStyle {
    var color: Color = .accentColor
    var height: CGFloat = 50

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(color, in: Capsule())
            .foregroundStyle(.white)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Plain bordered button — matches Apple's `.bordered` + `.capsule`.
struct BorderedButton: ButtonStyle {
    var color: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .padding(.horizontal, Spacing.standard)
            .padding(.vertical, Spacing.small)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Section Header

/// Standard section header matching Apple's native section header style.
struct SectionHeader: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.title2.weight(.bold))
            .foregroundColor(.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.standard)
    }
}

// MARK: - Card Style

/// Container card matching iOS card appearance.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Spacing.standard)
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: CornerRadius.standard))
    }
}

// MARK: - Info Pill

/// Small pill label used for tags, servings, time info.
struct InfoPill: View {
    var text: String
    var color: Color = .textSecondary
    var bg: Color = Color(.tertiarySystemGroupedBackground)

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(bg, in: Capsule())
    }
}

// MARK: - Font Backward Compatibility (removed in refactor, aliases to system fonts)

extension Font {
    static let display = Font.system(size: 34, weight: .bold)
    static let title1 = Font.system(size: 28, weight: .bold)
    static let title2 = Font.system(size: 20, weight: .semibold)
    static let bodyText = Font.body
    static let bodyEmphasis = Font.body.weight(.semibold)
    static let calloutText = Font.callout
    static let captionText = Font.caption
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        SectionHeader(title: "Section Header")
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Card Content").font(.body)
                Text("Body text with secondary color").font(.callout).foregroundColor(.textSecondary)
            }
        }
        .padding(.horizontal)

        HStack(spacing: 8) {
            InfoPill(text: "4 servings")
            InfoPill(text: "30 min", color: .accentOrange)
            InfoPill(text: "#tag", color: .brandBlue)
        }

        Button("Primary") {}
            .buttonStyle(PrimaryButton())
            .padding(.horizontal)

        Button("Bordered") {}
            .buttonStyle(BorderedButton())
    }
    .padding()
    .background(Color.pageBg)
}
