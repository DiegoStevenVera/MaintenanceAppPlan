import Foundation
import SwiftUI

enum UserRole: String, CaseIterable, Identifiable, Codable {
    case maintenanceEngineer
    case coordinator
    case boss
    case administrator

    var id: String { rawValue }

    init?(apiValue: String) {
        switch apiValue {
        case "MAINTENANCE_ENGINEER": self = .maintenanceEngineer
        case "COORDINATOR": self = .coordinator
        case "BOSS": self = .boss
        case "ADMINISTRATOR": self = .administrator
        default: return nil
        }
    }

    var label: String {
        switch self {
        case .maintenanceEngineer: return "Ingeniero de Mantenimiento de Sistemas de Señalización"
        case .coordinator: return "Coordinador"
        case .boss: return "Jefe"
        case .administrator: return "Administrador"
        }
    }

    var apiValue: String {
        switch self {
        case .maintenanceEngineer: return "MAINTENANCE_ENGINEER"
        case .coordinator: return "COORDINATOR"
        case .boss: return "BOSS"
        case .administrator: return "ADMINISTRATOR"
        }
    }

    var canEditMaintenance: Bool { self != .boss }
    var canCloseMaintenance: Bool { self == .coordinator || self == .administrator }
    var canEditPlanning: Bool { self == .administrator }
    var canEditSchedules: Bool { self == .coordinator || self == .administrator }
}

enum AppModulePermission: String, CaseIterable, Identifiable, Codable {
    case home = "HOME"
    case preventive = "PREVENTIVE"
    case corrective = "CORRECTIVE"
    case pcon = "PCON"
    case equipment = "EQUIPMENT"
    case schedule = "SCHEDULE"
    case stock = "STOCK"
    case tools = "TOOLS"
    case profile = "PROFILE"

    var id: String { rawValue }
}

enum PermissionLevel: String, CaseIterable, Identifiable, Codable, Comparable {
    case none = "NONE"
    case read = "READ"
    case write = "WRITE"

    var id: String { rawValue }

    static func < (lhs: PermissionLevel, rhs: PermissionLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .none: 0
        case .read: 1
        case .write: 2
        }
    }
}

struct AppUser: Identifiable, Codable {
    let id: String
    let name: String
    var role: UserRole
    var email: String
    var avatarSystemImage: String
}

enum MaintenanceDateFilter: String, CaseIterable, Identifiable, Codable {
    case today
    case thisWeek
    case thisMonth
    case specificMonth

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: return "Hoy"
        case .thisWeek: return "Esta semana"
        case .thisMonth: return "Este Mes"
        case .specificMonth: return "Mes especifico"
        }
    }

    var icon: String {
        switch self {
        case .today: return "calendar"
        case .thisWeek: return "calendar.badge.clock"
        case .thisMonth: return "calendar.circle"
        case .specificMonth: return "line.3.horizontal.decrease.circle"
        }
    }
}

enum PeruvianDateFormat {
    static func display(_ rawValue: String) -> String {
        for formatter in inputFormatters {
            if let date = formatter.date(from: rawValue) {
                return outputFormatter.string(from: date)
            }
        }
        return rawValue
    }

    private static let inputFormatters: [DateFormatter] = [
        formatter("yyyy-MM-dd"),
        formatter("dd/MM/yyyy"),
        formatter("dd-MM-yyyy"),
    ]

    private static let outputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "America/Lima")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "America/Lima")
        formatter.dateFormat = format
        return formatter
    }
}

enum Severity: String, CaseIterable, Identifiable, Codable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low: return "Baja"
        case .medium: return "Media"
        case .high: return "Alta"
        }
    }

    var color: Color {
        switch self {
        case .low: return BrandColor.green
        case .medium: return BrandColor.amber
        case .high: return BrandColor.red
        }
    }
}
