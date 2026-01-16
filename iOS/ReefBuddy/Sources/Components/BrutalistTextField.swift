import SwiftUI

// MARK: - Brutalist Text Field

/// A bold, high-contrast text field following New Brutalist design principles.
/// Sharp corners, thick borders, clear labels.
struct BrutalistTextField: View {

    // MARK: - Properties

    let placeholder: String
    @Binding var text: String
    let label: String?
    let helperText: String?
    let errorText: String?
    let keyboardType: UIKeyboardType
    let isSecure: Bool

    // MARK: - State

    @FocusState private var isFocused: Bool

    // MARK: - Initialization

    init(
        _ placeholder: String,
        text: Binding<String>,
        label: String? = nil,
        helperText: String? = nil,
        errorText: String? = nil,
        keyboardType: UIKeyboardType = .default,
        isSecure: Bool = false
    ) {
        self.placeholder = placeholder
        self._text = text
        self.label = label
        self.helperText = helperText
        self.errorText = errorText
        self.keyboardType = keyboardType
        self.isSecure = isSecure
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
            // Label
            if let label = label {
                Text(label.uppercased())
                    .font(BrutalistTheme.Typography.caption)
                    .fontWeight(.bold)
                    .foregroundColor(BrutalistTheme.Colors.text)
            }

            // Input Field
            inputField
                .padding(BrutalistTheme.Spacing.md)
                .background(BrutalistTheme.Colors.background)
                .brutalistBorder(
                    width: isFocused ? BrutalistTheme.Borders.heavy : BrutalistTheme.Borders.standard,
                    color: borderColor
                )
                .focused($isFocused)

            // Helper/Error Text
            if let errorText = errorText {
                Text(errorText)
                    .font(BrutalistTheme.Typography.caption)
                    .foregroundColor(BrutalistTheme.Colors.warning)
            } else if let helperText = helperText {
                Text(helperText)
                    .font(BrutalistTheme.Typography.caption)
                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
            }
        }
    }

    // MARK: - Input Field

    @ViewBuilder
    private var inputField: some View {
        if isSecure {
            SecureField(placeholder, text: $text)
                .font(BrutalistTheme.Typography.body)
                .foregroundColor(BrutalistTheme.Colors.text)
        } else {
            TextField(placeholder, text: $text)
                .font(BrutalistTheme.Typography.body)
                .foregroundColor(BrutalistTheme.Colors.text)
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
        }
    }

    // MARK: - Colors

    private var borderColor: Color {
        if errorText != nil {
            return BrutalistTheme.Colors.warning
        } else if isFocused {
            return BrutalistTheme.Colors.action
        } else {
            return BrutalistTheme.Colors.text
        }
    }
}

// MARK: - Brutalist Text Area

/// A multi-line text input following Brutalist design
struct BrutalistTextArea: View {

    // MARK: - Properties

    let placeholder: String
    @Binding var text: String
    let label: String?
    let minHeight: CGFloat

    // MARK: - State

    @FocusState private var isFocused: Bool

    // MARK: - Initialization

    init(
        _ placeholder: String,
        text: Binding<String>,
        label: String? = nil,
        minHeight: CGFloat = 100
    ) {
        self.placeholder = placeholder
        self._text = text
        self.label = label
        self.minHeight = minHeight
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
            // Label
            if let label = label {
                Text(label.uppercased())
                    .font(BrutalistTheme.Typography.caption)
                    .fontWeight(.bold)
                    .foregroundColor(BrutalistTheme.Colors.text)
            }

            // Text Editor with placeholder
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(BrutalistTheme.Typography.body)
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.4))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }

                TextEditor(text: $text)
                    .font(BrutalistTheme.Typography.body)
                    .foregroundColor(BrutalistTheme.Colors.text)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .focused($isFocused)
            }
            .frame(minHeight: minHeight)
            .padding(BrutalistTheme.Spacing.sm)
            .background(BrutalistTheme.Colors.background)
            .brutalistBorder(
                width: isFocused ? BrutalistTheme.Borders.heavy : BrutalistTheme.Borders.standard,
                color: isFocused ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.text
            )
        }
    }
}

// MARK: - Brutalist Picker

/// A segmented picker following Brutalist design
struct BrutalistPicker<T: Hashable>: View {
    let label: String?
    let options: [T]
    @Binding var selection: T
    let labelForOption: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
            if let label = label {
                Text(label.uppercased())
                    .font(BrutalistTheme.Typography.caption)
                    .fontWeight(.bold)
                    .foregroundColor(BrutalistTheme.Colors.text)
            }

            HStack(spacing: 0) {
                ForEach(options, id: \.self) { option in
                    Button(action: { selection = option }) {
                        Text(labelForOption(option).uppercased())
                            .font(BrutalistTheme.Typography.caption)
                            .fontWeight(.bold)
                            .foregroundColor(BrutalistTheme.Colors.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, BrutalistTheme.Spacing.sm)
                            .background(selection == option ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.background)
                    }
                    .buttonStyle(.plain)

                    if option != options.last {
                        Rectangle()
                            .fill(BrutalistTheme.Colors.text)
                            .frame(width: BrutalistTheme.Borders.standard)
                    }
                }
            }
            .brutalistBorder()
        }
    }
}

// MARK: - Brutalist Stepper

/// A numeric stepper following Brutalist design
struct BrutalistStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    init(
        _ label: String,
        value: Binding<Int>,
        range: ClosedRange<Int> = 0...100,
        step: Int = 1
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
            Text(label.uppercased())
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(BrutalistTheme.Colors.text)

            HStack(spacing: 0) {
                // Decrement button
                Button(action: decrement) {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(BrutalistTheme.Colors.text)
                        .frame(width: 44, height: 44)
                        .background(BrutalistTheme.Colors.background)
                }
                .buttonStyle(.plain)
                .disabled(value <= range.lowerBound)

                Rectangle()
                    .fill(BrutalistTheme.Colors.text)
                    .frame(width: BrutalistTheme.Borders.standard)

                // Value display
                Text("\(value)")
                    .font(BrutalistTheme.Typography.headerMedium)
                    .foregroundColor(BrutalistTheme.Colors.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(BrutalistTheme.Colors.action.opacity(0.2))

                Rectangle()
                    .fill(BrutalistTheme.Colors.text)
                    .frame(width: BrutalistTheme.Borders.standard)

                // Increment button
                Button(action: increment) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(BrutalistTheme.Colors.text)
                        .frame(width: 44, height: 44)
                        .background(BrutalistTheme.Colors.background)
                }
                .buttonStyle(.plain)
                .disabled(value >= range.upperBound)
            }
            .brutalistBorder()
        }
    }

    private func increment() {
        if value + step <= range.upperBound {
            value += step
        }
    }

    private func decrement() {
        if value - step >= range.lowerBound {
            value -= step
        }
    }
}

// MARK: - Previews

#Preview("Text Field") {
    VStack(spacing: 20) {
        BrutalistTextField(
            "Enter your email",
            text: .constant(""),
            label: "Email Address",
            helperText: "We'll never share your email"
        )

        BrutalistTextField(
            "Enter password",
            text: .constant("secret"),
            label: "Password",
            isSecure: true
        )

        BrutalistTextField(
            "78.0",
            text: .constant("77.5"),
            label: "Temperature",
            keyboardType: .decimalPad
        )

        BrutalistTextField(
            "Enter value",
            text: .constant("invalid"),
            label: "With Error",
            errorText: "This value is out of range"
        )
    }
    .padding()
    .background(BrutalistTheme.Colors.background)
}

#Preview("Text Area") {
    VStack(spacing: 20) {
        BrutalistTextArea(
            "Enter your notes here...",
            text: .constant(""),
            label: "Notes"
        )

        BrutalistTextArea(
            "Observations...",
            text: .constant("Tank looking great today. Corals are extending well."),
            label: "Tank Observations",
            minHeight: 120
        )
    }
    .padding()
    .background(BrutalistTheme.Colors.background)
}

#Preview("Stepper") {
    VStack(spacing: 20) {
        BrutalistStepper("Tank Volume (Gallons)", value: .constant(75), range: 10...500, step: 5)
    }
    .padding()
    .background(BrutalistTheme.Colors.background)
}
