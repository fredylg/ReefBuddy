import SwiftUI
import UserNotifications

// MARK: - Notification Settings View

/// View for managing parameter notification thresholds and alerts.
/// New Brutalist design: sharp corners, bold borders, high contrast.
struct NotificationSettingsView: View {

    // MARK: - State

    @EnvironmentObject private var appState: AppState
    @State private var notificationSettings: [ParameterNotificationSetting] = ParameterNotificationSetting.defaults
    @State private var notificationsEnabled = true
    @State private var showingTestAlert = false
    @State private var notificationHistory: [NotificationHistoryItem] = NotificationHistoryItem.samples
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: BrutalistTheme.Spacing.lg) {
                // Master toggle section
                masterToggleSection

                // Permission warning if needed
                if permissionStatus == .denied {
                    permissionWarningSection
                }

                // Parameter thresholds
                parameterThresholdsSection

                // Test notification button
                testNotificationSection

                // Notification history
                notificationHistorySection
            }
            .padding(BrutalistTheme.Spacing.lg)
        }
        .background(BrutalistTheme.Colors.background)
        .onAppear {
            checkNotificationPermissions()
        }
        .alert("Test Notification Sent!", isPresented: $showingTestAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("If notifications are enabled, you should receive a test alert shortly.")
        }
    }

    // MARK: - Master Toggle Section

    private var masterToggleSection: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
            HStack {
                Image(systemName: "bell.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("NOTIFICATIONS")
                    .font(BrutalistTheme.Typography.caption)
                    .fontWeight(.bold)
            }
            .foregroundColor(BrutalistTheme.Colors.text)

            Rectangle()
                .fill(BrutalistTheme.Colors.text)
                .frame(height: 1)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Alerts")
                        .font(BrutalistTheme.Typography.bodyBold)
                        .foregroundColor(BrutalistTheme.Colors.text)

                    Text("Get notified when parameters are out of range")
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                }

                Spacer()

                brutalistToggle(isOn: $notificationsEnabled)
            }
            .padding(.vertical, BrutalistTheme.Spacing.sm)
        }
        .padding(BrutalistTheme.Spacing.md)
        .background(BrutalistTheme.Colors.cardBackground)
        .brutalistCard()
    }

    // MARK: - Permission Warning Section

    private var permissionWarningSection: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(BrutalistTheme.Colors.warning)
                Text("NOTIFICATIONS DISABLED")
                    .font(BrutalistTheme.Typography.caption)
                    .fontWeight(.bold)
                    .foregroundColor(BrutalistTheme.Colors.warning)
            }

            Rectangle()
                .fill(BrutalistTheme.Colors.warning)
                .frame(height: 1)

            Text("Notifications are disabled for ReefBuddy. Enable them in Settings to receive parameter alerts.")
                .font(BrutalistTheme.Typography.body)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.8))

            BrutalistButton.primary("OPEN SETTINGS") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
        .padding(BrutalistTheme.Spacing.md)
        .background(BrutalistTheme.Colors.warning.opacity(0.1))
        .brutalistCard(borderColor: BrutalistTheme.Colors.warning)
    }

    // MARK: - Parameter Thresholds Section

    private var parameterThresholdsSection: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .bold))
                Text("PARAMETER THRESHOLDS")
                    .font(BrutalistTheme.Typography.caption)
                    .fontWeight(.bold)
            }
            .foregroundColor(BrutalistTheme.Colors.text)

            Rectangle()
                .fill(BrutalistTheme.Colors.text)
                .frame(height: 1)

            Text("Set min/max thresholds to get notified when values are out of range.")
                .font(BrutalistTheme.Typography.caption)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                .padding(.bottom, BrutalistTheme.Spacing.sm)

            ForEach($notificationSettings) { $setting in
                ParameterThresholdRow(setting: $setting, isEnabled: notificationsEnabled)

                if setting.id != notificationSettings.last?.id {
                    Rectangle()
                        .fill(BrutalistTheme.Colors.text.opacity(0.1))
                        .frame(height: 1)
                }
            }
        }
        .padding(BrutalistTheme.Spacing.md)
        .background(BrutalistTheme.Colors.cardBackground)
        .brutalistCard()
    }

    // MARK: - Test Notification Section

    private var testNotificationSection: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("TEST NOTIFICATIONS")
                    .font(BrutalistTheme.Typography.caption)
                    .fontWeight(.bold)
            }
            .foregroundColor(BrutalistTheme.Colors.text)

            Rectangle()
                .fill(BrutalistTheme.Colors.text)
                .frame(height: 1)

            Text("Send a test notification to verify your settings are working.")
                .font(BrutalistTheme.Typography.body)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.7))

            BrutalistButton.secondary("SEND TEST NOTIFICATION", isFullWidth: true, isEnabled: notificationsEnabled && permissionStatus == .authorized) {
                sendTestNotification()
            }
        }
        .padding(BrutalistTheme.Spacing.md)
        .background(BrutalistTheme.Colors.cardBackground)
        .brutalistCard()
    }

    // MARK: - Notification History Section

    private var notificationHistorySection: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("NOTIFICATION HISTORY")
                    .font(BrutalistTheme.Typography.caption)
                    .fontWeight(.bold)

                Spacer()

                if !notificationHistory.isEmpty {
                    Button(action: clearHistory) {
                        Text("CLEAR")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(BrutalistTheme.Colors.warning)
                    }
                    .buttonStyle(.plain)
                }
            }
            .foregroundColor(BrutalistTheme.Colors.text)

            Rectangle()
                .fill(BrutalistTheme.Colors.text)
                .frame(height: 1)

            if notificationHistory.isEmpty {
                VStack(spacing: BrutalistTheme.Spacing.sm) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.3))

                    Text("No notifications yet")
                        .font(BrutalistTheme.Typography.body)
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, BrutalistTheme.Spacing.lg)
            } else {
                ForEach(notificationHistory) { item in
                    notificationHistoryRow(item)
                }
            }
        }
        .padding(BrutalistTheme.Spacing.md)
        .background(BrutalistTheme.Colors.cardBackground)
        .brutalistCard()
    }

    private func notificationHistoryRow(_ item: NotificationHistoryItem) -> some View {
        HStack(alignment: .top, spacing: BrutalistTheme.Spacing.md) {
            // Status indicator
            Circle()
                .fill(item.type == .warning ? BrutalistTheme.Colors.warning : BrutalistTheme.Colors.action)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(BrutalistTheme.Typography.bodyBold)
                    .foregroundColor(BrutalistTheme.Colors.text)

                Text(item.message)
                    .font(BrutalistTheme.Typography.caption)
                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.7))
            }

            Spacer()

            Text(formatTime(item.timestamp))
                .font(BrutalistTheme.Typography.caption)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
        }
        .padding(.vertical, BrutalistTheme.Spacing.sm)
    }

    // MARK: - Custom Brutalist Toggle

    private func brutalistToggle(isOn: Binding<Bool>) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isOn.wrappedValue.toggle()
            }
        }) {
            ZStack(alignment: isOn.wrappedValue ? .trailing : .leading) {
                Rectangle()
                    .fill(isOn.wrappedValue ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.text.opacity(0.2))
                    .frame(width: 52, height: 28)
                    .brutalistBorder(width: 2)

                Rectangle()
                    .fill(BrutalistTheme.Colors.background)
                    .frame(width: 22, height: 22)
                    .brutalistBorder(width: 2)
                    .padding(2)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helper Functions

    private func checkNotificationPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                permissionStatus = settings.authorizationStatus
            }
        }
    }

    private func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "ReefBuddy Test"
        content.body = "This is a test notification. Your alerts are working!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        UNUserNotificationCenter.current().add(request) { error in
            if error == nil {
                DispatchQueue.main.async {
                    showingTestAlert = true
                }
            }
        }
    }

    private func clearHistory() {
        withAnimation {
            notificationHistory.removeAll()
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Parameter Threshold Row

struct ParameterThresholdRow: View {
    @Binding var setting: ParameterNotificationSetting
    let isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
            // Header with toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(setting.parameter.displayName.uppercased())
                        .font(BrutalistTheme.Typography.bodyBold)
                        .foregroundColor(isEnabled && setting.isEnabled ? BrutalistTheme.Colors.text : BrutalistTheme.Colors.text.opacity(0.5))

                    Text("Range: \(formatValue(setting.minValue)) - \(formatValue(setting.maxValue)) \(setting.parameter.unit)")
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                }

                Spacer()

                // Toggle
                parameterToggle
            }

            // Sliders (visible when enabled)
            if setting.isEnabled && isEnabled {
                VStack(spacing: BrutalistTheme.Spacing.sm) {
                    // Min threshold slider
                    sliderRow(
                        label: "MIN",
                        value: $setting.minValue,
                        range: setting.parameter.range
                    )

                    // Max threshold slider
                    sliderRow(
                        label: "MAX",
                        value: $setting.maxValue,
                        range: setting.parameter.range
                    )
                }
                .padding(.top, BrutalistTheme.Spacing.xs)
            }
        }
        .padding(.vertical, BrutalistTheme.Spacing.sm)
        .opacity(isEnabled ? 1.0 : 0.6)
    }

    private var parameterToggle: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                setting.isEnabled.toggle()
            }
        }) {
            ZStack(alignment: setting.isEnabled ? .trailing : .leading) {
                Rectangle()
                    .fill(setting.isEnabled && isEnabled ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.text.opacity(0.2))
                    .frame(width: 44, height: 24)
                    .brutalistBorder(width: 2)

                Rectangle()
                    .fill(BrutalistTheme.Colors.background)
                    .frame(width: 18, height: 18)
                    .brutalistBorder(width: 2)
                    .padding(2)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func sliderRow(label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: BrutalistTheme.Spacing.md) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                .frame(width: 30)

            // Custom brutalist slider
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    Rectangle()
                        .fill(BrutalistTheme.Colors.text.opacity(0.2))
                        .frame(height: 8)
                        .brutalistBorder(width: 1)

                    // Filled portion
                    Rectangle()
                        .fill(BrutalistTheme.Colors.action)
                        .frame(width: thumbPosition(value: value.wrappedValue, range: range, width: geometry.size.width), height: 8)

                    // Thumb
                    Rectangle()
                        .fill(BrutalistTheme.Colors.background)
                        .frame(width: 16, height: 20)
                        .brutalistBorder(width: 2)
                        .offset(x: thumbPosition(value: value.wrappedValue, range: range, width: geometry.size.width) - 8)
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    let newValue = calculateValue(from: gesture.location.x, range: range, width: geometry.size.width)
                                    value.wrappedValue = newValue
                                }
                        )
                }
            }
            .frame(height: 24)

            Text(formatValue(value.wrappedValue))
                .font(BrutalistTheme.Typography.caption)
                .foregroundColor(BrutalistTheme.Colors.text)
                .frame(width: 50, alignment: .trailing)
        }
    }

    private func thumbPosition(value: Double, range: ClosedRange<Double>, width: CGFloat) -> CGFloat {
        let percentage = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return CGFloat(percentage) * width
    }

    private func calculateValue(from position: CGFloat, range: ClosedRange<Double>, width: CGFloat) -> Double {
        let percentage = max(0, min(1, position / width))
        let value = range.lowerBound + (Double(percentage) * (range.upperBound - range.lowerBound))
        return value
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        } else if value >= 1 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.3f", value)
        }
    }
}

// MARK: - Parameter Notification Setting Model

struct ParameterNotificationSetting: Identifiable {
    let id = UUID()
    let parameter: ParameterRange
    var isEnabled: Bool
    var minValue: Double
    var maxValue: Double

    static var defaults: [ParameterNotificationSetting] {
        ParameterRange.allCases.map { param in
            ParameterNotificationSetting(
                parameter: param,
                isEnabled: true,
                minValue: param.range.lowerBound,
                maxValue: param.range.upperBound
            )
        }
    }
}

// Extension for ParameterRange to support iteration
extension ParameterRange: CaseIterable {
    static var allCases: [ParameterRange] {
        [.temperature, .salinity, .pH, .alkalinity, .calcium, .magnesium, .nitrate, .phosphate, .ammonia, .nitrite]
    }
}

// MARK: - Notification History Item

struct NotificationHistoryItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let timestamp: Date
    let type: NotificationType

    enum NotificationType {
        case warning
        case info
    }

    static var samples: [NotificationHistoryItem] {
        [
            NotificationHistoryItem(
                title: "Alkalinity Low",
                message: "Alkalinity dropped to 6.8 dKH in Living Room Reef",
                timestamp: Date().addingTimeInterval(-3600),
                type: .warning
            ),
            NotificationHistoryItem(
                title: "Nitrate Warning",
                message: "Nitrate reached 15 ppm in Office Nano",
                timestamp: Date().addingTimeInterval(-86400),
                type: .warning
            ),
            NotificationHistoryItem(
                title: "Parameters Stable",
                message: "All parameters in optimal range",
                timestamp: Date().addingTimeInterval(-172800),
                type: .info
            )
        ]
    }
}

// MARK: - Preview

#Preview("Notification Settings") {
    NotificationSettingsView()
        .environmentObject(AppState())
}
