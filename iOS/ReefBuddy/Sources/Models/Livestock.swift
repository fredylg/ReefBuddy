import Foundation

// MARK: - Livestock Category

/// Category of livestock in a saltwater aquarium
enum LivestockCategory: String, Codable, CaseIterable, Identifiable {
    case sps = "sps"
    case lps = "lps"
    case softCoral = "soft_coral"
    case fish = "fish"
    case invertebrate = "invertebrate"
    case anemone = "anemone"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sps:
            return "SPS"
        case .lps:
            return "LPS"
        case .softCoral:
            return "Soft Coral"
        case .fish:
            return "Fish"
        case .invertebrate:
            return "Invertebrate"
        case .anemone:
            return "Anemone"
        case .other:
            return "Other"
        }
    }

    var icon: String {
        switch self {
        case .sps:
            return "leaf.fill"
        case .lps:
            return "leaf.circle.fill"
        case .softCoral:
            return "cloud.fill"
        case .fish:
            return "fish.fill"
        case .invertebrate:
            return "ladybug.fill"
        case .anemone:
            return "sparkles"
        case .other:
            return "questionmark.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .sps:
            return "Small Polyp Stony corals (Acropora, Montipora, etc.)"
        case .lps:
            return "Large Polyp Stony corals (Hammer, Torch, Frogspawn, etc.)"
        case .softCoral:
            return "Soft corals (Mushrooms, Zoanthids, Leathers, etc.)"
        case .fish:
            return "Marine fish species"
        case .invertebrate:
            return "Shrimp, crabs, snails, and other invertebrates"
        case .anemone:
            return "Sea anemones (Bubble tip, Long tentacle, etc.)"
        case .other:
            return "Other livestock types"
        }
    }
}

// MARK: - Health Status

/// Health status of livestock
enum HealthStatus: String, Codable, CaseIterable, Identifiable {
    case thriving = "thriving"
    case healthy = "healthy"
    case stressed = "stressed"
    case declining = "declining"
    case critical = "critical"
    case deceased = "deceased"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .thriving:
            return "THRIVING"
        case .healthy:
            return "HEALTHY"
        case .stressed:
            return "STRESSED"
        case .declining:
            return "DECLINING"
        case .critical:
            return "CRITICAL"
        case .deceased:
            return "DECEASED"
        }
    }

    var icon: String {
        switch self {
        case .thriving:
            return "star.fill"
        case .healthy:
            return "checkmark.circle.fill"
        case .stressed:
            return "exclamationmark.triangle.fill"
        case .declining:
            return "arrow.down.circle.fill"
        case .critical:
            return "xmark.octagon.fill"
        case .deceased:
            return "heart.slash.fill"
        }
    }

    /// Returns true if status indicates concern (warning color)
    var isWarning: Bool {
        switch self {
        case .thriving, .healthy:
            return false
        case .stressed, .declining, .critical, .deceased:
            return true
        }
    }
}

// MARK: - Livestock Model

/// Represents a livestock item (coral, fish, invertebrate) in a tank
struct Livestock: Identifiable, Codable, Equatable {

    // MARK: - Properties

    /// Unique identifier
    let id: UUID

    /// The tank this livestock belongs to
    let tankId: UUID

    /// Species or common name
    var name: String

    /// Scientific name (optional)
    var scientificName: String?

    /// Category of livestock
    var category: LivestockCategory

    /// Current health status
    var healthStatus: HealthStatus

    /// Quantity (for colonies, schools, etc.)
    var quantity: Int

    /// Date when the livestock was purchased/added
    var purchaseDate: Date

    /// Purchase price (optional)
    var purchasePrice: Double?

    /// Photo data - NOT encoded to UserDefaults (stored in file system via ImageStorage)
    var photoData: Data?

    /// Notes about this livestock
    var notes: String?

    /// Date record was created
    let createdAt: Date

    /// Date record was last updated
    var updatedAt: Date

    // MARK: - Coding Keys

    /// Exclude photoData from encoding to prevent UserDefaults size limit issues
    /// Images are stored separately in the file system via ImageStorage
    private enum CodingKeys: String, CodingKey {
        case id, tankId, name, scientificName, category, healthStatus
        case quantity, purchaseDate, purchasePrice, notes, createdAt, updatedAt
        // photoData intentionally excluded - stored in file system
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        tankId: UUID,
        name: String,
        scientificName: String? = nil,
        category: LivestockCategory,
        healthStatus: HealthStatus = .healthy,
        quantity: Int = 1,
        purchaseDate: Date = Date(),
        purchasePrice: Double? = nil,
        photoData: Data? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.tankId = tankId
        self.name = name
        self.scientificName = scientificName
        self.category = category
        self.healthStatus = healthStatus
        self.quantity = quantity
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.photoData = photoData
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Livestock Health Log

/// A health log entry for tracking livestock condition over time
struct LivestockLog: Identifiable, Codable, Equatable {

    // MARK: - Properties

    /// Unique identifier
    let id: UUID

    /// The livestock this log belongs to
    let livestockId: UUID

    /// Date and time of the log entry
    let loggedAt: Date

    /// Health status at time of logging
    var healthStatus: HealthStatus

    /// Observations or notes
    var notes: String?

    /// Photo data - NOT encoded to UserDefaults (stored in file system via ImageStorage)
    var photoData: Data?

    // MARK: - Coding Keys

    /// Exclude photoData from encoding to prevent UserDefaults size limit issues
    /// Images are stored separately in the file system via ImageStorage
    private enum CodingKeys: String, CodingKey {
        case id, livestockId, loggedAt, healthStatus, notes
        // photoData intentionally excluded - stored in file system
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        livestockId: UUID,
        loggedAt: Date = Date(),
        healthStatus: HealthStatus,
        notes: String? = nil,
        photoData: Data? = nil
    ) {
        self.id = id
        self.livestockId = livestockId
        self.loggedAt = loggedAt
        self.healthStatus = healthStatus
        self.notes = notes
        self.photoData = photoData
    }
}

// MARK: - Sample Data

extension Livestock {
    /// Sample livestock for previews and testing (empty for clean start)
    static let samples: [Livestock] = []

    /// Single sample for previews
    static let sample = Livestock(
        tankId: Tank.sample.id,
        name: "Sample Coral",
        category: .lps,
        healthStatus: .healthy,
        quantity: 1,
        purchaseDate: Date()
    )
}

extension LivestockLog {
    /// Sample logs for previews and testing (empty for clean start)
    static let samples: [LivestockLog] = []

    /// Single sample for previews
    static let sample = LivestockLog(
        livestockId: Livestock.sample.id,
        loggedAt: Date(),
        healthStatus: .healthy,
        notes: "Sample log entry"
    )
}

// MARK: - API Request Models

/// Request body for creating new livestock via API
struct CreateLivestockRequest: Codable {
    let name: String
    let species: String?
    let category: String
    let quantity: Int
    let purchaseDate: String?
    let purchasePrice: Double?
    let healthStatus: String?
    let notes: String?
    let imageUrl: String?

    init(from livestock: Livestock) {
        self.name = livestock.name
        self.species = livestock.scientificName
        // Convert iOS category to backend format (SPS, LPS, Soft, Fish, Invertebrate)
        switch livestock.category {
        case .sps:
            self.category = "SPS"
        case .lps:
            self.category = "LPS"
        case .softCoral:
            self.category = "Soft"
        case .fish:
            self.category = "Fish"
        case .invertebrate:
            self.category = "Invertebrate"
        case .anemone:
            self.category = "Invertebrate" // Map anemone to Invertebrate for backend
        case .other:
            self.category = "Invertebrate" // Map other to Invertebrate for backend
        }
        self.quantity = livestock.quantity
        // Convert Date to ISO 8601 string
        let formatter = ISO8601DateFormatter()
        self.purchaseDate = formatter.string(from: livestock.purchaseDate)
        self.purchasePrice = livestock.purchasePrice
        self.healthStatus = livestock.healthStatus.rawValue
        self.notes = livestock.notes
        self.imageUrl = nil // Image upload handled separately if needed
    }
}

/// Request body for updating livestock via API
struct UpdateLivestockRequest: Codable {
    let name: String?
    let species: String?
    let category: String?
    let quantity: Int?
    let purchaseDate: String?
    let purchasePrice: Double?
    let healthStatus: String?
    let notes: String?
    let imageUrl: String?

    init(from livestock: Livestock) {
        self.name = livestock.name
        self.species = livestock.scientificName
        self.category = livestock.category.rawValue
        self.quantity = livestock.quantity
        let formatter = ISO8601DateFormatter()
        self.purchaseDate = formatter.string(from: livestock.purchaseDate)
        self.purchasePrice = livestock.purchasePrice
        self.healthStatus = livestock.healthStatus.rawValue
        self.notes = livestock.notes
        self.imageUrl = nil
    }
}

/// Response from livestock creation endpoint
struct LivestockCreateResponse: Codable {
    let success: Bool
    let livestock: LivestockDBRecord
    
    struct LivestockDBRecord: Codable {
        let id: String
        let tankId: String
        let name: String
        let species: String?
        let category: String
        let quantity: Int
        let purchaseDate: String?
        let purchasePrice: Double?
        let healthStatus: String?
        let notes: String?
        let imageUrl: String?
        let addedAt: String
        let createdAt: String
    }
}

/// Response from livestock list endpoint
struct LivestockListResponse: Codable {
    let success: Bool
    let livestock: [LivestockDBRecord]
    
    struct LivestockDBRecord: Codable {
        let id: String
        let tankId: String
        let name: String
        let species: String?
        let category: String?
        let quantity: Int
        let purchaseDate: String?
        let purchasePrice: Double?
        let healthStatus: String?
        let notes: String?
        let imageUrl: String?
        let addedAt: String
        let createdAt: String
    }
}

/// Response from livestock update endpoint
struct LivestockUpdateResponse: Codable {
    let success: Bool
    let livestock: LivestockDBRecord
    
    struct LivestockDBRecord: Codable {
        let id: String
        let tankId: String
        let name: String
        let species: String?
        let category: String?
        let quantity: Int
        let purchaseDate: String?
        let purchasePrice: Double?
        let healthStatus: String?
        let notes: String?
        let imageUrl: String?
        let addedAt: String
        let createdAt: String
    }
}
