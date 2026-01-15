import SwiftUI

// MARK: - Brutalist Text Field Styles

/// The visual style variants for BrutalistTextField
enum BrutalistTextFieldStyle {
    /// Standard input field - White background
    case standard

    /// Highlighted/focused state - Electric Aquamarine accent
    case highlighted

    /// Error state - Safety Orange border
    case error
}

// MARK: - Brutalist Text Field

/// A reusable text field component following ReefBuddy's New Brutalist design manifesto.
/// Features: Sharp corners (0px radius), bold borders (3pt), hard offset shadows (5pt 5pt).
struct BrutalistTextField: View {

    // MARK: - Properties

    let placeholder: String
    @Binding var text: String
    let label: String?
    let helperText: String?
    let errorMessage: String?
    let keyboardType: UIKeyboardType
    let isSecure: Bool
    let isEnabled: Bool

    @FocusState private var isFocused: Bool

    // MARK: - Computed Properties

    private var currentStyle: BrutalistTextFieldStyle {
        if errorMessage != nil {
            return .error
        } else if isFocused {
            return .highlighted
        }
        return .standard
    }

    private var borderColor: Color {
        switch currentStyle {
        case .standard:
            return BrutalistTheme.Colors.text
        case .highlighted:
            return BrutalistTheme.Colors.action
        case .error:
            return BrutalistTheme.Colors.warning
        }
    }

    private var shadowColor: Color {
        switch currentStyle {
        case .standard:
            return BrutalistTheme.Colors.shadow
        case .highlighted:
            return BrutalistTheme.Colors.action
        case .error:
            return BrutalistTheme.Colors.warning
        }
    }

    private var displayHelperText: String? {
        errorMessage ?? helperText
    }

    private var helperTextColor: Color {
        errorMessage != nil ? BrutalistTheme.Colors.warning : BrutalistTheme.Colors.text.opacity(0.6)
    }

    // MARK: - Initialization

    /// Creates a new BrutalistTextField
    /// - Parameters:
    ///   - placeholder: Placeholder text shown when empty
    ///   - text: Binding to the text value
    ///   - label: Optional label shown above the field
    ///   - helperText: Optional helper text shown below the field
    ///   - errorMessage: Optional error message (overrides helperText, shows error state)
    ///   - keyboardType: Keyboard type (default: .default)
    ///   - isSecure: Whether to mask input (default: false)
    ///   - isEnabled: Whether field is interactive (default: true)
    init(
        _ placeholder: String,
        text: Binding<String>,
        label: String? = nil,
        helperText: String? = nil,
        errorMessage: String? = nil,
        keyboardType: UIKeyboardType = .default,
        isSecure: Bool = false,
        isEnabled: Bool = true
    ) {
        self.placeholder = placeholder
        self._text = text
        self.label = label
        self.helperText = helperText
        self.errorMessage = errorMessage
        self.keyboardType = keyboardType
        self.isSecure = isSecure
        self.isEnabled = isEnabled
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
            // Label
            if let label = label {
                Text(label.uppercased())
                    .font(BrutalistTheme.Typography.caption)
                    .foregroundColor(BrutalistTheme.Colors.text)
                    .fontWeight(.bold)
            }

            // Text Field Container
            textFieldContainer

            // Helper/Error Text
            if let displayText = displayHelperText {
                Text(displayText)
                    .font(BrutalistTheme.Typography.caption)
                    .foregroundColor(helperTextColor)
            }
        }
    }

    private var textFieldContainer: some View {
        HStack(spacing: BrutalistTheme.Spacing.sm) {
            // Text Input
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(BrutalistTheme.Typography.body)
            .foregroundColor(isEnabled ? BrutalistTheme.Colors.text : BrutalistTheme.Colors.text.opacity(0.5))
            .keyboardType(keyboardType)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused($isFocused)
            .disabled(!isEnabled)

            // Clear Button
            if !text.isEmpty && isEnabled && !isSecure {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(BrutalistTheme.Colors.text)
                        .frame(width: 24, height: 24)
                        .background(BrutalistTheme.Colors.background)
                        .overlay(
                            Rectangle()
                                .stroke(BrutalistTheme.Colors.text, lineWidth: 2)
                        )
                }
            }
        }
        .padding(.horizontal, BrutalistTheme.Spacing.md)
        .padding(.vertical, BrutalistTheme.Spacing.md)
        .background(isEnabled ? BrutalistTheme.Colors.background : BrutalistTheme.Colors.disabled.opacity(0.3))
        .overlay(
            Rectangle()
                .stroke(borderColor, lineWidth: BrutalistTheme.Borders.standard)
        )
        .background(
            Rectangle()
                .fill(shadowColor)
                .offset(
                    x: BrutalistTheme.Shadows.offsetX,
                    y: BrutalistTheme.Shadows.offsetY
                )
        )
    }
}

// MARK: - Numeric Text Field

/// A specialized brutalist text field for numeric input (water parameters)
struct BrutalistNumericField: View {
    let placeholder: String
    @Binding var value: Double?
    let label: String?
    let unit: String?
    let range: ClosedRange<Double>?
    let errorMessage: String?

    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    private var currentStyle: BrutalistTextFieldStyle {
        if errorMessage != nil || isOutOfRange {
            return .error
        } else if isFocused {
            return .highlighted
        }
        return .standard
    }

    private var isOutOfRange: Bool {
        guard let value = value, let range = range else { return false }
        return !range.contains(value)
    }

    private var borderColor: Color {
        switch currentStyle {
        case .standard:
            return BrutalistTheme.Colors.text
        case .highlighted:
            return BrutalistTheme.Colors.action
        case .error:
            return BrutalistTheme.Colors.warning
        }
    }

    private var shadowColor: Color {
        switch currentStyle {
        case .standard:
            return BrutalistTheme.Colors.shadow
        case .highlighted:
            return BrutalistTheme.Colors.action
        case .error:
            return BrutalistTheme.Colors.warning
        }
    }

    init(
        _ placeholder: String,
        value: Binding<Double?>,
        label: String? = nil,
        unit: String? = nil,
        range: ClosedRange<Double>? = nil,
        errorMessage: String? = nil
    ) {
        self.placeholder = placeholder
        self._value = value
        self.label = label
        self.unit = unit
        self.range = range
        self.errorMessage = errorMessage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
            // Label
            if let label = label {
                Text(label.uppercased())
                    .font(BrutalistTheme.Typography.caption)
                    .foregroundColor(BrutalistTheme.Colors.text)
                    .fontWeight(.bold)
            }

            // Input Container
            HStack(spacing: BrutalistTheme.Spacing.sm) {
                TextField(placeholder, text: $textValue)
                    .font(BrutalistTheme.Typography.body)
                    .foregroundColor(BrutalistTheme.Colors.text)
                    .keyboardType(.decimalPad)
                    .focused($isFocused)
                    .onChange(of: textValue) { _, newValue in
                        if let doubleValue = Double(newValue) {
                            value = doubleValue
                        } else if newValue.isEmpty {
                            value = nil
                        }
                    }
                    .onAppear {
                        if let value = value {
                            textValue = String(format: "%.2f", value)
                        }
                    }

                if let unit = unit {
                    Text(unit)
                        .font(BrutalistTheme.Typography.bodyBold)
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                }
            }
            .padding(.horizontal, BrutalistTheme.Spacing.md)
            .padding(.vertical, BrutalistTheme.Spacing.md)
            .background(BrutalistTheme.Colors.background)
            .overlay(
                Rectangle()
                    .stroke(borderColor, lineWidth: BrutalistTheme.Borders.standard)
            )
            .background(
                Rectangle()
                    .fill(shadowColor)
                    .offset(
                        x: BrutalistTheme.Shadows.offsetX,
                        y: BrutalistTheme.Shadows.offsetY
                    )
            )

            // Range indicator or error
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(BrutalistTheme.Typography.caption)
                    .foregroundColor(BrutalistTheme.Colors.warning)
            } else if let range = range {
                Text("Range: \(String(format: "%.1f", range.lowerBound)) - \(String(format: "%.1f", range.upperBound))")
                    .font(BrutalistTheme.Typography.caption)
                    .foregroundColor(isOutOfRange ? BrutalistTheme.Colors.warning : BrutalistTheme.Colors.text.opacity(0.5))
            }
        }
    }
}

// MARK: - Text Area (Multiline)

/// A brutalist multiline text input for longer content
struct BrutalistTextArea: View {
    let placeholder: String
    @Binding var text: String
    let label: String?
    let minHeight: CGFloat
    let isEnabled: Bool

    @FocusState private var isFocused: Bool

    private var borderColor: Color {
        isFocused ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.text
    }

    private var shadowColor: Color {
        isFocused ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.shadow
    }

    init(
        _ placeholder: String,
        text: Binding<String>,
        label: String? = nil,
        minHeight: CGFloat = 100,
        isEnabled: Bool = true
    ) {
        self.placeholder = placeholder
        self._text = text
        self.label = label
        self.minHeight = minHeight
        self.isEnabled = isEnabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
            // Label
            if let label = label {
                Text(label.uppercased())
                    .font(BrutalistTheme.Typography.caption)
                    .foregroundColor(BrutalistTheme.Colors.text)
                    .fontWeight(.bold)
            }

            // Text Editor
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(BrutalistTheme.Typography.body)
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.4))
                        .padding(.horizontal, BrutalistTheme.Spacing.md)
                        .padding(.vertical, BrutalistTheme.Spacing.md + 8)
                }

                TextEditor(text: $text)
                    .font(BrutalistTheme.Typography.body)
                    .foregroundColor(BrutalistTheme.Colors.text)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .focused($isFocused)
                    .disabled(!isEnabled)
                    .padding(.horizontal, BrutalistTheme.Spacing.sm)
                    .padding(.vertical, BrutalistTheme.Spacing.sm)
            }
            .frame(minHeight: minHeight)
            .background(isEnabled ? BrutalistTheme.Colors.background : BrutalistTheme.Colors.disabled.opacity(0.3))
            .overlay(
                Rectangle()
                    .stroke(borderColor, lineWidth: BrutalistTheme.Borders.standard)
            )
            .background(
                Rectangle()
                    .fill(shadowColor)
                    .offset(
                        x: BrutalistTheme.Shadows.offsetX,
                        y: BrutalistTheme.Shadows.offsetY
                    )
            )

            // Character count
            HStack {
                Spacer()
                Text("\(text.count) characters")
                    .font(BrutalistTheme.Typography.caption)
                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
            }
        }
    }
}

// MARK: - Preview

#Preview("Brutalist Text Fields") {
    ScrollView {
        VStack(spacing: BrutalistTheme.Spacing.lg) {
            Text("TEXT FIELDS")
                .font(BrutalistTheme.Typography.headerMedium)

            // Standard Text Field
            BrutalistTextField(
                "Enter tank name",
                text: .constant(""),
                label: "Tank Name",
                helperText: "Give your aquarium a memorable name"
            )

            // With Value
            BrutalistTextField(
                "Enter email",
                text: .constant("reef@example.com"),
                label: "Email Address"
            )

            // Error State
            BrutalistTextField(
                "Enter value",
                text: .constant("abc"),
                label: "Salinity",
                errorMessage: "Must be a numeric value"
            )

            // Secure Field
            BrutalistTextField(
                "Enter password",
                text: .constant("secret123"),
                label: "Password",
                isSecure: true
            )

            // Disabled
            BrutalistTextField(
                "Disabled field",
                text: .constant("Cannot edit"),
                label: "Disabled Field",
                isEnabled: false
            )

            Divider()
                .padding(.vertical, BrutalistTheme.Spacing.md)

            Text("NUMERIC FIELDS")
                .font(BrutalistTheme.Typography.headerSmall)

            // Numeric Fields for Water Parameters
            BrutalistNumericField(
                "0.00",
                value: .constant(8.2),
                label: "pH Level",
                range: 7.8...8.4
            )

            BrutalistNumericField(
                "0.00",
                value: .constant(1.026),
                label: "Specific Gravity",
                unit: "SG",
                range: 1.020...1.028
            )

            BrutalistNumericField(
                "0.00",
                value: .constant(520.0),
                label: "Calcium",
                unit: "ppm",
                range: 380...450,
                errorMessage: "Value is above recommended range"
            )

            Divider()
                .padding(.vertical, BrutalistTheme.Spacing.md)

            Text("TEXT AREA")
                .font(BrutalistTheme.Typography.headerSmall)

            BrutalistTextArea(
                "Enter your observations...",
                text: .constant("Coral looking healthy. New frag acclimating well."),
                label: "Notes"
            )
        }
        .padding(BrutalistTheme.Spacing.lg)
    }
    .background(BrutalistTheme.Colors.background)
}
