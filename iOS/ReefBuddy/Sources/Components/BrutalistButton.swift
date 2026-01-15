import SwiftUI

// MARK: - Brutalist Button Styles

/// The visual style variants for BrutalistButton
enum BrutalistButtonStyle {
    /// Primary action button - Electric Aquamarine background
    case primary

    /// Secondary button - White background with black border
    case secondary

    /// Warning/destructive action - Safety Orange background
    case warning

    /// Ghost button - Transparent with border only
    case ghost
}

// MARK: - Brutalist Button

/// A reusable button component following ReefBuddy's New Brutalist design manifesto.
/// Features: Sharp corners (0px radius), bold borders (3pt/4pt), hard offset shadows (5pt 5pt).
struct BrutalistButton: View {

    // MARK: - Properties

    let title: String
    let style: BrutalistButtonStyle
    let isFullWidth: Bool
    let isEnabled: Bool
    let action: () -> Void

    // MARK: - Computed Properties

    private var backgroundColor: Color {
        guard isEnabled else { return BrutalistTheme.Colors.disabled }

        switch style {
        case .primary:
            return BrutalistTheme.Colors.action
        case .secondary:
            return BrutalistTheme.Colors.background
        case .warning:
            return BrutalistTheme.Colors.warning
        case .ghost:
            return .clear
        }
    }

    private var foregroundColor: Color {
        guard isEnabled else { return BrutalistTheme.Colors.text.opacity(0.5) }

        switch style {
        case .primary, .warning:
            return BrutalistTheme.Colors.text
        case .secondary, .ghost:
            return BrutalistTheme.Colors.text
        }
    }

    private var borderWidth: CGFloat {
        switch style {
        case .primary, .warning:
            return BrutalistTheme.Borders.heavy
        case .secondary, .ghost:
            return BrutalistTheme.Borders.standard
        }
    }

    private var showShadow: Bool {
        isEnabled && style != .ghost
    }

    // MARK: - Initialization

    /// Creates a new BrutalistButton
    /// - Parameters:
    ///   - title: The button's label text
    ///   - style: Visual style variant (default: .primary)
    ///   - isFullWidth: Whether button should expand to full width (default: false)
    ///   - isEnabled: Whether button is interactive (default: true)
    ///   - action: Closure to execute on tap
    init(
        _ title: String,
        style: BrutalistButtonStyle = .primary,
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
            buttonContent
        }
        .buttonStyle(BrutalistButtonPressStyle(isEnabled: isEnabled, showShadow: showShadow))
        .disabled(!isEnabled)
    }

    private var buttonContent: some View {
        Text(title.uppercased())
            .font(BrutalistTheme.Typography.button)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, BrutalistTheme.Spacing.lg)
            .padding(.vertical, BrutalistTheme.Spacing.md)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background(backgroundColor)
            .overlay(
                Rectangle()
                    .stroke(BrutalistTheme.Colors.text, lineWidth: borderWidth)
            )
            .background(
                showShadow ?
                Rectangle()
                    .fill(BrutalistTheme.Colors.shadow)
                    .offset(
                        x: BrutalistTheme.Shadows.offsetX,
                        y: BrutalistTheme.Shadows.offsetY
                    )
                : nil
            )
    }
}

// MARK: - Press Animation Style

/// Custom button style that provides tactile press feedback
/// by reducing shadow offset and moving the button on press.
struct BrutalistButtonPressStyle: ButtonStyle {
    let isEnabled: Bool
    let showShadow: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(
                x: configuration.isPressed && showShadow ? BrutalistTheme.Shadows.offsetX / 2 : 0,
                y: configuration.isPressed && showShadow ? BrutalistTheme.Shadows.offsetY / 2 : 0
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Convenience Initializers

extension BrutalistButton {
    /// Creates a primary action button
    static func primary(
        _ title: String,
        isFullWidth: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> BrutalistButton {
        BrutalistButton(title, style: .primary, isFullWidth: isFullWidth, isEnabled: isEnabled, action: action)
    }

    /// Creates a secondary button
    static func secondary(
        _ title: String,
        isFullWidth: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> BrutalistButton {
        BrutalistButton(title, style: .secondary, isFullWidth: isFullWidth, isEnabled: isEnabled, action: action)
    }

    /// Creates a warning/destructive action button
    static func warning(
        _ title: String,
        isFullWidth: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> BrutalistButton {
        BrutalistButton(title, style: .warning, isFullWidth: isFullWidth, isEnabled: isEnabled, action: action)
    }

    /// Creates a ghost button (transparent background)
    static func ghost(
        _ title: String,
        isFullWidth: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> BrutalistButton {
        BrutalistButton(title, style: .ghost, isFullWidth: isFullWidth, isEnabled: isEnabled, action: action)
    }
}

// MARK: - Icon Button Variant

/// A brutalist button with an SF Symbol icon
struct BrutalistIconButton: View {
    let systemName: String
    let style: BrutalistButtonStyle
    let size: CGFloat
    let isEnabled: Bool
    let action: () -> Void

    private var backgroundColor: Color {
        guard isEnabled else { return BrutalistTheme.Colors.disabled }

        switch style {
        case .primary:
            return BrutalistTheme.Colors.action
        case .secondary:
            return BrutalistTheme.Colors.background
        case .warning:
            return BrutalistTheme.Colors.warning
        case .ghost:
            return .clear
        }
    }

    init(
        systemName: String,
        style: BrutalistButtonStyle = .primary,
        size: CGFloat = 44,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.style = style
        self.size = size
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: {
            if isEnabled {
                action()
            }
        }) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(isEnabled ? BrutalistTheme.Colors.text : BrutalistTheme.Colors.text.opacity(0.5))
                .frame(width: size, height: size)
                .background(backgroundColor)
                .brutalistCard(
                    borderWidth: BrutalistTheme.Borders.standard,
                    borderColor: BrutalistTheme.Colors.text
                )
        }
        .buttonStyle(BrutalistButtonPressStyle(isEnabled: isEnabled, showShadow: style != .ghost))
        .disabled(!isEnabled)
    }
}

// MARK: - Preview

#Preview("Brutalist Buttons") {
    ScrollView {
        VStack(spacing: BrutalistTheme.Spacing.lg) {
            Text("BUTTON STYLES")
                .font(BrutalistTheme.Typography.headerMedium)

            VStack(spacing: BrutalistTheme.Spacing.md) {
                BrutalistButton.primary("Primary Action") {
                    print("Primary tapped")
                }

                BrutalistButton.secondary("Secondary Action") {
                    print("Secondary tapped")
                }

                BrutalistButton.warning("Delete Tank") {
                    print("Warning tapped")
                }

                BrutalistButton.ghost("Cancel") {
                    print("Ghost tapped")
                }
            }

            Divider()
                .padding(.vertical, BrutalistTheme.Spacing.md)

            Text("FULL WIDTH")
                .font(BrutalistTheme.Typography.headerSmall)

            BrutalistButton.primary("Save Parameters", isFullWidth: true) {
                print("Full width tapped")
            }

            Divider()
                .padding(.vertical, BrutalistTheme.Spacing.md)

            Text("DISABLED STATE")
                .font(BrutalistTheme.Typography.headerSmall)

            BrutalistButton.primary("Disabled", isEnabled: false) {
                print("Should not print")
            }

            Divider()
                .padding(.vertical, BrutalistTheme.Spacing.md)

            Text("ICON BUTTONS")
                .font(BrutalistTheme.Typography.headerSmall)

            HStack(spacing: BrutalistTheme.Spacing.md) {
                BrutalistIconButton(systemName: "plus", style: .primary) {
                    print("Add tapped")
                }

                BrutalistIconButton(systemName: "pencil", style: .secondary) {
                    print("Edit tapped")
                }

                BrutalistIconButton(systemName: "trash", style: .warning) {
                    print("Delete tapped")
                }

                BrutalistIconButton(systemName: "xmark", style: .ghost) {
                    print("Close tapped")
                }
            }
        }
        .padding(BrutalistTheme.Spacing.lg)
    }
    .background(BrutalistTheme.Colors.background)
}
