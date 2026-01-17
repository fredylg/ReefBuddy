import Foundation
import StoreKit

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
    
    var displayPrice: String {
        switch self {
        case .credits5: return "$0.99"
        case .credits50: return "$4.99"
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
class StoreManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseInProgress = false
    @Published private(set) var purchaseError: String?
    @Published private(set) var creditBalance: CreditBalance?
    
    // MARK: - Private Properties
    
    private var productIDs: Set<String> {
        Set(CreditProduct.allCases.map { $0.rawValue })
    }
    
    private var updateListenerTask: Task<Void, Error>?
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
    
    /// Get the device identifier for credit tracking
    var deviceId: String {
        // Use identifierForVendor which persists across app reinstalls
        // but is unique per device per vendor
        if let id = UIDevice.current.identifierForVendor?.uuidString {
            return id
        }
        
        // Fallback to stored UUID if vendor ID unavailable
        let key = "ReefBuddy.DeviceID"
        if let storedId = UserDefaults.standard.string(forKey: key) {
            return storedId
        }
        
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
    
    // MARK: - Product Loading
    
    /// Load available products from App Store
    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
                .sorted { $0.price < $1.price }
            print("Loaded \(products.count) products")
        } catch {
            print("Failed to load products: \(error)")
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
        // Use a unique identifier for this validation attempt
        // StoreKit 2 transaction IDs might be 0 in sandbox, so we'll use a UUID
        let transactionId = UUID().uuidString
        let originalTransactionId = String(transaction.originalID)

        print("📦 Sending JWS to backend for validation (transactionId: \(transactionId), originalId: \(originalTransactionId))")
        print("🔐 JWS Representation: \(jwsRepresentation)")

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

            print("✅ Purchase validated, credits added: \(response.creditsAdded)")
            return true
        } catch {
            print("❌ Failed to validate purchase with server: \(error)")
            purchaseError = "Server validation failed: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Credit Balance
    
    /// Fetch current credit balance from server
    /// If fetch fails, initializes with default 3 free credits for offline use
    func fetchCreditBalance() async {
        do {
            let balance = try await apiClient.getCreditsBalance(deviceId: deviceId)
            let newBalance = CreditBalance(
                freeRemaining: balance.freeRemaining,
                paidCredits: balance.paidCredits,
                totalCredits: balance.totalCredits,
                totalAnalyses: balance.totalAnalyses
            )
            print("📡 Fetched credit balance: free=\(newBalance.freeRemaining), paid=\(newBalance.paidCredits), total=\(newBalance.totalCredits)")
            creditBalance = newBalance
        } catch {
            print("❌ Failed to fetch credit balance: \(error)")
            // Initialize with default 3 free credits for offline/development use
            // This ensures credit tracking works even without backend connectivity
            if creditBalance == nil {
                let defaultBalance = CreditBalance(
                    freeRemaining: 3,
                    paidCredits: 0,
                    totalCredits: 3,
                    totalAnalyses: 0
                )
                print("📱 Initialized default credit balance: 3 free credits")
                creditBalance = defaultBalance
            }
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
        print("🔄 Updating credit balance: free=\(mergedBalance.freeRemaining), paid=\(mergedBalance.paidCredits), total=\(mergedBalance.totalCredits)")
        creditBalance = mergedBalance
    }


    /// Decrement local credit balance (for development when backend is unavailable)
    func decrementLocalCredit() {
        guard let currentBalance = creditBalance else {
            print("⚠️ No credit balance to decrement")
            return
        }

        // Decrement free credits first, then paid credits
        let newFreeRemaining: Int
        let newPaidCredits: Int

        if currentBalance.freeRemaining > 0 {
            newFreeRemaining = currentBalance.freeRemaining - 1
            newPaidCredits = currentBalance.paidCredits
        } else if currentBalance.paidCredits > 0 {
            newFreeRemaining = currentBalance.freeRemaining
            newPaidCredits = currentBalance.paidCredits - 1
        } else {
            print("⚠️ No credits available to decrement")
            return
        }

        let newBalance = CreditBalance(
            freeRemaining: newFreeRemaining,
            paidCredits: newPaidCredits,
            totalCredits: newFreeRemaining + newPaidCredits,
            totalAnalyses: currentBalance.totalAnalyses + 1
        )

        print("📱 Decremented local credit: free=\(newBalance.freeRemaining), paid=\(newBalance.paidCredits), total=\(newBalance.totalCredits)")
        creditBalance = newBalance
    }
    
    // MARK: - Transaction Listener
    
    /// Listen for transaction updates (renewals, purchases from other devices, etc.)
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    // Get JWS from VerificationResult and validate with backend
                    let jwsRepresentation = result.jwsRepresentation
                    await self.validateAndAddCredits(
                        for: transaction,
                        jwsRepresentation: jwsRepresentation,
                        productId: transaction.productID
                    )
                    await transaction.finish()

                case .unverified(_, let error):
                    print("Unverified transaction update: \(error)")
                }
            }
        }
    }
    
    // MARK: - Restore Purchases
    
    /// Restore previous purchases (for consumables, this syncs any pending transactions)
    func restorePurchases() async {
        purchaseInProgress = true
        purchaseError = nil
        
        do {
            try await AppStore.sync()
            await fetchCreditBalance()
        } catch {
            purchaseError = "Failed to restore purchases: \(error.localizedDescription)"
        }
        
        purchaseInProgress = false
    }
}
