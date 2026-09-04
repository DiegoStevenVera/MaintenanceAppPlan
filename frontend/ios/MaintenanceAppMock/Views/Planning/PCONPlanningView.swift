import SwiftUI

private enum PCONSection: String, CaseIterable, Identifiable {
    case annual = "Plan anual"
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
        case .proposed: "Propuesto"
        case .confirmed: "Confirmado"
        case .reschedulePending: "Reprogramación pendiente"
        case .executed: "Ejecutado"
        }
    }

    var color: Color {
        switch self {
        case .monthOnly: BrandColor.red
        case .proposed: BrandColor.amber
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
            return monthOnlyCount > 0 ? BrandColor.red : BrandColor.amber
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

struct PCONPlanningView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var section = PCONSection.annual
    @State private var selectedYear: Int
    @State private var weekStart: Date
    @State private var query = ""
    @State private var annualPlan: PCONAnnualPlan?
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

    private let calendar = Calendar(identifier: .iso8601)
    private let descriptorWidth: CGFloat = 390
    private let monthWidth: CGFloat = 62
    private let totalWidth: CGFloat = 76

    init() {
        let now = Date()
        let calendar = Calendar(identifier: .iso8601)
        _selectedYear = State(initialValue: calendar.component(.year, from: now))
        _weekStart = State(initialValue: Self.startOfWeek(now))
    }

    private var canEdit: Bool {
        session.currentUser?.role.canEditPlanning == true
    }

    var body: some View {
        ZStack {
            MaintenanceScreenBackground()
            VStack(spacing: 0) {
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
                case .weekly:
                    weeklyContent
                }
            }
        }
        .navigationTitle("PCON")
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
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Buscar subsistema, ubicación, equipo o mantenimiento"
        )
        .onSubmit(of: .search) {
            Task { await loadCurrentSection() }
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
        VStack(spacing: AppSpacing.md) {
            annualToolbar
            annualLegend
            if isLoading && annualPlan == nil {
                Spacer()
                ProgressView("Cargando planificación anual...")
                Spacer()
            } else if let plan = annualPlan, !plan.rows.isEmpty {
                annualMatrix(plan)
            } else {
                Spacer()
                ContentUnavailableView(
                    "Sin planificación",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("No hay mantenimientos para el año y búsqueda elegidos.")
                )
                Spacer()
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, AppSpacing.md)
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

    private var annualLegend: some View {
        GlassPanel {
            HStack(spacing: AppSpacing.lg) {
                Text("Estado de la cantidad")
                    .font(.subheadline.bold())
                legendNumber("1", label: "Solo mes", color: BrandColor.red)
                legendNumber("1", label: "Propuesto", color: BrandColor.amber)
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
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(spacing: 1, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(visibleHierarchyRows(plan.rows)) { hierarchy in
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

    private var weeklyContent: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.md) {
                weekPicker
                weeklySummary

                if let detail = weekDetail, !detail.proposals.isEmpty {
                    proposalPanel(detail)
                }

                SectionHeaderText(
                    title: "Pendientes del plan mensual",
                    subtitle: "Cada fila es una ejecución que puede recibir fecha y rango horario"
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                if isLoading && weeklyItems.isEmpty {
                    ProgressView("Cargando actividades...")
                        .padding(.top, 40)
                } else if availableWeeklyItems.isEmpty {
                    ContentUnavailableView(
                        "Sin actividades pendientes",
                        systemImage: "calendar.badge.checkmark",
                        description: Text("No hay ocurrencias sin programar para este periodo.")
                    )
                } else {
                    weeklyHierarchy
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .refreshable { await loadWeekly() }
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

    private var availableWeeklyItems: [PCONPlanItem] {
        weeklyItems.filter {
            $0.activityStatus == "SCHEDULED"
                && $0.planningState != .executed
        }
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
        case .weekly:
            await loadWeekly()
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
            let center = calendar.date(byAdding: .day, value: 3, to: weekStart) ?? weekStart
            let year = calendar.component(.year, from: center)
            let month = calendar.component(.month, from: center)
            weeklyItems = try await withService { service, token in
                try await service.plan(year: year, month: month, query: query, token: token).items
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
            let detail = try await withService { service, token in
                let current = if let weekDetail, weekDetail.session.status == "DRAFT" {
                    weekDetail
                } else {
                    try await service.createWeek(Self.apiDate(weekStart), token: token)
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
            weekDetail = detail
            await loadWeekly()
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

    private static let weekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateFormat = "d 'de' MMMM 'de' yyyy"
        return formatter
    }()
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
                if let date = item.scheduledStartAt {
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
                Section("Fecha y rango horario") {
                    DatePicker(
                        "Inicio",
                        selection: $start,
                        in: weekStart...weekEnd,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    DatePicker(
                        "Fin",
                        selection: $end,
                        in: start...weekEnd,
                        displayedComponents: [.date, .hourAndMinute]
                    )
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
                            if await onSave(start, end, reason) {
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
                            || end <= start
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
