import SwiftUI

// MARK: - Brutalist Button

/// A bold, high-contrast button following New Brutalist design principles.
/// Sharp corners, thick borders, hard shadows, no subtlety.
struct BrutalistButton: View {

    // MARK: - Properties

    let title: String
    let style: Style
    let isFullWidth: Bool
    let isEnabled: Bool
    let action: () -> Void

    // MARK: - Initialization

    init(
        _ title: String,
        style: Style = .primary,
        isFullWidth: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isFullWidth = isFullWidth
        self.isEnabled = isEnabled
        self.action = action
    }

    // MARK: - Body

    var body: some View {
        Button(action: {
            if isEnabled {
                action()
            }
        }) {
            Text(title.uppercased())
                .font(BrutalistTheme.Typography.button)
                .foregroundColor(textColor)
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .padding(.horizontal, BrutalistTheme.Spacing.lg)
                .padding(.vertical, BrutalistTheme.Spacing.md)
                .background(backgroundColor)
                .brutalistCard(
                    borderWidth: BrutalistTheme.Borders.standard,
                    borderColor: borderColor,
                    shadowOffset: isEnabled ? BrutalistTheme.Shadows.offset : 0,
                    shadowColor: shadowColor
                )
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1.0 : 0.6)
    }

    // MARK: - Colors

    private var textColor: Color {
        switch style {
        case .primary:
            return BrutalistTheme.Colors.text
        case .secondary:
            return BrutalistTheme.Colors.text
        case .destructive:
            return BrutalistTheme.Colors.background
        case .ghost:
            return BrutalistTheme.Colors.text
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return BrutalistTheme.Colors.action
        case .secondary:
            return BrutalistTheme.Colors.background
        case .destructive:
            return BrutalistTheme.Colors.warning
        case .ghost:
            return Color.clear
        }
    }

    private var borderColor: Color {
        guard isEnabled else { return BrutalistTheme.Colors.disabled }

        switch style {
        case .primary:
            return BrutalistTheme.Colors.text
        case .secondary:
            return BrutalistTheme.Colors.text
        case .destructive:
            return BrutalistTheme.Colors.text
        case .ghost:
            return BrutalistTheme.Colors.text.opacity(0.3)
        }
    }

    private var shadowColor: Color {
        guard isEnabled else { return Color.clear }

        switch style {
        case .ghost:
            return Color.clear
        default:
            return BrutalistTheme.Shadows.color
        }
    }
}

// MARK: - Button Style

extension BrutalistButton {
    /// Button style variants
    enum Style {
        /// Primary action button - aquamarine background
        case primary

        /// Secondary button - white background with border
        case secondary

        /// Destructive action - orange/red background
        case destructive

        /// Ghost button - transparent with subtle border
        case ghost
    }
}

// MARK: - Convenience Initializers

extension BrutalistButton {
    /// Create a primary action button
    static func primary(
        _ title: String,
        isFullWidth: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> BrutalistButton {
        BrutalistButton(
            title,
            style: .primary,
            isFullWidth: isFullWidth,
            isEnabled: isEnabled,
            action: action
        )
    }

    /// Create a secondary button
    static func secondary(
        _ title: String,
        isFullWidth: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> BrutalistButton {
        BrutalistButton(
            title,
            style: .secondary,
            isFullWidth: isFullWidth,
            isEnabled: isEnabled,
            action: action
        )
    }

    /// Create a destructive action button
    static func destructive(
        _ title: String,
        isFullWidth: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> BrutalistButton {
        BrutalistButton(
            title,
            style: .destructive,
            isFullWidth: isFullWidth,
            isEnabled: isEnabled,
            action: action
        )
    }

    /// Create a ghost button
    static func ghost(
        _ title: String,
        isFullWidth: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> BrutalistButton {
        BrutalistButton(
            title,
            style: .ghost,
            isFullWidth: isFullWidth,
            isEnabled: isEnabled,
            action: action
        )
    }
}

// MARK: - Icon Button

/// A button with an icon, following Brutalist design
struct BrutalistIconButton: View {
    let systemName: String
    let size: CGFloat
    let color: Color
    let action: () -> Void

    init(
        systemName: String,
        size: CGFloat = 24,
        color: Color = BrutalistTheme.Colors.text,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.size = size
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .bold))
                .foregroundColor(color)
                .frame(width: size + 20, height: size + 20)
                .background(BrutalistTheme.Colors.background)
                .brutalistBorder()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Button Styles") {
    VStack(spacing: 20) {
        Text("BUTTON STYLES")
            .font(BrutalistTheme.Typography.headerMedium)

        BrutalistButton.primary("Primary Action") {
            print("Primary tapped")
        }

        BrutalistButton.secondary("Secondary Action") {
            print("Secondary tapped")
        }

        BrutalistButton.destructive("Delete Item") {
            print("Delete tapped")
        }

        BrutalistButton.ghost("Ghost Button") {
            print("Ghost tapped")
        }

        Divider()

        Text("FULL WIDTH")
            .font(BrutalistTheme.Typography.caption)

        BrutalistButton.primary("Full Width Button", isFullWidth: true) {
            print("Full width tapped")
        }

        BrutalistButton.primary("Disabled Button", isFullWidth: true, isEnabled: false) {
            print("This won't print")
        }
    }
    .padding()
    .background(BrutalistTheme.Colors.background)
}

#Preview("Icon Buttons") {
    HStack(spacing: 20) {
        BrutalistIconButton(systemName: "plus") {}
        BrutalistIconButton(systemName: "trash", color: BrutalistTheme.Colors.warning) {}
        BrutalistIconButton(systemName: "pencil") {}
    }
    .padding()
    .background(BrutalistTheme.Colors.background)
}
