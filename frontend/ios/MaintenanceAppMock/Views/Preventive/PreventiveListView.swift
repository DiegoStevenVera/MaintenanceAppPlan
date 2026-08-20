import SwiftUI

struct APIMaintenanceAsset: Identifiable, Codable {
    let id: String
    let name: String
    let role: String
}

struct APIReportVersion: Identifiable, Codable {
    let id: String
    let reportKind: String
    let reportNumber: Int
    let versionNumber: Int
    let documentStatus: String
    let summary: String?
    let createdAt: Date
    let finalizedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, summary
        case reportKind = "report_kind"
        case reportNumber = "report_number"
        case versionNumber = "version_number"
        case documentStatus = "document_status"
        case createdAt = "created_at"
        case finalizedAt = "finalized_at"
    }
}

struct APIPreventiveTest: Identifiable, Codable {
    let id: String
    let name: String
    let selectedResult: String
    let numericValue: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, name, notes
        case selectedResult = "selected_result"
        case numericValue = "numeric_value"
    }
}

struct APIPreventiveStep: Identifiable, Codable {
    let id: String
    let title: String
    let manualPage: Int?
    let isCompleted: Bool
    let comment: String?
    let tests: [APIPreventiveTest]

    enum CodingKeys: String, CodingKey {
        case id, title, comment, tests
        case manualPage = "manual_page"
        case isCompleted = "is_completed"
    }
}

struct APIPreventiveReport: Codable {
    let actualDate: String
    let activityStartedAt: Date
    let activityEndedAt: Date?
    let finalResult: String?
    let additionalComments: String?
    let steps: [APIPreventiveStep]

    enum CodingKeys: String, CodingKey {
        case steps
        case actualDate = "actual_date"
        case activityStartedAt = "activity_started_at"
        case activityEndedAt = "activity_ended_at"
        case finalResult = "final_result"
        case additionalComments = "additional_comments"
    }
}

struct APIComponentReplacement: Codable {
    let parentAssetID: String
    let parentAssetName: String?
    let removedAssetID: String
    let removedAssetName: String?
    let removedAssetPath: String?
    let removedPartNumber: String?
    let removedSerialNumber: String?
    let removedModel: String?
    let removedManufacturer: String?
    let installedAssetID: String
    let installedAssetName: String?
    let installedAssetPath: String?
    let installedPartNumber: String?
    let installedSerialNumber: String?
    let installedModel: String?
    let installedManufacturer: String?
    let sourceDescription: String
    let destinationDescription: String
    let removedCondition: String?
    let installedCondition: String?
    let removedNotes: String?
    let installedNotes: String?
    let reason: String

    enum CodingKeys: String, CodingKey {
        case reason
        case parentAssetID = "parent_asset_id"
        case parentAssetName = "parent_asset_name"
        case removedAssetID = "removed_asset_id"
        case removedAssetName = "removed_asset_name"
        case removedAssetPath = "removed_asset_path"
        case removedPartNumber = "removed_part_number"
        case removedSerialNumber = "removed_serial_number"
        case removedModel = "removed_model"
        case removedManufacturer = "removed_manufacturer"
        case installedAssetID = "installed_asset_id"
        case installedAssetName = "installed_asset_name"
        case installedAssetPath = "installed_asset_path"
        case installedPartNumber = "installed_part_number"
        case installedSerialNumber = "installed_serial_number"
        case installedModel = "installed_model"
        case installedManufacturer = "installed_manufacturer"
        case sourceDescription = "source_description"
        case destinationDescription = "destination_description"
        case removedCondition = "removed_condition"
        case installedCondition = "installed_condition"
        case removedNotes = "removed_notes"
        case installedNotes = "installed_notes"
    }
}

struct APICorrectiveActivity: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let startedAt: Date
    let endedAt: Date?
    let replacement: APIComponentReplacement?

    enum CodingKeys: String, CodingKey {
        case id, name, description, replacement
        case startedAt = "started_at"
        case endedAt = "ended_at"
    }
}

struct APICorrectiveReport: Codable {
    let eventCode: String?
    let sapNotification: String?
    let sapEventName: String?
    let affectedAssetPath: String?
    let noticeCreatedAt: Date?
    let responseAt: Date?
    let correctiveStartedAt: Date?
    let correctiveEndedAt: Date?
    let symptom: String?
    let technicalDescription: String?
    let operationalImpact: String?
    let failureAnalysisType: String?
    let functionalTests: String?
    let validationResult: String?
    let serviceReleased: Bool
    let serviceReleasedAt: Date?
    let validationResponsible: String?
    let technicalStatus: String?
    let conclusion: String?
    let additionalComments: String?
    let activities: [APICorrectiveActivity]

    enum CodingKeys: String, CodingKey {
        case symptom, activities, conclusion
        case eventCode = "event_code"
        case sapNotification = "sap_notification"
        case sapEventName = "sap_event_name"
        case affectedAssetPath = "affected_asset_path"
        case noticeCreatedAt = "notice_created_at"
        case responseAt = "response_at"
        case correctiveStartedAt = "corrective_started_at"
        case correctiveEndedAt = "corrective_ended_at"
        case technicalDescription = "technical_description"
        case operationalImpact = "operational_impact"
        case failureAnalysisType = "failure_analysis_type"
        case functionalTests = "functional_tests"
        case validationResult = "validation_result"
        case serviceReleased = "service_released"
        case serviceReleasedAt = "service_released_at"
        case validationResponsible = "validation_responsible"
        case technicalStatus = "technical_status"
        case additionalComments = "additional_comments"
    }
}

struct APIActivity: Identifiable, Codable {
    let id: String
    let activityType: String
    let status: String
    let title: String
    let internalCode: String
    let sapOrder: String?
    let project: String?
    let stage: String?
    let system: String?
    let subsystem: String
    let site: String?
    let locationPath: String?
    let scheduledAt: Date?
    let plannedYear: Int?
    let plannedMonth: Int?
    let actualStartAt: Date?
    let actualEndAt: Date?
    let assets: [APIMaintenanceAsset]
    let reportVersionCount: Int
    let eventID: String?
    let eventCode: String?
    let severity: String?

    enum CodingKeys: String, CodingKey {
        case id, status, title, project, stage, system, subsystem, site, assets, severity
        case activityType = "activity_type"
        case internalCode = "internal_code"
        case sapOrder = "sap_order"
        case locationPath = "location_path"
        case scheduledAt = "scheduled_at"
        case plannedYear = "planned_year"
        case plannedMonth = "planned_month"
        case actualStartAt = "actual_start_at"
        case actualEndAt = "actual_end_at"
        case reportVersionCount = "report_version_count"
        case eventID = "event_id"
        case eventCode = "event_code"
    }
}

struct APIActivityDetail: Identifiable, Codable {
    let id: String
    let activityType: String
    let status: String
    let title: String
    let internalCode: String
    let sapOrder: String?
    let project: String?
    let stage: String?
    let system: String?
    let subsystem: String
    let site: String?
    let locationPath: String?
    let scheduledAt: Date?
    let plannedYear: Int?
    let plannedMonth: Int?
    let actualStartAt: Date?
    let actualEndAt: Date?
    let assets: [APIMaintenanceAsset]
    let reportVersionCount: Int
    let eventID: String?
    let eventCode: String?
    let severity: String?
    let isCritical: Bool
    let reports: [APIReportVersion]
    let preventiveReport: APIPreventiveReport?
    let correctiveReport: APICorrectiveReport?
    let sapEventName: String?
    let sapNotification: String?
    let noticeCreatedAt: Date?
    let responseAt: Date?
    let affectedAssets: [APICorrectiveAffectedAsset]

    enum CodingKeys: String, CodingKey {
        case id, status, title, project, stage, system, subsystem, site, assets, severity, reports
        case activityType = "activity_type"
        case internalCode = "internal_code"
        case sapOrder = "sap_order"
        case locationPath = "location_path"
        case scheduledAt = "scheduled_at"
        case plannedYear = "planned_year"
        case plannedMonth = "planned_month"
        case actualStartAt = "actual_start_at"
        case actualEndAt = "actual_end_at"
        case reportVersionCount = "report_version_count"
        case eventID = "event_id"
        case eventCode = "event_code"
        case preventiveReport = "preventive_report"
        case correctiveReport = "corrective_report"
        case sapEventName = "sap_event_name"
        case sapNotification = "sap_notification"
        case noticeCreatedAt = "notice_created_at"
        case responseAt = "response_at"
        case affectedAssets = "affected_assets"
        case isCritical = "is_critical"
    }
}

struct APICorrectiveAffectedAsset: Codable, Identifiable {
    let assetID: String
    let isCritical: Bool
    let name: String
    let path: String

    var id: String { assetID }

    enum CodingKeys: String, CodingKey {
        case name, path
        case assetID = "asset_id"
        case isCritical = "is_critical"
    }
}

struct APIActivityPage: Decodable {
    let items: [APIActivity]
    let total: Int
}

struct APIMaintenanceDashboard: Decodable {
    let preventiveTodayCount: Int
    let activeCorrectiveCount: Int
    let pendingClosureCount: Int
    let preventiveToday: [APIActivity]
    let activeCorrectives: [APIActivity]
    let pendingClosure: [APIActivity]

    enum CodingKeys: String, CodingKey {
        case preventiveTodayCount = "preventive_today_count"
        case activeCorrectiveCount = "active_corrective_count"
        case pendingClosureCount = "pending_closure_count"
        case preventiveToday = "preventive_today"
        case activeCorrectives = "active_correctives"
        case pendingClosure = "pending_closure"
    }
}

enum MaintenanceLifecycleCommand: String, Identifiable {
    case start
    case complete
    case close
    case reopen

    var id: String { rawValue }

    var label: String {
        switch self {
        case .start: return "Iniciar Mantenimiento"
        case .complete: return "Finalizar"
        case .close: return "Cerrar"
        case .reopen: return "Reabrir"
        }
    }

    var icon: String {
        switch self {
        case .start: return "play.fill"
        case .complete: return "checkmark.circle.fill"
        case .close: return "lock.fill"
        case .reopen: return "arrow.counterclockwise"
        }
    }
}

private struct ReopenMaintenanceRequest: Encodable {
    let reason: String
}

struct MaintenanceAPIService {
    private let client: APIClient

    init(baseURLString: String) {
        client = APIClient(baseURLString: baseURLString)
    }

    func list(
        type: String,
        query: String,
        status: String? = nil,
        dateFrom: Date? = nil,
        dateTo: Date? = nil,
        plannedYear: Int? = nil,
        plannedMonth: Int? = nil,
        accessToken: String
    ) async throws -> APIActivityPage {
        var allItems: [APIActivity] = []
        var total = 0
        var offset = 0

        repeat {
            var items = [
                URLQueryItem(name: "activity_type", value: type),
                URLQueryItem(name: "limit", value: "200"),
                URLQueryItem(name: "offset", value: String(offset))
            ]
            if !query.isEmpty {
                items.append(URLQueryItem(name: "q", value: query))
            }
            if let status {
                items.append(URLQueryItem(name: "status", value: status))
            }
            if let dateFrom {
                items.append(URLQueryItem(name: "date_from", value: Self.isoFormatter.string(from: dateFrom)))
            }
            if let dateTo {
                items.append(URLQueryItem(name: "date_to", value: Self.isoFormatter.string(from: dateTo)))
            }
            if let plannedYear {
                items.append(URLQueryItem(name: "planned_year", value: String(plannedYear)))
            }
            if let plannedMonth {
                items.append(URLQueryItem(name: "planned_month", value: String(plannedMonth)))
            }

            let page: APIActivityPage = try await client.get(
                "api/v1/maintenance-activities",
                bearerToken: accessToken,
                queryItems: items
            )
            total = page.total
            allItems.append(contentsOf: page.items)
            offset += page.items.count
            if page.items.isEmpty {
                break
            }
        } while offset < total

        return APIActivityPage(items: allItems, total: total)
    }

    func detail(id: String, accessToken: String) async throws -> APIActivityDetail {
        try await client.get("api/v1/maintenance-activities/\(id)", bearerToken: accessToken)
    }

    func dashboard(
        dayFrom: Date,
        dayTo: Date,
        accessToken: String
    ) async throws -> APIMaintenanceDashboard {
        try await client.get(
            "api/v1/maintenance-dashboard",
            bearerToken: accessToken,
            queryItems: [
                URLQueryItem(name: "day_from", value: Self.isoFormatter.string(from: dayFrom)),
                URLQueryItem(name: "day_to", value: Self.isoFormatter.string(from: dayTo))
            ]
        )
    }

    func transition(
        id: String,
        command: MaintenanceLifecycleCommand,
        reason: String?,
        accessToken: String
    ) async throws -> APIActivityDetail {
        let path = "api/v1/maintenance-activities/\(id)/\(command.rawValue)"
        if command == .reopen {
            return try await client.post(
                path,
                body: ReopenMaintenanceRequest(reason: reason ?? ""),
                bearerToken: accessToken
            )
        }
        return try await client.post(path, bearerToken: accessToken)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

@MainActor
final class MaintenanceActivityStore: ObservableObject {
    @Published private(set) var preventiveActivities: [APIActivity] = []
    @Published private(set) var correctiveActivities: [APIActivity] = []
    @Published private(set) var totalPreventives = 0
    @Published private(set) var totalCorrectives = 0
    @Published private(set) var dashboard: APIMaintenanceDashboard?
    @Published private(set) var dashboardError: String?
    @Published private(set) var isLoadingDashboard = false
    @Published private(set) var details: [String: APIActivityDetail] = [:]
    @Published private(set) var isLoadingPreventives = false
    @Published private(set) var isLoadingCorrectives = false
    @Published private(set) var preventiveError: String?
    @Published private(set) var correctiveError: String?
    @Published private(set) var detailErrors: [String: String] = [:]
    @Published private(set) var loadingDetailIDs: Set<String> = []
    @Published private(set) var transitioningIDs: Set<String> = []
    @Published private(set) var transitionErrors: [String: String] = [:]

    func cacheDetail(_ detail: APIActivityDetail) {
        details[detail.id] = detail
    }

    func load(
        type: String,
        query: String,
        dateFrom: Date? = nil,
        dateTo: Date? = nil,
        plannedYear: Int? = nil,
        plannedMonth: Int? = nil,
        session: SessionStore
    ) async {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else {
            setError(type: type, message: "No se encontro la URL de la API.")
            return
        }

        setLoading(type: type, value: true)
        setError(type: type, message: nil)
        do {
            let page = try await session.withValidAccessToken { token in
                try await MaintenanceAPIService(baseURLString: baseURL).list(
                    type: type,
                    query: query,
                    dateFrom: dateFrom,
                    dateTo: dateTo,
                    plannedYear: plannedYear,
                    plannedMonth: plannedMonth,
                    accessToken: token
                )
            }
            guard !Task.isCancelled else { return }
            if type == "PREVENTIVE" {
                preventiveActivities = page.items
                totalPreventives = page.total
            } else {
                correctiveActivities = page.items
                totalCorrectives = page.total
            }
        } catch {
            guard !Task.isCancelled else { return }
            setError(type: type, message: error.localizedDescription)
        }
        setLoading(type: type, value: false)
    }

    func loadDashboard(dayFrom: Date, dayTo: Date, session: SessionStore) async {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else {
            dashboardError = "No se encontro la URL de la API."
            return
        }

        isLoadingDashboard = true
        dashboardError = nil
        do {
            dashboard = try await session.withValidAccessToken { token in
                try await MaintenanceAPIService(baseURLString: baseURL).dashboard(
                    dayFrom: dayFrom,
                    dayTo: dayTo,
                    accessToken: token
                )
            }
        } catch {
            dashboardError = error.localizedDescription
        }
        isLoadingDashboard = false
    }

    func loadDetail(id: String, session: SessionStore, force: Bool = false) async {
        if !force, details[id] != nil {
            return
        }
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else {
            detailErrors[id] = "No se encontro la URL de la API."
            return
        }

        loadingDetailIDs.insert(id)
        detailErrors[id] = nil
        do {
            let detail = try await session.withValidAccessToken { token in
                try await MaintenanceAPIService(baseURLString: baseURL).detail(
                    id: id,
                    accessToken: token
                )
            }
            guard !Task.isCancelled else { return }
            details[id] = detail
        } catch {
            guard !Task.isCancelled else { return }
            detailErrors[id] = error.localizedDescription
        }
        loadingDetailIDs.remove(id)
    }

    func performLifecycle(
        id: String,
        command: MaintenanceLifecycleCommand,
        reason: String? = nil,
        session: SessionStore
    ) async {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else {
            transitionErrors[id] = "No se encontro la URL de la API."
            return
        }

        transitioningIDs.insert(id)
        transitionErrors[id] = nil
        defer { transitioningIDs.remove(id) }

        do {
            let detail = try await session.withValidAccessToken { token in
                try await MaintenanceAPIService(baseURLString: baseURL).transition(
                    id: id,
                    command: command,
                    reason: reason,
                    accessToken: token
                )
            }
            details[id] = detail
            updateCachedActivity(from: detail)

            let calendar = Calendar.current
            let dayFrom = calendar.startOfDay(for: Date())
            if let dayTo = calendar.date(byAdding: .day, value: 1, to: dayFrom) {
                await loadDashboard(dayFrom: dayFrom, dayTo: dayTo, session: session)
            }
        } catch {
            transitionErrors[id] = error.localizedDescription
        }
    }

    func clearTransitionError(id: String) {
        transitionErrors[id] = nil
    }

    private func updateCachedActivity(from detail: APIActivityDetail) {
        let activity = APIActivity(
            id: detail.id,
            activityType: detail.activityType,
            status: detail.status,
            title: detail.title,
            internalCode: detail.internalCode,
            sapOrder: detail.sapOrder,
            project: detail.project,
            stage: detail.stage,
            system: detail.system,
            subsystem: detail.subsystem,
            site: detail.site,
            locationPath: detail.locationPath,
            scheduledAt: detail.scheduledAt,
            plannedYear: detail.plannedYear,
            plannedMonth: detail.plannedMonth,
            actualStartAt: detail.actualStartAt,
            actualEndAt: detail.actualEndAt,
            assets: detail.assets,
            reportVersionCount: detail.reportVersionCount,
            eventID: detail.eventID,
            eventCode: detail.eventCode,
            severity: detail.severity
        )
        if let index = preventiveActivities.firstIndex(where: { $0.id == detail.id }) {
            preventiveActivities[index] = activity
        }
        if let index = correctiveActivities.firstIndex(where: { $0.id == detail.id }) {
            correctiveActivities[index] = activity
        }
    }

    private func setLoading(type: String, value: Bool) {
        if type == "PREVENTIVE" {
            isLoadingPreventives = value
        } else {
            isLoadingCorrectives = value
        }
    }

    private func setError(type: String, message: String?) {
        if type == "PREVENTIVE" {
            preventiveError = message
        } else {
            correctiveError = message
        }
    }
}

struct PreventiveListView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var activityStore: MaintenanceActivityStore
    @State private var selectedFilter: MaintenanceDateFilter = .today
    @State private var searchText = ""
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var selectedYear = Calendar.current.component(.year, from: Date())

    private var visibleActivities: [APIActivity] {
        activityStore.preventiveActivities
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                PreventiveAPISummaryStrip(activities: visibleActivities)
                filterPanel
                activitySection("Preventivos", subtitle: filterSubtitle, activities: visibleActivities)

                if let error = activityStore.preventiveError {
                    ContentUnavailableView {
                        Label("No se pudieron cargar los preventivos", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Reintentar") { Task { await load() } }
                    }
                } else if activityStore.isLoadingPreventives && visibleActivities.isEmpty {
                    ProgressView("Cargando preventivos")
                        .frame(maxWidth: .infinity)
                        .padding(AppSpacing.xl)
                } else if visibleActivities.isEmpty {
                    GlassPanel { Text("No hay preventivos para este filtro.").foregroundStyle(.secondary) }
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Preventivos")
        .refreshable { await load() }
        .task(id: "\(selectedFilter.id)-\(selectedMonth)-\(selectedYear)-\(searchText)") {
            if !searchText.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    private var filterPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Filtros", subtitle: "Segun fecha de programacion en la base de datos")
                ActionButtonGrid {
                    ForEach(MaintenanceDateFilter.allCases) { filter in
                        Button { selectedFilter = filter } label: {
                            Label(filter.label, systemImage: selectedFilter == filter ? "line.3.horizontal.decrease.circle.fill" : filter.icon)
                        }
                        .buttonStyle(ActionTileButtonStyle(prominent: selectedFilter == filter))
                    }
                }
                if selectedFilter == .specificMonth {
                    HStack(spacing: AppSpacing.md) {
                        Picker("Mes", selection: $selectedMonth) {
                            ForEach(1...12, id: \.self) { month in Text(Self.monthName(month)).tag(month) }
                        }
                        .pickerStyle(.menu)
                        Picker("Anio", selection: $selectedYear) {
                            ForEach((selectedYear - 2)...(selectedYear + 1), id: \.self) { year in Text(String(year)).tag(year) }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(AppSpacing.md)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Buscar por nombre de mantenimiento", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(AppSpacing.md)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func activitySection(_ title: String, subtitle: String, activities: [APIActivity]) -> some View {
        if !activities.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: title, subtitle: subtitle)
                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(activities) { activity in
                        NavigationLink { PreventiveDetailView(activityID: activity.id) } label: {
                            APIActivityCard(activity: activity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var filterSubtitle: String {
        selectedFilter == .specificMonth ? "\(Self.monthName(selectedMonth)) \(selectedYear)" : selectedFilter.label
    }

    private func load() async {
        let range = dateRange(for: selectedFilter)
        let plannedPeriod = plannedPeriod(for: selectedFilter)
        await activityStore.load(
            type: "PREVENTIVE",
            query: searchText.trimmingCharacters(in: .whitespacesAndNewlines),
            dateFrom: range?.lowerBound,
            dateTo: range?.upperBound,
            plannedYear: plannedPeriod?.year,
            plannedMonth: plannedPeriod?.month,
            session: session
        )
    }

    private func plannedPeriod(for filter: MaintenanceDateFilter) -> (year: Int, month: Int)? {
        switch filter {
        case .thisMonth:
            let calendar = Calendar.current
            return (
                calendar.component(.year, from: Date()),
                calendar.component(.month, from: Date())
            )
        case .specificMonth:
            return (selectedYear, selectedMonth)
        case .today, .thisWeek:
            return nil
        }
    }

    private func dateRange(for filter: MaintenanceDateFilter) -> Range<Date>? {
        let calendar = Calendar.current
        let now = Date()
        switch filter {
        case .today:
            let start = calendar.startOfDay(for: now)
            return start..<calendar.date(byAdding: .day, value: 1, to: start)!
        case .thisWeek:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return nil }
            return interval.start..<interval.end
        case .thisMonth:
            guard let interval = calendar.dateInterval(of: .month, for: now) else { return nil }
            return interval.start..<interval.end
        case .specificMonth:
            var components = DateComponents()
            components.year = selectedYear
            components.month = selectedMonth
            guard let start = calendar.date(from: components),
                  let end = calendar.date(byAdding: .month, value: 1, to: start) else { return nil }
            return start..<end
        }
    }

    private static func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        return formatter.monthSymbols[max(0, min(month - 1, 11))].capitalized
    }
}

private struct PreventiveAPISummaryStrip: View {
    let activities: [APIActivity]

    var body: some View {
        GlassPanel {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: AppSpacing.md)], spacing: AppSpacing.md) {
                metric("Programados", activities.filter { $0.status == "SCHEDULED" && $0.scheduledAt != nil }.count, "calendar", BrandColor.graphite)
                metric("Sin fecha", activities.filter { $0.status == "SCHEDULED" && $0.scheduledAt == nil }.count, "calendar.badge.exclamationmark", BrandColor.graphite)
                metric("En progreso", activities.filter { $0.status == "IN_PROGRESS" }.count, "arrow.triangle.2.circlepath", BrandColor.amber)
                metric("Completados", activities.filter { $0.status == "COMPLETED" }.count, "checkmark.circle.fill", BrandColor.green)
            }
        }
    }

    private func metric(_ title: String, _ value: Int, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)").font(.title2.weight(.bold)).monospacedDigit()
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

struct APIActivityCard: View {
    let activity: APIActivity

    var body: some View {
        GlassPanel {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Image(systemName: activity.activityType == "CORRECTIVE" ? "wrench.and.screwdriver.fill" : "checklist")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(BrandColor.red)
                    .frame(width: 48, height: 48)
                    .background(BrandColor.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    Text(activity.title).font(.headline).lineLimit(2)
                    Text(activity.assets.map(\.name).joined(separator: ", ")).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    Label(activity.locationPath ?? "Ubicacion no registrada", systemImage: "mappin.and.ellipse")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: AppSpacing.sm)
                VStack(alignment: .trailing, spacing: AppSpacing.sm) {
                    APIStatusBadge(status: activity.status)
                    Text(activity.subsystem).font(.caption.weight(.bold)).foregroundStyle(BrandColor.red)
                    Text(scheduleLabel)
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var scheduleLabel: String {
        if let scheduledAt = activity.scheduledAt {
            return Self.dateFormatter.string(from: scheduledAt)
        }
        if let year = activity.plannedYear, let month = activity.plannedMonth {
            return "Sin fecha · \(Self.monthName(month)) \(year)"
        }
        return "Sin fecha programada"
    }

    private static func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        return formatter.monthSymbols[max(0, min(month - 1, 11))].capitalized
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es_PE")
        return formatter
    }()
}

struct APIStatusBadge: View {
    let status: String

    var body: some View {
        Label(label, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var label: String {
        switch status {
        case "SCHEDULED": return "Programado"
        case "IN_PROGRESS": return "En progreso"
        case "COMPLETED": return "Completado"
        case "CLOSED": return "Cerrado"
        default: return status
        }
    }

    private var icon: String {
        switch status {
        case "SCHEDULED": return "calendar"
        case "IN_PROGRESS": return "arrow.triangle.2.circlepath"
        case "COMPLETED": return "checkmark.circle.fill"
        case "CLOSED": return "lock.circle.fill"
        default: return "questionmark.circle"
        }
    }

    private var color: Color {
        switch status {
        case "SCHEDULED": return BrandColor.graphite
        case "IN_PROGRESS": return BrandColor.amber
        case "COMPLETED": return BrandColor.green
        case "CLOSED": return BrandColor.graphite
        default: return .secondary
        }
    }
}

struct PreventiveListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PreventiveListView()
                .environmentObject(SessionStore())
                .environmentObject(MaintenanceActivityStore())
        }
    }
}
