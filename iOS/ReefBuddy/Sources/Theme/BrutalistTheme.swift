import SwiftUI

// MARK: - Brutalist Theme

/// The New Brutalist design system for ReefBuddy.
/// High contrast, sharp edges, bold typography, no compromises.
enum BrutalistTheme {

    // MARK: - Colors

    /// Color palette following New Brutalist principles
    enum Colors {
        /// Pure white background - #FFFFFF
        static let background = Color.white

        /// Pure black for text and accents - #000000
        static let text = Color.black

        /// Electric Aquamarine for actions - #00FFD1
        static let action = Color(red: 0, green: 1, blue: 0.82)

        /// Safety Orange for warnings - #FF3D00
        static let warning = Color(red: 1, green: 0.24, blue: 0)

        /// Secondary gray for disabled states
        static let disabled = Color.gray.opacity(0.4)

        /// Card background with subtle tint
        static let cardBackground = Color.white
    }

    // MARK: - Typography

    /// Bold, grotesque typography system
    enum Typography {
        /// Extra large header - 32pt bold
        static let headerLarge = Font.system(size: 32, weight: .black)

        /// Medium header - 24pt bold
        static let headerMedium = Font.system(size: 24, weight: .bold)

        /// Small header - 18pt bold
        static let headerSmall = Font.system(size: 18, weight: .bold)

        /// Body text - 16pt regular
        static let body = Font.system(size: 16, weight: .regular)

        /// Body bold - 16pt bold
        static let bodyBold = Font.system(size: 16, weight: .bold)

        /// Caption text - 12pt medium
        static let caption = Font.system(size: 12, weight: .medium)

        /// Button text - 14pt bold
        static let button = Font.system(size: 14, weight: .bold)
    }

    // MARK: - Spacing

    /// Spacing values for consistent layout
    enum Spacing {
        /// Extra small spacing - 4pt
        static let xs: CGFloat = 4

        /// Small spacing - 8pt
        static let sm: CGFloat = 8

        /// Medium spacing - 16pt
        static let md: CGFloat = 16

        /// Large spacing - 24pt
        static let lg: CGFloat = 24

        /// Extra large spacing - 32pt
        static let xl: CGFloat = 32

        /// XXL spacing - 48pt
        static let xxl: CGFloat = 48
    }

    // MARK: - Borders

    /// Border specifications for Brutalist style
    enum Borders {
        /// Standard border width - 3pt
        static let standard: CGFloat = 3

        /// Heavy border width - 4pt
        static let heavy: CGFloat = 4

        /// Light border width - 2pt
        static let light: CGFloat = 2
    }

    // MARK: - Shadows

    /// Hard offset shadows (no blur, no gradients)
    enum Shadows {
        /// Standard shadow offset - 5pt
        static let offset: CGFloat = 5

        /// Shadow color - pure black
        static let color = Color.black
    }

    // MARK: - Corner Radius

    /// Corner radius values (New Brutalism = sharp corners)
    enum CornerRadius {
        /// None - 0px (default Brutalist style)
        static let none: CGFloat = 0

        /// Minimal for special cases - 2px
        static let minimal: CGFloat = 2
    }
}

// MARK: - View Modifiers

/// Custom border modifier for Brutalist styling
struct BrutalistBorderModifier: ViewModifier {
    let width: CGFloat
    let color: Color

    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .strokeBorder(color, lineWidth: width)
            )
    }
}

/// Hard shadow modifier (no blur)
struct BrutalistShadowModifier: ViewModifier {
    let color: Color
    let offset: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                color
                    .offset(x: offset, y: offset)
            )
    }
}

/// Card styling with border and hard shadow
struct BrutalistCardModifier: ViewModifier {
    let borderWidth: CGFloat
    let borderColor: Color
    let shadowOffset: CGFloat
    let shadowColor: Color

    func body(content: Content) -> some View {
        content
            .background(BrutalistTheme.Colors.cardBackground)
            .overlay(
                Rectangle()
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .background(
                shadowColor
                    .offset(x: shadowOffset, y: shadowOffset)
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Apply Brutalist border styling
    func brutalistBorder(
        width: CGFloat = BrutalistTheme.Borders.standard,
        color: Color = BrutalistTheme.Colors.text
    ) -> some View {
        modifier(BrutalistBorderModifier(width: width, color: color))
    }

    /// Apply Brutalist hard shadow
    func brutalistShadow(
        color: Color = BrutalistTheme.Shadows.color,
        offset: CGFloat = BrutalistTheme.Shadows.offset
    ) -> some View {
        modifier(BrutalistShadowModifier(color: color, offset: offset))
    }

    /// Apply Brutalist card styling (border + shadow)
    func brutalistCard(
        borderWidth: CGFloat = BrutalistTheme.Borders.standard,
        borderColor: Color = BrutalistTheme.Colors.text,
        shadowOffset: CGFloat = BrutalistTheme.Shadows.offset,
        shadowColor: Color = BrutalistTheme.Shadows.color
    ) -> some View {
        modifier(BrutalistCardModifier(
            borderWidth: borderWidth,
            borderColor: borderColor,
            shadowOffset: shadowOffset,
            shadowColor: shadowColor
        ))
    }
}

// MARK: - Preview

#Preview("Theme Colors") {
    VStack(spacing: 20) {
        Text("REEFBUDDY THEME")
            .font(BrutalistTheme.Typography.headerLarge)
            .foregroundColor(BrutalistTheme.Colors.text)

        HStack(spacing: 20) {
            colorSwatch("Background", color: BrutalistTheme.Colors.background)
            colorSwatch("Text", color: BrutalistTheme.Colors.text)
            colorSwatch("Action", color: BrutalistTheme.Colors.action)
            colorSwatch("Warning", color: BrutalistTheme.Colors.warning)
        }

        VStack(spacing: 10) {
            Text("Card with Shadow")
                .font(BrutalistTheme.Typography.bodyBold)
                .padding()
                .brutalistCard()

            Text("Border Only")
                .font(BrutalistTheme.Typography.body)
                .padding()
                .brutalistBorder()
        }
        .padding()
    }
    .padding()
    .background(BrutalistTheme.Colors.background)
}

@ViewBuilder
private func colorSwatch(_ name: String, color: Color) -> some View {
    VStack {
        Rectangle()
            .fill(color)
            .frame(width: 60, height: 60)
            .brutalistBorder()

        Text(name.uppercased())
            .font(.system(size: 8, weight: .bold))
    }
}
