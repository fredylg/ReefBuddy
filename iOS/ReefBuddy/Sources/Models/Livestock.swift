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

    /// Photo data filename or URL (optional)
    var photoData: Data?

    /// Notes about this livestock
    var notes: String?

    /// Date record was created
    let createdAt: Date

    /// Date record was last updated
    var updatedAt: Date

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

    /// Photo data for this log entry (optional)
    var photoData: Data?

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
    /// Sample livestock for previews and testing
    static let samples: [Livestock] = [
        Livestock(
            tankId: Tank.sample.id,
            name: "Green Slimer",
            scientificName: "Acropora yongei",
            category: .sps,
            healthStatus: .thriving,
            quantity: 1,
            purchaseDate: Date().addingTimeInterval(-86400 * 90),
            purchasePrice: 75.00,
            notes: "Fast grower, positioned high in tank"
        ),
        Livestock(
            tankId: Tank.sample.id,
            name: "Hammer Coral",
            scientificName: "Euphyllia ancora",
            category: .lps,
            healthStatus: .healthy,
            quantity: 1,
            purchaseDate: Date().addingTimeInterval(-86400 * 60),
            purchasePrice: 65.00,
            notes: "Wall hammer, 8 heads"
        ),
        Livestock(
            tankId: Tank.sample.id,
            name: "Ocellaris Clownfish",
            scientificName: "Amphiprion ocellaris",
            category: .fish,
            healthStatus: .thriving,
            quantity: 2,
            purchaseDate: Date().addingTimeInterval(-86400 * 180),
            purchasePrice: 40.00,
            notes: "Bonded pair, hosted by bubble tip anemone"
        ),
        Livestock(
            tankId: Tank.sample.id,
            name: "Bubble Tip Anemone",
            scientificName: "Entacmaea quadricolor",
            category: .anemone,
            healthStatus: .healthy,
            quantity: 1,
            purchaseDate: Date().addingTimeInterval(-86400 * 120),
            purchasePrice: 50.00,
            notes: "Rose color variety"
        ),
        Livestock(
            tankId: Tank.sample.id,
            name: "Zoanthid Colony",
            category: .softCoral,
            healthStatus: .stressed,
            quantity: 1,
            purchaseDate: Date().addingTimeInterval(-86400 * 14),
            purchasePrice: 35.00,
            notes: "Mixed zoa garden, some polyps not opening"
        ),
        Livestock(
            tankId: Tank.sample.id,
            name: "Emerald Crab",
            scientificName: "Mithraculus sculptus",
            category: .invertebrate,
            healthStatus: .healthy,
            quantity: 2,
            purchaseDate: Date().addingTimeInterval(-86400 * 45),
            purchasePrice: 12.00,
            notes: "Good algae cleaners"
        )
    ]

    static let sample = samples[0]
}

extension LivestockLog {
    /// Sample logs for previews and testing
    static let samples: [LivestockLog] = [
        LivestockLog(
            livestockId: Livestock.sample.id,
            loggedAt: Date(),
            healthStatus: .thriving,
            notes: "New growth tips showing, polyp extension excellent"
        ),
        LivestockLog(
            livestockId: Livestock.sample.id,
            loggedAt: Date().addingTimeInterval(-86400 * 7),
            healthStatus: .healthy,
            notes: "Good coloration, moved to higher light"
        ),
        LivestockLog(
            livestockId: Livestock.sample.id,
            loggedAt: Date().addingTimeInterval(-86400 * 14),
            healthStatus: .stressed,
            notes: "Slight bleaching after new lights installed"
        ),
        LivestockLog(
            livestockId: Livestock.sample.id,
            loggedAt: Date().addingTimeInterval(-86400 * 30),
            healthStatus: .healthy,
            notes: "Acclimated well after dip and quarantine"
        )
    ]

    static let sample = samples[0]
}

// MARK: - API Request Models

/// Request body for creating new livestock via API
struct CreateLivestockRequest: Codable {
    let tankId: UUID
    let name: String
    let scientificName: String?
    let category: String
    let healthStatus: String
    let quantity: Int
    let purchaseDate: Date
    let purchasePrice: Double?
    let notes: String?

    init(from livestock: Livestock) {
        self.tankId = livestock.tankId
        self.name = livestock.name
        self.scientificName = livestock.scientificName
        self.category = livestock.category.rawValue
        self.healthStatus = livestock.healthStatus.rawValue
        self.quantity = livestock.quantity
        self.purchaseDate = livestock.purchaseDate
        self.purchasePrice = livestock.purchasePrice
        self.notes = livestock.notes
    }
}
