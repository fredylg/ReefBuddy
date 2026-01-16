import Foundation

// MARK: - User Model

/// Represents a ReefBuddy user account
struct User: Identifiable, Codable, Equatable {

    // MARK: - Properties

    /// Unique identifier for the user
    let id: UUID

    /// User's email address
    var email: String

    /// User's display name (optional)
    var displayName: String?

    /// Date the account was created
    let createdAt: Date

    /// Date of last update
    var updatedAt: Date

    /// User's subscription tier
    var subscriptionTier: SubscriptionTier

    /// Number of free analyses used this month
    var analysesUsedThisMonth: Int

    /// Date when the monthly counter resets
    var monthlyResetDate: Date

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        email: String,
        displayName: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        subscriptionTier: SubscriptionTier = .free,
        analysesUsedThisMonth: Int = 0,
        monthlyResetDate: Date = Date().startOfNextMonth
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.subscriptionTier = subscriptionTier
        self.analysesUsedThisMonth = analysesUsedThisMonth
        self.monthlyResetDate = monthlyResetDate
    }

    // MARK: - Computed Properties

    /// Returns the user's name or email prefix as display
    var displayIdentifier: String {
        if let name = displayName, !name.isEmpty {
            return name
        }
        return email.components(separatedBy: "@").first ?? email
    }

    /// Free analyses remaining this month
    var freeAnalysesRemaining: Int {
        max(0, subscriptionTier.monthlyAnalysisLimit - analysesUsedThisMonth)
    }

    /// Whether the user can perform an analysis
    var canPerformAnalysis: Bool {
        subscriptionTier == .premium || freeAnalysesRemaining > 0
    }
}

// MARK: - Subscription Tier

/// User subscription levels
enum SubscriptionTier: String, Codable, CaseIterable {
    case free = "free"
    case premium = "premium"

    /// Monthly analysis limit for this tier
    var monthlyAnalysisLimit: Int {
        switch self {
        case .free:
            return 3
        case .premium:
            return .max
        }
    }

    /// Display name for the tier
    var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .premium:
            return "Premium"
        }
    }

    /// Description of the tier benefits
    var description: String {
        switch self {
        case .free:
            return "3 AI analyses per month"
        case .premium:
            return "Unlimited AI analyses"
        }
    }
}

// MARK: - Authentication State

/// Represents the current authentication state
enum AuthState: Equatable {
    /// User is not authenticated
    case unauthenticated

    /// Authentication is in progress
    case authenticating

    /// User is authenticated
    case authenticated(User)

    /// Authentication failed
    case failed(String)

    /// Returns the authenticated user if available
    var user: User? {
        if case .authenticated(let user) = self {
            return user
        }
        return nil
    }

    /// Whether the user is currently authenticated
    var isAuthenticated: Bool {
        if case .authenticated = self {
            return true
        }
        return false
    }
}

// MARK: - Auth Request/Response Models

/// Login request body
struct LoginRequest: Codable {
    let email: String
    let password: String
}

/// Registration request body
struct RegisterRequest: Codable {
    let email: String
    let password: String
    let displayName: String?
}

/// Authentication response from the server
struct AuthResponse: Codable {
    let user: User
    let token: String
    let expiresAt: Date
}

/// Token refresh response
struct RefreshResponse: Codable {
    let token: String
    let expiresAt: Date
}

// MARK: - Date Extension

extension Date {
    /// Returns the start of next month
    var startOfNextMonth: Date {
        let calendar = Calendar.current
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: self) else {
            return self
        }
        let components = calendar.dateComponents([.year, .month], from: nextMonth)
        return calendar.date(from: components) ?? self
    }
}

// MARK: - Sample Data

extension User {
    /// Sample user for previews and testing
    static let sample = User(
        email: "reefkeeper@example.com",
        displayName: "Reef Keeper",
        subscriptionTier: .free,
        analysesUsedThisMonth: 1
    )

    /// Premium sample user
    static let premiumSample = User(
        email: "premium@example.com",
        displayName: "Premium Reefer",
        subscriptionTier: .premium
    )
}
