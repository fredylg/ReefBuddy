import Foundation
import Observation
import StoreKit
import os

private let log = Logger(subsystem: "au.com.aethers.reefbuddy", category: "Store")

// MARK: - Product Definitions

/// Credit pack products available for purchase
enum CreditProduct: String, CaseIterable {
    case credits5 = "com.reefbuddy.credits5"   // 5 credits for $0.99
    case credits50 = "com.reefbuddy.credits50" // 50 credits for $4.99
    
    var credits: Int {
        switch self {
        case .credits5: return 5
        case .credits50: return 50
        }
    }
    
    var displayName: String {
        switch self {
        case .credits5: return "5 CREDITS"
        case .credits50: return "50 CREDITS"
        }
    }
    
    var savingsText: String? {
        switch self {
        case .credits5: return nil
        case .credits50: return "BEST VALUE - SAVE 50%"
        }
    }
}

// MARK: - Store Manager

/// Manages in-app purchases using StoreKit 2
@MainActor
@Observable
final class StoreManager {
    
    // MARK: - Published Properties
    
    private(set) var products: [Product] = []
    private(set) var purchaseInProgress = false
    private(set) var purchaseError: String?
    private(set) var creditBalance: CreditBalance?
    /// True when no balance could be loaded yet (offline or server error); the analyze button waits.
    private(set) var balanceUnavailable = false
    
    // MARK: - Private Properties
    
    private var productIDs: Set<String> {
        Set(CreditProduct.allCases.map { $0.rawValue })
    }
    
    /// Not observed (nothing renders it) and plain-stored so `deinit` can cancel it.
    @ObservationIgnored private var updateListenerTask: Task<Void, Error>?
    private let apiClient: APIClient
    
    // MARK: - Credit Balance Model
    
    
    // MARK: - Initialization
    
    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
        
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        // Load products
        Task {
            await loadProducts()
        }

        // Fetch initial credit balance
        Task {
            await fetchCreditBalance()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Device ID
    
    /// Stable anonymous device identifier (Keychain-backed, see DeviceIdentity).
    var deviceId: String { DeviceIdentity.deviceId }

    /// Clear the last purchase error (bound to the purchase alert).
    func clearError() {
        purchaseError = nil
    }

    /// Storefront price for a pack, from StoreKit (never hardcoded; wrong in most storefronts otherwise).
    func displayPrice(for creditProduct: CreditProduct) -> String? {
        products.first(where: { $0.id == creditProduct.rawValue })?.displayPrice
    }

    /// Per-credit price in the storefront currency, e.g. "$0.10".
    func perCreditPrice(for creditProduct: CreditProduct) -> String? {
        guard let product = products.first(where: { $0.id == creditProduct.rawValue }), creditProduct.credits > 0 else { return nil }
        let each = product.price / Decimal(creditProduct.credits)
        return each.formatted(product.priceFormatStyle)
    }
    
    // MARK: - Product Loading
    
    /// Load available products from App Store
    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
                .sorted { $0.price < $1.price }
            log.info("Loaded \(self.products.count) products")
        } catch {
            log.error("Failed to load products: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    // MARK: - Purchase Flow
    
    /// Purchase a credit pack
    func purchase(_ creditProduct: CreditProduct) async -> Bool {
        guard let product = products.first(where: { $0.id == creditProduct.rawValue }) else {
            purchaseError = "Product not available"
            return false
        }
        
        return await purchase(product)
    }
    
    /// Purchase a specific product
    func purchase(_ product: Product) async -> Bool {
        purchaseInProgress = true
        purchaseError = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Verify the transaction
                switch verification {
                case .verified(let transaction):
                    // Get JWS from VerificationResult (not Transaction)
                    let jwsRepresentation = verification.jwsRepresentation

                    // Send JWS to backend for validation and credit addition
                    let success = await validateAndAddCredits(
                        for: transaction,
                        jwsRepresentation: jwsRepresentation,
                        productId: product.id
                    )

                    if success {
                        // Mark transaction as finished
                        await transaction.finish()
                        purchaseInProgress = false
                        return true
                    } else {
                        purchaseError = "Failed to validate purchase with server"
                        purchaseInProgress = false
                        return false
                    }

                case .unverified(_, let error):
                    purchaseError = "Purchase verification failed: \(error.localizedDescription)"
                    purchaseInProgress = false
                    return false
                }
                
            case .pending:
                purchaseError = "Purchase is pending approval"
                purchaseInProgress = false
                return false
                
            case .userCancelled:
                purchaseInProgress = false
                return false
                
            @unknown default:
                purchaseError = "Unknown purchase result"
                purchaseInProgress = false
                return false
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
            purchaseInProgress = false
            return false
        }
    }
    
    // MARK: - Transaction Validation (StoreKit 2)

    /// Validate transaction with backend using StoreKit 2 JWS
    /// - Parameters:
    ///   - transaction: The verified Transaction from StoreKit 2
    ///   - jwsRepresentation: The JWS string from VerificationResult.jwsRepresentation
    ///   - productId: The product ID being purchased
    private func validateAndAddCredits(
        for transaction: Transaction,
        jwsRepresentation: String,
        productId: String
    ) async -> Bool {
        // Informational only: the server takes the authoritative id from the signed payload.
        let transactionId = String(transaction.id)
        let originalTransactionId = String(transaction.originalID)
        log.info("Validating transaction \(transactionId, privacy: .private) for \(productId, privacy: .public)")

        do {
            let response = try await apiClient.purchaseCredits(
                deviceId: deviceId,
                jwsRepresentation: jwsRepresentation,
                transactionId: transactionId,
                originalTransactionId: originalTransactionId,
                productId: productId
            )

            // Update local credit balance
            creditBalance = CreditBalance(
                freeRemaining: response.newBalance.freeRemaining,
                paidCredits: response.newBalance.paidCredits,
                totalCredits: response.newBalance.totalCredits,
                totalAnalyses: creditBalance?.totalAnalyses ?? 0
            )

            log.info("Purchase validated, credits added: \(response.creditsAdded)")
            return true
        } catch {
            log.error("Purchase validation failed: \(error.localizedDescription, privacy: .public)")
            purchaseError = "Server validation failed: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Credit Balance
    
    /// Fetch the current credit balance. On failure the balance stays as it was (or nil); the UI shows
    /// "unavailable" rather than inventing free credits (I-16).
    func fetchCreditBalance() async {
        do {
            let balance = try await apiClient.getCreditsBalance(deviceId: deviceId)
            creditBalance = CreditBalance(
                freeRemaining: balance.freeRemaining,
                paidCredits: balance.paidCredits,
                totalCredits: balance.totalCredits,
                totalAnalyses: balance.totalAnalyses
            )
            balanceUnavailable = false
        } catch {
            log.error("Failed to fetch credit balance: \(error.localizedDescription, privacy: .public)")
            balanceUnavailable = creditBalance == nil
        }
    }

    /// Check if user has credits available for analysis
    var hasCredits: Bool {
        guard let balance = creditBalance else {
            // If no balance info, assume no credits (fail safe)
            return false
        }
        return balance.totalCredits > 0
    }

    /// Get the total number of credits available
    var totalCredits: Int {
        return creditBalance?.totalCredits ?? 0
    }

    /// Update credit balance with new values (used after analysis)
    func updateCreditBalance(_ newBalance: CreditBalance) {
        // Preserve totalAnalyses if the new balance has the sentinel value -1
        let mergedBalance = CreditBalance(
            freeRemaining: newBalance.freeRemaining,
            paidCredits: newBalance.paidCredits,
            totalCredits: newBalance.totalCredits,
            totalAnalyses: newBalance.totalAnalyses == -1 ? (creditBalance?.totalAnalyses ?? 0) : newBalance.totalAnalyses
        )
        creditBalance = mergedBalance
        balanceUnavailable = false
    }

    
    // MARK: - Transaction Listener
    
    /// Listen for transaction updates (renewals, purchases from other devices, etc.)
    private func listenForTransactions() -> Task<Void, Error> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handle(transactionResult: result)
            }
        }
    }

    /// Validate a transaction with the server and finish it only once credits were granted; an
    /// unfinished transaction is redelivered by StoreKit, a finished one is gone for good (I-13).
    private func handle(transactionResult result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            let granted = await validateAndAddCredits(for: transaction, jwsRepresentation: result.jwsRepresentation, productId: transaction.productID)
            if granted {
                await transaction.finish()
            } else {
                log.error("Leaving transaction \(String(transaction.id), privacy: .private) unfinished for redelivery")
            }
        case .unverified(_, let error):
            log.error("Unverified transaction update: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Restore Purchases
    
    /// Consumables cannot be "restored"; what can be recovered is a purchase that was never granted.
    /// Replay every unfinished transaction, then refresh the balance (I-18).
    func restorePurchases() async {
        purchaseInProgress = true
        purchaseError = nil
        var replayed = 0
        for await result in Transaction.unfinished {
            await handle(transactionResult: result)
            replayed += 1
        }
        await fetchCreditBalance()
        if replayed == 0 {
            purchaseError = "No pending purchases to restore. Your balance is up to date."
        }
        purchaseInProgress = false
    }
}
