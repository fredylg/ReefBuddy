import Foundation
import DeviceCheck
import os

private let log = Logger(subsystem: "au.com.aethers.reefbuddy", category: "APIClient")

// MARK: - Date handling

/// The Worker emits ISO 8601 with milliseconds (`toISOString()`), D1 defaults emit `YYYY-MM-DD HH:MM:SS`,
/// and older rows may carry plain ISO without fractions. Foundation's `.iso8601` strategy only accepts
/// the last of these, which is why every server response used to fail to decode (I-01).
enum APIDates {
    static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static let sqlite: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
    private static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func parse(_ value: String) -> Date? {
        isoFractional.date(from: value) ?? iso.date(from: value) ?? sqlite.date(from: value) ?? dateOnly.date(from: value)
    }

    static let decodingStrategy: JSONDecoder.DateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let date = parse(raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognised date: \(raw)")
        }
        return date
    }

    /// Decoder for snake_case server payloads (tanks, measurements, water changes, livestock records).
    static func snakeCaseDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = decodingStrategy
        return d
    }

    /// Decoder for camelCase server payloads (schedules, analyze, credits).
    static func camelCaseDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = decodingStrategy
        return d
    }
}

// MARK: - API Client

/// Network client for the ReefBuddy Cloudflare Worker.
/// Every call goes through `send`, so network failures, HTTP errors (with the Worker's `code`) and
/// decoding failures surface as typed `APIError`s and are logged, instead of silently falling back.
actor APIClient {

    // MARK: - Configuration

    /// Production API URL (custom domain; the workers.dev host is being retired, C-03)
    static let productionURL = "https://api.reefbuddy.aethers.com.au"

    /// Local development API URL (for `npm run dev`)
    private static let localDevURL = "http://localhost:8787"

    /// True when the client targets production (release builds, or DEBUG with API_BASE_URL set to it).
    static func isUsingProduction() -> Bool {
        #if DEBUG
        if let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"], let url = URL(string: envURL) {
            return url.absoluteString == productionURL
        }
        return false
        #else
        return true
        #endif
    }

    private let baseURL: URL
    private let session: URLSession
    private let deviceId: String

    /// snake_case body encoder for tank/measurement endpoints
    private let snakeEncoder: JSONEncoder
    /// camelCase body encoder for schedules, water changes, livestock, credits and analyze
    private let camelEncoder: JSONEncoder
    private let snakeDecoder = APIDates.snakeCaseDecoder()
    private let camelDecoder = APIDates.camelCaseDecoder()

    // MARK: - Initialization

    init(baseURL: URL? = nil, deviceId: String = DeviceIdentity.deviceId) {
        if let baseURL {
            self.baseURL = baseURL
        } else {
            #if DEBUG
            if let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"], let url = URL(string: envURL) {
                self.baseURL = url
            } else {
                self.baseURL = URL(string: Self.localDevURL)!
            }
            #else
            self.baseURL = URL(string: Self.productionURL)!
            #endif
        }
        self.deviceId = deviceId

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        snakeEncoder = JSONEncoder()
        snakeEncoder.keyEncodingStrategy = .convertToSnakeCase
        snakeEncoder.dateEncodingStrategy = .iso8601

        camelEncoder = JSONEncoder()
        camelEncoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Tank Endpoints

    func getTanks() async throws -> [Tank] {
        try await send(request("api/tanks"), as: APIResponse<[Tank]>.self, decoder: snakeDecoder).data
    }

    func getTank(id: UUID) async throws -> Tank {
        try await send(request("api/tanks/\(path(id))"), as: APIResponse<Tank>.self, decoder: snakeDecoder).data
    }

    func createTank(_ tank: Tank) async throws -> Tank {
        var req = request("api/tanks", method: "POST")
        req.httpBody = try snakeEncoder.encode(tank)
        return try await send(req, as: APIResponse<Tank>.self, decoder: snakeDecoder).data
    }

    func updateTank(_ tank: Tank) async throws -> Tank {
        var req = request("api/tanks/\(path(tank.id))", method: "PUT")
        req.httpBody = try snakeEncoder.encode(tank)
        return try await send(req, as: APIResponse<Tank>.self, decoder: snakeDecoder).data
    }

    func deleteTank(_ id: UUID) async throws {
        try await sendIgnoringBody(request("api/tanks/\(path(id))", method: "DELETE"))
    }

    // MARK: - Maintenance Schedules (config sync only)

    func createMaintenanceSchedule(_ schedule: MaintenanceSchedule) async throws -> MaintenanceSchedule {
        var req = request("maintenance/schedules", method: "POST")
        req.httpBody = try camelEncoder.encode(MaintenanceScheduleUpsertRequest(schedule: schedule, includeId: true))
        return try await send(req, as: MaintenanceScheduleUpsertResponse.self, decoder: camelDecoder).schedule
    }

    func updateMaintenanceSchedule(_ schedule: MaintenanceSchedule) async throws -> MaintenanceSchedule {
        var req = request("maintenance/schedules/\(path(schedule.id))", method: "PUT")
        req.httpBody = try camelEncoder.encode(MaintenanceScheduleUpsertRequest(schedule: schedule, includeId: false))
        return try await send(req, as: MaintenanceScheduleUpsertResponse.self, decoder: camelDecoder).schedule
    }

    func deleteMaintenanceSchedule(id: UUID) async throws {
        try await sendIgnoringBody(request("maintenance/schedules/\(path(id))", method: "DELETE"))
    }

    // MARK: - Water Changes

    func createWaterChange(_ waterChange: WaterChange) async throws -> WaterChange {
        var req = request("api/tanks/\(path(waterChange.tankId))/water-changes", method: "POST")
        req.httpBody = try camelEncoder.encode(WaterChangeCreateRequest(from: waterChange))
        var created = try await send(req, as: APIResponse<WaterChange>.self, decoder: camelDecoder).data
        created.needsSync = false
        created.isDeleted = false
        return created
    }

    func getWaterChanges(for tankId: UUID, limit: Int = 50) async throws -> [WaterChange] {
        let req = request("api/tanks/\(path(tankId))/water-changes", query: [URLQueryItem(name: "limit", value: String(limit))])
        return try await send(req, as: APIResponse<[WaterChange]>.self, decoder: camelDecoder).data.map { item in
            var synced = item
            synced.needsSync = false
            synced.isDeleted = false
            return synced
        }
    }

    func deleteWaterChange(id: UUID) async throws {
        try await sendIgnoringBody(request("api/water-changes/\(path(id))", method: "DELETE"))
    }

    // MARK: - Measurement Endpoints

    /// Measurements for a tank, newest first. Backed by `GET /tanks/:id/history` (the only server-side
    /// read of measurements); the default window is the last two years.
    func getMeasurements(for tankId: UUID, since: Date = Date().addingTimeInterval(-2 * 365 * 24 * 3600)) async throws -> [Measurement] {
        let req = request("tanks/\(path(tankId))/history", query: [
            URLQueryItem(name: "start", value: APIDates.iso.string(from: since)),
            URLQueryItem(name: "end", value: APIDates.iso.string(from: Date().addingTimeInterval(60))),
        ])
        return try await send(req, as: HistoryResponse.self, decoder: snakeDecoder).measurements
    }

    func createMeasurement(_ measurement: Measurement) async throws -> Measurement {
        var req = request("api/measurements", method: "POST")
        req.httpBody = try snakeEncoder.encode(CreateMeasurementRequest(from: measurement))
        return try await send(req, as: APIResponse<Measurement>.self, decoder: snakeDecoder).data
    }

    // MARK: - AI Analysis Endpoint

    /// Request AI analysis of water parameters. Uses device credits (3 free, then paid) and a
    /// DeviceCheck token for device attestation.
    func analyzeParameters(_ measurement: Measurement, tankVolume: Double, deviceId: String, temperatureUnit: String = "F") async throws -> AnalysisResult {
        var req = request("analyze", method: "POST")
        let deviceToken = await generateDeviceToken()
        let body = AnalysisRequest(
            measurement: measurement,
            tankVolume: tankVolume,
            deviceId: deviceId,
            deviceToken: deviceToken,
            isDevelopment: isDebugBuild(),
            temperatureUnit: temperatureUnit
        )
        req.httpBody = try camelEncoder.encode(body)

        let apiResponse = try await send(req, as: AnalyzeAPIResponse.self, decoder: camelDecoder)
        guard let analysis = apiResponse.analysis else { throw APIError.invalidResponse }

        var creditBalance: CreditBalance?
        if let freeRemaining = apiResponse.freeRemaining, let paidCredits = apiResponse.paidCredits, let creditsRemaining = apiResponse.creditsRemaining {
            // totalAnalyses is not part of this response; -1 tells StoreManager to keep its current value.
            creditBalance = CreditBalance(freeRemaining: freeRemaining, paidCredits: paidCredits, totalCredits: creditsRemaining, totalAnalyses: -1)
        }
        return AnalysisResult(analysis: analysis.toAnalysisResponse(), creditBalance: creditBalance, truncated: apiResponse.truncated ?? false)
    }

    // MARK: - DeviceCheck

    /// DeviceCheck token for device attestation; nil where unsupported (simulator).
    private func generateDeviceToken() async -> String? {
        guard DCDevice.current.isSupported else {
            log.notice("DeviceCheck not supported on this device")
            return nil
        }
        return await withCheckedContinuation { continuation in
            DCDevice.current.generateToken { data, error in
                if let error {
                    log.error("DeviceCheck token generation failed: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: data?.base64EncodedString())
                }
            }
        }
    }

    private func isDebugBuild() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: - Livestock Endpoints

    func createLivestock(_ livestock: Livestock, for tankId: UUID) async throws -> Livestock {
        var req = request("api/tanks/\(path(tankId))/livestock", method: "POST")
        req.httpBody = try camelEncoder.encode(CreateLivestockRequest(from: livestock))
        let record = try await send(req, as: LivestockEnvelope.self, decoder: snakeDecoder).livestock
        return record.toLivestock(fallbackTankId: tankId, photoData: livestock.photoData)
    }

    func getLivestock(for tankId: UUID) async throws -> [Livestock] {
        let list = try await send(request("api/tanks/\(path(tankId))/livestock"), as: LivestockListEnvelope.self, decoder: snakeDecoder)
        return list.livestock.map { $0.toLivestock(fallbackTankId: tankId, photoData: nil) }
    }

    func updateLivestock(_ livestock: Livestock) async throws -> Livestock {
        var req = request("api/livestock/\(path(livestock.id))", method: "PUT")
        req.httpBody = try camelEncoder.encode(UpdateLivestockRequest(from: livestock))
        let record = try await send(req, as: LivestockEnvelope.self, decoder: snakeDecoder).livestock
        return record.toLivestock(fallbackTankId: livestock.tankId, photoData: livestock.photoData)
    }

    func deleteLivestock(_ id: UUID) async throws {
        try await sendIgnoringBody(request("api/livestock/\(path(id))", method: "DELETE"))
    }

    func createLivestockLog(_ logEntry: LivestockLog) async throws -> LivestockLog {
        var req = request("api/livestock/\(path(logEntry.livestockId))/logs", method: "POST")

        // The server records event types; the app records health states. Map one to the other.
        let logType: String
        switch logEntry.healthStatus {
        case .deceased: logType = "death"
        case .critical, .declining: logType = "treatment"
        case .thriving, .healthy, .stressed: logType = "observation"
        }
        struct LivestockLogRequest: Encodable {
            let logType: String
            let description: String?
            let loggedAt: Date
        }
        req.httpBody = try camelEncoder.encode(LivestockLogRequest(logType: logType, description: logEntry.notes, loggedAt: logEntry.loggedAt))

        struct LivestockLogResponse: Decodable {
            let log: LogRecord
            struct LogRecord: Decodable {
                let id: String
                let livestockId: String
                let logType: String
                let description: String?
                let loggedAt: Date
            }
        }
        let record = try await send(req, as: LivestockLogResponse.self, decoder: snakeDecoder).log
        guard let logId = UUID(uuidString: record.id), let livestockId = UUID(uuidString: record.livestockId) else {
            throw APIError.decodingError(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Log record ids are not UUIDs")))
        }
        return LivestockLog(
            id: logId,
            livestockId: livestockId,
            loggedAt: record.loggedAt,
            healthStatus: record.logType == "death" ? .deceased : logEntry.healthStatus,
            notes: record.description
        )
    }

    // MARK: - Credits Endpoints

    func getCreditsBalance(deviceId: String) async throws -> CreditsBalanceResponse {
        try await send(request("credits/balance", query: [URLQueryItem(name: "deviceId", value: deviceId)]), as: CreditsBalanceResponse.self, decoder: camelDecoder)
    }

    /// Validate a StoreKit 2 signed transaction and add its credits.
    func purchaseCredits(deviceId: String, jwsRepresentation: String, transactionId: String, originalTransactionId: String, productId: String) async throws -> CreditsPurchaseResponse {
        var req = request("credits/purchase", method: "POST")
        req.httpBody = try camelEncoder.encode(CreditsPurchaseRequest(
            deviceId: deviceId,
            jwsRepresentation: jwsRepresentation,
            transactionId: transactionId,
            originalTransactionId: originalTransactionId,
            productId: productId
        ))
        return try await send(req, as: CreditsPurchaseResponse.self, decoder: camelDecoder)
    }

    // MARK: - Request plumbing

    /// UUIDs go into paths lowercased; the server stores and matches lowercase (P4-04).
    private func path(_ id: UUID) -> String { id.uuidString.lowercased() }

    private func request(_ path: String, method: String = "GET", query: [URLQueryItem]? = nil) -> URLRequest {
        var url = baseURL.appendingPathComponent(path)
        if let query {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = query
            url = components.url!
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        return req
    }

    /// Perform, validate and decode. Network and decoding failures are logged and typed (I-10).
    private func send<T: Decodable>(_ req: URLRequest, as type: T.Type, decoder: JSONDecoder) async throws -> T {
        let (data, response) = try await perform(req)
        try validate(response, data: data, for: req)
        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            log.error("Decoding \(String(describing: T.self), privacy: .public) failed for \(req.httpMethod ?? "", privacy: .public) \(req.url?.path ?? "", privacy: .public): \(String(describing: error), privacy: .public)")
            throw APIError.decodingError(error)
        }
    }

    private func sendIgnoringBody(_ req: URLRequest) async throws {
        let (data, response) = try await perform(req)
        try validate(response, data: data, for: req)
    }

    private func perform(_ req: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: req)
        } catch let error as URLError {
            log.error("Network error for \(req.url?.path ?? "", privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw APIError.networkError(error)
        }
    }

    private struct ErrorBody: Decodable {
        let error: String?
        let message: String?
        let code: String?
    }

    private func validate(_ response: URLResponse, data: Data, for req: URLRequest) throws {
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if (200...299).contains(http.statusCode) { return }

        let body = try? JSONDecoder().decode(ErrorBody.self, from: data)
        let detail = [body?.message, body?.error].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " — ")
        log.notice("HTTP \(http.statusCode) for \(req.httpMethod ?? "", privacy: .public) \(req.url?.path ?? "", privacy: .public) code=\(body?.code ?? "-", privacy: .public)")

        switch http.statusCode {
        case 400: throw detail.isEmpty ? APIError.badRequest : APIError.badRequestDetail(detail)
        case 401: throw APIError.unauthorized
        case 402: throw APIError.noCredits
        case 403: throw (body?.code ?? "").hasPrefix("DEVICE_CHECK") ? APIError.deviceCheckRequired : APIError.forbidden(detail)
        case 404: throw APIError.notFound
        case 409: throw APIError.conflict(detail)
        case 422: throw APIError.analysisRefused(detail)
        case 429: throw APIError.rateLimited
        case 502, 503: throw APIError.serviceUnavailable
        case 500...599: throw APIError.serverError(http.statusCode)
        default: throw APIError.unknown(http.statusCode)
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

/// `GET /tanks/:id/history`
private struct HistoryResponse: Decodable {
    let measurements: [Measurement]
}

// MARK: - Maintenance Schedule API Models

private struct MaintenanceScheduleUpsertRequest: Encodable {
    var id: String?
    let tankId: String
    let type: String
    let enabled: Bool
    let scheduleKind: String
    let intervalDays: Int?
    let weekdays: [Int]?
    let timeLocal: String
    let timezone: String
    let notes: String?

    init(schedule: MaintenanceSchedule, includeId: Bool) {
        self.id = includeId ? schedule.id.uuidString.lowercased() : nil
        self.tankId = schedule.tankId.uuidString.lowercased()
        self.type = schedule.type.rawValue
        self.enabled = schedule.enabled
        self.scheduleKind = schedule.scheduleKind.rawValue
        self.intervalDays = schedule.intervalDays
        self.weekdays = schedule.weekdays
        self.timeLocal = schedule.timeLocal
        self.timezone = schedule.timezone
        self.notes = schedule.notes
    }
}

private struct MaintenanceScheduleUpsertResponse: Decodable {
    let success: Bool
    let schedule: MaintenanceSchedule
}

private struct WaterChangeCreateRequest: Encodable {
    let performedAt: Date
    let percentReplaced: Double?
    let gallonsReplaced: Double?
    let notes: String?
    let sourceScheduleId: String?

    init(from waterChange: WaterChange) {
        self.performedAt = waterChange.performedAt
        self.percentReplaced = waterChange.percentReplaced
        self.gallonsReplaced = waterChange.gallonsReplaced
        self.notes = waterChange.notes
        self.sourceScheduleId = waterChange.sourceScheduleId?.uuidString.lowercased()
    }
}

// MARK: - Credits Models

/// Request body for purchasing credits (StoreKit 2 JWS format)
struct CreditsPurchaseRequest: Encodable {
    let deviceId: String
    let jwsRepresentation: String
    let transactionId: String
    let originalTransactionId: String
    let productId: String
}

/// Response from credits balance endpoint
struct CreditsBalanceResponse: Decodable {
    let success: Bool
    let deviceId: String
    let freeLimit: Int
    let freeUsed: Int
    let freeRemaining: Int
    let paidCredits: Int
    let totalCredits: Int
    let totalAnalyses: Int
}

/// Response from credits purchase endpoint
struct CreditsPurchaseResponse: Decodable {
    let success: Bool
    let creditsAdded: Int
    let newBalance: NewBalanceInfo

    struct NewBalanceInfo: Decodable {
        let freeRemaining: Int
        let paidCredits: Int
        let totalCredits: Int
    }
}

// MARK: - Credit Balance

/// Credit balance information
struct CreditBalance: Codable {
    let freeRemaining: Int
    let paidCredits: Int
    let totalCredits: Int
    let totalAnalyses: Int

    var hasCredits: Bool { totalCredits > 0 }
}

// MARK: - Analysis Result

/// Combined result from analysis endpoint (analysis + credit balance)
struct AnalysisResult {
    let analysis: AnalysisResponse
    let creditBalance: CreditBalance?
    /// True when the model's reply was cut off even after a retry with more room.
    let truncated: Bool
}

// MARK: - API Errors

/// API error types
enum APIError: LocalizedError {
    case invalidResponse
    case badRequest
    /// Server returned 400 with a specific message (e.g. validation summary)
    case badRequestDetail(String)
    case unauthorized
    case noCredits
    /// 403 that is not a DeviceCheck failure (e.g. another device's tank)
    case forbidden(String)
    case deviceCheckRequired
    case notFound
    case conflict(String)
    /// 422: the AI declined to analyse the input; the credit was refunded
    case analysisRefused(String)
    case rateLimited
    case serviceUnavailable
    case serverError(Int)
    case unknown(Int)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from server"
        case .badRequest: return "Invalid request. Please check your input."
        case .badRequestDetail(let message): return message
        case .unauthorized: return "Authentication required"
        case .noCredits: return "No analysis credits remaining. Purchase more to continue."
        case .forbidden(let message): return message.isEmpty ? "Access denied" : message
        case .deviceCheckRequired: return "This device could not be verified. Please update to the latest app version and try again."
        case .notFound: return "Resource not found"
        case .conflict(let message): return message.isEmpty ? "This item already exists" : message
        case .analysisRefused(let message): return message.isEmpty ? "The AI declined to analyse this input. Your credit has been refunded." : message
        case .rateLimited: return "Too many requests. Please wait and try again."
        case .serviceUnavailable: return "Service temporarily unavailable. Please try again in a moment."
        case .serverError(let code): return "Server error (\(code)). Please try again later."
        case .unknown(let code): return "Unexpected error (\(code))"
        case .decodingError: return "The server sent a response the app could not read. Please update the app."
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        }
    }
}
