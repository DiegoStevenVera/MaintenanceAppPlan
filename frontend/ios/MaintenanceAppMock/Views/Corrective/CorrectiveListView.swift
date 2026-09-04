import SwiftUI
struct DatabaseCorrectiveListView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var activityStore: MaintenanceActivityStore
    @EnvironmentObject private var assetStore: AssetStore
    @EnvironmentObject private var offlineStore: OfflineReportStore
    @State private var isCreatingEvent = false
    @State private var selectedFilter: MaintenanceDateFilter?
    @State private var searchText = ""
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedStatus = "Todos"
    @State private var selectedSubsystem = "Todos"
    @State private var selectedEquipment = "Todos"
    @State private var isSelectingOfflineWork = false
    @State private var selectedOfflineIDs: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                GlassPanel {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "waveform.path.ecg.rectangle")
                            .font(.title)
                            .foregroundStyle(BrandColor.red)
                            .frame(width: 56, height: 56)
                            .background(BrandColor.red.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Eventos correctivos").font(.title2.weight(.bold))
                            Text("Lectura de eventos normalizados y su estado actual")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }

                filterPanel
                if isSelectingOfflineWork {
                    OfflinePackageBatchPanel(
                        selectedCount: selectedOfflineIDs.count,
                        onCancel: { selectedOfflineIDs = []; isSelectingOfflineWork = false },
                        onDownload: { Task { await downloadSelected() } }
                    )
                }
                section("Abiertos", statuses: ["SCHEDULED"])
                section("En progreso", statuses: ["IN_PROGRESS"])
                section("Completados", statuses: ["COMPLETED"])
                section("Cerrados", statuses: ["CLOSED"])

                if !isOfflineMode, let error = activityStore.correctiveError {
                    ContentUnavailableView {
                        Label("No se pudieron cargar los correctivos", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Reintentar") { Task { await load() } }
                    }
                } else if !isOfflineMode && activityStore.isLoadingCorrectives && filteredActivities.isEmpty {
                    ProgressView("Cargando correctivos")
                        .frame(maxWidth: .infinity)
                        .padding(AppSpacing.xl)
                } else if filteredActivities.isEmpty {
                    GlassPanel {
                        Text(isOfflineMode
                            ? "No hay correctivos descargados en este iPad."
                            : "No hay correctivos para este filtro.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Correctivos")
        .toolbar {
            Button {
                isSelectingOfflineWork.toggle()
                if !isSelectingOfflineWork { selectedOfflineIDs = [] }
            } label: {
                Label(
                    isSelectingOfflineWork ? "Cancelar selección" : "Descargar offline",
                    systemImage: isSelectingOfflineWork ? "xmark.circle" : "arrow.down.circle"
                )
            }
            if session.currentUser?.role.canEditMaintenance == true {
                Button {
                    isCreatingEvent = true
                } label: {
                    Label("Crear correctivo", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isCreatingEvent) {
            NavigationStack {
                DatabaseCorrectiveEventCreateView {
                    isCreatingEvent = false
                    Task { await load() }
                }
                .environmentObject(session)
                .environmentObject(assetStore)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .refreshable { await load() }
        .task(id: "\(selectedFilter?.id ?? "all")-\(selectedMonth)-\(selectedYear)-\(searchText)") {
            if !searchText.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    private var filterPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Filtros", subtitle: "Opcional segun fecha de creacion de aviso")
                ActionButtonGrid {
                    ForEach(MaintenanceDateFilter.allCases) { filter in
                        Button {
                            selectedFilter = selectedFilter == filter ? nil : filter
                        } label: {
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
                ActionButtonGrid {
                    Menu {
                        Picker("Estado", selection: $selectedStatus) {
                        ForEach(["Todos", "SCHEDULED", "IN_PROGRESS", "COMPLETED", "CLOSED"], id: \.self) { value in
                            Text(statusLabel(value)).tag(value)
                        }
                    }
                    } label: {
                        Label("Estado: \(statusLabel(selectedStatus))", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .buttonStyle(ActionTileButtonStyle(prominent: selectedStatus != "Todos"))
                    Menu {
                        Picker("Subsistema", selection: $selectedSubsystem) {
                        ForEach(subsystemOptions, id: \.self) { Text($0).tag($0) }
                    }
                    } label: {
                        Label("Subsistema: \(selectedSubsystem)", systemImage: "square.stack.3d.up")
                    }
                    .buttonStyle(ActionTileButtonStyle(prominent: selectedSubsystem != "Todos"))
                    Menu {
                        Picker("Equipo", selection: $selectedEquipment) {
                        ForEach(equipmentOptions, id: \.self) { Text($0).tag($0) }
                    }
                    } label: {
                        Label("Equipo: \(selectedEquipment)", systemImage: "shippingbox")
                    }
                    .buttonStyle(ActionTileButtonStyle(prominent: selectedEquipment != "Todos"))
                }
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Buscar por nombre, SAP o equipo", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(AppSpacing.md)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, statuses: [String]) -> some View {
        let activities = filteredActivities.filter { statuses.contains($0.status) }
        if !activities.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: title, subtitle: "\(activities.count) evento(s)")
                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(activities) { activity in
                        if isSelectingOfflineWork {
                            Button { toggleOfflineSelection(activity.id) } label: {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: selectedOfflineIDs.contains(activity.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(selectedOfflineIDs.contains(activity.id) ? BrandColor.red : .secondary)
                                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                        CorrectiveAPIActivityCard(activity: activity)
                                        OfflineActivityDownloadMetadata(activity: activity)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink { CorrectiveDetailView(eventID: activity.id) } label: {
                                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                    CorrectiveAPIActivityCard(activity: activity)
                                    OfflineActivityDownloadMetadata(activity: activity)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var isOfflineMode: Bool { !offlineStore.isNetworkAvailable }

    private var activitySource: [APIActivity] {
        if isOfflineMode {
            return offlineStore.workPackagesByActivity.values
                .map { APIActivity(detail: $0.activityDetail) }
                .filter { $0.activityType == "CORRECTIVE" }
                .sorted { ($0.scheduledAt ?? .distantFuture) < ($1.scheduledAt ?? .distantFuture) }
        }
        return activityStore.correctiveActivities.map(offlineStore.displayActivity)
    }

    private func load() async {
        guard !isOfflineMode else { return }
        let range = dateRange
        await activityStore.load(
            type: "CORRECTIVE",
            query: searchText.trimmingCharacters(in: .whitespacesAndNewlines),
            dateFrom: range?.lowerBound,
            dateTo: range?.upperBound,
            session: session
        )
    }

    private var filteredActivities: [APIActivity] {
        guard !isOfflineMode else { return activitySource }
        return activitySource.filter { activity in
            (selectedStatus == "Todos" || activity.status == selectedStatus)
                && (selectedSubsystem == "Todos" || activity.subsystem == selectedSubsystem)
                && (selectedEquipment == "Todos" || activity.assets.contains { $0.name == selectedEquipment })
        }
    }

    private var subsystemOptions: [String] {
        ["Todos"] + Array(Set(activitySource.map(\.subsystem))).sorted()
    }

    private var equipmentOptions: [String] {
        ["Todos"] + Array(Set(activitySource.flatMap { $0.assets.map(\.name) })).sorted()
    }

    private func toggleOfflineSelection(_ id: String) {
        if selectedOfflineIDs.contains(id) { selectedOfflineIDs.remove(id) }
        else { selectedOfflineIDs.insert(id) }
    }

    private func downloadSelected() async {
        let activities = filteredActivities.filter { selectedOfflineIDs.contains($0.id) }
        await offlineStore.downloadWorkPackages(activities: activities, session: session, activityStore: activityStore)
        if offlineStore.lastDownloadFailedTitles.isEmpty { selectedOfflineIDs = [] }
    }

    private func statusLabel(_ value: String) -> String {
        switch value {
        case "SCHEDULED": return "Programado"
        case "IN_PROGRESS": return "En progreso"
        case "COMPLETED": return "Completado"
        case "CLOSED": return "Cerrado"
        default: return "Todos"
        }
    }

    private var dateRange: Range<Date>? {
        guard let selectedFilter else { return nil }
        let calendar = Calendar.current
        let now = Date()
        switch selectedFilter {
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

struct CorrectiveCreationContext: Codable {
    let businessAnchorAssetID: String
    let site: String
    let project: String
    let stage: String?
    let system: String
    let subsystem: String
    let physicalLocation: String

    enum CodingKeys: String, CodingKey {
        case site, project, stage, system, subsystem
        case businessAnchorAssetID = "business_anchor_asset_id"
        case physicalLocation = "physical_location"
    }
}

struct CorrectiveLocationOption: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let level: Int
    let parentLocationID: String?

    enum CodingKeys: String, CodingKey {
        case id, name, level
        case parentLocationID = "parent_location_id"
    }
}

struct CorrectiveCreateRequest: Codable {
    let sapEventName: String
    let sapNotification: String
    let businessAnchorAssetID: String?
    let affectedAssetID: String?
    let affectedAssetPath: String
    let affectedAssets: [CorrectiveAffectedAssetWrite]
    let correctiveEquipmentGroupID: String?
    let subsystem: String
    let severity: String
    let isCritical: Bool
    let noticeCreatedAt: Date
    let responseAt: Date
    let physicalLocation: String

    enum CodingKeys: String, CodingKey {
        case subsystem, severity
        case isCritical = "is_critical"
        case sapEventName = "sap_event_name"
        case sapNotification = "sap_notification"
        case businessAnchorAssetID = "business_anchor_asset_id"
        case affectedAssetID = "affected_asset_id"
        case affectedAssetPath = "affected_asset_path"
        case affectedAssets = "affected_assets"
        case correctiveEquipmentGroupID = "corrective_equipment_group_id"
        case noticeCreatedAt = "notice_created_at"
        case responseAt = "response_at"
        case physicalLocation = "physical_location"
    }
}

struct CorrectiveAffectedAssetWrite: Codable {
    let assetID: String
    let isCritical: Bool

    enum CodingKeys: String, CodingKey {
        case assetID = "asset_id"
        case isCritical = "is_critical"
    }
}

struct CorrectiveTargetMember: Codable, Identifiable {
    let id: String
    let name: String
}

struct CorrectiveTarget: Codable, Identifiable {
    let id: String
    let name: String
    let subsystem: String
    let kind: String
    let memberCount: Int
    let members: [CorrectiveTargetMember]

    enum CodingKeys: String, CodingKey {
        case id, name, subsystem, kind, members
        case memberCount = "member_count"
    }

    var roots: [CorrectiveTargetMember] {
        kind == "GROUP" ? members : [CorrectiveTargetMember(id: id, name: name)]
    }
}

struct CorrectiveCreateResult: Codable {
    let id: String
    let code: String
    let status: String
}

struct CorrectiveCreationAPIService {
    private let client: APIClient

    init(baseURLString: String) {
        client = APIClient(baseURLString: baseURLString)
    }

    func context(
        equipmentID: String,
        accessToken: String
    ) async throws -> CorrectiveCreationContext {
        try await client.get(
            "api/v1/corrective-events/creation-context",
            bearerToken: accessToken,
            queryItems: [
                URLQueryItem(
                    name: "business_anchor_asset_id",
                    value: equipmentID
                )
            ]
        )
    }

    func targets(subsystem: String, accessToken: String) async throws -> [CorrectiveTarget] {
        try await client.get(
            "api/v1/corrective-targets",
            bearerToken: accessToken,
            queryItems: [URLQueryItem(name: "subsystem", value: subsystem)]
        )
    }

    func locationOptions(accessToken: String) async throws -> [CorrectiveLocationOption] {
        try await client.get(
            "api/v1/corrective-location-options",
            bearerToken: accessToken
        )
    }

    func create(
        request: CorrectiveCreateRequest,
        accessToken: String
    ) async throws -> CorrectiveCreateResult {
        try await client.post(
            "api/v1/corrective-events",
            body: request,
            bearerToken: accessToken
        )
    }
}

private struct DatabaseCorrectiveEventCreateView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var assetStore: AssetStore
    @EnvironmentObject private var offlineStore: OfflineReportStore
    @Environment(\.dismiss) private var dismiss

    let onCreated: () -> Void

    @State private var selectedSubsystem = "ATS"
    @State private var equipmentSearchText = ""
    @State private var targets: [CorrectiveTarget] = []
    @State private var isLoadingTargets = false
    @State private var selectedTargetID: String?
    @State private var selectedAssetIDs: Set<String> = []
    @State private var criticalAssetIDs: Set<String> = []
    @State private var context: CorrectiveCreationContext?
    @State private var sapEventName = ""
    @State private var sapNotification = ""
    @State private var severity: Severity = .medium
    @State private var isCritical = false
    @State private var noticeCreatedAt = Date()
    @State private var responseAt = Date()
    @State private var isCreating = false
    @State private var creationError: String?
    @State private var offlineTrees: [String: [EquipmentTreeNodeDTO]] = [:]
    @State private var creationStep = 0
    @State private var locationOptions: [CorrectiveLocationOption] = []
    @State private var selectedLocationLevelOneID = ""
    @State private var selectedLocationLevelTwoID = ""

    private let subsystemOptions = ["ATS", "CBTC", "IXL"]

    private var filteredTargets: [CorrectiveTarget] {
        let query = equipmentSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return targets }
        return targets.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.members.contains { $0.name.localizedCaseInsensitiveContains(query) }
        }
    }

    private var selectedTarget: CorrectiveTarget? {
        targets.first { $0.id == selectedTargetID }
    }

    private var selectedAssetPath: String {
        let names = selectedAssets.map(\.name).sorted()
        return names.isEmpty ? "Asset no seleccionado" : names.joined(separator: ", ")
    }

    private var selectedAssets: [EquipmentTreeNodeDTO] {
        let nodes = selectedTarget?.roots.flatMap { root in
            offlineTrees[root.id] ?? assetStore.trees[root.id] ?? []
        } ?? []
        let selectedNodes = nodes.filter { selectedAssetIDs.contains($0.id) }
        let roots = selectedTarget?.roots
            .filter { selectedAssetIDs.contains($0.id) }
            .map {
                EquipmentTreeNodeDTO(
                    id: $0.id,
                    name: $0.name,
                    category: "Equipo",
                    assetType: "Equipo",
                    status: "ACTIVE",
                    serialNumber: nil,
                    partNumber: nil,
                    model: nil,
                    manufacturer: nil,
                    parentID: nil,
                    depth: 0,
                    slotPath: nil,
                    position: nil
                )
            } ?? []
        return selectedNodes + roots.filter { root in
            !selectedNodes.contains { $0.id == root.id }
        }
    }

    private var canCreate: Bool {
        selectedTarget != nil
            && !selectedAssetIDs.isEmpty
            && context != nil
            && !sapEventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !sapNotification.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!allowsVariableEventLocation || !selectedLocationLevelTwoID.isEmpty)
            && !isCreating
    }

    private var canContinue: Bool {
        selectedTarget != nil && !selectedAssetIDs.isEmpty && context != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                header
                creationProgress
                if creationStep == 0 {
                    assetSelector
                    ActionButtonGrid {
                        Button { creationStep = 1 } label: {
                            Label("Continuar con datos del evento", systemImage: "arrow.right.circle.fill")
                        }
                        .buttonStyle(ActionTileButtonStyle(prominent: true))
                        .disabled(!canContinue)
                    }
                } else {
                    contextPanel
                    sapPanel
                    ActionButtonGrid {
                        Button { creationStep = 0 } label: {
                            Label("Volver al equipo", systemImage: "arrow.left.circle")
                        }
                        .buttonStyle(ActionTileButtonStyle())
                        Button {
                            Task { await createCorrective() }
                        } label: {
                            if isCreating {
                                ProgressView()
                            } else {
                                Label("Crear Correctivo", systemImage: "plus.circle.fill")
                            }
                        }
                        .buttonStyle(ActionTileButtonStyle(prominent: true))
                        .disabled(!canCreate)
                    }
                }

                if let creationError {
                    Label(creationError, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(BrandColor.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Nuevo correctivo")
        .toolbar {
            Button("Cerrar") { dismiss() }
        }
        .task(id: selectedSubsystem) {
            await loadTargets()
        }
        .task {
            await loadLocationOptions()
        }
        .task(id: selectedTargetID) {
            guard let selectedTarget else {
                context = nil
                selectedAssetIDs = []
                criticalAssetIDs = []
                return
            }
            selectedAssetIDs = []
            criticalAssetIDs = []
            let roots = selectedTarget.roots
            creationStep = 0
            offlineTrees = [:]
            if !offlineStore.isNetworkAvailable,
               let catalog = offlineStore.correctiveCatalog {
                offlineTrees = Dictionary(uniqueKeysWithValues: roots.map {
                    ($0.id, catalog.trees[$0.id] ?? [])
                })
                context = roots.lazy.compactMap { catalog.contexts[$0.id] }.first
                configureEventLocation()
                return
            }
            for root in roots {
                await assetStore.loadTree(id: root.id, session: session, force: true)
            }
            await loadContext(equipmentID: roots.first?.id ?? "")
        }
        .onChange(of: selectedSubsystem) { _, _ in
            equipmentSearchText = ""
            selectedTargetID = nil
            selectedAssetIDs = []
            criticalAssetIDs = []
            context = nil
            offlineTrees = [:]
            creationStep = 0
            selectedLocationLevelOneID = ""
            selectedLocationLevelTwoID = ""
        }
        .onChange(of: locationOptions) { _, _ in configureEventLocation() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Correctivo")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(BrandColor.red)
            Text("Crear evento correctivo")
                .font(.system(.largeTitle, design: .rounded).weight(.black))
            Text("Selecciona el equipo y baja por su arbol hasta el asset afectado.")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var creationProgress: some View {
        HStack(spacing: AppSpacing.sm) {
            Label("1. Equipo afectado", systemImage: creationStep == 0 ? "1.circle.fill" : "1.circle")
                .foregroundStyle(creationStep == 0 ? BrandColor.red : .secondary)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            Label("2. Datos del evento", systemImage: creationStep == 1 ? "2.circle.fill" : "2.circle")
                .foregroundStyle(creationStep == 1 ? BrandColor.red : .secondary)
        }
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var assetSelector: some View {
        ContentGlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Equipo afectado",
                    subtitle: "Seleccion desde el equipo hasta el componente"
                )

                Picker("Subsistema", selection: $selectedSubsystem) {
                    ForEach(subsystemOptions, id: \.self) { subsystem in
                        Text(subsystem).tag(subsystem)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Buscar equipo", text: $equipmentSearchText)
                    .textFieldStyle(.roundedBorder)

                if isLoadingTargets {
                    ProgressView("Cargando equipos")
                        .frame(maxWidth: .infinity)
                } else if let error = creationError, selectedTargetID == nil {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if filteredTargets.isEmpty {
                    Text("No hay equipos para este filtro.")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: AppSpacing.xs) {
                            ForEach(filteredTargets) { target in
                                Button {
                                    selectedTargetID = target.id
                                } label: {
                                    HStack(spacing: AppSpacing.sm) {
                                        Image(
                                            systemName: selectedTargetID == target.id
                                                ? "checkmark.circle.fill"
                                                : "circle"
                                        )
                                        .foregroundStyle(
                                            selectedTargetID == target.id
                                                ? BrandColor.red
                                                : .secondary
                                        )
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(target.name)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Text(
                                                target.kind == "GROUP"
                                                    ? "Grupo lógico · \(target.memberCount) equipos"
                                                    : "Equipo"
                                            )
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, AppSpacing.xs)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 240)
                }

                if let selectedTarget {
                    ForEach(selectedTarget.roots) { root in
                        CorrectiveMultiAssetTreePicker(
                            root: root,
                            nodes: offlineTrees[root.id] ?? assetStore.trees[root.id] ?? [],
                            selectedAssetIDs: $selectedAssetIDs,
                            criticalAssetIDs: $criticalAssetIDs
                        )
                    }
                    DetailTile(
                        title: "Assets seleccionados",
                        value: selectedAssetPath
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var contextPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Datos del contexto",
                    subtitle: "Valores obtenidos del equipo"
                )
                if let context {
                    DetailTile(title: "Sede", value: context.site)
                    DetailTile(title: "Proyecto", value: context.project)
                    DetailTile(
                        title: "Etapa",
                        value: context.stage ?? "No registrada"
                    )
                    DetailTile(title: "Sistema", value: context.system)
                    DetailTile(title: "Subsistema", value: context.subsystem)
                    DetailTile(
                        title: "Ubicación registrada del equipo",
                        value: context.physicalLocation
                    )
                    eventLocationFields
                } else if selectedTarget != nil {
                    ProgressView("Cargando contexto")
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Selecciona un equipo para cargar su contexto.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var sapPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Datos SAP y tiempos")
                TextField("Nombre del evento SAP", text: $sapEventName)
                    .textFieldStyle(.roundedBorder)
                TextField("Notificacion SAP", text: $sapNotification)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                Picker("Severidad", selection: $severity) {
                    ForEach(Severity.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Elemento crítico", isOn: $isCritical)
                DatePicker(
                    "Fecha y hora de creacion de aviso",
                    selection: $noticeCreatedAt,
                    displayedComponents: [.date, .hourAndMinute]
                )
                DetailTile(
                    title: "Fecha y hora de respuesta",
                    value: Self.dateTimeFormatter.string(from: responseAt)
                )
            }
        }
    }

    @ViewBuilder
    private var eventLocationFields: some View {
        let firstLevel = levelOneOptions
        let secondLevel = levelTwoOptions
        Text("Ubicación del evento")
            .font(.headline)
            .padding(.top, AppSpacing.sm)
        Text(
            allowsVariableEventLocation
                ? "Selecciona dónde ocurrió el evento."
                : "Ubicación fija según el equipo seleccionado."
        )
            .font(.caption)
            .foregroundStyle(.secondary)

        if firstLevel.isEmpty {
            DetailTile(title: "Nivel 1", value: locationLevelsFromContext.first ?? "No registrada")
            DetailTile(title: "Nivel 2", value: locationLevelsFromContext.dropFirst().first ?? "No registrada")
        } else {
            Picker("Tipo de ubicación", selection: $selectedLocationLevelOneID) {
                Text("Seleccionar").tag("")
                ForEach(firstLevel) { location in
                    Text(location.name).tag(location.id)
                }
            }
            .pickerStyle(.menu)
            .disabled(!allowsVariableEventLocation)
            .onChange(of: selectedLocationLevelOneID) { _, _ in
                if allowsVariableEventLocation {
                    selectedLocationLevelTwoID = ""
                }
            }

            Picker("Ubicación", selection: $selectedLocationLevelTwoID) {
                Text("Seleccionar").tag("")
                ForEach(secondLevel) { location in
                    Text(location.name).tag(location.id)
                }
            }
            .pickerStyle(.menu)
            .disabled(!allowsVariableEventLocation || selectedLocationLevelOneID.isEmpty)
        }
    }

    @MainActor
    private func loadContext(equipmentID: String) async {
        if !offlineStore.isNetworkAvailable,
           let context = offlineStore.correctiveCatalog?.contexts[equipmentID] {
            self.context = context
            responseAt = Date()
            configureEventLocation()
            return
        }
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else {
            creationError = "No se encontro la URL de la API."
            return
        }
        creationError = nil
        do {
            context = try await session.withValidAccessToken { token in
                try await CorrectiveCreationAPIService(
                    baseURLString: baseURL
                ).context(
                    equipmentID: equipmentID,
                    accessToken: token
                )
            }
            responseAt = Date()
            configureEventLocation()
        } catch {
            context = nil
            creationError = error.localizedDescription
        }
    }

    @MainActor
    private func loadTargets() async {
        if !offlineStore.isNetworkAvailable,
           let catalog = offlineStore.correctiveCatalog {
            targets = catalog.targets.filter { $0.subsystem == selectedSubsystem }
            creationError = nil
            return
        }
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else {
            creationError = "No se encontro la URL de la API."
            return
        }
        isLoadingTargets = true
        creationError = nil
        defer { isLoadingTargets = false }
        do {
            targets = try await session.withValidAccessToken { token in
                try await CorrectiveCreationAPIService(baseURLString: baseURL).targets(
                    subsystem: selectedSubsystem,
                    accessToken: token
                )
            }
        } catch {
            targets = []
            creationError = error.localizedDescription
        }
    }

    @MainActor
    private func loadLocationOptions() async {
        if !offlineStore.isNetworkAvailable {
            locationOptions = offlineStore.correctiveCatalog?.locationOptions ?? []
            return
        }
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else { return }
        do {
            locationOptions = try await session.withValidAccessToken { token in
                try await CorrectiveCreationAPIService(baseURLString: baseURL).locationOptions(
                    accessToken: token
                )
            }
        } catch {
            // The fixed equipment context remains sufficient when the location catalog is unavailable.
            locationOptions = []
        }
    }

    @MainActor
    private func createCorrective() async {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL"),
              let selectedTarget,
              let context else {
            return
        }

        let request = CorrectiveCreateRequest(
            sapEventName: sapEventName.trimmingCharacters(in: .whitespacesAndNewlines),
            sapNotification: sapNotification.trimmingCharacters(in: .whitespacesAndNewlines),
            businessAnchorAssetID: selectedTarget.roots.first?.id,
            affectedAssetID: selectedAssetIDs.first,
            affectedAssetPath: selectedAssetPath,
            affectedAssets: selectedAssetIDs.sorted().map {
                CorrectiveAffectedAssetWrite(assetID: $0, isCritical: criticalAssetIDs.contains($0))
            },
            correctiveEquipmentGroupID: selectedTarget.kind == "GROUP" ? selectedTarget.id : nil,
            subsystem: context.subsystem, severity: severity.rawValue.uppercased(),
            isCritical: isCritical, noticeCreatedAt: noticeCreatedAt,
            responseAt: Date(), physicalLocation: eventPhysicalLocation
        )
        if !offlineStore.isNetworkAvailable {
            await offlineStore.queueCorrective(request: request)
            onCreated()
            dismiss()
            return
        }

        isCreating = true
        creationError = nil
        defer { isCreating = false }
        do {
            responseAt = request.responseAt
            _ = try await session.withValidAccessToken { token in
                try await CorrectiveCreationAPIService(
                    baseURLString: baseURL
                ).create(
                    request: request,
                    accessToken: token
                )
            }
            onCreated()
            dismiss()
        } catch {
            creationError = error.localizedDescription
        }
    }

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es_PE")
        return formatter
    }()

    private var allowsVariableEventLocation: Bool {
        guard let selectedTarget else { return false }
        let name = selectedTarget.name.uppercased()
        return name.contains("SOFTWARE ATS PCON")
            || name.contains("SOFTWARE ATS PCOE")
            || selectedTarget.roots.contains {
                $0.name.localizedCaseInsensitiveContains("tren")
            }
    }

    private var levelOneOptions: [CorrectiveLocationOption] {
        locationOptions.filter { $0.level == 1 }
    }

    private var levelTwoOptions: [CorrectiveLocationOption] {
        locationOptions.filter {
            $0.level == 2 && $0.parentLocationID == selectedLocationLevelOneID
        }
    }

    private var locationLevelsFromContext: [String] {
        guard let physicalLocation = context?.physicalLocation else { return [] }
        return physicalLocation
            .split(separator: "/")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var eventPhysicalLocation: String {
        guard allowsVariableEventLocation,
              let first = levelOneOptions.first(where: { $0.id == selectedLocationLevelOneID }),
              let second = levelTwoOptions.first(where: { $0.id == selectedLocationLevelTwoID }) else {
            return context?.physicalLocation ?? ""
        }
        return "\(first.name) / \(second.name)"
    }

    private func configureEventLocation() {
        guard !allowsVariableEventLocation else {
            selectedLocationLevelOneID = ""
            selectedLocationLevelTwoID = ""
            return
        }
        let levels = locationLevelsFromContext
        guard let firstName = levels.first,
              let first = levelOneOptions.first(where: {
                  $0.name.compare(firstName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
              }) else {
            return
        }
        selectedLocationLevelOneID = first.id
        if let secondName = levels.dropFirst().first,
           let second = locationOptions.first(where: {
               $0.level == 2 && $0.parentLocationID == first.id
                   && $0.name.compare(secondName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
           }) {
            selectedLocationLevelTwoID = second.id
        }
    }
}

private struct CorrectiveAssetTreeNode: Identifiable {
    let asset: EquipmentTreeNodeDTO
    let children: [CorrectiveAssetTreeNode]
    let depth: Int

    var id: String { asset.id }

    static func roots(
        nodes: [EquipmentTreeNodeDTO],
        equipmentID: String
    ) -> [CorrectiveAssetTreeNode] {
        let grouped = Dictionary(grouping: nodes) { $0.parentID ?? "" }

        func build(
            parentID: String,
            visited: Set<String>,
            depth: Int
        ) -> [CorrectiveAssetTreeNode] {
            (grouped[parentID] ?? []).compactMap { node in
                guard !visited.contains(node.id) else { return nil }
                return CorrectiveAssetTreeNode(
                    asset: node,
                    children: build(
                        parentID: node.id,
                        visited: visited.union([node.id]),
                        depth: depth + 1
                    ),
                    depth: depth
                )
            }
        }

        return build(parentID: equipmentID, visited: [equipmentID], depth: 0)
    }

    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return asset.name.localizedCaseInsensitiveContains(query)
            || asset.assetType.localizedCaseInsensitiveContains(query)
            || (asset.serialNumber?.localizedCaseInsensitiveContains(query) ?? false)
            || (asset.partNumber?.localizedCaseInsensitiveContains(query) ?? false)
            || (asset.slotPath?.localizedCaseInsensitiveContains(query) ?? false)
    }

    func containsMatch(_ query: String) -> Bool {
        matches(query) || children.contains { $0.containsMatch(query) }
    }

    func expandableIDs(keepingMatchesFor query: String) -> [String] {
        guard !children.isEmpty else { return [] }
        let nested = children.flatMap { $0.expandableIDs(keepingMatchesFor: query) }
        return (children.contains { $0.containsMatch(query) } ? [id] : []) + nested
    }
}

private struct CorrectiveMultiAssetTreePicker: View {
    let root: CorrectiveTargetMember
    let nodes: [EquipmentTreeNodeDTO]
    @Binding var selectedAssetIDs: Set<String>
    @Binding var criticalAssetIDs: Set<String>
    @State private var expandedAssetIDs: Set<String> = []
    @State private var componentSearchText = ""

    private var tree: [CorrectiveAssetTreeNode] {
        CorrectiveAssetTreeNode.roots(nodes: nodes, equipmentID: root.id)
    }

    private var normalizedSearch: String {
        componentSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var visibleTree: [CorrectiveAssetTreeNode] {
        guard !normalizedSearch.isEmpty else { return tree }
        return tree.filter { $0.containsMatch(normalizedSearch) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(root.name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
            multiSelectionRow(
                id: root.id,
                name: root.name,
                type: "Equipo"
            )
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Buscar dentro del equipo", text: $componentSearchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(AppSpacing.sm)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            LazyVStack(alignment: .leading, spacing: AppSpacing.xs) {
                ForEach(visibleTree) { branch in
                    CorrectiveMultiAssetTreeBranchView(
                        branch: branch,
                        selectedAssetIDs: $selectedAssetIDs,
                        criticalAssetIDs: $criticalAssetIDs,
                        expandedAssetIDs: $expandedAssetIDs,
                        query: normalizedSearch
                    )
                    .padding(.leading, AppSpacing.md)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            .background.opacity(0.72),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .onChange(of: normalizedSearch) { _, query in
            guard !query.isEmpty else { return }
            expandedAssetIDs = Set(tree.flatMap { $0.expandableIDs(keepingMatchesFor: query) })
        }
    }

    private func multiSelectionRow(id: String, name: String, type: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Button { toggleAsset(id) } label: {
                Image(systemName: selectedAssetIDs.contains(id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedAssetIDs.contains(id) ? BrandColor.red : .secondary)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.headline)
                Text(type).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private func toggleAsset(_ id: String) {
        if selectedAssetIDs.contains(id) {
            selectedAssetIDs.remove(id)
            criticalAssetIDs.remove(id)
        } else {
            selectedAssetIDs.insert(id)
        }
    }

    private func criticalBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { criticalAssetIDs.contains(id) },
            set: { isCritical in
                if isCritical { criticalAssetIDs.insert(id) }
                else { criticalAssetIDs.remove(id) }
            }
        )
    }
}

private struct CorrectiveMultiAssetTreeBranchView: View {
    let branch: CorrectiveAssetTreeNode
    @Binding var selectedAssetIDs: Set<String>
    @Binding var criticalAssetIDs: Set<String>
    @Binding var expandedAssetIDs: Set<String>
    let query: String

    private var visibleChildren: [CorrectiveAssetTreeNode] {
        guard !query.isEmpty else { return branch.children }
        return branch.children.filter { $0.containsMatch(query) }
    }

    var body: some View {
        if visibleChildren.isEmpty {
            row
        } else {
            DisclosureGroup(isExpanded: expansionBinding) {
                LazyVStack(alignment: .leading, spacing: AppSpacing.xs) {
                    ForEach(visibleChildren) { child in
                        CorrectiveMultiAssetTreeBranchView(
                            branch: child,
                            selectedAssetIDs: $selectedAssetIDs,
                            criticalAssetIDs: $criticalAssetIDs,
                            expandedAssetIDs: $expandedAssetIDs,
                            query: query
                        )
                        .padding(.leading, AppSpacing.md)
                    }
                }
            } label: { row }
            .tint(BrandColor.red)
        }
    }

    private var expansionBinding: Binding<Bool> {
        Binding(
            get: { expandedAssetIDs.contains(branch.id) },
            set: { isExpanded in
                if isExpanded { expandedAssetIDs.insert(branch.id) }
                else { expandedAssetIDs.remove(branch.id) }
            }
        )
    }

    private var row: some View {
        HStack(spacing: AppSpacing.sm) {
            if branch.asset.selectable {
                Button { toggleAsset(branch.id) } label: {
                    Image(systemName: selectedAssetIDs.contains(branch.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedAssetIDs.contains(branch.id) ? BrandColor.red : .secondary)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(branch.asset.name).font(.headline)
                Text(branch.asset.nodeKind == "LOCATION" ? "Ubicacion fisica" : branch.asset.assetType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private func toggleAsset(_ id: String) {
        if selectedAssetIDs.contains(id) {
            selectedAssetIDs.remove(id)
            criticalAssetIDs.remove(id)
        } else {
            selectedAssetIDs.insert(id)
        }
    }

    private func criticalBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { criticalAssetIDs.contains(id) },
            set: { isCritical in
                if isCritical { criticalAssetIDs.insert(id) }
                else { criticalAssetIDs.remove(id) }
            }
        )
    }
}

private struct CorrectiveAssetTreePicker: View {
    let equipment: EquipmentDTO
    let nodes: [EquipmentTreeNodeDTO]
    @Binding var selectedAssetID: String?
    @State private var tree: [CorrectiveAssetTreeNode]
    @State private var expandedAssetIDs: Set<String> = []

    init(
        equipment: EquipmentDTO,
        nodes: [EquipmentTreeNodeDTO],
        selectedAssetID: Binding<String?>
    ) {
        self.equipment = equipment
        self.nodes = nodes
        self._selectedAssetID = selectedAssetID
        self._tree = State(
            initialValue: CorrectiveAssetTreeNode.roots(
                nodes: nodes,
                equipmentID: equipment.id
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            selectionRow(
                id: equipment.id,
                name: equipment.name,
                type: "Equipo"
            )
            LazyVStack(alignment: .leading, spacing: AppSpacing.xs) {
                ForEach(tree) { branch in
                    CorrectiveAssetTreeBranchView(
                        branch: branch,
                        selectedAssetID: $selectedAssetID,
                        expandedAssetIDs: $expandedAssetIDs
                    )
                    .padding(.leading, AppSpacing.md)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            .background.opacity(0.72),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .onChange(of: nodeSignature) { _, _ in
            tree = CorrectiveAssetTreeNode.roots(
                nodes: nodes,
                equipmentID: equipment.id
            )
            expandedAssetIDs.removeAll()
        }
    }

    private var nodeSignature: String {
        nodes.map(\.id).joined(separator: "|")
    }

    private func selectionRow(id: String, name: String, type: String) -> some View {
        Button {
            selectedAssetID = id
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(
                    systemName: selectedAssetID == id
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .foregroundStyle(selectedAssetID == id ? BrandColor.red : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.headline).foregroundStyle(.primary)
                    Text(type).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, AppSpacing.xs)
        }
        .buttonStyle(.plain)
    }
}

private struct CorrectiveAssetTreeBranchView: View {
    let branch: CorrectiveAssetTreeNode
    @Binding var selectedAssetID: String?
    @Binding var expandedAssetIDs: Set<String>

    var body: some View {
        if branch.children.isEmpty {
            row
        } else {
            DisclosureGroup(isExpanded: expansionBinding) {
                LazyVStack(alignment: .leading, spacing: AppSpacing.xs) {
                    ForEach(branch.children) { child in
                        CorrectiveAssetTreeBranchView(
                            branch: child,
                            selectedAssetID: $selectedAssetID,
                            expandedAssetIDs: $expandedAssetIDs
                        )
                        .padding(.leading, AppSpacing.md)
                    }
                }
            } label: {
                row
            }
            .tint(BrandColor.red)
        }
    }

    private var expansionBinding: Binding<Bool> {
        Binding(
            get: { expandedAssetIDs.contains(branch.id) },
            set: { isExpanded in
                if isExpanded {
                    expandedAssetIDs.insert(branch.id)
                } else {
                    expandedAssetIDs.remove(branch.id)
                }
            }
        )
    }

    private var row: some View {
        Button {
            guard branch.asset.selectable else { return }
            selectedAssetID = branch.id
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: branch.asset.selectable
                    ? (selectedAssetID == branch.id ? "checkmark.circle.fill" : "circle")
                    : "folder.fill")
                .foregroundStyle(
                    selectedAssetID == branch.id ? BrandColor.red : .secondary
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(branch.asset.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(branch.asset.nodeKind == "LOCATION" ? "Ubicacion fisica" : branch.asset.assetType)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, AppSpacing.xs)
        }
        .buttonStyle(.plain)
        .disabled(!branch.asset.selectable)
    }
}

private struct CorrectiveAPIActivityCard: View {
    let activity: APIActivity

    var body: some View {
        GlassPanel {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(BrandColor.red)
                    .frame(width: 48, height: 48)
                    .background(BrandColor.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    Text(activity.title).font(.headline).lineLimit(2)
                    Text("Notificación SAP: \(activity.sapNotification?.isEmpty == false ? activity.sapNotification! : "No registrada")")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BrandColor.red)
                    Text(activity.assets.map(\.name).joined(separator: ", ")).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    Label(
                        activity.locationPath?.activityLocationSummary ?? "Ubicacion no registrada",
                        systemImage: "mappin.and.ellipse"
                    )
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: AppSpacing.sm)
                VStack(alignment: .trailing, spacing: AppSpacing.sm) {
                    APIStatusBadge(status: activity.status)
                    if let severity = activity.severity {
                        Text(severity).font(.caption.weight(.bold)).foregroundStyle(severity == "HIGH" ? BrandColor.red : BrandColor.amber)
                    }
                    if let noticeCreatedAt = activity.noticeCreatedAt {
                        Text(Self.dateFormatter.string(from: noticeCreatedAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es_PE")
        return formatter
    }()
}
