import Foundation

// MARK: - Saved Analysis Model

/// Represents a saved AI water analysis for later reference.
/// Stores the complete analysis result along with the parameters that were analyzed.
struct SavedAnalysis: Identifiable, Codable {
    
    // MARK: - Properties
    
    /// Unique identifier for the saved analysis
    let id: UUID
    
    /// ID of the tank this analysis is for
    let tankId: String
    
    /// Name of the tank at time of analysis
    let tankName: String
    
    /// Date when the analysis was performed
    let analyzedAt: Date
    
    /// Water parameters that were analyzed
    let parameters: AnalyzedParameters
    
    /// The AI-generated analysis summary
    let summary: String
    
    /// AI-generated recommendations
    let recommendations: [String]
    
    /// AI-generated warnings (if any)
    let warnings: [String]?
    
    /// AI-generated dosing advice (if any)
    let dosingAdvice: String?
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        tankId: String,
        tankName: String,
        analyzedAt: Date = Date(),
        parameters: AnalyzedParameters,
        summary: String,
        recommendations: [String],
        warnings: [String]? = nil,
        dosingAdvice: String? = nil
    ) {
        self.id = id
        self.tankId = tankId
        self.tankName = tankName
        self.analyzedAt = analyzedAt
        self.parameters = parameters
        self.summary = summary
        self.recommendations = recommendations
        self.warnings = warnings
        self.dosingAdvice = dosingAdvice
    }
    
    /// Create a SavedAnalysis from an AnalysisResponse and tank info
    init(from response: AnalysisResponse, tank: Tank, parameters: AnalyzedParameters) {
        self.id = UUID()
        self.tankId = tank.id
        self.tankName = tank.name
        self.analyzedAt = Date()
        self.parameters = parameters
        self.summary = response.summary
        self.recommendations = response.recommendations
        self.warnings = response.warnings
        self.dosingAdvice = response.dosingAdvice
    }
}

// MARK: - Analyzed Parameters

/// Water parameters captured at the time of analysis
struct AnalyzedParameters: Codable {
    let salinity: Double?
    let temperature: Double?
    let ph: Double?
    let alkalinity: Double?
    let calcium: Double?
    let magnesium: Double?
    let nitrate: Double?
    let nitrite: Double?
    let ammonia: Double?
    let phosphate: Double?
    
    init(
        salinity: Double? = nil,
        temperature: Double? = nil,
        ph: Double? = nil,
        alkalinity: Double? = nil,
        calcium: Double? = nil,
        magnesium: Double? = nil,
        nitrate: Double? = nil,
        nitrite: Double? = nil,
        ammonia: Double? = nil,
        phosphate: Double? = nil
    ) {
        self.salinity = salinity
        self.temperature = temperature
        self.ph = ph
        self.alkalinity = alkalinity
        self.calcium = calcium
        self.magnesium = magnesium
        self.nitrate = nitrate
        self.nitrite = nitrite
        self.ammonia = ammonia
        self.phosphate = phosphate
    }
}

// MARK: - Sample Data

extension SavedAnalysis {
    static let samples: [SavedAnalysis] = []
}
