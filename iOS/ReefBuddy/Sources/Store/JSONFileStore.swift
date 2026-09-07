import Foundation
import os

private let log = Logger(subsystem: "au.com.aethers.reefbuddy", category: "Storage")

// MARK: - JSON File Store

/// One JSON document per file under `Application Support/ReefBuddy/Data` (I-33).
///
/// Reads are synchronous: the documents are small and the stores need their contents before the first
/// frame, exactly as the old UserDefaults blobs did. Writes are encoded and written off the main actor and
/// serialised through the actor; a per-file generation counter makes the newest snapshot win when several
/// saves are queued in quick succession. The first read of a document migrates the legacy UserDefaults blob
/// (same bytes, same coding) and removes the defaults key.
actor JSONFileStore {
    static let shared = JSONFileStore()

    /// How `Date` values are encoded in a document. The stores that predate this actor used ISO 8601,
    /// except saved analyses, which used Foundation's default (`timeIntervalSinceReferenceDate`).
    enum DateCoding: Sendable {
        case iso8601
        case foundationDefault

        fileprivate func makeEncoder() -> JSONEncoder {
            let encoder = JSONEncoder()
            if case .iso8601 = self { encoder.dateEncodingStrategy = .iso8601 }
            return encoder
        }

        fileprivate func makeDecoder() -> JSONDecoder {
            let decoder = JSONDecoder()
            if case .iso8601 = self { decoder.dateDecodingStrategy = .iso8601 }
            return decoder
        }
    }

    nonisolated let directory: URL
    private var lastGeneration: [String: UInt64] = [:]

    init(directory: URL = JSONFileStore.defaultDirectory) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    nonisolated static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ReefBuddy/Data", isDirectory: true)
    }

    nonisolated func url(for file: String) -> URL {
        directory.appendingPathComponent(file)
    }

    // MARK: Loading

    /// Decodes `file`. When the file does not exist yet and `legacyDefaultsKey` holds a blob, that blob is
    /// decoded, written to the file and removed from UserDefaults. Returns nil when nothing is stored, or when
    /// the stored bytes do not decode (the unreadable file is kept next to the document as `*.corrupt`).
    nonisolated func load<T: Decodable>(
        _ type: T.Type,
        from file: String,
        dates: DateCoding,
        legacyDefaultsKey: String? = nil
    ) -> T? {
        let decoder = dates.makeDecoder()
        let url = url(for: file)

        if let data = try? Data(contentsOf: url) {
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                log.error("Could not decode \(file, privacy: .public): \(error.localizedDescription, privacy: .public)")
                let quarantine = url.appendingPathExtension("corrupt")
                try? FileManager.default.removeItem(at: quarantine)
                try? FileManager.default.moveItem(at: url, to: quarantine)
                return nil
            }
        }

        guard let key = legacyDefaultsKey, let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        do {
            let value = try decoder.decode(T.self, from: data)
            try data.write(to: url, options: .atomic)
            UserDefaults.standard.removeObject(forKey: key)
            log.notice("Migrated \(key, privacy: .public) → \(file, privacy: .public) (\(data.count) bytes)")
            return value
        } catch {
            log.error("Could not migrate \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: Saving

    /// Writes `value` atomically unless a newer generation for the same file has already been written.
    func save<T: Encodable & Sendable>(_ value: T, to file: String, dates: DateCoding, generation: UInt64) {
        if let last = lastGeneration[file], last > generation { return }
        lastGeneration[file] = generation
        do {
            let data = try dates.makeEncoder().encode(value)
            try data.write(to: url(for: file), options: .atomic)
            log.debug("Saved \(file, privacy: .public) (\(data.count) bytes)")
        } catch {
            log.error("Could not save \(file, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - JSON Document

/// A store's handle on one persisted document: synchronous load at start-up, ordered background saves.
@MainActor
struct JSONDocument<Value: Codable & Sendable> {
    let file: String
    let dates: JSONFileStore.DateCoding
    let legacyDefaultsKey: String?
    private var generation: UInt64 = 0

    init(file: String, dates: JSONFileStore.DateCoding = .iso8601, legacyDefaultsKey: String? = nil) {
        self.file = file
        self.dates = dates
        self.legacyDefaultsKey = legacyDefaultsKey
    }

    func load() -> Value? {
        JSONFileStore.shared.load(Value.self, from: file, dates: dates, legacyDefaultsKey: legacyDefaultsKey)
    }

    mutating func save(_ value: Value) {
        generation += 1
        let generation = generation
        let file = file
        let dates = dates
        Task.detached(priority: .utility) {
            await JSONFileStore.shared.save(value, to: file, dates: dates, generation: generation)
        }
    }
}
