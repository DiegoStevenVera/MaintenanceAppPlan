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
        case "MAINTENANCE_ENGINEER":
            self = .maintenanceEngineer
        case "COORDINATOR":
            self = .coordinator
        case "BOSS":
            self = .boss
        case "ADMINISTRATOR":
            self = .administrator
        default:
            return nil
        }
    }

    var label: String {
        switch self {
        case .maintenanceEngineer:
            return "Ingeniero de Mantenimiento"
        case .coordinator:
            return "Coordinador"
        case .boss:
            return "Jefe"
        case .administrator:
            return "Administrador"
        }
    }

    var apiValue: String {
        switch self {
        case .maintenanceEngineer:
            return "MAINTENANCE_ENGINEER"
        case .coordinator:
            return "COORDINATOR"
        case .boss:
            return "BOSS"
        case .administrator:
            return "ADMINISTRATOR"
        }
    }

    var canEditMaintenance: Bool {
        self != .boss
    }

    var canCloseMaintenance: Bool {
        self == .coordinator || self == .administrator
    }

    var canEditPlanning: Bool {
        self == .coordinator || self == .administrator
    }
}

enum MaintenanceStatus: String, CaseIterable, Identifiable, Codable {
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

struct MockUser: Identifiable, Codable {
    let id: String
    let name: String
    var role: UserRole
    var email: String = ""
    var avatarSystemImage: String = "person.crop.circle.fill"
}

struct MaintenanceComment: Identifiable, Codable {
    let id: UUID
    let scopeKey: String
    let scopeDescription: String
    let author: MockUser
    let message: String
    let createdAt: Date
}

struct CorrectiveComment: Identifiable, Codable {
    let id: UUID
    let eventID: String
    let author: MockUser
    let message: String
    let createdAt: Date
}

struct ReportSignature: Identifiable, Codable {
    let id: UUID
    let user: MockUser
    let strokes: [[CGPoint]]
    let signedAt: Date?
}

struct HistoricalMaintenanceReport: Identifiable, Codable {
    let id: UUID
    let equipmentName: String
    let activityName: String
    let engineerName: String
    let performedAt: Date
    let result: String
    let steps: [MaintenanceStep]
    let participants: [ReportSignature]

    init(
        id: UUID,
        equipmentName: String,
        activityName: String,
        engineerName: String,
        performedAt: Date,
        result: String,
        steps: [MaintenanceStep] = [],
        participants: [ReportSignature] = []
    ) {
        self.id = id
        self.equipmentName = equipmentName
        self.activityName = activityName
        self.engineerName = engineerName
        self.performedAt = performedAt
        self.result = result
        self.steps = steps
        self.participants = participants
    }
}

struct ReportVersion: Identifiable, Codable {
    let id: UUID
    let versionNumber: Int
    let createdBy: String
    let createdAt: Date
    let summary: String

    init(id: UUID, versionNumber: Int, createdBy: String, createdAt: Date, summary: String = "PDF disponible") {
        self.id = id
        self.versionNumber = versionNumber
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.summary = summary
    }
}

struct MaintenanceStep: Identifiable, Codable {
    let id: UUID
    let title: String
    let manualPage: Int
    var isCompleted: Bool
    var comment: String
    var tests: [MaintenanceStepTest]

    init(id: UUID, title: String, manualPage: Int, isCompleted: Bool, comment: String, tests: [MaintenanceStepTest] = []) {
        self.id = id
        self.title = title
        self.manualPage = manualPage
        self.isCompleted = isCompleted
        self.comment = comment
        self.tests = tests
    }
}

struct MaintenanceStepTest: Identifiable, Codable {
    let id: UUID
    var name: String
    var resultOptions: [String]
    var selectedResult: String
    var notes: String
}

struct ReportParticipantDraft: Identifiable, Codable {
    let id: UUID
    var user: MockUser
    var isSelected: Bool
    var hasSignature: Bool
}

enum PreventiveConclusion: String, CaseIterable, Identifiable, Codable {
    case operational = "Equipo operativo"
    case notOperational = "Equipo no operativo"
    case partiallyOperational = "Equipo medio operativo"

    var id: String { rawValue }
}

enum PreventiveHistoryFilter: String, CaseIterable, Identifiable, Codable {
    case today
    case previousWeek
    case thisMonth
    case olderMonths

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: return "Hoy"
        case .previousWeek: return "Semana anterior"
        case .thisMonth: return "Este mes"
        case .olderMonths: return "Meses anteriores"
        }
    }
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

struct PreventiveActivity: Identifiable, Codable {
    let id: String
    var name: String
    var templateName: String
    var assets: [String]
    var site: String
    var project: String
    var stage: String
    var system: String
    var location: String
    var locationPath: String
    var subsystem: String
    var scheduledDate: Date
    var startedAt: Date?
    var endedAt: Date?
    var status: MaintenanceStatus
    var manualReference: String
    var frequency: String
    var estimatedMinutes: Int
    var requiredPersonnel: Int
    var requiredTools: [String]
    var steps: [MaintenanceStep]
    var reportVersions: [ReportVersion]
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
        case .low: return Color(red: 0.122, green: 0.541, blue: 0.298)
        case .medium: return Color(red: 0.780, green: 0.471, blue: 0.0)
        case .high: return BrandColor.red
        }
    }
}

enum CorrectiveActivityType: String, CaseIterable, Identifiable, Codable {
    case inspection
    case replacement
    case cleaning
    case adjustment
    case measurement
    case software
    case testing
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .inspection: return "Inspeccion / Levantamiento de data"
        case .replacement: return "Cambio de componente"
        case .cleaning: return "Limpieza"
        case .adjustment: return "Ajuste"
        case .measurement: return "Medicion"
        case .software: return "Accion de software"
        case .testing: return "Investigacion / Pruebas"
        case .other: return "Otro"
        }
    }
}

enum CorrectiveImpact: String, CaseIterable, Identifiable, Codable {
    case none = "Sin impacto operacional"
    case degraded = "Operacion degradada"
    case serviceAffected = "Servicio afectado"
    case stopped = "Servicio detenido"

    var id: String { rawValue }
}

enum FailureAnalysisType: String, CaseIterable, Identifiable, Codable {
    case functional = "Funcional"
    case hardware = "Hardware"
    case software = "Software"
    case communications = "Comunicaciones"
    case power = "Energia"

    var id: String { rawValue }
}

enum ComponentCondition: String, CaseIterable, Identifiable, Codable {
    case operational = "Operativo"
    case inoperative = "Inoperativo"

    var id: String { rawValue }
}

enum CorrectiveValidationResult: String, CaseIterable, Identifiable, Codable {
    case compliant = "Conforme"
    case notCompliant = "No Conforme"

    var id: String { rawValue }
}

enum CorrectiveTechnicalStatus: String, CaseIterable, Identifiable, Codable {
    case operational = "Operativo"
    case restricted = "Operativo con restricciones"
    case inoperative = "Inoperativo"

    var id: String { rawValue }
}

struct ReplacementDraft: Identifiable, Codable {
    let id: UUID
    var parentAsset: String
    var removedAsset: String
    var installedAsset: String
    var source: String
    var destination: String
    var reason: String
    var removedPartNumber: String = ""
    var removedSerialNumber: String = ""
    var removedModel: String = ""
    var removedManufacturer: String = ""
    var removedCondition: ComponentCondition = .inoperative
    var removedDestination: String = "Almacenamiento Mantto Hitachi"
    var removedNotes: String = ""
    var installedPartNumber: String = ""
    var installedSerialNumber: String = ""
    var installedModel: String = ""
    var installedManufacturer: String = ""
    var installedCondition: ComponentCondition = .operational
    var installedNotes: String = ""
}

struct CorrectiveActivityEntry: Identifiable, Codable {
    let id: UUID
    var type: CorrectiveActivityType
    var description: String
    var notes: String
    var startedAt: Date = Date()
    var endedAt: Date = Date()
    var replacement: ReplacementDraft?
}

struct TimelineEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: String
    let text: String
}

struct CorrectiveEvent: Identifiable, Codable {
    let id: String
    var code: String
    var sapCode: String
    var name: String
    var site: String = "Metro Lima"
    var project: String = "Linea 2"
    var stage: String = "Etapa 1A"
    var system: String = "Senalizacion"
    var affectedAsset: String
    var location: String
    var subsystem: String
    var noticeCreatedAt: Date = Date()
    var responseAt: Date = Date()
    var severity: Severity
    var status: MaintenanceStatus
    var failureDescription: String
    var operationalImpact: String
    var symptom: String = ""
    var technicalDescription: String = ""
    var impactSelection: CorrectiveImpact = .degraded
    var failureAnalysis: FailureAnalysisType = .hardware
    var functionalTests: String = ""
    var validationResult: CorrectiveValidationResult = .compliant
    var serviceRelease: Bool = false
    var serviceReleaseAt: Date = Date()
    var validationResponsible: String = ""
    var technicalStatus: CorrectiveTechnicalStatus = .operational
    var observations: String = ""
    var timeline: [TimelineEntry]
    var activities: [CorrectiveActivityEntry]
    var reportVersions: [ReportVersion]
}

struct MaintenanceAsset: Identifiable, Codable {
    let id: String
    var name: String
    var type: String
    var category: String
    var businessLabel: String
    var isBusinessAnchor: Bool
    var serialOrCode: String
    var partNumber: String
    var status: String
    var location: String
    var parent: String?
    var children: [String]
    var history: [String]
}

struct StockAsset: Identifiable, Codable {
    let id: String
    var name: String
    var type: String
    var serialOrCode: String
    var partNumber: String
    var status: String
    var location: String
    var subsystem: String
}
