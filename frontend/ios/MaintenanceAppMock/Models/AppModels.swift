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
        case .maintenanceEngineer: return "Ingeniero de Mantenimiento"
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
    var canEditPlanning: Bool { self == .coordinator || self == .administrator }
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
