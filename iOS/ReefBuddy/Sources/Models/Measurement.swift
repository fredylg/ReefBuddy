import Foundation

// MARK: - Measurement Model

/// Represents a water parameter measurement entry for a tank
struct Measurement: Identifiable, Codable, Equatable {

    // MARK: - Properties

    /// Unique identifier for this measurement
    let id: UUID

    /// The tank this measurement belongs to
    let tankId: UUID

    /// Date and time the measurement was taken
    let measuredAt: Date

    // MARK: - Water Parameters

    /// Temperature in Fahrenheit
    var temperature: Double?

    /// Salinity as specific gravity (e.g., 1.025)
    var salinity: Double?

    /// pH level (typically 7.8-8.4)
    var pH: Double?

    /// Alkalinity in dKH
    var alkalinity: Double?

    /// Calcium in ppm
    var calcium: Double?

    /// Magnesium in ppm
    var magnesium: Double?

    /// Nitrate (NO3) in ppm
    var nitrate: Double?

    /// Phosphate (PO4) in ppm
    var phosphate: Double?

    /// Ammonia (NH3/NH4) in ppm
    var ammonia: Double?

    /// Nitrite (NO2) in ppm
    var nitrite: Double?

    /// Optional notes about this measurement
    var notes: String?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        tankId: UUID,
        measuredAt: Date = Date(),
        temperature: Double? = nil,
        salinity: Double? = nil,
        pH: Double? = nil,
        alkalinity: Double? = nil,
        calcium: Double? = nil,
        magnesium: Double? = nil,
        nitrate: Double? = nil,
        phosphate: Double? = nil,
        ammonia: Double? = nil,
        nitrite: Double? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.tankId = tankId
        self.measuredAt = measuredAt
        self.temperature = temperature
        self.salinity = salinity
        self.pH = pH
        self.alkalinity = alkalinity
        self.calcium = calcium
        self.magnesium = magnesium
        self.nitrate = nitrate
        self.phosphate = phosphate
        self.ammonia = ammonia
        self.nitrite = nitrite
        self.notes = notes
    }
}

// MARK: - Parameter Ranges

/// Defines healthy ranges for water parameters
enum ParameterRange {
    case temperature
    case salinity
    case pH
    case alkalinity
    case calcium
    case magnesium
    case nitrate
    case phosphate
    case ammonia
    case nitrite

    var range: ClosedRange<Double> {
        switch self {
        case .temperature:
            return 76.0...80.0
        case .salinity:
            return 1.023...1.026
        case .pH:
            return 7.8...8.4
        case .alkalinity:
            return 7.0...11.0
        case .calcium:
            return 380.0...450.0
        case .magnesium:
            return 1250.0...1400.0
        case .nitrate:
            return 0.0...10.0
        case .phosphate:
            return 0.0...0.1
        case .ammonia:
            return 0.0...0.0
        case .nitrite:
            return 0.0...0.0
        }
    }

    var unit: String {
        switch self {
        case .temperature:
            return "°F"
        case .salinity:
            return "SG"
        case .pH:
            return ""
        case .alkalinity:
            return "dKH"
        case .calcium:
            return "ppm"
        case .magnesium:
            return "ppm"
        case .nitrate:
            return "ppm"
        case .phosphate:
            return "ppm"
        case .ammonia:
            return "ppm"
        case .nitrite:
            return "ppm"
        }
    }

    var displayName: String {
        switch self {
        case .temperature:
            return "Temperature"
        case .salinity:
            return "Salinity"
        case .pH:
            return "pH"
        case .alkalinity:
            return "Alkalinity"
        case .calcium:
            return "Calcium"
        case .magnesium:
            return "Magnesium"
        case .nitrate:
            return "Nitrate (NO3)"
        case .phosphate:
            return "Phosphate (PO4)"
        case .ammonia:
            return "Ammonia"
        case .nitrite:
            return "Nitrite"
        }
    }

    /// Returns the status of a value within this parameter's range
    func status(for value: Double?) -> ParameterStatus {
        guard let value = value else { return .unknown }

        if range.contains(value) {
            return .optimal
        } else if value < range.lowerBound {
            return .low
        } else {
            return .high
        }
    }
}

// MARK: - Parameter Status

/// Status indicating how a parameter value compares to optimal range
enum ParameterStatus {
    case optimal
    case low
    case high
    case unknown

    var displayText: String {
        switch self {
        case .optimal:
            return "OPTIMAL"
        case .low:
            return "LOW"
        case .high:
            return "HIGH"
        case .unknown:
            return "—"
        }
    }
}

// MARK: - Sample Data

extension Measurement {
    /// Sample measurements for previews and testing
    static let samples: [Measurement] = [
        Measurement(
            tankId: Tank.sample.id,
            measuredAt: Date(),
            temperature: 78.2,
            salinity: 1.025,
            pH: 8.1,
            alkalinity: 8.5,
            calcium: 420.0,
            magnesium: 1320.0,
            nitrate: 5.0,
            phosphate: 0.03,
            notes: "All parameters looking good"
        ),
        Measurement(
            tankId: Tank.sample.id,
            measuredAt: Date().addingTimeInterval(-86400 * 7),
            temperature: 77.8,
            salinity: 1.024,
            pH: 8.2,
            alkalinity: 9.0,
            calcium: 415.0,
            magnesium: 1350.0,
            nitrate: 8.0,
            phosphate: 0.05
        ),
        Measurement(
            tankId: Tank.sample.id,
            measuredAt: Date().addingTimeInterval(-86400 * 14),
            temperature: 79.0,
            salinity: 1.026,
            pH: 7.9,
            alkalinity: 7.5,
            calcium: 390.0,
            magnesium: 1280.0,
            nitrate: 12.0,
            phosphate: 0.08,
            notes: "Nitrate slightly elevated, did 10% water change"
        )
    ]

    static let sample = samples[0]
}

// MARK: - API Request/Response Models

/// Request body for creating a new measurement via API
struct CreateMeasurementRequest: Codable {
    let tankId: UUID
    let temperature: Double?
    let salinity: Double?
    let pH: Double?
    let alkalinity: Double?
    let calcium: Double?
    let magnesium: Double?
    let nitrate: Double?
    let phosphate: Double?
    let ammonia: Double?
    let nitrite: Double?
    let notes: String?

    init(from measurement: Measurement) {
        self.tankId = measurement.tankId
        self.temperature = measurement.temperature
        self.salinity = measurement.salinity
        self.pH = measurement.pH
        self.alkalinity = measurement.alkalinity
        self.calcium = measurement.calcium
        self.magnesium = measurement.magnesium
        self.nitrate = measurement.nitrate
        self.phosphate = measurement.phosphate
        self.ammonia = measurement.ammonia
        self.nitrite = measurement.nitrite
        self.notes = measurement.notes
    }
}

/// Response from AI analysis of water parameters
struct AnalysisResponse: Codable {
    let summary: String
    let recommendations: [String]
    let warnings: [String]?
    let dosingAdvice: [DosingRecommendation]?
}

/// A specific dosing recommendation from AI analysis
struct DosingRecommendation: Codable, Identifiable {
    var id: String { product }
    let product: String
    let amount: String
    let frequency: String
    let reason: String
}
