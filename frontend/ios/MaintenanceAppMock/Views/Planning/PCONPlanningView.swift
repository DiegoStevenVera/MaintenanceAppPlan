import SwiftUI

private enum PCONPlanningError: LocalizedError {
    case proposalNotEditable

    var errorDescription: String? {
        switch self {
        case .proposalNotEditable:
            "La fecha ya pertenece a una semana confirmada. Reprográmala indicando el motivo."
        }
    }
}

private enum PCONSection: String, CaseIterable, Identifiable {
    case annual = "Plan anual"
    case monthly = "Calendario mensual"
    case weekly = "Programación semanal"

    var id: String { rawValue }
}

private enum APIPlanningState: String, Decodable {
    case monthOnly = "MONTH_ONLY"
    case proposed = "PROPOSED"
    case confirmed = "CONFIRMED"
    case reschedulePending = "RESCHEDULE_PENDING"
    case executed = "EXECUTED"

    var label: String {
        switch self {
        case .monthOnly: "Solo mes"
        case .proposed: "Fecha tentativa"
        case .confirmed: "Confirmado"
        case .reschedulePending: "Reprogramación pendiente"
        case .executed: "Ejecutado"
        }
    }

    var color: Color {
        switch self {
        case .monthOnly: BrandColor.amber
        case .proposed: Color.blue
        case .confirmed: BrandColor.green
        case .reschedulePending: BrandColor.red
        case .executed: BrandColor.graphite
        }
    }
}

private struct PCONPlanItem: Decodable, Identifiable {
    let planEntryID: UUID
    let activityID: UUID
    let maintenanceTemplateScopeID: UUID
    let maintenanceTemplateID: UUID
    let title: String
    let templateName: String
    let maintenanceName: String
    let frequency: String?
    let equipmentID: String?
    let equipmentName: String
    let equipmentCategory: String
    let locationName: String
    let subsystemCode: String
    let subsystemName: String
    let year: Int
    let month: Int
    let estimatedMinutes: Int?
    let requiredWorkers: Int?
    let activityStatus: String
    let scheduledStartAt: Date?
    let scheduledEndAt: Date?
    let proposedStartAt: Date?
    let proposedEndAt: Date?
    let planningState: APIPlanningState

    var id: UUID { planEntryID }

    enum CodingKeys: String, CodingKey {
        case planEntryID = "plan_entry_id"
        case activityID = "activity_id"
        case maintenanceTemplateScopeID = "maintenance_template_scope_id"
        case maintenanceTemplateID = "maintenance_template_id"
        case title
        case templateName = "template_name"
        case maintenanceName = "maintenance_name"
        case frequency
        case equipmentID = "equipment_id"
        case equipmentName = "equipment_name"
        case equipmentCategory = "equipment_category"
        case locationName = "location_name"
        case subsystemCode = "subsystem_code"
        case subsystemName = "subsystem_name"
        case year
        case month
        case estimatedMinutes = "estimated_minutes"
        case requiredWorkers = "required_workers"
        case activityStatus = "activity_status"
        case scheduledStartAt = "scheduled_start_at"
        case scheduledEndAt = "scheduled_end_at"
        case proposedStartAt = "proposed_start_at"
        case proposedEndAt = "proposed_end_at"
        case planningState = "planning_state"
    }
}

private struct PCONPlanPage: Decodable {
    let items: [PCONPlanItem]
    let total: Int
}

private struct PCONAnnualMonth: Decodable, Identifiable {
    let month: Int
    let count: Int
    let monthOnlyCount: Int
    let proposedCount: Int
    let confirmedCount: Int
    let executedCount: Int
    let occurrences: [PCONPlanItem]

    var id: Int { month }

    var displayColor: Color {
        if monthOnlyCount > 0 || proposedCount > 0 {
            return monthOnlyCount > 0 ? BrandColor.amber : Color.blue
        }
        if confirmedCount > 0 {
            return BrandColor.green
        }
        if executedCount > 0 {
            return BrandColor.graphite
        }
        return .secondary
    }

    enum CodingKeys: String, CodingKey {
        case month
        case count
        case monthOnlyCount = "month_only_count"
        case proposedCount = "proposed_count"
        case confirmedCount = "confirmed_count"
        case executedCount = "executed_count"
        case occurrences
    }
}

private struct PCONAnnualRow: Decodable, Identifiable {
    let id: UUID
    let maintenanceTemplateScopeID: UUID
    let maintenanceTemplateID: UUID
    let subsystemCode: String
    let subsystemName: String
    let equipmentCategory: String
    let locationName: String
    let equipmentID: String?
    let equipmentName: String
    let maintenanceName: String
    let frequency: String?
    let annualCount: Int
    let months: [PCONAnnualMonth]

    enum CodingKeys: String, CodingKey {
        case id
        case maintenanceTemplateScopeID = "maintenance_template_scope_id"
        case maintenanceTemplateID = "maintenance_template_id"
        case subsystemCode = "subsystem_code"
        case subsystemName = "subsystem_name"
        case equipmentCategory = "equipment_category"
        case locationName = "location_name"
        case equipmentID = "equipment_id"
        case equipmentName = "equipment_name"
        case maintenanceName = "maintenance_name"
        case frequency
        case annualCount = "annual_count"
        case months
    }
}

private struct PCONAnnualPlan: Decodable {
    let year: Int
    let status: String
    let copiedFromYear: Int?
    let isVirtual: Bool
    let rows: [PCONAnnualRow]
    let totalRows: Int
    let totalExecutions: Int

    enum CodingKeys: String, CodingKey {
        case year
        case status
        case copiedFromYear = "copied_from_year"
        case isVirtual = "is_virtual"
        case rows
        case totalRows = "total_rows"
        case totalExecutions = "total_executions"
    }
}

private struct PCONCatalogAsset: Decodable, Identifiable {
    let id: String
    let name: String
    let subsystem: String
    let category: String
    let locationName: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case subsystem
        case category
        case locationName = "location_name"
    }
}

private struct PCONCatalogTemplate: Decodable, Identifiable {
    let id: UUID
    let name: String
    let subsystemCode: String
    let frequency: String?
    let estimatedMinutes: Int?
    let requiredWorkers: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case subsystemCode = "subsystem_code"
        case frequency
        case estimatedMinutes = "estimated_minutes"
        case requiredWorkers = "required_workers"
    }
}

private struct PCONCatalog: Decodable {
    let assets: [PCONCatalogAsset]
    let templates: [PCONCatalogTemplate]
}

private struct PCONWeekSession: Decodable, Identifiable {
    let id: UUID
    let weekStart: String
    let version: Int
    let status: String
    let proposalCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case weekStart = "week_start"
        case version
        case status
        case proposalCount = "proposal_count"
    }
}

private struct PCONProposal: Decodable, Identifiable {
    let id: UUID
    let sessionID: UUID
    let activityID: UUID
    let activityTitle: String
    let equipmentName: String
    let proposedStartAt: Date
    let proposedEndAt: Date
    let previousStartAt: Date?
    let previousEndAt: Date?
    let reason: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case sessionID = "session_id"
        case activityID = "activity_id"
        case activityTitle = "activity_title"
        case equipmentName = "equipment_name"
        case proposedStartAt = "proposed_start_at"
        case proposedEndAt = "proposed_end_at"
        case previousStartAt = "previous_start_at"
        case previousEndAt = "previous_end_at"
        case reason
        case status
    }
}

private struct PCONWeekDetail: Decodable {
    let session: PCONWeekSession
    let proposals: [PCONProposal]
}

private struct PCONHistoryItem: Decodable, Identifiable {
    let revisionID: UUID
    let weekStart: String
    let sessionVersion: Int
    let activityTitle: String
    let equipmentName: String
    let proposedStartAt: Date
    let previousStartAt: Date?
    let reason: String?
    let status: String
    let confirmedByName: String?

    var id: UUID { revisionID }

    enum CodingKeys: String, CodingKey {
        case revisionID = "revision_id"
        case weekStart = "week_start"
        case sessionVersion = "session_version"
        case activityTitle = "activity_title"
        case equipmentName = "equipment_name"
        case proposedStartAt = "proposed_start_at"
        case previousStartAt = "previous_start_at"
        case reason
        case status
        case confirmedByName = "confirmed_by_name"
    }
}

private struct EmptyRequest: Encodable {
    let notes: String? = nil
}

private struct ProposalRequest: Encodable {
    let proposedStartAt: Date
    let proposedEndAt: Date
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case proposedStartAt = "proposed_start_at"
        case proposedEndAt = "proposed_end_at"
        case reason
    }
}

private struct SetAnnualCountRequest: Encodable {
    let maintenanceTemplateScopeID: UUID
    let year: Int
    let month: Int
    let count: Int

    enum CodingKeys: String, CodingKey {
        case maintenanceTemplateScopeID = "maintenance_template_scope_id"
        case year
        case month
        case count
    }
}

private struct SetAnnualCountResponse: Decodable {
    let previousCount: Int
    let count: Int
    let created: Int
    let removed: Int

    enum CodingKeys: String, CodingKey {
        case previousCount = "previous_count"
        case count
        case created
        case removed
    }
}

private struct CopyAnnualPlanRequest: Encodable {
    let sourceYear: Int
    let targetYear: Int
    let mode = "FILL_EMPTY"

    enum CodingKeys: String, CodingKey {
        case sourceYear = "source_year"
        case targetYear = "target_year"
        case mode
    }
}

private struct CopyAnnualPlanResponse: Decodable {
    let sourceYear: Int
    let targetYear: Int
    let scopesAdded: Int
    let occurrencesCreated: Int
    let preservedCells: Int

    enum CodingKeys: String, CodingKey {
        case sourceYear = "source_year"
        case targetYear = "target_year"
        case scopesAdded = "scopes_added"
        case occurrencesCreated = "occurrences_created"
        case preservedCells = "preserved_cells"
    }
}

private struct AddPlanScopeRequest: Encodable {
    let year: Int
    let assetID: String
    let maintenanceTemplateID: UUID
    let month: Int
    let quantity: Int
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case year
        case assetID = "asset_id"
        case maintenanceTemplateID = "maintenance_template_id"
        case month
        case quantity
        case reason
    }
}

private struct AddPlanScopeResponse: Decodable {
    let maintenanceTemplateScopeID: UUID
    let createdScope: Bool
    let createdMembership: Bool
    let occurrencesCreated: Int

    enum CodingKeys: String, CodingKey {
        case maintenanceTemplateScopeID = "maintenance_template_scope_id"
        case createdScope = "created_scope"
        case createdMembership = "created_membership"
        case occurrencesCreated = "occurrences_created"
    }
}

private struct MoveOccurrenceRequest: Encodable {
    let year: Int
    let month: Int
    let reason: String?
}

private struct CancelOccurrenceRequest: Encodable {
    let reason: String
}

private struct MutationResponse: Decodable {
    let updated: Bool?
    let cancelled: Bool?
}

private struct PCONPlanChange: Decodable, Identifiable {
    let id: UUID
    let action: String
    let year: Int
    let month: Int?
    let equipmentName: String?
    let maintenanceName: String?
    let quantityDelta: Int?
    let reason: String?
    let changedByName: String
    let changedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case action
        case year
        case month
        case equipmentName = "equipment_name"
        case maintenanceName = "maintenance_name"
        case quantityDelta = "quantity_delta"
        case reason
        case changedByName = "changed_by_name"
        case changedAt = "changed_at"
    }
}

private struct PCONService {
    let client: APIClient

    init(baseURL: String) {
        client = APIClient(baseURLString: baseURL)
    }

    func annualPlan(year: Int, query: String, token: String) async throws -> PCONAnnualPlan {
        var items = [URLQueryItem(name: "year", value: String(year))]
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(URLQueryItem(name: "q", value: query))
        }
        return try await client.get(
            "api/v1/pcon/annual-plan",
            bearerToken: token,
            queryItems: items
        )
    }

    func plan(year: Int, month: Int, query: String, token: String) async throws -> PCONPlanPage {
        var items = [
            URLQueryItem(name: "year", value: String(year)),
            URLQueryItem(name: "month", value: String(month))
        ]
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(URLQueryItem(name: "q", value: query))
        }
        return try await client.get(
            "api/v1/pcon/plan",
            bearerToken: token,
            queryItems: items
        )
    }

    func setCount(
        scopeID: UUID,
        year: Int,
        month: Int,
        count: Int,
        token: String
    ) async throws -> SetAnnualCountResponse {
        try await client.put(
            "api/v1/pcon/annual-plan/count",
            body: SetAnnualCountRequest(
                maintenanceTemplateScopeID: scopeID,
                year: year,
                month: month,
                count: count
            ),
            bearerToken: token
        )
    }

    func catalog(token: String) async throws -> PCONCatalog {
        try await client.get("api/v1/pcon/catalog", bearerToken: token)
    }

    func copyPlan(sourceYear: Int, targetYear: Int, token: String) async throws
        -> CopyAnnualPlanResponse {
        try await client.post(
            "api/v1/pcon/annual-plan/copy",
            body: CopyAnnualPlanRequest(sourceYear: sourceYear, targetYear: targetYear),
            bearerToken: token
        )
    }

    func addPlanScope(
        year: Int,
        assetID: String,
        templateID: UUID,
        month: Int,
        quantity: Int,
        reason: String,
        token: String
    ) async throws -> AddPlanScopeResponse {
        try await client.post(
            "api/v1/pcon/plan-scopes",
            body: AddPlanScopeRequest(
                year: year,
                assetID: assetID,
                maintenanceTemplateID: templateID,
                month: month,
                quantity: quantity,
                reason: reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : reason
            ),
            bearerToken: token
        )
    }

    func moveOccurrence(
        _ item: PCONPlanItem,
        year: Int,
        month: Int,
        reason: String,
        token: String
    ) async throws {
        let _: MutationResponse = try await client.patch(
            "api/v1/pcon/occurrences/\(item.planEntryID)",
            body: MoveOccurrenceRequest(
                year: year,
                month: month,
                reason: reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : reason
            ),
            bearerToken: token
        )
    }

    func removeOccurrence(_ item: PCONPlanItem, token: String) async throws {
        try await client.delete(
            "api/v1/pcon/occurrences/\(item.planEntryID)",
            bearerToken: token
        )
    }

    func cancelOccurrence(
        _ item: PCONPlanItem,
        reason: String,
        token: String
    ) async throws {
        let _: MutationResponse = try await client.post(
            "api/v1/pcon/occurrences/\(item.planEntryID)/cancel",
            body: CancelOccurrenceRequest(reason: reason),
            bearerToken: token
        )
    }

    func planChanges(year: Int, token: String) async throws -> [PCONPlanChange] {
        try await client.get(
            "api/v1/pcon/change-history",
            bearerToken: token,
            queryItems: [
                URLQueryItem(name: "year", value: String(year)),
                URLQueryItem(name: "limit", value: "200")
            ]
        )
    }

    func currentWeek(_ weekStart: String, token: String) async throws -> PCONWeekDetail {
        try await client.get(
            "api/v1/pcon/weeks/\(weekStart)/current",
            bearerToken: token
        )
    }

    func createWeek(_ weekStart: String, token: String) async throws -> PCONWeekDetail {
        try await client.post(
            "api/v1/pcon/weeks/\(weekStart)/sessions",
            body: EmptyRequest(),
            bearerToken: token
        )
    }

    func saveProposal(
        sessionID: UUID,
        item: PCONPlanItem,
        start: Date,
        end: Date,
        reason: String,
        token: String
    ) async throws -> PCONWeekDetail {
        try await client.put(
            "api/v1/pcon/sessions/\(sessionID)/proposals/\(item.activityID)",
            body: ProposalRequest(
                proposedStartAt: start,
                proposedEndAt: end,
                reason: reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : reason
            ),
            bearerToken: token
        )
    }

    func deleteProposal(sessionID: UUID, activityID: UUID, token: String) async throws {
        try await client.delete(
            "api/v1/pcon/sessions/\(sessionID)/proposals/\(activityID)",
            bearerToken: token
        )
    }

    func confirm(sessionID: UUID, token: String) async throws -> PCONWeekDetail {
        try await client.post(
            "api/v1/pcon/sessions/\(sessionID)/confirm",
            bearerToken: token
        )
    }

    func history(token: String) async throws -> [PCONHistoryItem] {
        try await client.get(
            "api/v1/pcon/history",
            bearerToken: token,
            queryItems: [URLQueryItem(name: "limit", value: "200")]
        )
    }
}

private struct AnnualCellSelection: Identifiable {
    let row: PCONAnnualRow
    let month: PCONAnnualMonth

    var id: String { "\(row.id)-\(month.month)" }
}

private struct TentativeScheduleRequest: Identifiable {
    let item: PCONPlanItem
    let start: Date
    let end: Date

    var id: UUID { item.planEntryID }
}

private struct AnnualTentativeBatch: Identifiable {
    let items: [PCONPlanItem]
    let year: Int
    let month: Int

    var id: String { "\(year)-\(month)-\(items.map(\.id.uuidString).joined(separator: ","))" }
}

private struct HierarchyGroup: Identifiable {
    let key: String
    let label: String
    let level: Int
    let rows: [PCONAnnualRow]

    var id: String { key }
}

private struct PCONCalendarSlot: Identifiable {
    let id: Int
    let date: Date?
    let day: Int?
}

private struct PlanningStateBadge: View {
    let state: APIPlanningState

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(state.color).frame(width: 6, height: 6)
            Text(state.label)
                .font(.caption2.bold())
                .lineLimit(1)
        }
        .foregroundStyle(state.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(state.color.opacity(0.11), in: Capsule())
    }
}

struct PCONPlanningView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var section = PCONSection.annual
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    @State private var selectedCalendarDay: Date
    @State private var weekStart: Date
    @State private var query = ""
    @State private var selectedSubsystem = "Todos"
    @State private var selectedCategory = "Todas"
    @State private var selectedLocation = "Todas"
    @State private var selectedEquipment = "Todos"
    @State private var weeklyQuery = ""
    @State private var weeklySelectedSubsystem = "Todos"
    @State private var weeklySelectedCategory = "Todas"
    @State private var weeklySelectedLocation = "Todas"
    @State private var annualPlan: PCONAnnualPlan?
    @State private var monthlyItems: [PCONPlanItem] = []
    @State private var weeklyItems: [PCONPlanItem] = []
    @State private var weekDetail: PCONWeekDetail?
    @State private var history: [PCONHistoryItem] = []
    @State private var planChanges: [PCONPlanChange] = []
    @State private var catalog: PCONCatalog?
    @State private var expandedGroups: Set<String> = []
    @State private var selectedCell: AnnualCellSelection?
    @State private var schedulingItem: PCONPlanItem?
    @State private var showsHistory = false
    @State private var showsAddMaintenance = false
    @State private var isConfirmingCopy = false
    @State private var isConfirmingWeek = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var weeklyPendingPage = 0

    private let calendar = Calendar(identifier: .iso8601)
    private let descriptorWidth: CGFloat = 390
    private let monthWidth: CGFloat = 62
    private let totalWidth: CGFloat = 76

    init() {
        let now = Date()
        let calendar = Calendar(identifier: .iso8601)
        _selectedYear = State(initialValue: calendar.component(.year, from: now))
        _selectedMonth = State(initialValue: calendar.component(.month, from: now))
        _selectedCalendarDay = State(initialValue: now)
        _weekStart = State(initialValue: Self.startOfWeek(now))
    }

    private var canEdit: Bool {
        session.currentUser?.role.canEditPlanning == true
    }

    var body: some View {
        ZStack {
            MaintenanceScreenBackground()
            VStack(spacing: 0) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PCON")
                            .font(.largeTitle.bold())
                        Text("Planifica, programa y gestiona los mantenimientos preventivos")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)

                Picker("Vista PCON", selection: $section) {
                    ForEach(PCONSection.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)

                switch section {
                case .annual:
                    annualContent
                case .monthly:
                    monthlyContent
                case .weekly:
                    weeklyContent
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !canEdit {
                    Label("Solo lectura", systemImage: "eye")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Button {
                    showsHistory = true
                    Task { await loadHistory() }
                } label: {
                    Label("Historial de programación", systemImage: "clock.arrow.circlepath")
                }
            }
        }
        .onChange(of: section) {
            query = ""
            Task { await loadCurrentSection() }
        }
        .task {
            await loadCurrentSection()
        }
        .sheet(item: $selectedCell) { selection in
            AnnualCountSheet(
                selection: selection,
                year: selectedYear,
                canEdit: canEdit,
                onSave: { count in
                    await setAnnualCount(selection: selection, count: count)
                },
                onSchedule: { requests in
                    await saveAnnualTentativeProposals(requests)
                },
                onMove: { item, month, reason in
                    await moveOccurrence(item, month: month, reason: reason)
                },
                onRemove: { item, reason in
                    await removeOccurrence(item, reason: reason)
                }
            )
        }
        .sheet(isPresented: $showsAddMaintenance) {
            if let catalog {
                AddPlanScopeSheet(
                    year: selectedYear,
                    catalog: catalog,
                    onSave: { assetID, templateID, month, quantity, reason in
                        await addPlanScope(
                            assetID: assetID,
                            templateID: templateID,
                            month: month,
                            quantity: quantity,
                            reason: reason
                        )
                    }
                )
            } else {
                ProgressView("Cargando catálogo...")
                    .presentationDetents([.medium])
            }
        }
        .sheet(item: $schedulingItem) { item in
            ScheduleProposalSheet(
                item: item,
                weekStart: weekStart,
                onSave: { start, end, reason in
                    await saveProposal(item: item, start: start, end: end, reason: reason)
                }
            )
        }
        .sheet(isPresented: $showsHistory) {
            PlanningHistorySheet(
                weeklyHistory: history,
                annualChanges: planChanges,
                year: selectedYear,
                isLoading: isLoading
            )
        }
        .alert("Copiar plan anual", isPresented: $isConfirmingCopy) {
            Button("Copiar \(selectedYear - 1)") {
                Task { await copyPreviousYear() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(
                "Se copiarán las cantidades de \(selectedYear - 1) a \(selectedYear), "
                    + "sin fechas semanales. Las celdas que ya tengan datos se conservarán."
            )
        }
        .alert("Confirmar toda la semana", isPresented: $isConfirmingWeek) {
            Button("Confirmar \(weekDetail?.proposals.count ?? 0) propuestas") {
                Task { await confirmWeek() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Las fechas se publicarán juntas. Si una no es válida, no se aplicará ninguna.")
        }
        .alert(
            "No se pudo completar la operación",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("Aceptar") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var annualContent: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: AppSpacing.md) {
                annualFilterBar
                annualSummary
                if isLoading && annualPlan == nil {
                    ProgressView("Cargando planificación anual...")
                        .padding(.vertical, 80)
                } else if let plan = annualPlan, !filteredAnnualRows.isEmpty {
                    annualMatrix(plan)
                } else {
                    ContentUnavailableView(
                        "Sin planificación",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("No hay mantenimientos para el año y filtros elegidos.")
                    )
                    .padding(.vertical, 80)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .refreshable { await loadAnnual() }
    }

    private var annualToolbar: some View {
        GlassPanel {
            HStack(spacing: AppSpacing.md) {
                Button {
                    selectedYear -= 1
                    Task { await loadAnnual() }
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glass)

                Text(String(selectedYear))
                    .font(.title2.bold())
                    .monospacedDigit()

                Button {
                    selectedYear += 1
                    Task { await loadAnnual() }
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glass)

                Divider().frame(height: 32)

                if let plan = annualPlan {
                    Label("\(plan.totalRows) mantenimientos", systemImage: "list.bullet.rectangle")
                    Label("\(plan.totalExecutions) ejecuciones", systemImage: "calendar")
                    if plan.isVirtual {
                        Label("Base \(plan.copiedFromYear ?? selectedYear - 1)", systemImage: "doc.on.doc")
                            .foregroundStyle(BrandColor.amber)
                    }
                }

                Spacer()

                Button {
                    if expandedGroups.isEmpty {
                        expandedGroups = Set(allGroupKeys)
                    } else {
                        expandedGroups.removeAll()
                    }
                } label: {
                    Label(
                        expandedGroups.isEmpty ? "Expandir" : "Contraer",
                        systemImage: expandedGroups.isEmpty
                            ? "arrow.down.right.and.arrow.up.left"
                            : "arrow.up.left.and.arrow.down.right"
                    )
                }
                .buttonStyle(.glass)

                if canEdit {
                    Menu {
                        Button {
                            Task { await prepareAddMaintenance() }
                        } label: {
                            Label("Agregar mantenimiento", systemImage: "plus")
                        }
                        Button {
                            isConfirmingCopy = true
                        } label: {
                            Label(
                                "Copiar plan de \(selectedYear - 1)",
                                systemImage: "doc.on.doc"
                            )
                        }
                    } label: {
                        Label("Administrar", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .font(.subheadline.weight(.semibold))
        }
    }

    private var annualFilterBar: some View {
        GlassPanel {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 155), spacing: AppSpacing.sm)],
                alignment: .leading,
                spacing: AppSpacing.sm
            ) {
                annualFilterControls
            }
        }
    }

    @ViewBuilder
    private var annualFilterControls: some View {
        yearFilter
        planningFilter("Subsistema", selection: $selectedSubsystem, values: annualSubsystems)
        planningFilter("Categoría", selection: $selectedCategory, values: annualCategories)
        planningFilter("Ubicación", selection: $selectedLocation, values: annualLocations)
        planningFilter("Equipo", selection: $selectedEquipment, values: annualEquipment)
        Button {
            selectedSubsystem = "Todos"
            selectedCategory = "Todas"
            selectedLocation = "Todas"
            selectedEquipment = "Todos"
            query = ""
            Task { await loadAnnual() }
        } label: {
            Label("Limpiar filtros", systemImage: "arrow.counterclockwise")
                .frame(minHeight: 42)
        }
        .buttonStyle(.glass)
        Button {
            if expandedGroups.isEmpty {
                expandedGroups = Set(allGroupKeys)
            } else {
                expandedGroups.removeAll()
            }
        } label: {
            Label(
                expandedGroups.isEmpty ? "Expandir" : "Contraer",
                systemImage: expandedGroups.isEmpty
                    ? "arrow.down.right.and.arrow.up.left"
                    : "arrow.up.left.and.arrow.down.right"
            )
            .frame(maxWidth: .infinity, minHeight: 42)
        }
        .buttonStyle(.glass)
        if canEdit {
            Menu {
                Button {
                    Task { await prepareAddMaintenance() }
                } label: {
                    Label("Agregar mantenimiento", systemImage: "plus")
                }
                Button {
                    isConfirmingCopy = true
                } label: {
                    Label("Copiar plan de \(selectedYear - 1)", systemImage: "doc.on.doc")
                }
            } label: {
                Label("Administrar", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(.glassProminent)
        }
    }

    private var yearFilter: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("AÑO")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Picker("Año", selection: $selectedYear) {
                ForEach((selectedYear - 3)...(selectedYear + 3), id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .labelsHidden()
            .onChange(of: selectedYear) {
                Task { await loadAnnual() }
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
    }

    private func planningFilter(
        _ title: String,
        selection: Binding<String>,
        values: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach(values, id: \.self) { value in Text(value).tag(value) }
            }
            .labelsHidden()
        }
        .padding(.horizontal, AppSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
    }

    private var annualSummary: some View {
        let items = filteredAnnualRows.flatMap { $0.months.flatMap(\.occurrences) }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                summaryCard("Planificados", value: items.count, color: BrandColor.graphite, icon: "calendar")
                summaryCard("Con fecha asignada", value: items.filter { ($0.proposedStartAt ?? $0.scheduledStartAt) != nil }.count, color: BrandColor.green, icon: "calendar.badge.checkmark")
                summaryCard("Pendientes de fecha", value: items.filter { $0.planningState == .monthOnly }.count, color: BrandColor.amber, icon: "calendar.badge.exclamationmark")
                summaryCard("Reprogramación pendiente", value: items.filter { $0.planningState == .reschedulePending }.count, color: BrandColor.red, icon: "arrow.triangle.2.circlepath")
                summaryCard("Ejecutados", value: items.filter { $0.planningState == .executed }.count, color: .blue, icon: "checkmark.circle.fill")
            }
        }
    }

    private func summaryCard(_ title: String, value: Int, color: Color, icon: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(String(value)).font(.title3.bold()).monospacedDigit()
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(AppSpacing.md)
        .frame(minWidth: 190, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.06)) }
    }

    private var annualLegend: some View {
        GlassPanel {
            HStack(spacing: AppSpacing.lg) {
                Text("Estado de la cantidad")
                    .font(.subheadline.bold())
                legendNumber("1", label: "Solo mes", color: BrandColor.amber)
                legendNumber("1", label: "Fecha tentativa", color: Color.blue)
                legendNumber("1", label: "Confirmado", color: BrandColor.green)
                legendNumber("1", label: "Ejecutado", color: BrandColor.graphite)
                Spacer()
                Text("Si hay estados mixtos, prevalece el más pendiente.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func legendNumber(_ number: String, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Text(number)
                .font(.subheadline.bold())
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func annualMatrix(_ plan: PCONAnnualPlan) -> some View {
        ScrollView(.horizontal) {
            LazyVStack(spacing: 1, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(visibleHierarchyRows(filteredAnnualRows)) { hierarchy in
                        annualHierarchyRow(hierarchy)
                    }
                } header: {
                    annualHeader
                }
            }
            .frame(
                minWidth: descriptorWidth + monthWidth * 12 + totalWidth,
                alignment: .topLeading
            )
        }
        .scrollIndicators(.visible)
        .background(.regularMaterial.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var annualHeader: some View {
        HStack(spacing: 1) {
            Text("SUBSISTEMA / CATEGORÍA / UBICACIÓN / EQUIPO / MANTENIMIENTO")
                .frame(width: descriptorWidth, alignment: .leading)
                .padding(.horizontal, AppSpacing.md)
            ForEach(1...12, id: \.self) { month in
                Text(Self.shortMonthName(month))
                    .frame(width: monthWidth)
            }
            Text("AÑO")
                .frame(width: totalWidth)
        }
        .frame(height: 46)
        .font(.caption.bold())
        .foregroundStyle(.white)
        .background(BrandColor.graphite)
    }

    private func annualHierarchyRow(_ group: HierarchyGroup) -> some View {
        let isLeaf = group.level == 4 && group.rows.count == 1
        let monthTotals = (1...12).map { month in
            group.rows.reduce(0) { result, row in
                result + (row.months.first { $0.month == month }?.count ?? 0)
            }
        }
        let annualTotal = group.rows.reduce(0) { $0 + $1.annualCount }

        return HStack(spacing: 1) {
            Button {
                if isLeaf {
                    return
                }
                toggle(group.key)
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    if !isLeaf {
                        Image(
                            systemName: expandedGroups.contains(group.key)
                                ? "chevron.down"
                                : "chevron.right"
                        )
                        .font(.caption.bold())
                    } else {
                        Image(systemName: "wrench.and.screwdriver")
                            .foregroundStyle(BrandColor.red)
                    }
                    Image(systemName: hierarchyIcon(level: group.level))
                        .foregroundStyle(group.level == 0 ? BrandColor.red : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.label)
                            .font(group.level == 0 ? .headline : .subheadline.weight(.semibold))
                            .lineLimit(2)
                        if isLeaf, let frequency = group.rows.first?.frequency, !frequency.isEmpty {
                            Text(frequency)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, CGFloat(group.level) * 18 + AppSpacing.sm)
                .padding(.trailing, AppSpacing.sm)
                .frame(width: descriptorWidth, alignment: .leading)
                .frame(minHeight: isLeaf ? 58 : 46)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ForEach(Array(monthTotals.enumerated()), id: \.offset) { index, count in
                if isLeaf, let row = group.rows.first,
                   let month = row.months.first(where: { $0.month == index + 1 }) {
                    Button {
                        selectedCell = AnnualCellSelection(row: row, month: month)
                    } label: {
                        annualCell(month)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        "\(Self.monthName(index + 1)): \(count) ejecuciones"
                    )
                } else {
                    Text(count == 0 ? "–" : String(count))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(count == 0 ? .tertiary : .primary)
                        .frame(width: monthWidth)
                        .frame(minHeight: 46)
                }
            }

            Text(String(annualTotal))
                .font(.subheadline.bold())
                .monospacedDigit()
                .frame(width: totalWidth)
                .frame(minHeight: isLeaf ? 58 : 46)
        }
        .background(rowBackground(level: group.level))
    }

    private func annualCell(_ month: PCONAnnualMonth) -> some View {
        Text(month.count == 0 ? "–" : String(month.count))
            .font(.headline)
            .monospacedDigit()
            .foregroundStyle(month.count == 0 ? Color.secondary.opacity(0.45) : month.displayColor)
        .frame(width: monthWidth)
        .frame(minHeight: 58)
        .background(month.count > 0 ? BrandColor.red.opacity(0.055) : .clear)
        .contentShape(Rectangle())
    }

    private var monthlyContent: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 920
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    monthlyToolbar
                    if isLoading && monthlyItems.isEmpty {
                        ProgressView("Cargando calendario mensual...")
                            .padding(.top, 80)
                    } else {
                        if isWide {
                            HStack(alignment: .top, spacing: AppSpacing.md) {
                                monthlyCalendar
                                    .frame(maxWidth: .infinity)
                                monthlyDayPanel
                                    .frame(width: 390)
                            }
                        } else {
                            VStack(spacing: AppSpacing.md) {
                                monthlyCalendar
                                monthlyDayPanel
                            }
                        }
                    }
                    planningLegend
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
            }
            .refreshable { await loadMonthly() }
        }
    }

    private var monthlyToolbar: some View {
        GlassPanel {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppSpacing.md) {
                    monthNavigation
                    Spacer()
                    monthlyMetric("Planificados", value: monthlyItems.count, color: Color.blue)
                    monthlyMetric("Con fecha", value: monthlyDatedItems.count, color: BrandColor.green)
                    monthlyMetric("Pendientes", value: monthlyPendingItems.count, color: BrandColor.amber)
                    todayButton
                }
                VStack(spacing: AppSpacing.md) {
                    HStack { monthNavigation; Spacer(); todayButton }
                    HStack(spacing: AppSpacing.md) {
                        monthlyMetric("Planificados", value: monthlyItems.count, color: Color.blue)
                        monthlyMetric("Con fecha", value: monthlyDatedItems.count, color: BrandColor.green)
                        monthlyMetric("Pendientes", value: monthlyPendingItems.count, color: BrandColor.amber)
                    }
                }
            }
        }
    }

    private var monthNavigation: some View {
        HStack(spacing: AppSpacing.sm) {
            Button {
                moveSelectedMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            Text("\(Self.monthName(selectedMonth)) \(selectedYear)")
                .font(.headline)
                .frame(minWidth: 170)
            Button {
                moveSelectedMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
        }
    }

    private var todayButton: some View {
        Button("Hoy") {
            let now = Date()
            selectedYear = calendar.component(.year, from: now)
            selectedMonth = calendar.component(.month, from: now)
            selectedCalendarDay = now
            Task { await loadMonthly() }
        }
        .buttonStyle(.glass)
    }

    private func monthlyMetric(_ label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(String(value)).font(.headline).monospacedDigit()
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var monthlyCalendar: some View {
        GlassPanel {
            VStack(spacing: 0) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7),
                    spacing: 1
                ) {
                    ForEach(["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"], id: \.self) {
                        Text($0)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.sm)
                    }
                    ForEach(monthCalendarSlots) { slot in
                        calendarDayCell(slot)
                    }
                }
            }
        }
    }

    private func calendarDayCell(_ slot: PCONCalendarSlot) -> some View {
        let items = slot.date.map(items(on:)) ?? []
        let isSelected = slot.date.map { calendar.isDate($0, inSameDayAs: selectedCalendarDay) } ?? false
        let isToday = slot.date.map(calendar.isDateInToday) ?? false
        return Button {
            if let date = slot.date { selectedCalendarDay = date }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(slot.day.map(String.init) ?? "")
                        .font(.subheadline.weight(isToday ? .bold : .medium))
                        .foregroundStyle(isToday ? BrandColor.red : .primary)
                    Spacer()
                    if !items.isEmpty {
                        Text("\(items.count) mant.")
                            .font(.caption2.bold())
                            .foregroundStyle(dominantStateColor(items))
                    }
                }
                HStack(spacing: 3) {
                    ForEach(Array(items.prefix(4))) { item in
                        Capsule()
                            .fill(item.planningState.color)
                            .frame(height: 5)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(AppSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
            .background(
                isSelected ? BrandColor.red.opacity(0.09) : Color.primary.opacity(0.025),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(BrandColor.red.opacity(0.55), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(slot.date == nil)
    }

    private var monthlyDayPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: Self.fullDateFormatter.string(from: selectedCalendarDay),
                    subtitle: "\(selectedDayItems.count) mantenimiento(s)"
                )
                if selectedDayItems.isEmpty {
                    ContentUnavailableView(
                        "Sin mantenimientos con fecha",
                        systemImage: "calendar",
                        description: Text("Asigna una fecha desde las ocurrencias pendientes del mes.")
                    )
                    .frame(minHeight: 220)
                } else {
                    ForEach(selectedDayItems) { item in
                        monthlyItemRow(item)
                    }
                }
                if canEdit, !monthlyPendingItems.isEmpty {
                    Menu {
                        ForEach(monthlyPendingItems) { pending in
                            Button {
                                weekStart = Self.startOfWeek(selectedCalendarDay)
                                schedulingItem = pending
                            } label: {
                                Label(
                                    "\(pending.maintenanceName) · \(pending.equipmentName)",
                                    systemImage: "calendar.badge.plus"
                                )
                            }
                        }
                    } label: {
                        Label("Agregar mantenimiento al día", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
    }

    private func monthlyItemRow(_ item: PCONPlanItem) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "doc.text")
                .foregroundStyle(BrandColor.red)
                .frame(width: 34, height: 34)
                .background(BrandColor.red.opacity(0.09), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.maintenanceName).font(.subheadline.bold()).lineLimit(2)
                Text("\(item.equipmentName) · \(item.locationName.activityLocationSummary)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                PlanningStateBadge(state: item.planningState)
                if let date = item.proposedStartAt ?? item.scheduledStartAt {
                    Text(Self.timeRange(item, start: date))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if canEdit, item.planningState != .executed {
                Menu {
                    Button {
                        weekStart = Self.startOfWeek(
                            item.proposedStartAt ?? item.scheduledStartAt ?? selectedCalendarDay
                        )
                        schedulingItem = item
                    } label: {
                        Label("Editar fecha", systemImage: "calendar.badge.clock")
                    }
                    if item.planningState == .proposed {
                        Button(role: .destructive) {
                            Task { await clearTentativeDate(item) }
                        } label: {
                            Label("Quitar fecha tentativa", systemImage: "calendar.badge.minus")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Administrar ocurrencia")
            }
        }
        .padding(AppSpacing.sm)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
    }

    private var planningLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.lg) {
                legendPill("Solo mes", color: BrandColor.amber, detail: "Tiene mes, pero no fecha")
                legendPill("Fecha tentativa", color: .blue, detail: "Ya tiene día propuesto")
                legendPill("Confirmado", color: BrandColor.green, detail: "Semana confirmada")
                legendPill("En ejecución", color: .purple, detail: "Mantenimiento en curso")
                legendPill("Completado", color: BrandColor.graphite, detail: "Finalizado")
                legendPill("Reprogramación pendiente", color: BrandColor.red, detail: "Requiere nueva fecha")
            }
        }
    }

    private func legendPill(_ title: String, color: Color, detail: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(color)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 6)
                .background(color.opacity(0.11), in: Capsule())
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var weeklyContent: some View {
        GeometryReader { proxy in
            VStack(spacing: AppSpacing.md) {
                weeklyControlBar

                if isLoading && weeklyItems.isEmpty && weekDetail == nil {
                    Spacer()
                    ProgressView("Cargando programación semanal...")
                    Spacer()
                } else if proxy.size.width >= 1_000 {
                    GeometryReader { workspace in
                        HStack(alignment: .top, spacing: AppSpacing.md) {
                            weeklyScheduleBoard
                                .frame(
                                    width: max(workspace.size.width - 356, 520),
                                    height: workspace.size.height
                                )
                            weeklyPendingPanel
                                .frame(width: 340, height: workspace.size.height)
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.md) {
                            weeklyScheduleBoard
                            weeklyPendingPanel
                        }
                    }
                    .refreshable { await loadWeekly() }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
        }
        .onChange(of: weeklyFilterSignature) {
            weeklyPendingPage = 0
        }
    }

    private var weeklyControlBar: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                weeklyFilterBar

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppSpacing.md) {
                        weeklyMetrics
                        Spacer(minLength: AppSpacing.sm)
                        confirmWeekButton
                        weeklyOptionsMenu
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.sm) {
                            weeklyMetrics
                            confirmWeekButton
                            weeklyOptionsMenu
                        }
                    }
                }
            }
        }
    }

    private var weeklyFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                compactWeekNavigation

                Divider()
                    .frame(height: 36)

                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Buscar mantenimiento o equipo", text: $weeklyQuery)
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, AppSpacing.sm)
                .frame(width: 220, height: 42)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))

                compactWeeklyFilter("Subsistema", selection: $weeklySelectedSubsystem, values: weeklySubsystems)
                compactWeeklyFilter("Categoría", selection: $weeklySelectedCategory, values: weeklyCategories)
                compactWeeklyFilter("Ubicación", selection: $weeklySelectedLocation, values: weeklyLocations)

                Button {
                    weeklyQuery = ""
                    weeklySelectedSubsystem = "Todos"
                    weeklySelectedCategory = "Todas"
                    weeklySelectedLocation = "Todas"
                    weeklyPendingPage = 0
                } label: {
                    Label("Limpiar", systemImage: "arrow.counterclockwise")
                        .frame(minHeight: 42)
                }
                .buttonStyle(.glass)
            }
        }
    }

    private func compactWeeklyFilter(
        _ title: String,
        selection: Binding<String>,
        values: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach(values, id: \.self) { value in Text(value).tag(value) }
            }
            .labelsHidden()
        }
        .padding(.horizontal, AppSpacing.sm)
        .frame(width: 135, height: 42, alignment: .leading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
    }

    private var compactWeekNavigation: some View {
        HStack(spacing: AppSpacing.sm) {
            Button {
                weekStart = calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
                weeklyPendingPage = 0
                Task { await loadWeekly() }
            } label: {
                Image(systemName: "chevron.left").frame(width: 34, height: 34)
            }
            .buttonStyle(.glass)

            Text("Semana")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Button {
                weekStart = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
                weeklyPendingPage = 0
                Task { await loadWeekly() }
            } label: {
                Image(systemName: "chevron.right").frame(width: 34, height: 34)
            }
            .buttonStyle(.glass)

            Text(Self.weekRangeLabel(start: weekStart))
                .font(.subheadline.bold())
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var weeklyMetrics: some View {
        HStack(spacing: AppSpacing.sm) {
            weeklyMetric(value: weeklyPlannedCount, title: "Planificados", color: .blue)
            weeklyMetric(value: weeklyProposals.count, title: "Con fecha", color: BrandColor.green)
            weeklyMetric(value: availableWeeklyItems.count, title: "Pendientes", color: BrandColor.amber)
            weeklyMetric(value: weeklyConflictCount, title: "Conflictos", color: BrandColor.red)
        }
    }

    private func weeklyMetric(value: Int, title: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 0) {
                Text(String(value)).font(.headline)
                Text(title).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .frame(minWidth: 90, minHeight: 44, alignment: .leading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
    }

    private var confirmWeekButton: some View {
        let canConfirm = canEdit
            && weekDetail?.session.status == "DRAFT"
            && !weeklyProposals.isEmpty
        return Button {
            isConfirmingWeek = true
        } label: {
            Label("Confirmar semana", systemImage: "arrow.right")
                .font(.subheadline.bold())
                .frame(minHeight: 36)
        }
        .buttonStyle(.glassProminent)
        .disabled(!canConfirm)
        .opacity(canConfirm ? 1 : 0.55)
    }

    private var weeklyOptionsMenu: some View {
        Menu {
            Button {
                showsHistory = true
                Task { await loadHistory() }
            } label: {
                Label("Ver historial", systemImage: "clock.arrow.circlepath")
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.glass)
        .accessibilityLabel("Más opciones de programación semanal")
    }

    private var weeklyScheduleBoard: some View {
        GlassPanel {
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                HStack(alignment: .top, spacing: 0) {
                    weeklyTimeAxis
                    ForEach(weekDates, id: \.self) { day in
                        weeklyGridDayColumn(day)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var weeklyTimeAxis: some View {
        VStack(spacing: 0) {
            Text("Hora")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .frame(height: weeklyHeaderHeight)
            ForEach(0..<24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: weeklyHourHeight, alignment: .top)
                    .overlay(alignment: .top) { Divider() }
            }
        }
    }

    private func weeklyGridDayColumn(_ day: Date) -> some View {
        let proposals = weeklyProposals.filter {
            calendar.isDate($0.proposedStartAt, inSameDayAs: day)
        }
        let isToday = calendar.isDateInToday(day)
        return VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text(Self.weekdayFormatter.string(from: day).capitalized)
                Text(day, format: .dateTime.day())
            }
            .font(.caption2.bold())
            .foregroundStyle(isToday ? BrandColor.red : .secondary)
            .frame(width: weeklyDayWidth, height: weeklyHeaderHeight)
            .background(isToday ? BrandColor.red.opacity(0.08) : Color.clear)

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { _ in
                        Rectangle()
                            .fill(isToday ? BrandColor.red.opacity(0.025) : Color.clear)
                            .frame(width: weeklyDayWidth, height: weeklyHourHeight)
                            .overlay(alignment: .top) { Divider() }
                    }
                }
                ForEach(proposals) { proposal in
                    let geometry = proposalGeometry(proposal)
                    weeklyProposalBlock(proposal)
                        .frame(width: weeklyDayWidth - 10, height: geometry.height)
                        .offset(x: 5, y: geometry.offset)
                }
            }
            .frame(
                width: weeklyDayWidth,
                height: weeklyHourHeight * CGFloat(weeklyVisibleHours),
                alignment: .topLeading
            )
        }
        .overlay(alignment: .leading) { Divider() }
    }

    private func weeklyProposalBlock(_ proposal: PCONProposal) -> some View {
        let color = proposal.status == "CONFIRMED" ? BrandColor.green : Color.blue
        return VStack(alignment: .leading, spacing: 2) {
            Text(proposal.activityTitle)
                .lineLimit(2)
                .font(.caption2.bold())
            Text(Self.proposalTimeRange(proposal))
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 5))
        .overlay(alignment: .leading) { Rectangle().fill(color).frame(width: 3) }
        .clipped()
        .contextMenu {
            if canEdit, weekDetail?.session.status == "DRAFT" {
                Button(role: .destructive) {
                    Task { await deleteProposal(proposal) }
                } label: {
                    Label("Quitar de la semana", systemImage: "trash")
                }
            }
        }
    }

    private var weeklyPendingPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    SectionHeaderText(
                        title: "Pendientes del mes",
                        subtitle: "Asigna una fecha para incorporarlos a una semana"
                    )
                    Spacer()
                    Text(String(availableWeeklyItems.count))
                        .font(.caption.bold())
                        .foregroundStyle(BrandColor.red)
                        .padding(7)
                        .background(BrandColor.red.opacity(0.10), in: Circle())
                }
                if availableWeeklyItems.isEmpty {
                    ContentUnavailableView(
                        "Sin pendientes",
                        systemImage: "calendar.badge.checkmark",
                        description: Text("Todas las ocurrencias del periodo tienen fecha.")
                    )
                    .frame(minHeight: 220)
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.sm) {
                            ForEach(weeklyPendingPageItems) { item in
                                Button {
                                    schedulingItem = item
                                } label: {
                                    HStack(spacing: AppSpacing.sm) {
                                        Circle().fill(BrandColor.amber).frame(width: 7, height: 7)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.maintenanceName).font(.caption.bold()).lineLimit(2)
                                            Text("\(item.equipmentName) · \(item.subsystemCode)")
                                                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                            Text(item.locationName.activityLocationSummary)
                                                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold()).foregroundStyle(.tertiary)
                                    }
                                    .padding(AppSpacing.sm)
                                    .background(
                                        Color.primary.opacity(0.035),
                                        in: RoundedRectangle(cornerRadius: 7)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)

                    HStack {
                        Button {
                            weeklyPendingPage = max(weeklyPendingSafePage - 1, 0)
                        } label: {
                            Image(systemName: "chevron.left")
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.glass)
                        .disabled(weeklyPendingSafePage == 0)

                        Spacer()
                        Text("Página \(weeklyPendingSafePage + 1) de \(weeklyPendingPageCount)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()

                        Button {
                            weeklyPendingPage = min(
                                weeklyPendingSafePage + 1,
                                weeklyPendingPageCount - 1
                            )
                        } label: {
                            Image(systemName: "chevron.right")
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.glass)
                        .disabled(weeklyPendingSafePage >= weeklyPendingPageCount - 1)
                    }

                    Menu {
                        ForEach(weeklyPendingPageItems) { item in
                            Button {
                                schedulingItem = item
                            } label: {
                                Label(item.maintenanceName, systemImage: "calendar.badge.plus")
                            }
                        }
                    } label: {
                        Label("Asignar al calendario", systemImage: "calendar.badge.plus")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity, minHeight: 38)
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var weekPicker: some View {
        GlassPanel {
            HStack {
                Button {
                    weekStart = calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
                    Task { await loadWeekly() }
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)

                Spacer()
                VStack(spacing: 3) {
                    Text("SEMANA DEL")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(Self.weekFormatter.string(from: weekStart))
                        .font(.title3.bold())
                }
                Spacer()

                Button {
                    weekStart = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
                    Task { await loadWeekly() }
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
            }
        }
    }

    private var weeklySummary: some View {
        GlassPanel {
            HStack(spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Acuerdo semanal")
                        .font(.title3.bold())
                    Text(weekDetailSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label(
                    "\(weekDetail?.proposals.count ?? 0) propuestas",
                    systemImage: "calendar.badge.clock"
                )
                .font(.headline)
                if canEdit, let detail = weekDetail,
                   detail.session.status == "DRAFT",
                   !detail.proposals.isEmpty {
                    Button {
                        isConfirmingWeek = true
                    } label: {
                        Label("Confirmar semana", systemImage: "checkmark.seal.fill")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
    }

    private var weeklyHierarchy: some View {
        let subsystems = Dictionary(grouping: availableWeeklyItems, by: \.subsystemCode)
        return ForEach(subsystems.keys.sorted(), id: \.self) { subsystem in
            ContentGlassPanel {
                DisclosureGroup {
                    let equipment = Dictionary(
                        grouping: subsystems[subsystem, default: []],
                        by: \.equipmentName
                    )
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(equipment.keys.sorted(), id: \.self) { equipmentName in
                            DisclosureGroup {
                                VStack(spacing: AppSpacing.sm) {
                                    ForEach(equipment[equipmentName, default: []]) { item in
                                        weeklyOccurrenceRow(item)
                                    }
                                }
                                .padding(.top, AppSpacing.sm)
                            } label: {
                                Label(equipmentName, systemImage: "server.rack")
                                    .font(.headline)
                            }
                            .padding(AppSpacing.sm)
                            .background(
                                Color.primary.opacity(0.035),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        }
                    }
                    .padding(.top, AppSpacing.md)
                } label: {
                    HStack {
                        Label(subsystem, systemImage: "square.stack.3d.up.fill")
                            .font(.title3.bold())
                        Spacer()
                        Text("\(subsystems[subsystem]?.count ?? 0)")
                            .font(.caption.bold())
                    }
                }
            }
        }
    }

    private func weeklyOccurrenceRow(_ item: PCONPlanItem) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.maintenanceName)
                    .font(.headline)
                Text(item.locationName.activityLocationSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: AppSpacing.md) {
                    if let minutes = item.estimatedMinutes {
                        Label("\(minutes) min", systemImage: "clock")
                    }
                    if let workers = item.requiredWorkers {
                        Label("\(workers)", systemImage: "person.2")
                    }
                    Text(item.planningState.label)
                        .foregroundStyle(item.planningState.color)
                }
                .font(.caption.weight(.semibold))
            }
            Spacer()
            if canEdit {
                Button {
                    schedulingItem = item
                } label: {
                    Label(
                        item.scheduledStartAt == nil ? "Programar" : "Reprogramar",
                        systemImage: "calendar.badge.plus"
                    )
                        .frame(minWidth: 120)
                }
                .buttonStyle(.glass)
            }
        }
        .padding(AppSpacing.md)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }

    private func proposalPanel(_ detail: PCONWeekDetail) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Propuestas de la semana",
                    subtitle: "Se publicarán juntas al confirmar el bloque"
                )
                ForEach(detail.proposals) { proposal in
                    HStack(spacing: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(proposal.activityTitle)
                                .font(.headline)
                            Text(proposal.equipmentName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(Self.dateTimeFormatter.string(from: proposal.proposedStartAt))
                                .font(.subheadline.weight(.semibold))
                            if let reason = proposal.reason {
                                Text(reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if canEdit, detail.session.status == "DRAFT" {
                            Button(role: .destructive) {
                                Task { await deleteProposal(proposal) }
                            } label: {
                                Image(systemName: "trash")
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(
                        Color.primary.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
            }
        }
    }

    private var filteredWeeklyItems: [PCONPlanItem] {
        weeklyItems.filter { item in
            let normalizedQuery = weeklyQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let searchableText = [
                item.maintenanceName,
                item.equipmentName,
                item.subsystemCode,
                item.locationName
            ]
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return (normalizedQuery.isEmpty || searchableText.contains(normalizedQuery))
                && (weeklySelectedSubsystem == "Todos" || item.subsystemCode == weeklySelectedSubsystem)
                && (weeklySelectedCategory == "Todas" || item.equipmentCategory == weeklySelectedCategory)
                && (weeklySelectedLocation == "Todas"
                    || item.locationName.activityLocationSummary == weeklySelectedLocation)
        }
    }

    private var availableWeeklyItems: [PCONPlanItem] {
        filteredWeeklyItems.filter {
            $0.activityStatus == "SCHEDULED"
                && ($0.planningState == .monthOnly || $0.planningState == .reschedulePending)
        }
    }

    private var weeklySubsystems: [String] {
        ["Todos"] + Array(Set(weeklyItems.map(\.subsystemCode))).sorted()
    }

    private var weeklyCategories: [String] {
        ["Todas"] + Array(Set(weeklyItems.map(\.equipmentCategory))).sorted()
    }

    private var weeklyLocations: [String] {
        ["Todas"] + Array(Set(weeklyItems.map { $0.locationName.activityLocationSummary })).sorted()
    }

    private var weeklyFilterSignature: String {
        [
            weeklyQuery,
            weeklySelectedSubsystem,
            weeklySelectedCategory,
            weeklySelectedLocation
        ].joined(separator: "|")
    }

    private var weeklyPendingPageSize: Int { 4 }

    private var weeklyPendingPageCount: Int {
        max(1, Int(ceil(Double(availableWeeklyItems.count) / Double(weeklyPendingPageSize))))
    }

    private var weeklyPendingSafePage: Int {
        min(weeklyPendingPage, weeklyPendingPageCount - 1)
    }

    private var weeklyPendingPageItems: [PCONPlanItem] {
        let start = weeklyPendingSafePage * weeklyPendingPageSize
        guard start < availableWeeklyItems.count else { return [] }
        let end = min(start + weeklyPendingPageSize, availableWeeklyItems.count)
        return Array(availableWeeklyItems[start..<end])
    }

    private var weeklyProposals: [PCONProposal] {
        let filteredActivityIDs = Set(filteredWeeklyItems.map(\.activityID))
        return (weekDetail?.proposals ?? [])
            .filter { filteredActivityIDs.contains($0.activityID) }
            .sorted { $0.proposedStartAt < $1.proposedStartAt }
    }

    private var weeklyPlannedCount: Int {
        weeklyProposals.count + availableWeeklyItems.count
    }

    private var weeklyConflictCount: Int {
        var conflicts = 0
        for index in weeklyProposals.indices {
            for otherIndex in weeklyProposals.indices where otherIndex > index {
                let first = weeklyProposals[index]
                let second = weeklyProposals[otherIndex]
                guard calendar.isDate(first.proposedStartAt, inSameDayAs: second.proposedStartAt) else {
                    continue
                }
                if first.proposedStartAt < second.proposedEndAt
                    && second.proposedStartAt < first.proposedEndAt {
                    conflicts += 1
                }
            }
        }
        return conflicts
    }

    private var weeklyHeaderHeight: CGFloat { 34 }
    private var weeklyHourHeight: CGFloat { 44 }
    private var weeklyDayWidth: CGFloat { 108 }
    private var weeklyVisibleHours: Int { 24 }

    private func proposalGeometry(_ proposal: PCONProposal) -> (offset: CGFloat, height: CGFloat) {
        let startComponents = calendar.dateComponents([.hour, .minute], from: proposal.proposedStartAt)
        let startMinute = (startComponents.hour ?? 8) * 60 + (startComponents.minute ?? 0)
        let durationMinutes = max(
            Int(proposal.proposedEndAt.timeIntervalSince(proposal.proposedStartAt) / 60),
            15
        )
        let endMinute = startMinute + durationMinutes
        let visibleStart = 0
        let visibleEnd = 24 * 60
        let clampedStart = min(max(startMinute, visibleStart), visibleEnd)
        let clampedEnd = min(max(endMinute, clampedStart + 15), visibleEnd)
        let offset = CGFloat(clampedStart - visibleStart) / 60 * weeklyHourHeight
        let availableHeight = weeklyHourHeight * CGFloat(weeklyVisibleHours) - offset
        let durationHeight = CGFloat(clampedEnd - clampedStart) / 60 * weeklyHourHeight
        return (offset, min(max(durationHeight, 28), availableHeight))
    }

    private var weekDates: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var monthlyDatedItems: [PCONPlanItem] {
        monthlyItems.filter { ($0.proposedStartAt ?? $0.scheduledStartAt) != nil }
    }

    private var monthlyPendingItems: [PCONPlanItem] {
        monthlyItems.filter {
            $0.planningState == .monthOnly || $0.planningState == .reschedulePending
        }
    }

    private var selectedDayItems: [PCONPlanItem] {
        items(on: selectedCalendarDay)
    }

    private var monthCalendarSlots: [PCONCalendarSlot] {
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = 1
        guard let firstDay = calendar.date(from: components),
              let dayRange = calendar.range(of: .day, in: .month, for: firstDay) else {
            return []
        }
        let weekday = calendar.component(.weekday, from: firstDay)
        let mondayOffset = (weekday + 5) % 7
        var slots = (0..<mondayOffset).map {
            PCONCalendarSlot(id: $0, date: nil, day: nil)
        }
        slots += dayRange.map { day in
            let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay)
            return PCONCalendarSlot(id: mondayOffset + day - 1, date: date, day: day)
        }
        while slots.count % 7 != 0 {
            slots.append(PCONCalendarSlot(id: slots.count, date: nil, day: nil))
        }
        return slots
    }

    private func items(on date: Date) -> [PCONPlanItem] {
        monthlyItems
            .filter { item in
                guard let itemDate = item.proposedStartAt ?? item.scheduledStartAt else { return false }
                return calendar.isDate(itemDate, inSameDayAs: date)
            }
            .sorted {
                ($0.proposedStartAt ?? $0.scheduledStartAt ?? .distantFuture)
                    < ($1.proposedStartAt ?? $1.scheduledStartAt ?? .distantFuture)
            }
    }

    private func dominantStateColor(_ items: [PCONPlanItem]) -> Color {
        if let pending = items.first(where: { $0.planningState == .reschedulePending }) {
            return pending.planningState.color
        }
        return items.first?.planningState.color ?? .secondary
    }

    private func moveSelectedMonth(by value: Int) {
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = 1
        let current = calendar.date(from: components) ?? selectedCalendarDay
        let next = calendar.date(byAdding: .month, value: value, to: current) ?? current
        selectedYear = calendar.component(.year, from: next)
        selectedMonth = calendar.component(.month, from: next)
        selectedCalendarDay = next
        Task { await loadMonthly() }
    }

    private var weekDetailSubtitle: String {
        guard let detail = weekDetail else {
            return canEdit ? "Aún no hay propuestas" : "Aún no existe programación"
        }
        if detail.session.status == "CONFIRMED" {
            return "Semana confirmada · versión \(detail.session.version)"
        }
        return "\(detail.proposals.count) propuestas pendientes de confirmación"
    }

    private var allGroupKeys: [String] {
        guard let rows = annualPlan?.rows else { return [] }
        var keys: Set<String> = []
        for row in rows {
            let subsystem = "s|\(row.subsystemCode)"
            let category = "\(subsystem)|c|\(row.equipmentCategory)"
            let location = "\(category)|l|\(row.locationName.activityLocationSummary)"
            let equipment = "\(location)|e|\(row.equipmentID ?? row.equipmentName)"
            keys.formUnion([subsystem, category, location, equipment])
        }
        return Array(keys)
    }

    private var annualSubsystems: [String] {
        ["Todos"] + Array(Set(annualPlan?.rows.map(\.subsystemCode) ?? [])).sorted()
    }

    private var annualCategories: [String] {
        ["Todas"] + Array(Set(annualPlan?.rows.map(\.equipmentCategory) ?? [])).sorted()
    }

    private var annualLocations: [String] {
        ["Todas"] + Array(
            Set(annualPlan?.rows.map { $0.locationName.activityLocationSummary } ?? [])
        ).sorted()
    }

    private var annualEquipment: [String] {
        ["Todos"] + Array(Set(annualPlan?.rows.map(\.equipmentName) ?? [])).sorted()
    }

    private var filteredAnnualRows: [PCONAnnualRow] {
        guard let rows = annualPlan?.rows else { return [] }
        return rows.filter { row in
            (selectedSubsystem == "Todos" || row.subsystemCode == selectedSubsystem)
                && (selectedCategory == "Todas" || row.equipmentCategory == selectedCategory)
                && (selectedLocation == "Todas"
                    || row.locationName.activityLocationSummary == selectedLocation)
                && (selectedEquipment == "Todos" || row.equipmentName == selectedEquipment)
        }
    }

    private func visibleHierarchyRows(_ rows: [PCONAnnualRow]) -> [HierarchyGroup] {
        var result: [HierarchyGroup] = []
        let subsystems = Dictionary(grouping: rows, by: \.subsystemCode)
        for subsystem in subsystems.keys.sorted() {
            let subsystemRows = subsystems[subsystem, default: []]
            let subsystemKey = "s|\(subsystem)"
            result.append(
                HierarchyGroup(
                    key: subsystemKey,
                    label: subsystem,
                    level: 0,
                    rows: subsystemRows
                )
            )
            guard expandedGroups.contains(subsystemKey) else { continue }

            let categories = Dictionary(grouping: subsystemRows, by: \.equipmentCategory)
            for category in categories.keys.sorted() {
                let categoryRows = categories[category, default: []]
                let categoryKey = "\(subsystemKey)|c|\(category)"
                result.append(
                    HierarchyGroup(
                        key: categoryKey,
                        label: category,
                        level: 1,
                        rows: categoryRows
                    )
                )
                guard expandedGroups.contains(categoryKey) else { continue }

                let locations = Dictionary(
                    grouping: categoryRows,
                    by: { $0.locationName.activityLocationSummary }
                )
                for location in locations.keys.sorted() {
                    let locationRows = locations[location, default: []]
                    let locationKey = "\(categoryKey)|l|\(location)"
                    result.append(
                        HierarchyGroup(
                            key: locationKey,
                            label: location,
                            level: 2,
                            rows: locationRows
                        )
                    )
                    guard expandedGroups.contains(locationKey) else { continue }

                    let equipment = Dictionary(grouping: locationRows, by: \.equipmentName)
                    for equipmentName in equipment.keys.sorted() {
                        let equipmentRows = equipment[equipmentName, default: []]
                        let equipmentKey = "\(locationKey)|e|\(equipmentName)"
                        result.append(
                            HierarchyGroup(
                                key: equipmentKey,
                                label: equipmentName,
                                level: 3,
                                rows: equipmentRows
                            )
                        )
                        guard expandedGroups.contains(equipmentKey) else { continue }

                        for row in equipmentRows.sorted(by: {
                            $0.maintenanceName < $1.maintenanceName
                        }) {
                            result.append(
                                HierarchyGroup(
                                    key: "\(equipmentKey)|m|\(row.id)",
                                    label: row.maintenanceName,
                                    level: 4,
                                    rows: [row]
                                )
                            )
                        }
                    }
                }
            }
        }
        return result
    }

    private func toggle(_ key: String) {
        if expandedGroups.contains(key) {
            expandedGroups.remove(key)
        } else {
            expandedGroups.insert(key)
        }
    }

    private func hierarchyIcon(level: Int) -> String {
        switch level {
        case 0: "square.stack.3d.up.fill"
        case 1: "square.grid.2x2"
        case 2: "mappin.and.ellipse"
        case 3: "server.rack"
        default: "wrench.and.screwdriver"
        }
    }

    private func rowBackground(level: Int) -> Color {
        switch level {
        case 0: BrandColor.red.opacity(0.12)
        case 1: Color.primary.opacity(0.09)
        case 2: Color.primary.opacity(0.065)
        case 3: Color.primary.opacity(0.045)
        default: Color.primary.opacity(0.02)
        }
    }

    @MainActor
    private func loadCurrentSection() async {
        switch section {
        case .annual:
            await loadAnnual()
        case .monthly:
            await loadMonthly()
        case .weekly:
            await loadWeekly()
        }
    }

    @MainActor
    private func loadMonthly() async {
        isLoading = true
        defer { isLoading = false }
        do {
            monthlyItems = try await withService { service, token in
                try await service.plan(
                    year: selectedYear,
                    month: selectedMonth,
                    query: query,
                    token: token
                ).items
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadAnnual() async {
        isLoading = true
        defer { isLoading = false }
        do {
            annualPlan = try await withService { service, token in
                try await service.annualPlan(year: selectedYear, query: query, token: token)
            }
            if expandedGroups.isEmpty,
               let firstSubsystem = annualPlan?.rows.first?.subsystemCode {
                expandedGroups.insert("s|\(firstSubsystem)")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func setAnnualCount(
        selection: AnnualCellSelection,
        count: Int
    ) async -> [PCONPlanItem]? {
        do {
            _ = try await withService { service, token in
                try await service.setCount(
                    scopeID: selection.row.maintenanceTemplateScopeID,
                    year: selectedYear,
                    month: selection.month.month,
                    count: count,
                    token: token
                )
            }
            await loadAnnual()
            return annualPlan?.rows
                .first { $0.maintenanceTemplateScopeID == selection.row.maintenanceTemplateScopeID }?
                .months
                .first { $0.month == selection.month.month }?
                .occurrences
                .filter { $0.proposedStartAt == nil && $0.scheduledStartAt == nil }
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    @MainActor
    private func saveAnnualTentativeProposals(
        _ requests: [TentativeScheduleRequest]
    ) async -> Bool {
        guard !requests.isEmpty else { return true }
        do {
            try await withService { service, token in
                var sessions: [String: PCONWeekDetail] = [:]
                for request in requests {
                    let week = Self.startOfWeek(request.start)
                    let weekKey = Self.apiDate(week)
                    let detail: PCONWeekDetail
                    if let cached = sessions[weekKey] {
                        detail = cached
                    } else {
                        do {
                            let current = try await service.currentWeek(weekKey, token: token)
                            detail = current.session.status == "DRAFT"
                                ? current
                                : try await service.createWeek(weekKey, token: token)
                        } catch {
                            detail = try await service.createWeek(weekKey, token: token)
                        }
                        sessions[weekKey] = detail
                    }
                    let updated = try await service.saveProposal(
                        sessionID: detail.session.id,
                        item: request.item,
                        start: request.start,
                        end: request.end,
                        reason: "Propuesta creada desde el plan anual",
                        token: token
                    )
                    sessions[weekKey] = updated
                }
            }
            await loadAnnual()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    private func prepareAddMaintenance() async {
        do {
            catalog = try await withService { service, token in
                try await service.catalog(token: token)
            }
            showsAddMaintenance = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func addPlanScope(
        assetID: String,
        templateID: UUID,
        month: Int,
        quantity: Int,
        reason: String
    ) async -> Bool {
        do {
            _ = try await withService { service, token in
                try await service.addPlanScope(
                    year: selectedYear,
                    assetID: assetID,
                    templateID: templateID,
                    month: month,
                    quantity: quantity,
                    reason: reason,
                    token: token
                )
            }
            await loadAnnual()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    private func copyPreviousYear() async {
        do {
            _ = try await withService { service, token in
                try await service.copyPlan(
                    sourceYear: selectedYear - 1,
                    targetYear: selectedYear,
                    token: token
                )
            }
            await loadAnnual()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func moveOccurrence(
        _ item: PCONPlanItem,
        month: Int,
        reason: String
    ) async -> Bool {
        do {
            try await withService { service, token in
                try await service.moveOccurrence(
                    item,
                    year: selectedYear,
                    month: month,
                    reason: reason,
                    token: token
                )
            }
            selectedCell = nil
            await loadAnnual()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    private func removeOccurrence(
        _ item: PCONPlanItem,
        reason: String
    ) async -> Bool {
        do {
            try await withService { service, token in
                if item.scheduledStartAt == nil {
                    try await service.removeOccurrence(item, token: token)
                } else {
                    try await service.cancelOccurrence(
                        item,
                        reason: reason,
                        token: token
                    )
                }
            }
            selectedCell = nil
            await loadAnnual()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    private func loadWeekly() async {
        isLoading = true
        defer { isLoading = false }
        do {
            weeklyItems = try await withService { service, token in
                var loaded: [UUID: PCONPlanItem] = [:]
                let periods = Set(weekDates.map {
                    "\(calendar.component(.year, from: $0))-\(calendar.component(.month, from: $0))"
                })
                for period in periods {
                    let parts = period.split(separator: "-").compactMap { Int($0) }
                    guard parts.count == 2 else { continue }
                    let page = try await service.plan(
                        year: parts[0],
                        month: parts[1],
                        query: "",
                        token: token
                    )
                    for item in page.items { loaded[item.id] = item }
                }
                return Array(loaded.values)
            }
            do {
                weekDetail = try await withService { service, token in
                    try await service.currentWeek(Self.apiDate(weekStart), token: token)
                }
            } catch {
                weekDetail = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadHistory() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await withService { service, token in
                async let weekly = service.history(token: token)
                async let annual = service.planChanges(year: selectedYear, token: token)
                return try await (weekly, annual)
            }
            history = result.0
            planChanges = result.1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func saveProposal(
        item: PCONPlanItem,
        start: Date,
        end: Date,
        reason: String
    ) async -> Bool {
        do {
            let targetWeek = Self.startOfWeek(start)
            let targetWeekKey = Self.apiDate(targetWeek)
            let detail = try await withService { service, token in
                let current: PCONWeekDetail
                do {
                    let existing = try await service.currentWeek(targetWeekKey, token: token)
                    current = existing.session.status == "DRAFT"
                        ? existing
                        : try await service.createWeek(targetWeekKey, token: token)
                } catch {
                    current = try await service.createWeek(targetWeekKey, token: token)
                }
                return try await service.saveProposal(
                    sessionID: current.session.id,
                    item: item,
                    start: start,
                    end: end,
                    reason: reason,
                    token: token
                )
            }
            if section == .weekly, calendar.isDate(targetWeek, inSameDayAs: weekStart) {
                weekDetail = detail
            }
            await loadCurrentSection()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    private func deleteProposal(_ proposal: PCONProposal) async {
        do {
            try await withService { service, token in
                try await service.deleteProposal(
                    sessionID: proposal.sessionID,
                    activityID: proposal.activityID,
                    token: token
                )
            }
            await loadWeekly()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func clearTentativeDate(_ item: PCONPlanItem) async {
        guard let proposedDate = item.proposedStartAt else { return }
        do {
            try await withService { service, token in
                let detail = try await service.currentWeek(
                    Self.apiDate(Self.startOfWeek(proposedDate)),
                    token: token
                )
                guard detail.session.status == "DRAFT",
                      detail.proposals.contains(where: { $0.activityID == item.activityID }) else {
                    throw PCONPlanningError.proposalNotEditable
                }
                try await service.deleteProposal(
                    sessionID: detail.session.id,
                    activityID: item.activityID,
                    token: token
                )
            }
            await loadCurrentSection()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func confirmWeek() async {
        guard let sessionID = weekDetail?.session.id else { return }
        do {
            weekDetail = try await withService { service, token in
                try await service.confirm(sessionID: sessionID, token: token)
            }
            await loadWeekly()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func withService<Value>(
        _ operation: (PCONService, String) async throws -> Value
    ) async throws -> Value {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else {
            throw APIClient.APIError.invalidBaseURL
        }
        return try await session.withValidAccessToken { token in
            try await operation(PCONService(baseURL: baseURL), token)
        }
    }

    private static func startOfWeek(_ date: Date) -> Date {
        Calendar(identifier: .iso8601).dateInterval(of: .weekOfYear, for: date)?.start
            ?? date
    }

    private static func apiDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Lima")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    fileprivate static func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        return formatter.monthSymbols[month - 1].capitalized
    }

    private static func shortMonthName(_ month: Int) -> String {
        String(monthName(month).prefix(3)).uppercased()
    }

    fileprivate static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateFormat = "EEE d MMM · HH:mm"
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateFormat = "d 'de' MMMM 'de' yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static func timeRange(_ item: PCONPlanItem, start: Date) -> String {
        let end = item.proposedEndAt ?? item.scheduledEndAt
        guard let end else { return timeFormatter.string(from: start) }
        return "\(timeFormatter.string(from: start)) - \(timeFormatter.string(from: end))"
    }

    private static let weekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateFormat = "d 'de' MMMM 'de' yyyy"
        return formatter
    }()

    private static func weekRangeLabel(start: Date) -> String {
        let calendar = Calendar(identifier: .iso8601)
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "es_PE")
        dayFormatter.dateFormat = "d"
        let monthYearFormatter = DateFormatter()
        monthYearFormatter.locale = Locale(identifier: "es_PE")
        monthYearFormatter.dateFormat = "MMMM 'de' yyyy"
        return "\(dayFormatter.string(from: start)) - \(dayFormatter.string(from: end)) de \(monthYearFormatter.string(from: end))"
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static func proposalTimeRange(_ proposal: PCONProposal) -> String {
        "\(timeFormatter.string(from: proposal.proposedStartAt)) - \(timeFormatter.string(from: proposal.proposedEndAt))"
    }
}

private struct AnnualCountSheet: View {
    @Environment(\.dismiss) private var dismiss

    let selection: AnnualCellSelection
    let year: Int
    let canEdit: Bool
    let onSave: (Int) async -> [PCONPlanItem]?
    let onSchedule: ([TentativeScheduleRequest]) async -> Bool
    let onMove: (PCONPlanItem, Int, String) async -> Bool
    let onRemove: (PCONPlanItem, String) async -> Bool

    @State private var count: Int
    @State private var isSaving = false
    @State private var selectedOccurrence: PCONPlanItem?
    @State private var tentativeBatch: AnnualTentativeBatch?

    init(
        selection: AnnualCellSelection,
        year: Int,
        canEdit: Bool,
        onSave: @escaping (Int) async -> [PCONPlanItem]?,
        onSchedule: @escaping ([TentativeScheduleRequest]) async -> Bool,
        onMove: @escaping (PCONPlanItem, Int, String) async -> Bool,
        onRemove: @escaping (PCONPlanItem, String) async -> Bool
    ) {
        self.selection = selection
        self.year = year
        self.canEdit = canEdit
        self.onSave = onSave
        self.onSchedule = onSchedule
        self.onMove = onMove
        self.onRemove = onRemove
        _count = State(initialValue: selection.month.count)
    }

    var body: some View {
        NavigationStack {
            List {
                maintenanceSection
                monthlySection
                occurrencesSection
            }
            .navigationTitle("Cantidad mensual")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
                if canEdit {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Guardar") {
                            Task {
                                isSaving = true
                                if let items = await onSave(count) {
                                    if items.isEmpty {
                                        dismiss()
                                    } else {
                                        tentativeBatch = AnnualTentativeBatch(
                                            items: items,
                                            year: year,
                                            month: selection.month.month
                                        )
                                    }
                                }
                                isSaving = false
                            }
                        }
                        .disabled(isSaving || count == selection.month.count)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(item: $selectedOccurrence) { item in
            OccurrenceEditorSheet(
                item: item,
                currentMonth: selection.month.month,
                year: year,
                onMove: { month, reason in
                    let changed = await onMove(item, month, reason)
                    if changed { dismiss() }
                    return changed
                },
                onRemove: { reason in
                    let changed = await onRemove(item, reason)
                    if changed { dismiss() }
                    return changed
                },
                onSchedule: { start, end in
                    let changed = await onSchedule([
                        TentativeScheduleRequest(item: item, start: start, end: end)
                    ])
                    if changed { dismiss() }
                    return changed
                }
            )
        }
        .sheet(item: $tentativeBatch) { batch in
            AnnualTentativeScheduleSheet(
                batch: batch,
                onSave: onSchedule,
                onFinish: { dismiss() }
            )
        }
    }

    private var maintenanceSection: some View {
        Section("Mantenimiento del equipo") {
            LabeledContent("Subsistema", value: selection.row.subsystemCode)
            LabeledContent("Categoría", value: selection.row.equipmentCategory)
            LabeledContent(
                "Ubicación",
                value: selection.row.locationName.activityLocationSummary
            )
            LabeledContent("Equipo", value: selection.row.equipmentName)
            LabeledContent("Mantenimiento", value: selection.row.maintenanceName)
        }
    }

    @ViewBuilder
    private var monthlySection: some View {
        Section("Plan mensual") {
            LabeledContent(
                "Periodo",
                value: "\(PCONPlanningView.monthName(selection.month.month)) \(year)"
            )
            if canEdit {
                Stepper(value: $count, in: 0...366) {
                    HStack {
                        Text("Cantidad de mantenimientos")
                        Spacer()
                        Text(String(count))
                            .font(.title3.bold())
                            .monospacedDigit()
                    }
                }
            } else {
                LabeledContent(
                    "Cantidad de mantenimientos",
                    value: String(selection.month.count)
                )
            }
        }
    }

    @ViewBuilder
    private var occurrencesSection: some View {
        if !selection.month.occurrences.isEmpty {
            Section("Ocurrencias") {
                ForEach(selection.month.occurrences.indices, id: \.self) { index in
                    occurrenceRow(
                        selection.month.occurrences[index],
                        index: index
                    )
                }
            }
        }
    }

    private func occurrenceRow(_ item: PCONPlanItem, index: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Ejecución \(index + 1)")
                    .font(.headline)
                if let date = item.proposedStartAt ?? item.scheduledStartAt {
                    Text(PCONPlanningView.dateTimeFormatter.string(from: date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Sin fecha exacta")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(item.planningState.label)
                .font(.caption.bold())
                .foregroundStyle(item.planningState.color)
            if canEdit && item.planningState != .executed {
                Button {
                    selectedOccurrence = item
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Administrar ejecución \(index + 1)")
            }
        }
    }
}

private struct AnnualTentativeScheduleSheet: View {
    @Environment(\.dismiss) private var dismiss

    let batch: AnnualTentativeBatch
    let onSave: ([TentativeScheduleRequest]) async -> Bool
    let onFinish: () -> Void

    @State private var entries: [TentativeScheduleEntry]
    @State private var isSaving = false

    init(
        batch: AnnualTentativeBatch,
        onSave: @escaping ([TentativeScheduleRequest]) async -> Bool,
        onFinish: @escaping () -> Void
    ) {
        self.batch = batch
        self.onSave = onSave
        self.onFinish = onFinish
        let calendar = Calendar(identifier: .iso8601)
        let defaultEntries = batch.items.enumerated().map { index, item in
            var components = DateComponents()
            components.year = batch.year
            components.month = batch.month
            components.day = min(index + 1, 28)
            components.hour = 8
            let start = calendar.date(from: components) ?? Date()
            let duration = max(item.estimatedMinutes ?? 60, 15)
            let end = calendar.date(byAdding: .minute, value: duration, to: start) ?? start
            return TentativeScheduleEntry(item: item, start: start, end: end)
        }
        _entries = State(initialValue: defaultEntries)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Estas fechas crean propuestas de la semana. Podrás validarlas o modificarlas después desde Programación semanal antes de confirmarlas.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Programación tentativa")
                }

                ForEach($entries) { $entry in
                    Section("Ejecución \(entries.firstIndex(where: { $0.id == entry.id }).map { $0 + 1 } ?? 1)") {
                        Text(entry.item.maintenanceName)
                            .font(.headline)
                        Text(entry.item.equipmentName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        DatePicker(
                            "Inicio tentativo",
                            selection: $entry.start,
                            in: monthRange,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        DatePicker(
                            "Fin tentativo",
                            selection: $entry.end,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
            }
            .navigationTitle("Fechas tentativas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Omitir por ahora") {
                        onFinish()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isSaving = true
                            let requests = entries.map {
                                TentativeScheduleRequest(item: $0.item, start: $0.start, end: $0.end)
                            }
                            if await onSave(requests) {
                                onFinish()
                                dismiss()
                            }
                            isSaving = false
                        }
                    } label: {
                        isSaving ? AnyView(ProgressView()) : AnyView(Text("Guardar propuestas"))
                    }
                    .disabled(isSaving || entries.contains { $0.end <= $0.start })
                }
            }
        }
        .presentationDetents([.large])
    }

    private var monthRange: ClosedRange<Date> {
        let calendar = Calendar(identifier: .iso8601)
        var components = DateComponents()
        components.year = batch.year
        components.month = batch.month
        components.day = 1
        let start = calendar.date(from: components) ?? Date()
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? start
        return start...end
    }
}

private struct TentativeScheduleEntry: Identifiable {
    let item: PCONPlanItem
    var start: Date
    var end: Date

    var id: UUID { item.planEntryID }
}

private struct OccurrenceEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let item: PCONPlanItem
    let currentMonth: Int
    let year: Int
    let onMove: (Int, String) async -> Bool
    let onRemove: (String) async -> Bool
    let onSchedule: (Date, Date) async -> Bool

    @State private var destinationMonth: Int
    @State private var reason = ""
    @State private var isSaving = false
    @State private var isConfirmingRemoval = false
    @State private var tentativeStart: Date
    @State private var tentativeEnd: Date

    init(
        item: PCONPlanItem,
        currentMonth: Int,
        year: Int,
        onMove: @escaping (Int, String) async -> Bool,
        onRemove: @escaping (String) async -> Bool,
        onSchedule: @escaping (Date, Date) async -> Bool
    ) {
        self.item = item
        self.currentMonth = currentMonth
        self.year = year
        self.onMove = onMove
        self.onRemove = onRemove
        self.onSchedule = onSchedule
        _destinationMonth = State(initialValue: currentMonth)
        let calendar = Calendar(identifier: .iso8601)
        var components = DateComponents()
        components.year = year
        components.month = currentMonth
        components.day = 1
        components.hour = 8
        let defaultStart = calendar.date(from: components) ?? Date()
        _tentativeStart = State(initialValue: item.proposedStartAt ?? defaultStart)
        _tentativeEnd = State(initialValue: item.proposedEndAt
            ?? calendar.date(byAdding: .minute, value: max(item.estimatedMinutes ?? 60, 15), to: defaultStart)
            ?? defaultStart.addingTimeInterval(3600))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ejecución") {
                    LabeledContent("Mantenimiento", value: item.maintenanceName)
                    LabeledContent("Equipo", value: item.equipmentName)
                    LabeledContent("Estado", value: item.planningState.label)
                }
                if item.scheduledStartAt == nil {
                    Section("Fecha tentativa") {
                        Text("Este rango es una ventana propuesta para la reunión semanal; puede coincidir con otras actividades.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        DatePicker(
                            "Inicio tentativo",
                            selection: $tentativeStart,
                            in: monthRange,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        DatePicker(
                            "Fin tentativo",
                            selection: $tentativeEnd,
                            in: monthRange,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        Button {
                            Task {
                                isSaving = true
                                if await onSchedule(tentativeStart, tentativeEnd) {
                                    dismiss()
                                }
                                isSaving = false
                            }
                        } label: {
                            Label("Guardar fecha tentativa", systemImage: "calendar.badge.clock")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(isSaving || tentativeEnd <= tentativeStart)
                    }
                }
                Section("Mover dentro del plan anual") {
                    Picker("Mes destino", selection: $destinationMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text(PCONPlanningView.monthName(month)).tag(month)
                        }
                    }
                    TextField("Motivo del cambio", text: $reason, axis: .vertical)
                        .lineLimit(2...4)
                    Button {
                        Task {
                            isSaving = true
                            if await onMove(destinationMonth, reason) {
                                dismiss()
                            }
                            isSaving = false
                        }
                    } label: {
                        Label("Mover ejecución", systemImage: "arrow.right.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(isSaving || destinationMonth == currentMonth)
                }
                Section {
                    Button(role: .destructive) {
                        isConfirmingRemoval = true
                    } label: {
                        Label(
                            item.scheduledStartAt == nil
                                ? "Eliminar del plan"
                                : "Cancelar ejecución programada",
                            systemImage: item.scheduledStartAt == nil
                                ? "trash"
                                : "calendar.badge.minus"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(
                        isSaving
                            || (item.scheduledStartAt != nil
                                && reason.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ).count < 3)
                    )
                } footer: {
                    Text(
                        item.scheduledStartAt == nil
                            ? "Una ejecución sin fecha puede retirarse del plan."
                            : "Una ejecución confirmada conserva su trazabilidad y requiere un motivo."
                    )
                }
            }
            .navigationTitle("Administrar ejecución")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .alert(
            item.scheduledStartAt == nil ? "Eliminar ejecución" : "Cancelar ejecución",
            isPresented: $isConfirmingRemoval
        ) {
            Button(
                item.scheduledStartAt == nil ? "Eliminar" : "Cancelar ejecución",
                role: .destructive
            ) {
                Task {
                    isSaving = true
                    if await onRemove(reason) {
                        dismiss()
                    }
                    isSaving = false
                }
            }
            Button("Volver", role: .cancel) {}
        } message: {
            Text("El cambio quedará registrado en el historial de PCON.")
        }
    }

    private var monthRange: ClosedRange<Date> {
        let calendar = Calendar(identifier: .iso8601)
        var components = DateComponents()
        components.year = year
        components.month = currentMonth
        components.day = 1
        let start = calendar.date(from: components) ?? Date()
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? start
        return start...end
    }
}

private struct AddPlanScopeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let year: Int
    let catalog: PCONCatalog
    let onSave: (String, UUID, Int, Int, String) async -> Bool

    @State private var subsystem: String
    @State private var assetQuery = ""
    @State private var selectedAssetID: String?
    @State private var selectedTemplateID: UUID?
    @State private var month = 1
    @State private var quantity = 1
    @State private var reason = ""
    @State private var isSaving = false

    init(
        year: Int,
        catalog: PCONCatalog,
        onSave: @escaping (String, UUID, Int, Int, String) async -> Bool
    ) {
        self.year = year
        self.catalog = catalog
        self.onSave = onSave
        _subsystem = State(
            initialValue: catalog.templates
                .map(\.subsystemCode)
                .sorted()
                .first ?? ""
        )
    }

    private var subsystems: [String] {
        Array(Set(catalog.templates.map(\.subsystemCode))).sorted()
    }

    private var filteredAssets: [PCONCatalogAsset] {
        let normalizedQuery = assetQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return catalog.assets.filter { asset in
            let belongsToSubsystem = asset.subsystem.caseInsensitiveCompare(subsystem) == .orderedSame
            guard belongsToSubsystem else { return false }
            guard !normalizedQuery.isEmpty else { return true }
            return asset.name.localizedCaseInsensitiveContains(normalizedQuery)
                || asset.category.localizedCaseInsensitiveContains(normalizedQuery)
                || asset.locationName.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    private var filteredTemplates: [PCONCatalogTemplate] {
        catalog.templates
            .filter { $0.subsystemCode.caseInsensitiveCompare(subsystem) == .orderedSame }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Clasificación") {
                    Picker("Subsistema", selection: $subsystem) {
                        ForEach(subsystems, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                }

                Section("Equipo") {
                    TextField("Buscar equipo, categoría o ubicación", text: $assetQuery)
                        .textInputAutocapitalization(.never)
                    if filteredAssets.isEmpty {
                        ContentUnavailableView.search(text: assetQuery)
                    } else {
                        ForEach(filteredAssets.prefix(80)) { asset in
                            Button {
                                selectedAssetID = asset.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(asset.name)
                                            .font(.headline)
                                        Text("\(asset.category) · \(asset.locationName)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedAssetID == asset.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(BrandColor.green)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        if filteredAssets.count > 80 {
                            Text("Refina la búsqueda para ver los demás equipos.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Mantenimiento del equipo") {
                    Picker("Mantenimiento", selection: $selectedTemplateID) {
                        Text("Seleccionar").tag(UUID?.none)
                        ForEach(filteredTemplates) { template in
                            Text(template.name).tag(Optional(template.id))
                        }
                    }
                    Picker("Mes inicial", selection: $month) {
                        ForEach(1...12, id: \.self) { value in
                            Text(PCONPlanningView.monthName(value)).tag(value)
                        }
                    }
                    Stepper(value: $quantity, in: 1...366) {
                        LabeledContent("Cantidad", value: String(quantity))
                    }
                    TextField("Motivo o referencia", text: $reason, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Agregar mantenimiento · \(year)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        guard let selectedAssetID, let selectedTemplateID else { return }
                        Task {
                            isSaving = true
                            if await onSave(
                                selectedAssetID,
                                selectedTemplateID,
                                month,
                                quantity,
                                reason
                            ) {
                                dismiss()
                            }
                            isSaving = false
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Agregar")
                        }
                    }
                    .disabled(
                        isSaving || selectedAssetID == nil || selectedTemplateID == nil
                    )
                }
            }
        }
        .presentationDetents([.large])
        .onChange(of: subsystem) {
            selectedAssetID = nil
            selectedTemplateID = nil
            assetQuery = ""
        }
    }
}

private struct ScheduleProposalSheet: View {
    @Environment(\.dismiss) private var dismiss

    let item: PCONPlanItem
    let weekStart: Date
    let onSave: (Date, Date, String) async -> Bool

    @State private var start: Date
    @State private var end: Date
    @State private var includesTime: Bool
    @State private var reason = ""
    @State private var isSaving = false

    init(
        item: PCONPlanItem,
        weekStart: Date,
        onSave: @escaping (Date, Date, String) async -> Bool
    ) {
        self.item = item
        self.weekStart = weekStart
        self.onSave = onSave
        let calendar = Calendar(identifier: .iso8601)
        let weekEnd = calendar.date(
            byAdding: DateComponents(day: 6, hour: 23, minute: 59),
            to: weekStart
        ) ?? weekStart
        let existingStart = item.proposedStartAt ?? item.scheduledStartAt
        let startInsideWeek = existingStart.flatMap {
            weekStart...weekEnd ~= $0 ? $0 : nil
        }
        let defaultStart = startInsideWeek
            ?? calendar.date(byAdding: .hour, value: 8, to: weekStart)
            ?? weekStart
        let duration = max(item.estimatedMinutes ?? 60, 15)
        let existingEnd = item.proposedEndAt ?? item.scheduledEndAt
        let endInsideWeek = existingEnd.flatMap {
            defaultStart...weekEnd ~= $0 ? $0 : nil
        }
        _start = State(initialValue: defaultStart)
        _end = State(
            initialValue: endInsideWeek
                ?? calendar.date(byAdding: .minute, value: duration, to: defaultStart)
                ?? defaultStart
        )
        _includesTime = State(initialValue: existingStart != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Actividad") {
                    LabeledContent("Mantenimiento", value: item.maintenanceName)
                    LabeledContent("Equipo", value: item.equipmentName)
                    LabeledContent(
                        "Ubicación",
                        value: item.locationName.activityLocationSummary
                    )
                }
                Section("Fecha tentativa") {
                    DatePicker(
                        "Día",
                        selection: $start,
                        in: weekStart...weekEnd,
                        displayedComponents: [.date]
                    )
                    Toggle("Agregar rango horario", isOn: $includesTime)
                    if includesTime {
                        DatePicker(
                            "Hora inicial",
                            selection: $start,
                            displayedComponents: [.hourAndMinute]
                        )
                        DatePicker(
                            "Hora final",
                            selection: $end,
                            displayedComponents: [.hourAndMinute]
                        )
                    } else {
                        Text("La actividad quedará disponible durante la jornada y podrá acomodarse en la programación semanal.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if item.scheduledStartAt != nil {
                    Section("Motivo de reprogramación") {
                        TextField("Motivo obligatorio", text: $reason, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
            }
            .navigationTitle(item.scheduledStartAt == nil ? "Programar actividad" : "Reprogramar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isSaving = true
                            if await onSave(effectiveStart, effectiveEnd, reason) {
                                dismiss()
                            }
                            isSaving = false
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Guardar propuesta")
                        }
                    }
                    .disabled(
                        isSaving
                            || effectiveEnd <= effectiveStart
                            || (item.scheduledStartAt != nil
                                && reason.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ).isEmpty)
                    )
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var weekEnd: Date {
        Calendar(identifier: .iso8601).date(
            byAdding: DateComponents(day: 6, hour: 23, minute: 59),
            to: weekStart
        ) ?? weekStart
    }

    private var effectiveStart: Date {
        guard !includesTime else { return start }
        return Calendar(identifier: .iso8601).date(
            bySettingHour: 8,
            minute: 0,
            second: 0,
            of: start
        ) ?? start
    }

    private var effectiveEnd: Date {
        guard !includesTime else { return end }
        return Calendar(identifier: .iso8601).date(
            bySettingHour: 17,
            minute: 0,
            second: 0,
            of: start
        ) ?? start.addingTimeInterval(9 * 3600)
    }
}

private enum PlanningHistorySection: String, CaseIterable, Identifiable {
    case annual = "Plan anual"
    case weekly = "Programación semanal"

    var id: String { rawValue }
}

private struct PlanningHistorySheet: View {
    @Environment(\.dismiss) private var dismiss

    let weeklyHistory: [PCONHistoryItem]
    let annualChanges: [PCONPlanChange]
    let year: Int
    let isLoading: Bool
    @State private var section = PlanningHistorySection.annual

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Tipo de historial", selection: $section) {
                    ForEach(PlanningHistorySection.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if isLoading && weeklyHistory.isEmpty && annualChanges.isEmpty {
                    ProgressView("Cargando historial...")
                } else {
                    switch section {
                    case .annual:
                        annualHistory
                    case .weekly:
                        weeklyHistoryList
                    }
                }
            }
            .navigationTitle("Historial PCON")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var annualHistory: some View {
        if annualChanges.isEmpty {
            ContentUnavailableView(
                "Sin cambios en \(year)",
                systemImage: "calendar.badge.clock"
            )
        } else {
            List(annualChanges) { item in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(annualActionLabel(item.action))
                            .font(.headline)
                        Spacer()
                        Text(item.changedAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let maintenance = item.maintenanceName {
                        Text(maintenance)
                            .font(.subheadline.weight(.semibold))
                    }
                    if let equipment = item.equipmentName {
                        Text(equipment)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        if let month = item.month {
                            Label(
                                PCONPlanningView.monthName(month),
                                systemImage: "calendar"
                            )
                        }
                        if let delta = item.quantityDelta {
                            Text(delta > 0 ? "+\(delta)" : String(delta))
                                .font(.caption.bold())
                                .foregroundStyle(delta >= 0 ? BrandColor.green : BrandColor.red)
                        }
                    }
                    .font(.caption)
                    if let reason = item.reason, !reason.isEmpty {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(item.changedByName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var weeklyHistoryList: some View {
        if weeklyHistory.isEmpty {
            ContentUnavailableView(
                "Aún no hay confirmaciones",
                systemImage: "clock.arrow.circlepath"
            )
        } else {
            List(weeklyHistory) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(item.activityTitle)
                                    .font(.headline)
                                Spacer()
                                Text(item.status == "CONFIRMED" ? "Vigente" : "Reemplazado")
                                    .font(.caption.bold())
                                    .foregroundStyle(
                                        item.status == "CONFIRMED"
                                            ? BrandColor.green
                                            : .secondary
                                    )
                            }
                            Text(item.equipmentName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Label(
                                PCONPlanningView.dateTimeFormatter.string(
                                    from: item.proposedStartAt
                                ),
                                systemImage: "calendar.badge.checkmark"
                            )
                            .font(.subheadline.weight(.semibold))
                            if let previous = item.previousStartAt {
                                Text(
                                    "Antes: \(PCONPlanningView.dateTimeFormatter.string(from: previous))"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Text(
                                "Semana \(item.weekStart) · v\(item.sessionVersion)"
                                    + (item.confirmedByName.map { " · \($0)" } ?? "")
                            )
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
        }
    }

    private func annualActionLabel(_ action: String) -> String {
        switch action {
        case "COPY_YEAR": "Plan copiado"
        case "ADD_PLAN_SCOPE": "Mantenimiento agregado"
        case "CREATE_OCCURRENCES": "Ejecuciones creadas"
        case "MOVE_OCCURRENCE": "Ejecución movida"
        case "REMOVE_OCCURRENCE": "Ejecución eliminada"
        case "CANCEL_OCCURRENCE": "Ejecución cancelada"
        case "SET_COUNT": "Cantidad modificada"
        default: action.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
