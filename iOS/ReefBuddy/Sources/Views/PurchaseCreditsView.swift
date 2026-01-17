import SwiftUI

/// View for purchasing analysis credits with brutalist design
struct PurchaseCreditsView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                BrutalistTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: BrutalistTheme.Spacing.lg) {
                        // Header
                        headerSection
                        
                        // Current Balance
                        balanceSection
                        
                        // Credit Packs
                        creditPacksSection
                        
                        // Info Section
                        infoSection
                        
                        // Restore Purchases
                        restoreButton
                    }
                    .padding(BrutalistTheme.Spacing.md)
                }
                
                // Loading Overlay
                if storeManager.purchaseInProgress {
                    loadingOverlay
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text("CLOSE")
                            .font(BrutalistTheme.Typography.caption)
                            .fontWeight(.bold)
                            .foregroundColor(BrutalistTheme.Colors.text)
                    }
                }
            }
            .alert("Purchase Error", isPresented: .constant(storeManager.purchaseError != nil)) {
                Button("OK") {
                    // Clear error handled by StoreManager
                }
            } message: {
                Text(storeManager.purchaseError ?? "")
            }
            .task {
                await storeManager.loadProducts()
                await storeManager.fetchCreditBalance()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: BrutalistTheme.Spacing.sm) {
            Text("GET MORE")
                .font(BrutalistTheme.Typography.headerLarge)
                .fontWeight(.black)
                .foregroundColor(BrutalistTheme.Colors.text)
            
            Text("ANALYSES")
                .font(BrutalistTheme.Typography.headerLarge)
                .fontWeight(.black)
                .foregroundColor(BrutalistTheme.Colors.action)
            
            Text("Unlock AI-powered water analysis")
                .font(BrutalistTheme.Typography.body)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                .padding(.top, BrutalistTheme.Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(BrutalistTheme.Spacing.lg)
    }
    
    // MARK: - Balance Section
    
    private var balanceSection: some View {
        VStack(spacing: BrutalistTheme.Spacing.sm) {
            Text("YOUR BALANCE")
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
            
            HStack(spacing: BrutalistTheme.Spacing.lg) {
                balanceItem(
                    value: storeManager.creditBalance?.freeRemaining ?? 0,
                    label: "FREE LEFT"
                )

                Rectangle()
                    .fill(BrutalistTheme.Colors.text)
                    .frame(width: 3, height: 50)

                balanceItem(
                    value: storeManager.creditBalance?.paidCredits ?? 0,
                    label: "PURCHASED"
                )

                Rectangle()
                    .fill(BrutalistTheme.Colors.text)
                    .frame(width: 3, height: 50)

                balanceItem(
                    value: storeManager.totalCredits,
                    label: "TOTAL",
                    isHighlighted: true
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(BrutalistTheme.Spacing.lg)
        .background(BrutalistTheme.Colors.background)
        .brutalistBorder()
        .brutalistShadow()
    }
    
    private func balanceItem(value: Int, label: String, isHighlighted: Bool = false) -> some View {
        VStack(spacing: BrutalistTheme.Spacing.xs) {
            Text("\(value)")
                .font(.system(size: 36, weight: .black, design: .monospaced))
                .foregroundColor(isHighlighted ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.text)
            
            Text(label)
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
        }
    }
    
    // MARK: - Credit Packs Section
    
    private var creditPacksSection: some View {
        VStack(spacing: BrutalistTheme.Spacing.md) {
            ForEach(CreditProduct.allCases, id: \.rawValue) { product in
                creditPackCard(product)
            }
        }
    }
    
    private func creditPackCard(_ creditProduct: CreditProduct) -> some View {
        Button(action: {
            Task {
                await storeManager.purchase(creditProduct)
            }
        }) {
            VStack(spacing: 0) {
                // Savings badge
                if let savings = creditProduct.savingsText {
                    Text(savings)
                        .font(BrutalistTheme.Typography.caption)
                        .fontWeight(.black)
                        .foregroundColor(BrutalistTheme.Colors.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BrutalistTheme.Spacing.xs)
                        .background(BrutalistTheme.Colors.action)
                }
                
                // Main content
                HStack {
                    VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
                        Text(creditProduct.displayName)
                            .font(BrutalistTheme.Typography.headerMedium)
                            .fontWeight(.black)
                            .foregroundColor(BrutalistTheme.Colors.text)
                        
                        Text("\(creditProduct.credits) water analyses")
                            .font(BrutalistTheme.Typography.body)
                            .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    // Price
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(creditProduct.displayPrice)
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(BrutalistTheme.Colors.text)
                        
                        if creditProduct == .credits50 {
                            Text("$0.10/each")
                                .font(BrutalistTheme.Typography.caption)
                                .foregroundColor(BrutalistTheme.Colors.action)
                                .fontWeight(.bold)
                        } else {
                            Text("$0.20/each")
                                .font(BrutalistTheme.Typography.caption)
                                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                        }
                    }
                }
                .padding(BrutalistTheme.Spacing.lg)
            }
            .background(BrutalistTheme.Colors.background)
            .brutalistBorder(width: creditProduct == .credits50 ? 4 : 3)
            .brutalistShadow(offset: creditProduct == .credits50 ? 6 : 5)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
            infoRow(icon: "checkmark.circle.fill", text: "3 free analyses included")
            infoRow(icon: "bolt.fill", text: "AI-powered recommendations")
            infoRow(icon: "arrow.clockwise", text: "Credits never expire")
            infoRow(icon: "lock.shield.fill", text: "Secure Apple payment")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrutalistTheme.Spacing.lg)
        .background(BrutalistTheme.Colors.cardBackground)
        .brutalistBorder()
    }
    
    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: BrutalistTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(BrutalistTheme.Colors.action)
            
            Text(text)
                .font(BrutalistTheme.Typography.body)
                .foregroundColor(BrutalistTheme.Colors.text)
        }
    }
    
    // MARK: - Restore Button
    
    private var restoreButton: some View {
        Button(action: {
            Task {
                await storeManager.restorePurchases()
            }
        }) {
            Text("RESTORE PURCHASES")
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                .underline()
        }
        .padding(.top, BrutalistTheme.Spacing.sm)
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: BrutalistTheme.Spacing.md) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(BrutalistTheme.Colors.action)
                
                Text("PROCESSING...")
                    .font(BrutalistTheme.Typography.body)
                    .fontWeight(.bold)
                    .foregroundColor(BrutalistTheme.Colors.background)
            }
            .padding(BrutalistTheme.Spacing.xl)
            .background(BrutalistTheme.Colors.text)
            .brutalistBorder(color: BrutalistTheme.Colors.action)
        }
    }
}

// MARK: - Preview

#Preview {
    PurchaseCreditsView()
        .environmentObject(StoreManager())
}
