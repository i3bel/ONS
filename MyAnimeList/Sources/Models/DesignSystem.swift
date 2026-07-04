import SwiftUI

// MARK: - Design Tokens (per spec + fix.md)

extension Color {
    // iOS system colors for exact match
    static let brandBlue = Color(red: 0, green: 0.478, blue: 1)      // #007AFF
    static let brandBlueLight = Color(red: 0.89, green: 0.95, blue: 1) // #E3F2FD
    static let accentGreen = Color(red: 0.2, green: 0.78, blue: 0.35)  // #34C759
    static let accentRed = Color(red: 1, green: 0.23, blue: 0.19)     // #FF3B30
    static let accentOrange = Color(red: 1, green: 0.42, blue: 0.21)   // #FF6B35
    static let pageBg = Color(red: 0.95, green: 0.95, blue: 0.97)     // #F2F2F7
    static let cardBg = Color.white                                     // #FFFFFF
    static let dividerColor = Color(red: 0.9, green: 0.9, blue: 0.92)  // #E5E5EA
    static let textSecondary = Color(red: 0.56, green: 0.56, blue: 0.58) // #8E8E93
    static let textTertiary = Color(red: 0.78, green: 0.78, blue: 0.8)  // #C7C7CC
    static let tagBg = Color.brandBlueLight                               // #E3F2FD
    static let tagText = Color.brandBlue                                  // #007AFF
    static let pillBg = Color(red: 0.95, green: 0.95, blue: 0.97)      // #F2F2F7
    static let disabledBg = Color(red: 0.9, green: 0.9, blue: 0.92)     // #E5E5EA
    static let disabledText = Color(red: 0.78, green: 0.78, blue: 0.8)  // #C7C7CC

    // Aliases for backward compatibility
    static let bgSecondary = Color.pageBg
    static let bgPrimary = Color.cardBg
}

extension Font {
    static let display = Font.system(size: 34, weight: .bold)
    static let title1 = Font.system(size: 28, weight: .bold)
    static let title2 = Font.system(size: 20, weight: .semibold)
    static let bodyText = Font.system(size: 17, weight: .regular)
    static let bodyEmphasis = Font.system(size: 17, weight: .semibold)
    static let calloutText = Font.system(size: 15, weight: .medium)
    static let captionText = Font.system(size: 12, weight: .medium)
}

struct PillButton: ButtonStyle {
    var color: Color = .brandBlue
    var textColor: Color = .white
    var height: CGFloat = 48
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bodyText.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(isDisabled ? Color.disabledBg : color)
            .foregroundColor(isDisabled ? Color.disabledText : textColor)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
