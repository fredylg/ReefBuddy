import SwiftUI

// MARK: - Subscription View

/// Premium upgrade prompt with feature comparison.
/// New Brutalist style: bold typography, high contrast, hard shadows.
struct SubscriptionView: View {

    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var isPurchasing = false
    @State private var showingError = false
    @State private var errorMessage = ""

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BrutalistTheme.Spacing.xl) {
                    // Hero Section
                    heroSection

                    // Feature Comparison
                    featureComparison

                    // Current Status
                    currentStatusCard

                    // Upgrade Button
                    upgradeSection

                    // Terms
                    termsSection
                }
                .padding(BrutalistTheme.Spacing.lg)
            }
            .background(BrutalistTheme.Colors.background)
            .navigationTitle("PREMIUM")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("CLOSE") {
                        dismiss()
                    }
                    .font(BrutalistTheme.Typography.button)
                    .foregroundColor(BrutalistTheme.Colors.text)
                }
            }
            .alert("PURCHASE ERROR", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: BrutalistTheme.Spacing.md) {
            // Icon
            ZStack {
                Rectangle()
                    .fill(BrutalistTheme.Colors.action)
                    .frame(width: 80, height: 80)
                    .brutalistShadow()
                    .brutalistBorder()

                Image(systemName: "crown.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(BrutalistTheme.Colors.text)
            }

            Text("UNLOCK PREMIUM")
                .font(BrutalistTheme.Typography.headerLarge)
                .foregroundColor(BrutalistTheme.Colors.text)

            Text("Get unlimited AI analyses, CSV exports, and advanced features")
                .font(BrutalistTheme.Typography.body)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, BrutalistTheme.Spacing.lg)
    }

    // MARK: - Feature Comparison

    private var featureComparison: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("FEATURE")
                    .font(BrutalistTheme.Typography.caption)
                    .fontWeight(.bold)
                    .foregroundColor(BrutalistTheme.Colors.text)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("FREE")
                    .font(BrutalistTheme.Typography.caption)
                    .fontWeight(.bold)
                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                    .frame(width: 70)

                Text("PREMIUM")
                    .font(BrutalistTheme.Typography.caption)
                    .fontWeight(.bold)
                    .foregroundColor(BrutalistTheme.Colors.action)
                    .frame(width: 80)
            }
            .padding(BrutalistTheme.Spacing.md)
            .background(BrutalistTheme.Colors.text.opacity(0.05))

            // Features
            ForEach(features, id: \.name) { feature in
                featureRow(feature)
            }
        }
        .brutalistCard()
    }

    private func featureRow(_ feature: FeatureComparison) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.name)
                    .font(BrutalistTheme.Typography.bodyBold)
                    .foregroundColor(BrutalistTheme.Colors.text)

                if let description = feature.description {
                    Text(description)
                        .font(.system(size: 10))
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            featureValue(feature.freeValue, isHighlighted: false)
                .frame(width: 70)

            featureValue(feature.premiumValue, isHighlighted: true)
                .frame(width: 80)
        }
        .padding(BrutalistTheme.Spacing.md)
        .overlay(
            Rectangle()
                .fill(BrutalistTheme.Colors.text.opacity(0.1))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private func featureValue(_ value: FeatureValue, isHighlighted: Bool) -> some View {
        switch value {
        case .check:
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isHighlighted ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.text)

        case .cross:
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.3))

        case .text(let string):
            Text(string)
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(isHighlighted ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.text.opacity(0.6))
        }
    }

    // MARK: - Current Status

    private var currentStatusCard: some View {
        VStack(spacing: BrutalistTheme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
                    Text("CURRENT PLAN")
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))

                    Text(currentPlanName)
                        .font(BrutalistTheme.Typography.headerSmall)
                        .foregroundColor(BrutalistTheme.Colors.text)
                }

                Spacer()

                // Status badge
                Text(isPremium ? "ACTIVE" : "LIMITED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isPremium ? BrutalistTheme.Colors.text : BrutalistTheme.Colors.warning)
                    .padding(.horizontal, BrutalistTheme.Spacing.sm)
                    .padding(.vertical, BrutalistTheme.Spacing.xs)
                    .background(isPremium ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.warning.opacity(0.2))
                    .brutalistBorder(width: 2, color: isPremium ? BrutalistTheme.Colors.text : BrutalistTheme.Colors.warning)
            }

            if !isPremium {
                // Remaining analyses
                HStack {
                    Text("AI ANALYSES REMAINING:")
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))

                    Spacer()

                    Text("\(appState.freeAnalysesRemaining) / 3")
                        .font(BrutalistTheme.Typography.bodyBold)
                        .foregroundColor(appState.freeAnalysesRemaining > 0 ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.warning)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(BrutalistTheme.Colors.text.opacity(0.1))
                            .frame(height: 8)

                        Rectangle()
                            .fill(appState.freeAnalysesRemaining > 0 ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.warning)
                            .frame(width: geometry.size.width * CGFloat(appState.freeAnalysesRemaining) / 3, height: 8)
                    }
                    .brutalistBorder(width: 2)
                }
                .frame(height: 8)
            }
        }
        .padding(BrutalistTheme.Spacing.lg)
        .background(BrutalistTheme.Colors.background)
        .brutalistCard()
    }

    // MARK: - Upgrade Section

    private var upgradeSection: some View {
        VStack(spacing: BrutalistTheme.Spacing.md) {
            if isPremium {
                // Already premium
                VStack(spacing: BrutalistTheme.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(BrutalistTheme.Colors.action)

                    Text("YOU'RE A PREMIUM MEMBER")
                        .font(BrutalistTheme.Typography.bodyBold)
                        .foregroundColor(BrutalistTheme.Colors.text)

                    Text("Thank you for supporting ReefBuddy!")
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                }
                .padding(BrutalistTheme.Spacing.lg)
            } else {
                // Price badge
                VStack(spacing: BrutalistTheme.Spacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("$")
                            .font(BrutalistTheme.Typography.headerMedium)
                            .foregroundColor(BrutalistTheme.Colors.text)

                        Text("4.99")
                            .font(.system(size: 48, weight: .black))
                            .foregroundColor(BrutalistTheme.Colors.text)

                        Text("/mo")
                            .font(BrutalistTheme.Typography.body)
                            .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                    }

                    Text("Cancel anytime")
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
                }

                // Upgrade button
                Button(action: purchasePremium) {
                    HStack(spacing: BrutalistTheme.Spacing.sm) {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: BrutalistTheme.Colors.text))
                        } else {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 16, weight: .bold))
                        }

                        Text(isPurchasing ? "PROCESSING..." : "UPGRADE TO PREMIUM")
                            .font(BrutalistTheme.Typography.button)
                    }
                    .foregroundColor(BrutalistTheme.Colors.text)
                    .frame(maxWidth: .infinity)
                    .padding(BrutalistTheme.Spacing.lg)
                    .background(BrutalistTheme.Colors.action)
                    .brutalistCard()
                }
                .buttonStyle(.plain)
                .disabled(isPurchasing)

                // Restore purchases
                Button(action: restorePurchases) {
                    Text("RESTORE PURCHASES")
                        .font(BrutalistTheme.Typography.caption)
                        .fontWeight(.bold)
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Terms Section

    private var termsSection: some View {
        VStack(spacing: BrutalistTheme.Spacing.sm) {
            Text("SUBSCRIPTION TERMS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.4))

            Text("Premium subscription renews monthly. Cancel anytime in your Apple ID settings. Payment will be charged to your Apple ID account at confirmation of purchase.")
                .font(.system(size: 10))
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.4))
                .multilineTextAlignment(.center)

            HStack(spacing: BrutalistTheme.Spacing.lg) {
                Link("Privacy Policy", destination: URL(string: "https://reefbuddy.app/privacy")!)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.4))

                Link("Terms of Service", destination: URL(string: "https://reefbuddy.app/terms")!)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.4))
            }
        }
        .padding(.top, BrutalistTheme.Spacing.lg)
    }

    // MARK: - Computed Properties

    private var isPremium: Bool {
        // In a real app, this would check the user's subscription status
        false
    }

    private var currentPlanName: String {
        isPremium ? "PREMIUM" : "FREE"
    }

    private var features: [FeatureComparison] {
        [
            FeatureComparison(
                name: "AI WATER ANALYSIS",
                description: "Get personalized dosing advice",
                freeValue: .text("3/mo"),
                premiumValue: .text("UNLIMITED")
            ),
            FeatureComparison(
                name: "HISTORICAL CHARTS",
                description: "Track parameters over time",
                freeValue: .check,
                premiumValue: .check
            ),
            FeatureComparison(
                name: "CSV EXPORT",
                description: "Export data for spreadsheets",
                freeValue: .cross,
                premiumValue: .check
            ),
            FeatureComparison(
                name: "PRIORITY SUPPORT",
                description: "Get help from reef experts",
                freeValue: .cross,
                premiumValue: .check
            ),
            FeatureComparison(
                name: "TANK LIMIT",
                description: nil,
                freeValue: .text("2"),
                premiumValue: .text("UNLIMITED")
            ),
            FeatureComparison(
                name: "AD-FREE EXPERIENCE",
                description: nil,
                freeValue: .cross,
                premiumValue: .check
            )
        ]
    }

    // MARK: - Actions

    private func purchasePremium() {
        isPurchasing = true

        // Simulate purchase (in real app, use StoreKit)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isPurchasing = false
            // Show success or handle error
            errorMessage = "Purchase functionality requires StoreKit integration"
            showingError = true
        }
    }

    private func restorePurchases() {
        isPurchasing = true

        // Simulate restore (in real app, use StoreKit)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isPurchasing = false
            errorMessage = "No previous purchases found"
            showingError = true
        }
    }
}

// MARK: - Feature Comparison Model

struct FeatureComparison {
    let name: String
    let description: String?
    let freeValue: FeatureValue
    let premiumValue: FeatureValue
}

enum FeatureValue {
    case check
    case cross
    case text(String)
}

// MARK: - Premium Gate View

/// A reusable view for gating premium features
struct PremiumGateView: View {
    let feature: String
    let onUpgrade: () -> Void

    var body: some View {
        VStack(spacing: BrutalistTheme.Spacing.lg) {
            // Lock icon
            ZStack {
                Rectangle()
                    .fill(BrutalistTheme.Colors.warning.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .brutalistBorder(width: 2, color: BrutalistTheme.Colors.warning)

                Image(systemName: "lock.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(BrutalistTheme.Colors.warning)
            }

            Text("PREMIUM FEATURE")
                .font(BrutalistTheme.Typography.headerMedium)
                .foregroundColor(BrutalistTheme.Colors.text)

            Text("\(feature) requires a Premium subscription")
                .font(BrutalistTheme.Typography.body)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                .multilineTextAlignment(.center)

            BrutalistButton.primary("UPGRADE TO PREMIUM", isFullWidth: true) {
                onUpgrade()
            }
        }
        .padding(BrutalistTheme.Spacing.xl)
        .background(BrutalistTheme.Colors.background)
        .brutalistCard()
    }
}

// MARK: - Preview

#Preview("Subscription View") {
    SubscriptionView()
        .environmentObject(AppState())
}

#Preview("Premium Gate") {
    PremiumGateView(feature: "CSV Export") {
        print("Upgrade tapped")
    }
    .padding()
    .background(BrutalistTheme.Colors.background)
}
