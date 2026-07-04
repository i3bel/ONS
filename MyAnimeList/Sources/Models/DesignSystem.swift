import SwiftUI

// MARK: - Design Tokens (supports system dark mode)

extension Color {

    // MARK: - Backgrounds

    /// Page background: #F2F2F7 light → #000000 dark
    static let pageBg = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        : UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
    })

    /// Card background: #FFFFFF light → #2C2C2E dark
    static let cardBg = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.173, green: 0.173, blue: 0.18, alpha: 1)
        : UIColor(red: 1, green: 1, blue: 1, alpha: 1)
    })

    /// Divider: #E5E5EA light → #38383A dark
    static let dividerColor = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.22, green: 0.22, blue: 0.23, alpha: 1)
        : UIColor(red: 0.9, green: 0.9, blue: 0.92, alpha: 1)
    })

    // MARK: - Text

    /// Primary body text: black light → white dark
    static let textPrimary = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        : UIColor(red: 0, green: 0, blue: 0, alpha: 1)
    })

    /// Secondary text: #8E8E93 light → #98989E dark
    static let textSecondary = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.6, green: 0.6, blue: 0.62, alpha: 1)
        : UIColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1)
    })

    /// Tertiary text: #C7C7CC light → #636366 dark
    static let textTertiary = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.39, green: 0.39, blue: 0.4, alpha: 1)
        : UIColor(red: 0.78, green: 0.78, blue: 0.8, alpha: 1)
    })

    // MARK: - Brand (keep same brightness for contrast on both backgrounds)

    static let brandBlue = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.04, green: 0.52, blue: 1, alpha: 1)      // #0A84FF
        : UIColor(red: 0, green: 0.478, blue: 1, alpha: 1)        // #007AFF
    })

    static let brandedLightBlue = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.1, green: 0.23, blue: 0.36, alpha: 1)    // darker blue bg
        : UIColor(red: 0.89, green: 0.95, blue: 1, alpha: 1)      // #E3F2FD
    })

    static let accentGreen = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.19, green: 0.82, blue: 0.35, alpha: 1)   // #30D158
        : UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1)    // #34C759
    })

    static let accentRed = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 1, green: 0.27, blue: 0.23, alpha: 1)      // #FF453A
        : UIColor(red: 1, green: 0.23, blue: 0.19, alpha: 1)      // #FF3B30
    })

    static let accentOrange = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 1, green: 0.62, blue: 0.04, alpha: 1)      // #FF9F0A
        : UIColor(red: 1, green: 0.42, blue: 0.21, alpha: 1)      // #FF6B35
    })

    // MARK: - Aliases & composites

    static let disabledBg = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.22, green: 0.22, blue: 0.23, alpha: 1)
        : UIColor(red: 0.9, green: 0.9, blue: 0.92, alpha: 1)
    })

    static let disabledText = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.39, green: 0.39, blue: 0.4, alpha: 1)
        : UIColor(red: 0.78, green: 0.78, blue: 0.8, alpha: 1)
    })

    // Backward compat aliases
    static let bgSecondary = Color.pageBg
    static let bgPrimary = Color.cardBg
    static let tagBg = Color.brandedLightBlue
    static let tagText = Color.brandBlue
    static let pillBg = Color.pageBg
    static let brandBlueLight = Color.brandedLightBlue
}

// MARK: - Fonts

extension Font {
    static let display = Font.system(size: 34, weight: .bold)
    static let title1 = Font.system(size: 28, weight: .bold)
    static let title2 = Font.system(size: 20, weight: .semibold)
    static let bodyText = Font.system(size: 17, weight: .regular)
    static let bodyEmphasis = Font.system(size: 17, weight: .semibold)
    static let calloutText = Font.system(size: 15, weight: .medium)
    static let captionText = Font.system(size: 12, weight: .medium)
}

// MARK: - PillButton Style

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
