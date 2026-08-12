import Foundation
import Combine
import CoreGraphics

final class MockMaintenanceStore: ObservableObject {
    @Published var currentUser = MockUser(
        id: "",
        name: "",
        role: .maintenanceEngineer,
        email: ""
    )
    @Published var isAuthenticated = false

    @Published var loginUsers: [MockUser] = []
    @Published var activities: [PreventiveActivity] = []
    @Published var correctiveEvents: [CorrectiveEvent] = []
    @Published var assets: [MaintenanceAsset] = []
    @Published var stockAssets: [StockAsset] = []
    @Published var activeMaintainers: [MockUser] = []
    @Published var maintenanceComments: [MaintenanceComment] = []
    @Published var correctiveComments: [CorrectiveComment] = []
    @Published var historicalReports: [HistoricalMaintenanceReport] = []
    @Published var preventiveReportSignatures: [String: [ReportSignature]] = [:]
    @Published var correctiveReportSignatures: [String: [ReportSignature]] = [:]
    @Published var isDarkModeEnabled = false
    var apiBaseURL: String?

    var activeCorrectiveCount: Int {
        correctiveEvents.filter { $0.status == .scheduled || $0.status == .inProgress }.count
    }

    var pendingClosureCount: Int {
        activities.filter { $0.status == .completed }.count
    }

    func signIn(email: String, password: String) -> Bool {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard password == "123456",
              let user = loginUsers.first(where: { $0.email.lowercased() == normalizedEmail }) else {
            isAuthenticated = false
            return false
        }
        currentUser = user
        isAuthenticated = true
        return true
    }

    func completeAPISignIn(user: MockUser) {
        currentUser = user
        isAuthenticated = true
    }

    func applyRemoteState(_ state: RemoteAppState) {
        loginUsers = state.loginUsers
        activeMaintainers = state.activeMaintainers
        activities = state.activities
        correctiveEvents = state.correctiveEvents
        assets = state.assets
        stockAssets = state.stockAssets
        maintenanceComments = state.maintenanceComments
        correctiveComments = state.correctiveComments
        historicalReports = state.historicalReports
        preventiveReportSignatures = state.preventiveReportSignatures
        correctiveReportSignatures = state.correctiveReportSignatures
    }

    func remoteState() -> RemoteAppState {
        RemoteAppState(
            loginUsers: loginUsers,
            activeMaintainers: activeMaintainers,
            activities: activities,
            correctiveEvents: correctiveEvents,
            assets: assets,
            stockAssets: stockAssets,
            maintenanceComments: maintenanceComments,
            correctiveComments: correctiveComments,
            historicalReports: historicalReports,
            preventiveReportSignatures: preventiveReportSignatures,
            correctiveReportSignatures: correctiveReportSignatures
        )
    }

    func persistRemoteState() {
        guard let apiBaseURL else { return }
        let state = remoteState()
        Task {
            try? await AppStateService(baseURLString: apiBaseURL).replaceCurrentState(state)
        }
    }

    func signOut() {
        isAuthenticated = false
    }

    func activities(for status: MaintenanceStatus) -> [PreventiveActivity] {
        activities.filter { $0.status == status }
    }

    func start(_ activity: PreventiveActivity) {
        update(activity) { item in
            guard item.status == .scheduled, currentUser.role.canEditMaintenance else { return }
            item.status = .inProgress
            item.startedAt = Date()
        }
        persistRemoteState()
    }

    func complete(_ activity: PreventiveActivity) {
        update(activity) { item in
            guard item.status == .inProgress, currentUser.role.canEditMaintenance else { return }
            item.status = .completed
            item.endedAt = Date()
        }
        persistRemoteState()
    }

    func close(_ activity: PreventiveActivity) {
        update(activity) { item in
            guard item.status == .completed, currentUser.role.canCloseMaintenance else { return }
            item.status = .closed
        }
        persistRemoteState()
    }

    func reopen(_ activity: PreventiveActivity) {
        update(activity) { item in
            if item.status == .completed, currentUser.role.canEditMaintenance {
                item.status = .inProgress
                item.startedAt = Date()
                return
            }
            if item.status == .closed, currentUser.role.canCloseMaintenance {
                item.status = .inProgress
                item.startedAt = Date()
            }
        }
        persistRemoteState()
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
        persistRemoteState()
    }

    func finalizePreventiveReport(activityID: String, steps: [MaintenanceStep], conclusion: PreventiveConclusion, additionalComments: String, endedAt: Date, participants: [ReportParticipantDraft], signatureStrokes: [UUID: [[CGPoint]]]) {
        guard let index = activities.firstIndex(where: { $0.id == activityID }),
              currentUser.role.canEditMaintenance else { return }

        activities[index].steps = steps
        activities[index].endedAt = endedAt
        preventiveReportSignatures[activityID] = signatures(from: participants, signatureStrokes: signatureStrokes)
        let nextVersion = (activities[index].reportVersions.map(\.versionNumber).max() ?? 0) + 1
        let signedCount = participants.filter { $0.isSelected && $0.hasSignature }.count
        let commentMarker = additionalComments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : " · Con comentarios"
        activities[index].reportVersions.insert(
            ReportVersion(
                id: UUID(),
                versionNumber: nextVersion,
                createdBy: currentUser.name,
                createdAt: Date(),
                summary: "\(conclusion.rawValue) · \(signedCount) firma(s)\(commentMarker)"
            ),
            at: 0
        )
        persistRemoteState()
    }

    func comments(for activity: PreventiveActivity) -> [MaintenanceComment] {
        let keys = commentScopeKeys(for: activity)
        return maintenanceComments
            .filter { keys.contains($0.scopeKey) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func addComment(to activity: PreventiveActivity, message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        maintenanceComments.append(
            MaintenanceComment(
                id: UUID(),
                scopeKey: commentScopeKey(for: activity),
                scopeDescription: "\(activity.templateName) · \(activity.assets.first ?? "Equipo")",
                author: currentUser,
                message: trimmed,
                createdAt: Date()
            )
        )
        persistRemoteState()
    }

    func defaultParticipants() -> [ReportParticipantDraft] {
        activeMaintainers.map {
            ReportParticipantDraft(id: UUID(), user: $0, isSelected: true, hasSignature: false)
        }
    }

    func previousReports(for activity: PreventiveActivity) -> [HistoricalMaintenanceReport] {
        let equipmentNames = Set(activity.assets)
        return historicalReports
            .filter { equipmentNames.contains($0.equipmentName) || $0.activityName == activity.templateName }
            .sorted { $0.performedAt > $1.performedAt }
    }

    func historicalReports(for filter: PreventiveHistoryFilter) -> [HistoricalMaintenanceReport] {
        let now = Date()
        let calendar = Calendar.current
        return historicalReports
            .filter { report in
                switch filter {
                case .today:
                    return calendar.isDate(report.performedAt, inSameDayAs: now)
                case .previousWeek:
                    guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return false }
                    return report.performedAt >= weekAgo && !calendar.isDate(report.performedAt, inSameDayAs: now)
                case .thisMonth:
                    return calendar.isDate(report.performedAt, equalTo: now, toGranularity: .month)
                case .olderMonths:
                    return !calendar.isDate(report.performedAt, equalTo: now, toGranularity: .month)
                }
            }
            .sorted { $0.performedAt > $1.performedAt }
    }

    func comments(for event: CorrectiveEvent) -> [CorrectiveComment] {
        correctiveComments
            .filter { $0.eventID == event.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func addComment(to event: CorrectiveEvent, message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        correctiveComments.append(
            CorrectiveComment(
                id: UUID(),
                eventID: event.id,
                author: currentUser,
                message: trimmed,
                createdAt: Date()
            )
        )
        persistRemoteState()
    }

    func correctiveEvents(for status: MaintenanceStatus) -> [CorrectiveEvent] {
        correctiveEvents.filter { $0.status == status }
    }

    func createCorrectiveEvent(
        sapEventName: String,
        sapNotification: String,
        affectedAsset: String,
        location: String,
        subsystem: String,
        severity: Severity,
        noticeCreatedAt: Date,
        responseAt: Date
    ) {
        let nextNumber = correctiveEvents.count + 1
        let eventCode = "COR-2026-\(String(format: "%03d", nextNumber))"
        let safeName = sapEventName.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeNotification = sapNotification.trimmingCharacters(in: .whitespacesAndNewlines)

        correctiveEvents.insert(
            CorrectiveEvent(
                id: "cor-\(String(format: "%03d", nextNumber))",
                code: eventCode,
                sapCode: safeNotification.isEmpty ? "-" : safeNotification,
                name: safeName.isEmpty ? "Correctivo sin nombre SAP" : safeName,
                affectedAsset: affectedAsset,
                location: location,
                subsystem: subsystem,
                noticeCreatedAt: noticeCreatedAt,
                responseAt: responseAt,
                severity: severity,
                status: .scheduled,
                failureDescription: "Evento correctivo creado desde el mock. Pendiente de diagnostico.",
                operationalImpact: "Pendiente de evaluar",
                timeline: [
                    TimelineEntry(id: UUID(), timestamp: "Ahora", text: "Evento creado por \(currentUser.name)")
                ],
                activities: [],
                reportVersions: []
            ),
            at: 0
        )
        persistRemoteState()
    }

    func start(_ event: CorrectiveEvent) {
        update(event) { item in
            guard item.status == .scheduled, currentUser.role.canEditMaintenance else { return }
            item.status = .inProgress
            item.timeline.insert(TimelineEntry(id: UUID(), timestamp: "Ahora", text: "Mantenimiento iniciado por \(currentUser.name)"), at: 0)
        }
        persistRemoteState()
    }

    func complete(_ event: CorrectiveEvent) {
        update(event) { item in
            guard item.status == .inProgress, currentUser.role.canEditMaintenance else { return }
            item.status = .completed
            item.timeline.insert(TimelineEntry(id: UUID(), timestamp: "Ahora", text: "Evento marcado como completado"), at: 0)
        }
        persistRemoteState()
    }

    func close(_ event: CorrectiveEvent) {
        update(event) { item in
            guard item.status == .completed, currentUser.role.canCloseMaintenance else { return }
            item.status = .closed
            item.timeline.insert(TimelineEntry(id: UUID(), timestamp: "Ahora", text: "Evento cerrado por Coordinador"), at: 0)
        }
        persistRemoteState()
    }

    func reopen(_ event: CorrectiveEvent) {
        update(event) { item in
            if item.status == .completed, currentUser.role.canEditMaintenance {
                item.status = .inProgress
                item.timeline.insert(TimelineEntry(id: UUID(), timestamp: "Ahora", text: "Evento reabierto por \(currentUser.name)"), at: 0)
                return
            }
            if item.status == .closed, currentUser.role.canCloseMaintenance {
                item.status = .inProgress
                item.timeline.insert(TimelineEntry(id: UUID(), timestamp: "Ahora", text: "Evento reabierto por \(currentUser.name)"), at: 0)
            }
        }
        persistRemoteState()
    }

    func finalizeCorrectiveReport(
        eventID: String,
        activities reportActivities: [CorrectiveActivityEntry],
        symptom: String,
        technicalDescription: String,
        impactSelection: CorrectiveImpact,
        failureAnalysis: FailureAnalysisType,
        functionalTests: String,
        validationResult: CorrectiveValidationResult,
        serviceRelease: Bool,
        serviceReleaseAt: Date,
        validationResponsible: String,
        technicalStatus: CorrectiveTechnicalStatus,
        observations: String,
        stopHere: Bool,
        participants: [ReportParticipantDraft] = [],
        signatureStrokes: [UUID: [[CGPoint]]] = [:]
    ) {
        guard let index = correctiveEvents.firstIndex(where: { $0.id == eventID }),
              currentUser.role.canEditMaintenance else { return }

        correctiveEvents[index].activities = reportActivities
        correctiveEvents[index].symptom = symptom
        correctiveEvents[index].technicalDescription = technicalDescription
        correctiveEvents[index].impactSelection = impactSelection
        correctiveEvents[index].failureAnalysis = failureAnalysis
        correctiveEvents[index].functionalTests = functionalTests
        correctiveEvents[index].validationResult = validationResult
        correctiveEvents[index].serviceRelease = serviceRelease
        correctiveEvents[index].serviceReleaseAt = serviceReleaseAt
        correctiveEvents[index].validationResponsible = validationResponsible
        correctiveEvents[index].technicalStatus = technicalStatus
        correctiveEvents[index].observations = observations
        correctiveEvents[index].failureDescription = technicalDescription.isEmpty ? correctiveEvents[index].failureDescription : technicalDescription
        correctiveEvents[index].operationalImpact = impactSelection.rawValue
        correctiveReportSignatures[eventID] = signatures(from: participants, signatureStrokes: signatureStrokes)
        let nextVersion = (correctiveEvents[index].reportVersions.map(\.versionNumber).max() ?? 0) + 1
        let markerText = stopHere ? " con Stop Here despues de actividades" : ""
        correctiveEvents[index].reportVersions.insert(
            ReportVersion(
                id: UUID(),
                versionNumber: nextVersion,
                createdBy: currentUser.name,
                createdAt: Date(),
                summary: "\(technicalStatus.rawValue) · \(validationResult.rawValue)\(markerText)"
            ),
            at: 0
        )
        correctiveEvents[index].timeline.insert(
            TimelineEntry(id: UUID(), timestamp: "Ahora", text: "Version \(nextVersion) del reporte finalizada\(markerText)"),
            at: 0
        )
        persistRemoteState()
    }

    func toggleRole() {
        switch currentUser.role {
        case .maintenanceEngineer: currentUser.role = .coordinator
        case .coordinator: currentUser.role = .boss
        case .boss: currentUser.role = .administrator
        case .administrator: currentUser.role = .maintenanceEngineer
        }
    }

    func preventivePDFShareText(activity: PreventiveActivity, version: ReportVersion) -> String {
        """
        Reporte preventivo \(activity.name)
        Version \(version.versionNumber)
        Creado por \(version.createdBy)
        Resultado: \(version.summary)
        Equipo(s): \(activity.assets.joined(separator: ", "))
        Ubicacion: \(activity.locationPath)
        """
    }

    func correctivePDFShareText(event: CorrectiveEvent, version: ReportVersion) -> String {
        """
        Reporte correctivo \(event.name)
        Version \(version.versionNumber)
        Creado por \(version.createdBy)
        Resultado: \(version.summary)
        Evento: \(event.code)
        Activo afectado: \(event.affectedAsset)
        Estado tecnico: \(event.technicalStatus.rawValue)
        Validacion: \(event.validationResult.rawValue)
        """
    }

    func historicalPDFShareText(report: HistoricalMaintenanceReport) -> String {
        """
        Reporte preventivo historico
        \(report.activityName)
        Equipo: \(report.equipmentName)
        Ingeniero de Mantenimiento: \(report.engineerName)
        Resultado: \(report.result)
        """
    }

    private func update(_ activity: PreventiveActivity, mutate: (inout PreventiveActivity) -> Void) {
        guard let index = activities.firstIndex(where: { $0.id == activity.id }) else { return }
        mutate(&activities[index])
    }

    private func update(_ event: CorrectiveEvent, mutate: (inout CorrectiveEvent) -> Void) {
        guard let index = correctiveEvents.firstIndex(where: { $0.id == event.id }) else { return }
        mutate(&correctiveEvents[index])
    }

    private func signatures(from participants: [ReportParticipantDraft], signatureStrokes: [UUID: [[CGPoint]]]) -> [ReportSignature] {
        participants
            .filter { $0.isSelected }
            .map {
                ReportSignature(
                    id: UUID(),
                    user: $0.user,
                    strokes: signatureStrokes[$0.id] ?? [],
                    signedAt: $0.hasSignature ? Date() : nil
                )
            }
    }

    private func commentScopeKey(for activity: PreventiveActivity) -> String {
        let equipmentKey = activity.assets.first ?? "general"
        return "preventive:\(activity.templateName)|equipment:\(equipmentKey)"
    }

    private func commentScopeKeys(for activity: PreventiveActivity) -> Set<String> {
        Set(activity.assets.map { "preventive:\(activity.templateName)|equipment:\($0)" })
    }
}
