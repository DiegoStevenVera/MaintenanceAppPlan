import Foundation
import SwiftUI

enum UserRole: String, CaseIterable, Identifiable {
    case technician
    case coordinator
    case boss
    case administrator

    var id: String { rawValue }

    var label: String {
        switch self {
        case .technician:
            return "Tecnico mantenedor"
        case .coordinator:
            return "Coordinador"
        case .boss:
            return "Jefe"
        case .administrator:
            return "Administrador"
        }
    }

    var canEditMaintenance: Bool {
        self != .boss
    }

    var canCloseMaintenance: Bool {
        self == .coordinator || self == .administrator
    }
}

enum MaintenanceStatus: String, CaseIterable, Identifiable {
    case scheduled
    case inProgress
    case completed
    case closed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .scheduled:
            return "Programado"
        case .inProgress:
            return "En progreso"
        case .completed:
            return "Completado"
        case .closed:
            return "Cerrado"
        }
    }

    var icon: String {
        switch self {
        case .scheduled:
            return "calendar"
        case .inProgress:
            return "arrow.triangle.2.circlepath"
        case .completed:
            return "checkmark.circle.fill"
        case .closed:
            return "lock.circle.fill"
        }
    }

    var foregroundColor: Color {
        switch self {
        case .scheduled: BrandColor.graphite
        case .inProgress: Color(red: 0.780, green: 0.471, blue: 0.0)
        case .completed: Color(red: 0.122, green: 0.541, blue: 0.298)
        case .closed: Color(red: 0.420, green: 0.420, blue: 0.420)
        }
    }

    var backgroundColor: Color {
        foregroundColor.opacity(0.12)
    }
}

struct MockUser: Identifiable {
    let id: String
    let name: String
    var role: UserRole
}

struct ReportVersion: Identifiable {
    let id: UUID
    let versionNumber: Int
    let createdBy: String
    let createdAt: Date
}

struct MaintenanceStep: Identifiable {
    let id: UUID
    let title: String
    let manualPage: Int
    var isCompleted: Bool
    var comment: String
}

struct PreventiveActivity: Identifiable {
    let id: String
    var name: String
    var templateName: String
    var assets: [String]
    var location: String
    var subsystem: String
    var scheduledDate: Date
    var status: MaintenanceStatus
    var manualReference: String
    var frequency: String
    var estimatedMinutes: Int
    var requiredPersonnel: Int
    var requiredTools: [String]
    var steps: [MaintenanceStep]
    var reportVersions: [ReportVersion]
}
