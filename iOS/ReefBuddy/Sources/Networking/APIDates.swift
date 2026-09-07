import Foundation

// MARK: - Date handling

/// The Worker emits ISO 8601 with milliseconds (`toISOString()`), D1 defaults emit `YYYY-MM-DD HH:MM:SS`,
/// and older rows may carry plain ISO without fractions. Foundation's `.iso8601` strategy only accepts
/// the last of these, which is why every server response used to fail to decode (I-01).
enum APIDates {
    // ISO8601DateFormatter is thread-safe (like DateFormatter) but the SDK does not mark it Sendable,
    // and the instances are never mutated after creation.
    nonisolated(unsafe) static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) static let iso: ISO8601DateFormatter = {
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
