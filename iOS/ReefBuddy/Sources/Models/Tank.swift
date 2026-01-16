import Foundation

// MARK: - Tank Model

/// Represents a saltwater aquarium tank owned by a user
struct Tank: Identifiable, Codable, Equatable {

    // MARK: - Properties

    /// Unique identifier for the tank
    let id: UUID

    /// User-defined name for the tank (e.g., "Living Room Reef", "Office Nano")
    var name: String

    /// Tank volume in gallons
    var volumeGallons: Double

    /// Type of tank setup
    var tankType: TankType

    /// Date the tank was created/started
    let createdAt: Date

    /// Date of last modification
    var updatedAt: Date

    /// Optional notes about the tank
    var notes: String?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        volumeGallons: Double,
        tankType: TankType = .mixedReef,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.volumeGallons = volumeGallons
        self.tankType = tankType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.notes = notes
    }
}

// MARK: - Tank Type

/// The type of saltwater tank setup
enum TankType: String, Codable, CaseIterable {
    case fishOnly = "fish_only"
    case fowlr = "fowlr" // Fish Only With Live Rock
    case softCoralOnly = "soft_coral"
    case lps = "lps" // Large Polyp Stony
    case sps = "sps" // Small Polyp Stony
    case mixedReef = "mixed_reef"
    case nano = "nano"

    var displayName: String {
        switch self {
        case .fishOnly:
            return "Fish Only"
        case .fowlr:
            return "FOWLR"
        case .softCoralOnly:
            return "Soft Coral"
        case .lps:
            return "LPS Dominant"
        case .sps:
            return "SPS Dominant"
        case .mixedReef:
            return "Mixed Reef"
        case .nano:
            return "Nano Reef"
        }
    }

    var description: String {
        switch self {
        case .fishOnly:
            return "Fish only, no corals"
        case .fowlr:
            return "Fish only with live rock"
        case .softCoralOnly:
            return "Soft corals and mushrooms"
        case .lps:
            return "Large polyp stony corals"
        case .sps:
            return "Small polyp stony corals"
        case .mixedReef:
            return "Mix of soft, LPS, and SPS corals"
        case .nano:
            return "Small tank under 30 gallons"
        }
    }
}

// MARK: - Sample Data

extension Tank {
    /// Sample tanks for previews and testing
    static let samples: [Tank] = [
        Tank(
            name: "Living Room Reef",
            volumeGallons: 120,
            tankType: .mixedReef,
            notes: "Main display tank with mixed corals"
        ),
        Tank(
            name: "Office Nano",
            volumeGallons: 20,
            tankType: .nano,
            notes: "Small desk tank with softies"
        ),
        Tank(
            name: "Frag Tank",
            volumeGallons: 40,
            tankType: .sps,
            notes: "Coral propagation system"
        )
    ]

    static let sample = samples[0]
}
