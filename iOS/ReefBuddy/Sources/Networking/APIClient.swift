import Foundation
import UIKit

// MARK: - API Client

/// Network client for communicating with the ReefBuddy Cloudflare Workers backend.
/// Handles all API requests for tanks, measurements, and AI analysis.
actor APIClient {

    // MARK: - Configuration

    /// Base URL for the API (Cloudflare Worker)
    private let baseURL: URL

    /// URL session for network requests
    private let session: URLSession

    /// JSON encoder with snake_case conversion
    private let encoder: JSONEncoder

    /// JSON decoder with snake_case conversion
    private let decoder: JSONDecoder

    // MARK: - Initialization

    init(baseURL: URL? = nil) {
        // Use environment variable or default to localhost for development
        if let baseURL = baseURL {
            self.baseURL = baseURL
        } else if let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"],
                  let url = URL(string: envURL) {
            self.baseURL = url
        } else {
            // Default to local development worker
            self.baseURL = URL(string: "http://localhost:8787")!
        }

        // Configure URL session
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        // Configure JSON coding
        self.encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Tank Endpoints

    /// Fetch all tanks for the current user
    func getTanks() async throws -> [Tank] {
        let url = baseURL.appendingPathComponent("api/tanks")
        let request = makeRequest(url: url, method: "GET")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(APIResponse<[Tank]>.self, from: data)
        return apiResponse.data
    }

    /// Get a specific tank by ID
    func getTank(id: UUID) async throws -> Tank {
        let url = baseURL.appendingPathComponent("api/tanks/\(id.uuidString)")
        let request = makeRequest(url: url, method: "GET")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(APIResponse<Tank>.self, from: data)
        return apiResponse.data
    }

    /// Create a new tank
    func createTank(_ tank: Tank) async throws -> Tank {
        let url = baseURL.appendingPathComponent("api/tanks")
        var request = makeRequest(url: url, method: "POST")
        request.httpBody = try encoder.encode(tank)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(APIResponse<Tank>.self, from: data)
        return apiResponse.data
    }

    /// Update an existing tank
    func updateTank(_ tank: Tank) async throws -> Tank {
        let url = baseURL.appendingPathComponent("api/tanks/\(tank.id.uuidString)")
        var request = makeRequest(url: url, method: "PUT")
        request.httpBody = try encoder.encode(tank)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(APIResponse<Tank>.self, from: data)
        return apiResponse.data
    }

    /// Delete a tank
    func deleteTank(_ id: UUID) async throws {
        let url = baseURL.appendingPathComponent("api/tanks/\(id.uuidString)")
        let request = makeRequest(url: url, method: "DELETE")

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Measurement Endpoints

    /// Fetch all measurements for a tank
    func getMeasurements(for tankId: UUID, limit: Int = 50) async throws -> [Measurement] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/measurements"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "tank_id", value: tankId.uuidString),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        let request = makeRequest(url: components.url!, method: "GET")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(APIResponse<[Measurement]>.self, from: data)
        return apiResponse.data
    }

    /// Create a new measurement
    func createMeasurement(_ measurement: Measurement) async throws -> Measurement {
        let url = baseURL.appendingPathComponent("api/measurements")
        var request = makeRequest(url: url, method: "POST")

        let requestBody = CreateMeasurementRequest(from: measurement)
        request.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(APIResponse<Measurement>.self, from: data)
        return apiResponse.data
    }

    // MARK: - AI Analysis Endpoint

    /// Request AI analysis of water parameters
    /// This endpoint routes through Cloudflare AI Gateway to Claude-3.5-Sonnet
    func analyzeParameters(_ measurement: Measurement) async throws -> AnalysisResponse {
        let url = baseURL.appendingPathComponent("api/analyze")
        var request = makeRequest(url: url, method: "POST")

        let requestBody = CreateMeasurementRequest(from: measurement)
        request.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(APIResponse<AnalysisResponse>.self, from: data)
        return apiResponse.data
    }

    // MARK: - User/Subscription Endpoints

    /// Get the current user's free tier usage
    func getFreeTierUsage() async throws -> FreeTierUsage {
        let url = baseURL.appendingPathComponent("api/user/usage")
        let request = makeRequest(url: url, method: "GET")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(APIResponse<FreeTierUsage>.self, from: data)
        return apiResponse.data
    }

    // MARK: - Private Helpers

    private func makeRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add device identifier for tracking (anonymous)
        if let deviceId = UIDevice.current.identifierForVendor?.uuidString {
            request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        }

        return request
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 400:
            throw APIError.badRequest
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 429:
            throw APIError.rateLimited
        case 500...599:
            throw APIError.serverError(httpResponse.statusCode)
        default:
            throw APIError.unknown(httpResponse.statusCode)
        }
    }
}

// MARK: - API Response Wrapper

/// Standard API response wrapper
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T
    let message: String?
}

// MARK: - Free Tier Usage

/// Tracks the user's free tier usage
struct FreeTierUsage: Codable {
    let analysesUsed: Int
    let analysesLimit: Int
    let resetDate: Date

    var remaining: Int {
        max(0, analysesLimit - analysesUsed)
    }
}

// MARK: - API Errors

/// API error types
enum APIError: LocalizedError {
    case invalidResponse
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError(Int)
    case unknown(Int)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .badRequest:
            return "Invalid request. Please check your input."
        case .unauthorized:
            return "Authentication required"
        case .forbidden:
            return "Access denied"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Too many requests. Please wait and try again."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .unknown(let code):
            return "Unexpected error (\(code))"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
