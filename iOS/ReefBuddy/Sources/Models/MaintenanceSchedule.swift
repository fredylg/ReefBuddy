import Foundation

// MARK: - Maintenance Schedule

struct MaintenanceSchedule: Identifiable, Codable, Equatable {
    enum ScheduleType: String, Codable, CaseIterable {
        case waterChange = "water_change"
        case filter = "filter"
        case testing = "testing"

        var title: String {
            switch self {
            case .waterChange: return "Water change"
            case .filter: return "Filter"
            case .testing: return "Testing"
            }
        }

        var badgeText: String {
            switch self {
            case .waterChange: return "WATER CHANGE"
            case .filter: return "FILTER"
            case .testing: return "TESTING"
            }
        }

        var systemIcon: String {
            switch self {
            case .waterChange: return "drop.fill"
            case .filter: return "line.3.horizontal.decrease.circle.fill"
            case .testing: return "checklist"
            }
        }
    }

    enum ScheduleKind: String, Codable, CaseIterable {
        case intervalDays = "interval_days"
        case weekly = "weekly"
    }

    let id: UUID
    var tankId: UUID
    var type: ScheduleType
    var enabled: Bool

    var scheduleKind: ScheduleKind
    var intervalDays: Int?
    var weekdays: [Int]? // ISO weekday 1..7 (Mon..Sun)

    var timeLocal: String // "HH:MM"
    var timezone: String // IANA identifier
    var notes: String?

    var createdAt: Date
    var updatedAt: Date

    // Local-first sync metadata
    var needsSync: Bool
    var isDeleted: Bool

    init(
        id: UUID = UUID(),
        tankId: UUID,
        type: ScheduleType,
        enabled: Bool = true,
        scheduleKind: ScheduleKind,
        intervalDays: Int? = nil,
        weekdays: [Int]? = nil,
        timeLocal: String,
        timezone: String = TimeZone.current.identifier,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        needsSync: Bool = true,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.tankId = tankId
        self.type = type
        self.enabled = enabled
        self.scheduleKind = scheduleKind
        self.intervalDays = intervalDays
        self.weekdays = weekdays
        self.timeLocal = timeLocal
        self.timezone = timezone
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.needsSync = needsSync
        self.isDeleted = isDeleted
    }
}

// MARK: - Water Change

struct WaterChange: Identifiable, Codable, Equatable {
    let id: UUID
    var tankId: UUID
    var performedAt: Date
    var percentReplaced: Double?
    var gallonsReplaced: Double?
    var notes: String?
    var sourceScheduleId: UUID?
    var createdAt: Date
    var updatedAt: Date

    // Local-first sync metadata
    var needsSync: Bool
    var isDeleted: Bool

    init(
        id: UUID = UUID(),
        tankId: UUID,
        performedAt: Date = Date(),
        percentReplaced: Double? = nil,
        gallonsReplaced: Double? = nil,
        notes: String? = nil,
        sourceScheduleId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        needsSync: Bool = true,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.tankId = tankId
        self.performedAt = performedAt
        self.percentReplaced = percentReplaced
        self.gallonsReplaced = gallonsReplaced
        self.notes = notes
        self.sourceScheduleId = sourceScheduleId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.needsSync = needsSync
        self.isDeleted = isDeleted
    }
}

// MARK: - Notes helpers (testing checklist)

enum MaintenanceChecklistItem: String, CaseIterable, Codable, Hashable {
    case alk = "ALK"
    case ca = "CA"
    case mg = "MG"
    case no3 = "NO3"
    case po4 = "PO4"
    case ph = "PH"
    case sal = "SAL"
    case temp = "TEMP"
}

struct MaintenanceNotesPayload: Codable, Equatable {
    var checklist: [String]?
}

extension MaintenanceSchedule {
    func checklistItemsFromNotes() -> Set<MaintenanceChecklistItem> {
        guard let notes, let data = notes.data(using: .utf8) else { return [] }
        guard let payload = try? JSONDecoder().decode(MaintenanceNotesPayload.self, from: data) else { return [] }
        let raw = payload.checklist ?? []
        return Set(raw.compactMap { MaintenanceChecklistItem(rawValue: $0) })
    }

    static func notesJSON(for checklist: Set<MaintenanceChecklistItem>) -> String? {
        let items = checklist.map(\.rawValue).sorted()
        if items.isEmpty { return nil }
        let payload = MaintenanceNotesPayload(checklist: items)
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Deep link payload

struct MaintenanceDeepLink: Equatable {
    let scheduleId: UUID
    let tankId: UUID
    let type: MaintenanceSchedule.ScheduleType
}

struct AnalysisWaterChangeContext: Equatable {
    let id: UUID
    let tankId: UUID
}

