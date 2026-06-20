import Foundation
import Combine

final class MockMaintenanceStore: ObservableObject {
    @Published var currentUser = MockUser(
        id: "user-diego",
        name: "Diego Vera",
        role: .technician
    )

    @Published var activities: [PreventiveActivity] = MockMaintenanceStore.makeActivities()

    var activeCorrectiveCount: Int {
        1
    }

    var pendingClosureCount: Int {
        activities.filter { $0.status == .completed }.count
    }

    func activities(for status: MaintenanceStatus) -> [PreventiveActivity] {
        activities.filter { $0.status == status }
    }

    func start(_ activity: PreventiveActivity) {
        update(activity) { item in
            guard item.status == .scheduled, currentUser.role.canEditMaintenance else { return }
            item.status = .inProgress
        }
    }

    func complete(_ activity: PreventiveActivity) {
        update(activity) { item in
            guard item.status == .inProgress, currentUser.role.canEditMaintenance else { return }
            item.status = .completed
        }
    }

    func close(_ activity: PreventiveActivity) {
        update(activity) { item in
            guard item.status == .completed, currentUser.role.canCloseMaintenance else { return }
            item.status = .closed
        }
    }

    func reopen(_ activity: PreventiveActivity) {
        update(activity) { item in
            guard item.status == .closed, currentUser.role.canCloseMaintenance else { return }
            item.status = .completed
        }
    }

    func finalizeReport(for activity: PreventiveActivity) {
        update(activity) { item in
            guard currentUser.role.canEditMaintenance else { return }
            let nextVersion = (item.reportVersions.map(\.versionNumber).max() ?? 0) + 1
            item.reportVersions.insert(
                ReportVersion(
                    id: UUID(),
                    versionNumber: nextVersion,
                    createdBy: currentUser.name,
                    createdAt: Date()
                ),
                at: 0
            )
        }
    }

    func toggleRole() {
        switch currentUser.role {
        case .technician: currentUser.role = .coordinator
        case .coordinator: currentUser.role = .boss
        case .boss: currentUser.role = .administrator
        case .administrator: currentUser.role = .technician
        }
    }

    private func update(_ activity: PreventiveActivity, mutate: (inout PreventiveActivity) -> Void) {
        guard let index = activities.firstIndex(where: { $0.id == activity.id }) else { return }
        mutate(&activities[index])
    }

    private static func makeActivities() -> [PreventiveActivity] {
        [
            PreventiveActivity(
                id: "prv-001",
                name: "Mantenimiento preventivo de software ATS - ECIN",
                templateName: "Mantenimiento preventivo de software ATS",
                assets: ["Software ATS Patio", "LIMSYS001", "LIMSYS002"],
                location: "Sala 2.21",
                subsystem: "ATS",
                scheduledDate: Date(),
                status: .scheduled,
                manualReference: "ML2-AST-GEN-G-000-GRAL-SSATS-GEN-MN-3500-0A",
                frequency: "Revision periodica diaria",
                estimatedMinutes: 60,
                requiredPersonnel: 2,
                requiredTools: ["Laptop de mantenimiento", "Probador de red"],
                steps: [
                    MaintenanceStep(id: UUID(), title: "Revision de archivos de registro del sistema", manualPage: 12, isCompleted: false, comment: ""),
                    MaintenanceStep(id: UUID(), title: "Verificacion de herramienta de estado del nodo", manualPage: 15, isCompleted: false, comment: ""),
                    MaintenanceStep(id: UUID(), title: "Verificacion del uso de memoria", manualPage: 18, isCompleted: false, comment: "")
                ],
                reportVersions: []
            ),
            PreventiveActivity(
                id: "prv-002",
                name: "Inspeccion de gabinete Frontam - Colectora",
                templateName: "Inspeccion de gabinete Frontam",
                assets: ["Frontam Colectora"],
                location: "Sala 2.21",
                subsystem: "CBTC",
                scheduledDate: Date(),
                status: .inProgress,
                manualReference: "ML2-CBTC-FRONTAM-MN-001",
                frequency: "Mensual",
                estimatedMinutes: 90,
                requiredPersonnel: 2,
                requiredTools: ["Multimetro digital", "Torquimetro"],
                steps: [
                    MaintenanceStep(id: UUID(), title: "Inspeccion visual del gabinete", manualPage: 8, isCompleted: true, comment: "Sin observaciones."),
                    MaintenanceStep(id: UUID(), title: "Verificacion de ventiladores", manualPage: 11, isCompleted: false, comment: ""),
                    MaintenanceStep(id: UUID(), title: "Verificacion de servidores", manualPage: 14, isCompleted: false, comment: "")
                ],
                reportVersions: [
                    ReportVersion(id: UUID(), versionNumber: 1, createdBy: "Diego Vera", createdAt: Date())
                ]
            ),
            PreventiveActivity(
                id: "prv-003",
                name: "Inspeccion de CRK 1 y CRK 2",
                templateName: "Inspeccion de gabinete Frontam",
                assets: ["CRK 1", "CRK 2"],
                location: "Colectora Industrial",
                subsystem: "ATS",
                scheduledDate: Date(),
                status: .completed,
                manualReference: "ML2-ATS-CRK-MN-001",
                frequency: "Mensual",
                estimatedMinutes: 120,
                requiredPersonnel: 2,
                requiredTools: ["Laptop de mantenimiento", "Multimetro digital"],
                steps: [
                    MaintenanceStep(id: UUID(), title: "Inspeccion visual de gabinetes", manualPage: 6, isCompleted: true, comment: "Gabinetes operativos."),
                    MaintenanceStep(id: UUID(), title: "Verificacion de alarmas", manualPage: 10, isCompleted: true, comment: "Sin alarmas activas.")
                ],
                reportVersions: [
                    ReportVersion(id: UUID(), versionNumber: 1, createdBy: "Joab Apaza", createdAt: Date())
                ]
            )
        ]
    }
}
