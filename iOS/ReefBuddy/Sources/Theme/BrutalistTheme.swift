import SwiftUI

// MARK: - ReefBuddy New Brutalist Design System
// Strict adherence to sharp corners, bold borders, and hard offset shadows.

/// The central design token container for ReefBuddy's New Brutalist aesthetic.
struct BrutalistTheme {

    // MARK: - Color Palette

    struct Colors {
        /// Background: Pure White (#FFFFFF)
        static let background = Color(hex: "FFFFFF")

        /// Text/Accents: Pure Black (#000000)
        static let text = Color(hex: "000000")

        /// Action: Electric Aquamarine (#00FFD1)
        static let action = Color(hex: "00FFD1")

        /// Warning/Alert: Safety Orange (#FF3D00)
        static let warning = Color(hex: "FF3D00")

        /// Shadow color: Pure Black for hard shadows
        static let shadow = Color(hex: "000000")

        /// Disabled state: Gray
        static let disabled = Color(hex: "CCCCCC")
    }

    // MARK: - Border Widths

    struct Borders {
        /// Standard border width: 3pt
        static let standard: CGFloat = 3

        /// Heavy border width: 4pt
        static let heavy: CGFloat = 4
    }

    // MARK: - Corner Radius

    struct Radius {
        /// Sharp corners only: 0px
        static let none: CGFloat = 0
    }

    // MARK: - Shadows (Hard Offset)

    struct Shadows {
        /// Hard shadow X offset: 5pt
        static let offsetX: CGFloat = 5

        /// Hard shadow Y offset: 5pt
        static let offsetY: CGFloat = 5

        /// Shadow blur radius: 0 (no blur, hard edge)
        static let blur: CGFloat = 0
    }

    // MARK: - Spacing

    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Typography

    struct Typography {
        /// Bold, oversized headers (Grotesque sans-serif)
        static let headerLarge = Font.system(size: 32, weight: .black, design: .default)
        static let headerMedium = Font.system(size: 24, weight: .bold, design: .default)
        static let headerSmall = Font.system(size: 18, weight: .bold, design: .default)

        /// Body text
        static let body = Font.system(size: 16, weight: .regular, design: .default)
        static let bodyBold = Font.system(size: 16, weight: .bold, design: .default)

        /// Caption/small text
        static let caption = Font.system(size: 12, weight: .medium, design: .default)

        /// Button text
        static let button = Font.system(size: 16, weight: .bold, design: .default)
    }
}

// MARK: - Color Extension for Hex Support

extension Color {
    /// Initialize a Color from a hex string (without #)
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b, a: UInt64
        switch hex.count {
        case 6: // RGB (no alpha)
            (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, 255)
        case 8: // RGBA
            (r, g, b, a) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

/// Applies the standard brutalist border style
struct BrutalistBorderModifier: ViewModifier {
    var width: CGFloat = BrutalistTheme.Borders.standard
    var color: Color = BrutalistTheme.Colors.text

    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .stroke(color, lineWidth: width)
            )
    }
}

/// Applies the hard offset shadow (no blur)
struct BrutalistShadowModifier: ViewModifier {
    var color: Color = BrutalistTheme.Colors.shadow
    var offsetX: CGFloat = BrutalistTheme.Shadows.offsetX
    var offsetY: CGFloat = BrutalistTheme.Shadows.offsetY

    func body(content: Content) -> some View {
        content
            .background(
                Rectangle()
                    .fill(color)
                    .offset(x: offsetX, y: offsetY)
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Apply standard brutalist border
    func brutalistBorder(
        width: CGFloat = BrutalistTheme.Borders.standard,
        color: Color = BrutalistTheme.Colors.text
    ) -> some View {
        modifier(BrutalistBorderModifier(width: width, color: color))
    }

    /// Apply hard offset shadow (no blur)
    func brutalistShadow(
        color: Color = BrutalistTheme.Colors.shadow,
        offsetX: CGFloat = BrutalistTheme.Shadows.offsetX,
        offsetY: CGFloat = BrutalistTheme.Shadows.offsetY
    ) -> some View {
        modifier(BrutalistShadowModifier(color: color, offsetX: offsetX, offsetY: offsetY))
    }

    /// Combine border and shadow for the full brutalist card effect
    func brutalistCard(
        borderWidth: CGFloat = BrutalistTheme.Borders.standard,
        borderColor: Color = BrutalistTheme.Colors.text,
        shadowColor: Color = BrutalistTheme.Colors.shadow
    ) -> some View {
        self
            .brutalistShadow(color: shadowColor)
            .brutalistBorder(width: borderWidth, color: borderColor)
    }
}

// MARK: - Preview

#Preview("Brutalist Theme Colors") {
    VStack(spacing: BrutalistTheme.Spacing.md) {
        Text("ReefBuddy")
            .font(BrutalistTheme.Typography.headerLarge)
            .foregroundColor(BrutalistTheme.Colors.text)

        HStack(spacing: BrutalistTheme.Spacing.md) {
            colorSwatch(color: BrutalistTheme.Colors.background, label: "Background")
            colorSwatch(color: BrutalistTheme.Colors.text, label: "Text")
            colorSwatch(color: BrutalistTheme.Colors.action, label: "Action")
            colorSwatch(color: BrutalistTheme.Colors.warning, label: "Warning")
        }
    }
    .padding(BrutalistTheme.Spacing.lg)
    .background(BrutalistTheme.Colors.background)
}

private func colorSwatch(color: Color, label: String) -> some View {
    VStack(spacing: BrutalistTheme.Spacing.xs) {
        Rectangle()
            .fill(color)
            .frame(width: 60, height: 60)
            .brutalistCard()

        Text(label)
            .font(BrutalistTheme.Typography.caption)
            .foregroundColor(BrutalistTheme.Colors.text)
    }
}
