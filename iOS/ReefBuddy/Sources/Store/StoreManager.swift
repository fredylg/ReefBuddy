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

        // For development: initialize with default credits if fetch fails
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
            await MainActor.run {
                if creditBalance == nil {
                    print("📱 Initializing with default credits for development")
                    creditBalance = CreditBalance(freeRemaining: 3, paidCredits: 0, totalCredits: 3, totalAnalyses: 0)
                }
            }
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
                    // Send receipt to backend for validation and credit addition
                    let success = await validateAndAddCredits(for: transaction, productId: product.id)
                    
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
    
    // MARK: - Receipt Validation
    
    /// Validate transaction with backend and add credits
    private func validateAndAddCredits(for transaction: Transaction, productId: String) async -> Bool {
        // Get the App Store receipt
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              let receiptData = try? Data(contentsOf: receiptURL) else {
            purchaseError = "Could not retrieve purchase receipt"
            return false
        }
        
        let receiptString = receiptData.base64EncodedString()
        
        do {
            let response = try await apiClient.purchaseCredits(
                deviceId: deviceId,
                receiptData: receiptString,
                productId: productId
            )
            
            // Update local credit balance
            creditBalance = CreditBalance(
                freeRemaining: response.newBalance.freeRemaining,
                paidCredits: response.newBalance.paidCredits,
                totalCredits: response.newBalance.totalCredits,
                totalAnalyses: creditBalance?.totalAnalyses ?? 0
            )
            
            return true
        } catch {
            print("Failed to validate purchase with server: \(error)")

            // For development/testing: allow local credit addition when backend unavailable
            // This allows testing the purchase flow without deployed backend
            #if DEBUG
            print("DEBUG: Adding credits locally due to server unavailability")
            await addCreditsLocally(for: productId)
            purchaseError = "Purchase completed (local mode - server unavailable)"
            return true
            #else
            // In production/TestFlight, server validation is required
            purchaseError = "Server validation failed: \(error.localizedDescription)"
            return false
            #endif
        }
    }
    
    // MARK: - Credit Balance
    
    /// Fetch current credit balance from server
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
        }
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

    /// Add credits locally (for development when server validation unavailable)
    private func addCreditsLocally(for productId: String) async {
        let creditsToAdd: Int
        switch productId {
        case "com.reefbuddy.credits5":
            creditsToAdd = 5
        case "com.reefbuddy.credits50":
            creditsToAdd = 50
        default:
            print("Unknown product ID: \(productId)")
            return
        }

        guard let currentBalance = creditBalance else {
            // Initialize with credits if no balance exists
            creditBalance = CreditBalance(
                freeRemaining: 3, // Keep free credits
                paidCredits: creditsToAdd,
                totalCredits: 3 + creditsToAdd,
                totalAnalyses: 0
            )
            return
        }

        // Add to existing paid credits
        let newBalance = CreditBalance(
            freeRemaining: currentBalance.freeRemaining,
            paidCredits: currentBalance.paidCredits + creditsToAdd,
            totalCredits: currentBalance.totalCredits + creditsToAdd,
            totalAnalyses: currentBalance.totalAnalyses
        )

        creditBalance = newBalance
        print("💰 DEBUG: Added \(creditsToAdd) credits locally. New balance: free=\(newBalance.freeRemaining), paid=\(newBalance.paidCredits), total=\(newBalance.totalCredits)")
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
                    // Validate with backend
                    await self.validateAndAddCredits(for: transaction, productId: transaction.productID)
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
