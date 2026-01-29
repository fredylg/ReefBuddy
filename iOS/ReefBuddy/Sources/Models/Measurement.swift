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

    /// Salinity value in the unit given by salinityUnit (SG or PPT)
    var salinity: Double?

    /// Salinity unit: "SG" (specific gravity) or "PPT" (parts per thousand). Nil for legacy data.
    var salinityUnit: String?

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
        salinityUnit: String? = nil,
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
        self.salinityUnit = salinityUnit
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
    /// Sample measurements for previews and testing (empty for clean start)
    static let samples: [Measurement] = []

    /// Single sample for previews
    static let sample = Measurement(
        tankId: Tank.sample.id,
        measuredAt: Date(),
        temperature: 78.0,
        salinity: 1.025,
        pH: 8.2,
        alkalinity: 8.5,
        calcium: 420.0,
        magnesium: 1350.0
    )
}

// MARK: - API Request/Response Models

/// Request body for creating a new measurement via API
struct CreateMeasurementRequest: Codable {
    let tankId: UUID
    let temperature: Double?
    let salinity: Double?
    let salinityUnit: String?
    let pH: Double?
    let alkalinity: Double?
    let calcium: Double?
    let magnesium: Double?
    let nitrate: Double?
    let phosphate: Double?
    let ammonia: Double?
    let nitrite: Double?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case tankId = "tank_id"
        case temperature
        case salinity
        case salinityUnit = "salinity_unit"
        case pH = "ph"
        case alkalinity
        case calcium
        case magnesium
        case nitrate
        case phosphate
        case ammonia
        case nitrite
        case notes
    }

    init(from measurement: Measurement) {
        self.tankId = measurement.tankId
        self.temperature = measurement.temperature
        self.salinity = measurement.salinity
        self.salinityUnit = measurement.salinityUnit
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

    /// Create from raw AI response (text only)
    init(fromRawRecommendation text: String) {
        self.summary = text
        self.recommendations = []
        self.warnings = nil
        self.dosingAdvice = nil
    }

    init(summary: String, recommendations: [String], warnings: [String]?, dosingAdvice: [DosingRecommendation]?) {
        self.summary = summary
        self.recommendations = recommendations
        self.warnings = warnings
        self.dosingAdvice = dosingAdvice
    }
}

/// A specific dosing recommendation from AI analysis
struct DosingRecommendation: Codable, Identifiable {
    var id: String { product }
    let product: String
    let amount: String
    let frequency: String
    let reason: String
}

// MARK: - Analysis API Models

/// Request body for AI analysis endpoint (matches Worker's AnalysisRequestSchema)
struct AnalysisRequest: Codable {
    let deviceId: String
    let deviceToken: String?
    let isDevelopment: Bool
    let tankId: String
    let parameters: WaterParameters
    let tankVolume: Double
    let temperatureUnit: String

    // Use explicit coding keys to ensure camelCase (Worker expects camelCase, not snake_case)
    enum CodingKeys: String, CodingKey {
        case deviceId
        case deviceToken
        case isDevelopment
        case tankId
        case parameters
        case tankVolume
        case temperatureUnit
    }

    struct WaterParameters: Codable {
        let salinity: Double?
        let salinityUnit: String?
        let temperature: Double?
        let ph: Double?
        let alkalinity: Double?
        let calcium: Double?
        let magnesium: Double?
        let nitrate: Double?
        let phosphate: Double?
        let ammonia: Double?
        let notes: String?

        enum CodingKeys: String, CodingKey {
            case salinity
            case salinityUnit = "salinity_unit"
            case temperature
            case ph
            case alkalinity
            case calcium
            case magnesium
            case nitrate
            case phosphate
            case ammonia
            case notes
        }
    }

    init(measurement: Measurement, tankVolume: Double, deviceId: String, deviceToken: String? = nil, isDevelopment: Bool = false, temperatureUnit: String = "F") {
        self.deviceId = deviceId
        self.deviceToken = deviceToken
        self.isDevelopment = isDevelopment
        self.tankId = measurement.tankId.uuidString
        self.tankVolume = tankVolume
        self.temperatureUnit = temperatureUnit
        self.parameters = WaterParameters(
            salinity: measurement.salinity,
            salinityUnit: measurement.salinityUnit,
            temperature: measurement.temperature,
            ph: measurement.pH,
            alkalinity: measurement.alkalinity,
            calcium: measurement.calcium,
            magnesium: measurement.magnesium,
            nitrate: measurement.nitrate,
            phosphate: measurement.phosphate,
            ammonia: measurement.ammonia,
            notes: measurement.notes
        )
    }
}

/// Response wrapper from /analyze endpoint
struct AnalyzeAPIResponse: Codable {
    let success: Bool
    let tankId: String?
    let analysis: AnalysisContent?
    // Credit tracking fields (new IAP system)
    let creditsRemaining: Int?
    let freeRemaining: Int?
    let paidCredits: Int?

    /// The analysis content - could be structured or just a recommendation string
    struct AnalysisContent: Codable {
        // Structured fields (if AI returns JSON)
        let summary: String?
        let recommendations: [String]?
        let warnings: [String]?
        let dosingAdvice: [DosingRecommendation]?
        // Fallback field (if AI returns plain text)
        let recommendation: String?
        let status: String?
        let message: String?

        func toAnalysisResponse() -> AnalysisResponse {
            if let summary = summary {
                return AnalysisResponse(
                    summary: summary,
                    recommendations: recommendations ?? [],
                    warnings: warnings,
                    dosingAdvice: dosingAdvice
                )
            } else if let recommendation = recommendation {
                return AnalysisResponse(fromRawRecommendation: recommendation)
            } else if let message = message {
                return AnalysisResponse(fromRawRecommendation: message)
            } else {
                return AnalysisResponse(fromRawRecommendation: "Analysis complete. Check your parameters.")
            }
        }
    }
}
