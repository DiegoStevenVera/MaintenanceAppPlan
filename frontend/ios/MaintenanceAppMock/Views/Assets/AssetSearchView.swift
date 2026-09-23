import PhotosUI
import SwiftUI
import UIKit

struct EquipmentImageDTO: Identifiable, Decodable {
    let id: String
    let fileName: String
    let mediaType: String
    let byteSize: Int
    let caption: String?
    let isPrimary: Bool
    let sortOrder: Int
    let url: String

    enum CodingKeys: String, CodingKey {
        case id, caption, url
        case fileName = "file_name"
        case mediaType = "media_type"
        case byteSize = "byte_size"
        case isPrimary = "is_primary"
        case sortOrder = "sort_order"
    }
}

struct EquipmentDTO: Identifiable, Decodable {
    let id: String
    let name: String
    let category: String
    let assetType: String
    let subsystem: String
    let serialOrCode: String
    let partNumber: String?
    let status: String
    let physicalLocation: String
    let isBusinessAnchor: Bool
    let businessLabel: String?
    let manufacturer: String?
    let model: String?
    let softwareVersion: String?
    let currentPosition: String?
    let equipmentCategoryID: String?
    let subsystemID: String?
    let statusID: String?
    let geographicLocationID: String?
    let componentCount: Int
    let images: [EquipmentImageDTO]?

    enum CodingKeys: String, CodingKey {
        case id, name, category, subsystem, status, model, manufacturer
        case assetType = "asset_type"
        case serialOrCode = "serial_or_code"
        case partNumber = "part_number"
        case physicalLocation = "physical_location"
        case isBusinessAnchor = "is_business_anchor"
        case businessLabel = "business_label"
        case softwareVersion = "software_version"
        case currentPosition = "current_position"
        case equipmentCategoryID = "equipment_category_id"
        case subsystemID = "subsystem_id"
        case statusID = "status_id"
        case geographicLocationID = "geographic_location_id"
        case componentCount = "component_count"
        case images
    }

    var galleryImages: [EquipmentImageDTO] { images ?? [] }
}

struct EquipmentWritePayload: Encodable {
    let name: String
    let serial_or_code: String
    let part_number: String?
    let equipment_category_id: String
    let subsystem_id: String
    let status_id: String
    let geographic_location_id: String
    let business_label: String?
    let manufacturer: String?
    let model: String?
    let software_version: String?
}

struct EquipmentCatalogOption: Identifiable, Decodable {
    let id: String
    let name: String
    let code: String?
}

struct EquipmentCategoryOption: Identifiable, Decodable {
    let id: String
    let subsystemID: String
    let nameN1: String
    let nameN2: String

    enum CodingKeys: String, CodingKey {
        case id
        case subsystemID = "subsystem_id"
        case nameN1 = "name_n1"
        case nameN2 = "name_n2"
    }
}

struct EquipmentLocationOption: Identifiable, Decodable {
    let id: String
    let name: String
    let level: Int
    let parentID: String?
    let fullPath: String

    enum CodingKeys: String, CodingKey {
        case id, name, level
        case parentID = "parent_id"
        case fullPath = "full_path"
    }
}

struct EquipmentAdministrationCatalog: Decodable {
    let categories: [EquipmentCategoryOption]
    let subsystems: [EquipmentCatalogOption]
    let statuses: [EquipmentCatalogOption]
    let locations: [EquipmentLocationOption]
}

struct EquipmentImageWritePayload: Encodable {
    let image_base64: String
    let file_name: String
    let media_type: String
    let caption: String?
    let is_primary: Bool
}

struct EquipmentTreeNodeDTO: Identifiable, Codable {
    let id: String
    let name: String
    let category: String
    let assetType: String
    let status: String
    let serialNumber: String?
    let partNumber: String?
    let model: String?
    let manufacturer: String?
    let parentID: String?
    let depth: Int
    let slotPath: String?
    let position: String?
    let nodeKind: String
    let selectable: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, category, status, model, manufacturer, depth, position
        case assetType = "asset_type"
        case serialNumber = "serial_number"
        case partNumber = "part_number"
        case parentID = "parent_id"
        case slotPath = "slot_path"
        case nodeKind = "node_kind"
        case selectable
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(String.self, forKey: .category)
        assetType = try container.decode(String.self, forKey: .assetType)
        status = try container.decode(String.self, forKey: .status)
        serialNumber = try container.decodeIfPresent(String.self, forKey: .serialNumber)
        partNumber = try container.decodeIfPresent(String.self, forKey: .partNumber)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        manufacturer = try container.decodeIfPresent(String.self, forKey: .manufacturer)
        parentID = try container.decodeIfPresent(String.self, forKey: .parentID)
        depth = try container.decodeIfPresent(Int.self, forKey: .depth) ?? 0
        slotPath = try container.decodeIfPresent(String.self, forKey: .slotPath)
        position = try container.decodeIfPresent(String.self, forKey: .position)
        // DEV/QA may still expose the first tree contract. Keep it readable
        // while servers are rolled forward with the physical-node fields.
        nodeKind = try container.decodeIfPresent(String.self, forKey: .nodeKind) ?? "ASSET"
        selectable = try container.decodeIfPresent(Bool.self, forKey: .selectable) ?? true
    }

    init(
        id: String,
        name: String,
        category: String,
        assetType: String,
        status: String,
        serialNumber: String?,
        partNumber: String?,
        model: String?,
        manufacturer: String?,
        parentID: String?,
        depth: Int,
        slotPath: String?,
        position: String?,
        nodeKind: String = "ASSET",
        selectable: Bool = true
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.assetType = assetType
        self.status = status
        self.serialNumber = serialNumber
        self.partNumber = partNumber
        self.model = model
        self.manufacturer = manufacturer
        self.parentID = parentID
        self.depth = depth
        self.slotPath = slotPath
        self.position = position
        self.nodeKind = nodeKind
        self.selectable = selectable
    }
}

struct AssetComponentOperation: Encodable, Identifiable {
    enum Action: String, Encodable, CaseIterable {
        case create = "CREATE"
        case update = "UPDATE"
        case move = "MOVE"
        case delete = "DELETE"
    }

    let id = UUID()
    let action: Action
    let componentID: String?
    let parentID: String?
    let name: String?
    let category: String?
    let assetType: String?
    let status: String?
    let serialNumber: String?
    let partNumber: String?
    let model: String?
    let currentPosition: String?

    enum CodingKeys: String, CodingKey {
        case action, name, category, status, model
        case componentID = "component_id"
        case parentID = "parent_id"
        case assetType = "asset_type"
        case serialNumber = "serial_number"
        case partNumber = "part_number"
        case currentPosition = "current_position"
    }
}

private struct AssetComponentChangesRequest: Encodable {
    let operations: [AssetComponentOperation]
}

struct EquipmentMaintenanceDTO: Identifiable, Decodable {
    let id: String
    let reportType: String
    let reportID: String
    let title: String
    let performedAt: String
    let result: String
    let activityID: String?
    let activityStatus: String?
    let reportKind: String?
    let versionNumber: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, result
        case reportType = "report_type"
        case reportID = "report_id"
        case performedAt = "performed_at"
        case activityID = "activity_id"
        case activityStatus = "activity_status"
        case reportKind = "report_kind"
        case versionNumber = "version_number"
    }
}

private struct EquipmentPageDTO: Decodable {
    let items: [EquipmentDTO]
    let total: Int
}

private struct AssetService {
    private let client: APIClient

    init(baseURLString: String) {
        client = APIClient(baseURLString: baseURLString)
    }

    func list(
        query: String,
        subsystem: String?,
        category: String? = nil,
        status: String? = nil,
        accessToken: String
    ) async throws -> EquipmentPageDTO {
        var queryItems = [
            URLQueryItem(name: "business_anchor", value: "true"),
            URLQueryItem(name: "limit", value: "200")
        ]
        if !query.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }
        if let subsystem {
            queryItems.append(URLQueryItem(name: "subsystem", value: subsystem))
        }
        if let category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        if let status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        return try await client.get(
            "api/v1/assets",
            bearerToken: accessToken,
            queryItems: queryItems
        )
    }

    func detail(id: String, accessToken: String) async throws -> EquipmentDTO {
        try await client.get("api/v1/assets/\(id)", bearerToken: accessToken)
    }

    func administrationCatalog(accessToken: String) async throws -> EquipmentAdministrationCatalog {
        try await client.get("api/v1/assets/administration/catalog", bearerToken: accessToken)
    }

    func tree(id: String, accessToken: String) async throws -> [EquipmentTreeNodeDTO] {
        try await client.get("api/v1/assets/\(id)/tree", bearerToken: accessToken)
    }

    func history(id: String, accessToken: String) async throws -> [EquipmentMaintenanceDTO] {
        try await client.get("api/v1/assets/\(id)/history", bearerToken: accessToken)
    }

    func applyComponentChanges(
        rootID: String,
        operations: [AssetComponentOperation],
        accessToken: String
    ) async throws -> [EquipmentTreeNodeDTO] {
        try await client.patch(
            "api/v1/assets/\(rootID)/components",
            body: AssetComponentChangesRequest(operations: operations),
            bearerToken: accessToken
        )
    }

    func create(
        payload: EquipmentWritePayload,
        accessToken: String
    ) async throws -> EquipmentDTO {
        try await client.post("api/v1/assets", body: payload, bearerToken: accessToken)
    }

    func update(
        id: String,
        payload: EquipmentWritePayload,
        accessToken: String
    ) async throws -> EquipmentDTO {
        try await client.put("api/v1/assets/\(id)", body: payload, bearerToken: accessToken)
    }

    func archive(id: String, accessToken: String) async throws {
        try await client.delete("api/v1/assets/\(id)", bearerToken: accessToken)
    }

    func addImage(
        assetID: String,
        payload: EquipmentImageWritePayload,
        accessToken: String
    ) async throws -> EquipmentImageDTO {
        try await client.post(
            "api/v1/assets/\(assetID)/images",
            body: payload,
            bearerToken: accessToken
        )
    }

    func deleteImage(
        assetID: String,
        imageID: String,
        accessToken: String
    ) async throws {
        try await client.delete(
            "api/v1/assets/\(assetID)/images/\(imageID)",
            bearerToken: accessToken
        )
    }

    func imageData(
        assetID: String,
        imageID: String,
        accessToken: String
    ) async throws -> Data {
        try await client.getData(
            "api/v1/assets/\(assetID)/images/\(imageID)",
            bearerToken: accessToken
        )
    }
}

@MainActor
final class AssetStore: ObservableObject {
    @Published private(set) var equipments: [EquipmentDTO] = []
    @Published private(set) var total = 0
    @Published private(set) var isLoadingList = false
    @Published private(set) var listError: String?
    @Published private(set) var availableCategories: [String] = []
    @Published private(set) var availableSubsystems: [String] = []
    @Published private(set) var availableStatuses: [String] = []
    @Published private(set) var details: [String: EquipmentDTO] = [:]
    @Published private(set) var trees: [String: [EquipmentTreeNodeDTO]] = [:]
    @Published private(set) var histories: [String: [EquipmentMaintenanceDTO]] = [:]
    @Published private(set) var loadingDetailIDs: Set<String> = []
    @Published private(set) var detailErrors: [String: String] = [:]
    @Published private(set) var administrationCatalog: EquipmentAdministrationCatalog?
    @Published private(set) var isLoadingAdministrationCatalog = false
    @Published private(set) var administrationCatalogError: String?

    func loadAdministrationCatalog(session: SessionStore, force: Bool = false) async {
        if !force, administrationCatalog != nil { return }
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else {
            administrationCatalogError = "No se encontro la URL de la API."
            return
        }
        isLoadingAdministrationCatalog = true
        administrationCatalogError = nil
        defer { isLoadingAdministrationCatalog = false }
        do {
            let service = AssetService(baseURLString: baseURL)
            administrationCatalog = try await session.withValidAccessToken { token in
                try await service.administrationCatalog(accessToken: token)
            }
        } catch {
            administrationCatalogError = error.localizedDescription
        }
    }

    func loadEquipments(
        query: String,
        subsystem: String?,
        category: String? = nil,
        status: String? = nil,
        session: SessionStore
    ) async {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else {
            listError = "No se encontro la URL de la API."
            return
        }

        isLoadingList = true
        listError = nil
        do {
            let service = AssetService(baseURLString: baseURL)
            let page = try await session.withValidAccessToken { token in
                try await service.list(
                    query: query,
                    subsystem: subsystem,
                    category: category,
                    status: status,
                    accessToken: token
                )
            }
            guard !Task.isCancelled else { return }
            equipments = page.items
            total = page.total
            availableCategories = Array(
                Set(availableCategories).union(page.items.map(\.category).filter { !$0.isEmpty })
            ).sorted()
            availableSubsystems = Array(
                Set(availableSubsystems).union(page.items.map(\.subsystem).filter { !$0.isEmpty })
            ).sorted()
            availableStatuses = Array(
                Set(availableStatuses).union(page.items.map(\.status).filter { !$0.isEmpty })
            ).sorted()
        } catch {
            guard !Task.isCancelled else { return }
            listError = error.localizedDescription
        }
        isLoadingList = false
    }

    func loadDetail(id: String, session: SessionStore, force: Bool = false) async {
        if !force, details[id] != nil, trees[id] != nil, histories[id] != nil {
            return
        }
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else {
            detailErrors[id] = "No se encontro la URL de la API."
            return
        }

        loadingDetailIDs.insert(id)
        detailErrors[id] = nil
        do {
            let service = AssetService(baseURLString: baseURL)
            let response = try await session.withValidAccessToken { token in
                async let detail = service.detail(id: id, accessToken: token)
                async let tree = service.tree(id: id, accessToken: token)
                async let history = service.history(id: id, accessToken: token)
                return try await (detail, tree, history)
            }
            details[id] = response.0
            trees[id] = response.1
            histories[id] = response.2
        } catch {
            detailErrors[id] = error.localizedDescription
        }
        loadingDetailIDs.remove(id)
    }

    func loadTree(id: String, session: SessionStore, force: Bool = false) async {
        if !force, trees[id] != nil {
            return
        }
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else {
            detailErrors[id] = "No se encontro la URL de la API."
            return
        }

        do {
            let service = AssetService(baseURLString: baseURL)
            trees[id] = try await session.withValidAccessToken { token in
                try await service.tree(id: id, accessToken: token)
            }
        } catch {
            detailErrors[id] = error.localizedDescription
        }
    }

    func applyComponentChanges(
        rootID: String,
        operations: [AssetComponentOperation],
        session: SessionStore
    ) async throws {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else {
            throw APIClient.APIError.invalidBaseURL
        }
        let service = AssetService(baseURLString: baseURL)
        let tree = try await session.withValidAccessToken { token in
            try await service.applyComponentChanges(
                rootID: rootID,
                operations: operations,
                accessToken: token
            )
        }
        trees[rootID] = tree
        await loadDetail(id: rootID, session: session, force: true)
    }

    func saveEquipment(
        id: String?,
        payload: EquipmentWritePayload,
        imageData: Data?,
        session: SessionStore
    ) async throws -> EquipmentDTO {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else {
            throw APIClient.APIError.invalidBaseURL
        }
        let service = AssetService(baseURLString: baseURL)
        var saved = try await session.withValidAccessToken { token in
            if let id {
                return try await service.update(id: id, payload: payload, accessToken: token)
            }
            return try await service.create(payload: payload, accessToken: token)
        }
        if let imageData {
            _ = try await session.withValidAccessToken { token in
                try await service.addImage(
                    assetID: saved.id,
                    payload: EquipmentImageWritePayload(
                        image_base64: imageData.base64EncodedString(),
                        file_name: "equipo.jpg",
                        media_type: "image/jpeg",
                        caption: nil,
                        is_primary: saved.galleryImages.isEmpty
                    ),
                    accessToken: token
                )
            }
            saved = try await session.withValidAccessToken { token in
                try await service.detail(id: saved.id, accessToken: token)
            }
        }
        details[saved.id] = saved
        return saved
    }

    func archiveEquipment(id: String, session: SessionStore) async throws {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else {
            throw APIClient.APIError.invalidBaseURL
        }
        let service = AssetService(baseURLString: baseURL)
        try await session.withValidAccessToken { token in
            try await service.archive(id: id, accessToken: token)
        }
        let archived = try await session.withValidAccessToken { token in
            try await service.detail(id: id, accessToken: token)
        }
        details[id] = archived
        if let index = equipments.firstIndex(where: { $0.id == id }) {
            equipments[index] = archived
        }
    }

    func deleteImage(
        assetID: String,
        imageID: String,
        session: SessionStore
    ) async throws {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else {
            throw APIClient.APIError.invalidBaseURL
        }
        let service = AssetService(baseURLString: baseURL)
        try await session.withValidAccessToken { token in
            try await service.deleteImage(
                assetID: assetID,
                imageID: imageID,
                accessToken: token
            )
        }
        await loadDetail(id: assetID, session: session, force: true)
    }
}

struct AssetSearchView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var assetStore: AssetStore
    @State private var query = ""
    @State private var selectedCategory = ""
    @State private var selectedSubsystem = ""
    @State private var selectedStatus = ""
    @State private var page = 0
    @State private var isPresentingNewEquipment = false

    private let pageSize = 10

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 850
            let isNarrow = geometry.size.width < 650

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    pageHeader
                    filters(isCompact: isCompact)
                    results(
                        isWide: geometry.size.width >= 1_000,
                        isCompact: isCompact,
                        isNarrow: isNarrow
                    )
                }
                .padding(isCompact ? AppSpacing.md : AppSpacing.lg)
                .frame(maxWidth: 1_200, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Equipos")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await load()
        }
        .task(id: "\(query)|\(selectedCategory)|\(selectedSubsystem)|\(selectedStatus)") {
            if !query.isEmpty {
                try? await Task.sleep(for: .milliseconds(300))
            }
            guard !Task.isCancelled else { return }
            await load()
        }
        .onChange(of: query) { _, _ in page = 0 }
        .onChange(of: selectedCategory) { _, _ in page = 0 }
        .onChange(of: selectedSubsystem) { _, _ in page = 0 }
        .onChange(of: selectedStatus) { _, _ in page = 0 }
        .fullScreenCover(isPresented: $isPresentingNewEquipment) {
            EquipmentEditorView(equipment: nil) {
                await load()
            }
            .environmentObject(session)
            .environmentObject(assetStore)
        }
    }

    private var pageHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                pageTitle
                Spacer()
                if session.currentUser?.role == .administrator {
                    newEquipmentButton
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                pageTitle
                if session.currentUser?.role == .administrator {
                    newEquipmentButton
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    private var pageTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Equipos")
                .font(.largeTitle.bold())
            Text("Consulta los equipos, su ubicación y estado operativo")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var newEquipmentButton: some View {
        Button {
            isPresentingNewEquipment = true
        } label: {
            Label("Nuevo equipo", systemImage: "plus")
        }
        .buttonStyle(.borderedProminent)
        .tint(BrandColor.red)
    }

    @ViewBuilder
    private func filters(isCompact: Bool) -> some View {
        GlassPanel {
            if isCompact {
                VStack(spacing: AppSpacing.sm) {
                    searchField

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: AppSpacing.sm),
                            GridItem(.flexible(), spacing: AppSpacing.sm)
                        ],
                        spacing: AppSpacing.sm
                    ) {
                        categoryFilter
                        subsystemFilter
                        statusFilter
                        clearFiltersButton
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                }
            } else {
                HStack(spacing: AppSpacing.sm) {
                    searchField
                        .frame(minWidth: 170, maxWidth: .infinity)
                    categoryFilter
                        .frame(minWidth: 120, maxWidth: 150)
                    subsystemFilter
                        .frame(minWidth: 120, maxWidth: 150)
                    statusFilter
                        .frame(minWidth: 120, maxWidth: 150)
                    clearFiltersButton
                        .frame(minWidth: 104)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Buscar equipo", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(
            .background.opacity(0.72),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }

    private var categoryFilter: some View {
        MaintenanceChoiceField(
            "Categoría",
            systemImage: "square.stack.3d.up",
            selection: $selectedCategory
        ) {
            Text("Todas").tag("")
            ForEach(assetStore.availableCategories, id: \.self) { category in
                Text(category).tag(category)
            }
        }
    }

    private var statusFilter: some View {
        MaintenanceChoiceField(
            "Estado",
            systemImage: "checkmark.seal",
            selection: $selectedStatus
        ) {
            Text("Todos").tag("")
            ForEach(assetStore.availableStatuses, id: \.self) { status in
                Text(status).tag(status)
            }
        }
    }

    private var subsystemFilter: some View {
        MaintenanceChoiceField(
            "Subsistema",
            systemImage: "square.stack.3d.up.fill",
            selection: $selectedSubsystem
        ) {
            Text("Todos").tag("")
            ForEach(assetStore.availableSubsystems, id: \.self) { subsystem in
                Text(subsystem).tag(subsystem)
            }
        }
    }

    private var clearFiltersButton: some View {
        Button {
            query = ""
            selectedCategory = ""
            selectedSubsystem = ""
            selectedStatus = ""
        } label: {
            Label("Limpiar", systemImage: "arrow.counterclockwise")
        }
        .buttonStyle(CompactActionButtonStyle())
        .disabled(
            query.isEmpty
                && selectedCategory.isEmpty
                && selectedSubsystem.isEmpty
                && selectedStatus.isEmpty
        )
    }

    @ViewBuilder
    private func results(isWide: Bool, isCompact: Bool, isNarrow: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(assetStore.total) equipos")
                        .font(.title3.bold())
                    if !assetStore.equipments.isEmpty {
                        Text("Mostrando \(pageItems.count) de \(assetStore.total)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !isCompact {
                    Text("Inventario de equipos")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if assetStore.isLoadingList && assetStore.equipments.isEmpty {
                ProgressView("Cargando equipos")
                    .frame(maxWidth: .infinity)
                    .padding(AppSpacing.xl)
            } else if let error = assetStore.listError {
                ContentUnavailableView {
                    Label("No se pudieron cargar los equipos", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Reintentar") {
                        Task { await load() }
                    }
                }
            } else if assetStore.equipments.isEmpty {
                ContentUnavailableView.search(text: query)
            } else if isWide {
                equipmentTable
            } else {
                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(pageItems) { equipment in
                        NavigationLink {
                            AssetDetailView(assetID: equipment.id)
                        } label: {
                            EquipmentCompactRow(
                                equipment: equipment,
                                isNarrow: isNarrow
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !assetStore.equipments.isEmpty {
                pagination
            }
        }
    }

    private var equipmentTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.sm) {
                Text("Imagen").frame(width: 62, alignment: .leading)
                Text("Código").frame(width: 120, alignment: .leading)
                Text("Nombre").frame(minWidth: 210, maxWidth: .infinity, alignment: .leading)
                Text("Categoría").frame(width: 150, alignment: .leading)
                Text("Ubicación").frame(width: 180, alignment: .leading)
                Text("Estado").frame(width: 150, alignment: .leading)
                Text("Ver").frame(width: 44, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)

            ForEach(pageItems) { equipment in
                NavigationLink {
                    AssetDetailView(assetID: equipment.id)
                } label: {
                    EquipmentWideRow(equipment: equipment)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BrandColor.glassStroke)
        }
    }

    private var pageItems: [EquipmentDTO] {
        let start = page * pageSize
        guard start < assetStore.equipments.count else { return [] }
        return Array(assetStore.equipments[start..<min(start + pageSize, assetStore.equipments.count)])
    }

    private var pageCount: Int {
        max(1, Int(ceil(Double(assetStore.equipments.count) / Double(pageSize))))
    }

    private var pagination: some View {
        PaginationBar(currentPage: page, pageCount: pageCount) { selectedPage in
            page = selectedPage
        }
        .padding(.vertical, AppSpacing.sm)
    }

    private func load() async {
        await assetStore.loadEquipments(
            query: query.trimmingCharacters(in: .whitespacesAndNewlines),
            subsystem: selectedSubsystem.isEmpty ? nil : selectedSubsystem,
            category: selectedCategory.isEmpty ? nil : selectedCategory,
            status: selectedStatus.isEmpty ? nil : selectedStatus,
            session: session
        )
        page = min(page, max(0, pageCount - 1))
    }
}

private struct EquipmentWideRow: View {
    let equipment: EquipmentDTO

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            EquipmentThumbnail(equipment: equipment, size: 48)
                .frame(width: 62, alignment: .leading)
            Text(equipment.serialOrCode)
                .font(.subheadline.weight(.semibold))
                .frame(width: 120, alignment: .leading)
                .lineLimit(2)
            VStack(alignment: .leading, spacing: 3) {
                Text(equipment.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(equipment.assetType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 210, maxWidth: .infinity, alignment: .leading)
            Text(equipment.category)
                .font(.subheadline)
                .frame(width: 150, alignment: .leading)
                .lineLimit(2)
            Text(equipment.physicalLocation.activityLocationSummary)
                .font(.subheadline)
                .frame(width: 180, alignment: .leading)
                .lineLimit(2)
            EquipmentStatusBadge(status: equipment.status)
                .frame(width: 150, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .contentShape(.rect)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Abre el detalle del equipo")
    }
}

private struct EquipmentCompactRow: View {
    let equipment: EquipmentDTO
    let isNarrow: Bool

    var body: some View {
        HStack(alignment: .center, spacing: isNarrow ? AppSpacing.sm : AppSpacing.md) {
            EquipmentThumbnail(equipment: equipment, size: isNarrow ? 52 : 58)
            VStack(alignment: .leading, spacing: 3) {
                Text(equipment.serialOrCode)
                    .font(.subheadline.weight(.bold))
                Text(equipment.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text("\(equipment.category) · \(equipment.assetType)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(isNarrow ? 2 : 1)
                Text(equipment.physicalLocation.activityLocationSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(isNarrow ? 2 : 1)
                if isNarrow {
                    EquipmentStatusBadge(status: equipment.status)
                        .padding(.top, 3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !isNarrow {
                EquipmentStatusBadge(status: equipment.status)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.md)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BrandColor.glassStroke)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Abre el detalle del equipo")
    }
}

private struct EquipmentThumbnail: View {
    let equipment: EquipmentDTO
    let size: CGFloat

    var body: some View {
        Group {
            if let image = equipment.galleryImages.first {
                EquipmentRemoteImage(assetID: equipment.id, image: image) {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .background(BrandColor.red.opacity(0.09))
        .clipShape(.rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BrandColor.red.opacity(0.10))
        }
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Image(systemName: symbolName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(BrandColor.red)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var symbolName: String {
        switch equipment.category {
        case "Vehículo": "tram.fill"
        case "Servidor": "server.rack"
        case "Equipo de vía": "point.topleft.down.curvedto.point.bottomright.up"
        default: "square.stack.3d.up.fill"
        }
    }
}

private struct EquipmentStatusBadge: View {
    let status: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
            Text(displayStatus)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 6)
        .background(tint.opacity(0.10), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Estado: \(displayStatus)")
    }

    private var normalizedStatus: String {
        status.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
    }

    private var displayStatus: String {
        status.lowercased().capitalized
    }

    private var tint: Color {
        if normalizedStatus.contains("OPERATIVO")
            || normalizedStatus.contains("DISPONIBLE")
            || normalizedStatus == "ACTIVE" {
            return BrandColor.green
        }
        if normalizedStatus.contains("MANTENIMIENTO")
            || normalizedStatus.contains("PROCESO") {
            return BrandColor.amber
        }
        return BrandColor.red
    }
}

private struct EquipmentInfoCell: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandColor.red)
                .frame(width: 24, height: 24)
                .background(BrandColor.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private enum EquipmentDetailSection: String, CaseIterable, Identifiable {
    case components
    case preventiveMaintenance
    case maintenanceHistory

    var id: Self { self }

    var title: String {
        switch self {
        case .components: "Componentes internos"
        case .preventiveMaintenance: "Mantenimientos preventivos"
        case .maintenanceHistory: "Mantenimientos realizados"
        }
    }
}

struct AssetDetailView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var assetStore: AssetStore
    let assetID: String
    @State private var isPresentingComponentAdmin = false
    @State private var isPresentingEditor = false
    @State private var isConfirmingArchive = false
    @State private var administrationError: String?
    @State private var selectedSection: EquipmentDetailSection = .components

    var body: some View {
        Group {
            if let equipment = assetStore.details[assetID] {
                GeometryReader { geometry in
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppSpacing.lg) {
                            header(equipment)
                            overview(
                                equipment,
                                isWide: geometry.size.width >= 900
                            )
                            sectionPicker
                            selectedSectionContent(equipment)
                        }
                        .padding(AppSpacing.lg)
                        .frame(maxWidth: 1_100, alignment: .leading)
                        .frame(maxWidth: .infinity)
                    }
                    .refreshable {
                        await assetStore.loadDetail(id: assetID, session: session, force: true)
                    }
                }
            } else if assetStore.loadingDetailIDs.contains(assetID) {
                ProgressView("Cargando detalle del equipo")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = assetStore.detailErrors[assetID] {
                ContentUnavailableView {
                    Label("No se pudo cargar el equipo", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Reintentar") {
                        Task {
                            await assetStore.loadDetail(
                                id: assetID,
                                session: session,
                                force: true
                            )
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Detalle de equipo")
        .task {
            await assetStore.loadDetail(id: assetID, session: session)
        }
        .sheet(isPresented: $isPresentingComponentAdmin) {
            if let equipment = assetStore.details[assetID] {
                ComponentAdministrationSheet(
                    equipment: equipment,
                    nodes: assetStore.trees[assetID] ?? [],
                    canFullyAdminister: session.currentUser?.role == .administrator
                )
                .environmentObject(session)
                .environmentObject(assetStore)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .fullScreenCover(isPresented: $isPresentingEditor) {
            if let equipment = assetStore.details[assetID] {
                EquipmentEditorView(equipment: equipment) {
                    await assetStore.loadDetail(id: assetID, session: session, force: true)
                }
                .environmentObject(session)
                .environmentObject(assetStore)
            }
        }
        .alert("Dar de baja el equipo", isPresented: $isConfirmingArchive) {
            Button("Cancelar", role: .cancel) {}
            Button("Dar de baja", role: .destructive) {
                Task { await archiveEquipment() }
            }
        } message: {
            Text("El equipo conservará sus componentes e historial, pero quedará marcado como dado de baja.")
        }
        .alert("No se pudo completar la acción", isPresented: Binding(
            get: { administrationError != nil },
            set: { if !$0 { administrationError = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(administrationError ?? "Error desconocido")
        }
    }

    private func header(_ equipment: EquipmentDTO) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            EquipmentThumbnail(equipment: equipment, size: 72)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: AppSpacing.sm) {
                    Text(equipment.serialOrCode)
                        .font(.title2.bold())
                    EquipmentStatusBadge(status: equipment.status)
                }
                Text(equipment.name)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Label(
                    equipment.physicalLocation.activityLocationSummary,
                    systemImage: "mappin.and.ellipse"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if session.currentUser?.role == .administrator {
                HStack(spacing: AppSpacing.sm) {
                    Button {
                        isPresentingEditor = true
                    } label: {
                        Label("Editar equipo", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)
                    .tint(BrandColor.red)

                    Menu {
                        Button(role: .destructive) {
                            isConfirmingArchive = true
                        } label: {
                            Label("Dar de baja", systemImage: "archivebox")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 38, height: 38)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Más acciones del equipo")
                }
            }
        }
    }

    @ViewBuilder
    private func overview(_ equipment: EquipmentDTO, isWide: Bool) -> some View {
        if isWide {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                information(equipment)
                    .frame(maxWidth: .infinity)
                EquipmentAssetPhotoPanel(equipment: equipment)
                    .frame(width: 330)
            }
        } else {
            VStack(spacing: AppSpacing.md) {
                information(equipment)
                EquipmentAssetPhotoPanel(equipment: equipment)
            }
        }
    }

    private func information(_ equipment: EquipmentDTO) -> some View {
        ContentGlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Información general")
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 180), spacing: AppSpacing.md)],
                    alignment: .leading,
                    spacing: AppSpacing.md
                ) {
                    EquipmentInfoCell(
                        title: "Categoría",
                        value: equipment.category,
                        symbol: "square.stack.3d.up"
                    )
                    EquipmentInfoCell(
                        title: "Tipo",
                        value: equipment.assetType,
                        symbol: "point.3.connected.trianglepath.dotted"
                    )
                    EquipmentInfoCell(
                        title: "Ubicación",
                        value: equipment.physicalLocation.activityLocationSummary,
                        symbol: "mappin.and.ellipse"
                    )
                    EquipmentInfoCell(
                        title: "Subsistema",
                        value: equipment.subsystem,
                        symbol: "square.3.layers.3d"
                    )
                    if let manufacturer = equipment.manufacturer, !manufacturer.isEmpty {
                        EquipmentInfoCell(
                            title: "Fabricante",
                            value: manufacturer,
                            symbol: "building.2"
                        )
                    }
                    if let model = equipment.model, !model.isEmpty {
                        EquipmentInfoCell(
                            title: "Modelo",
                            value: model,
                            symbol: "tag"
                        )
                    }
                    if let partNumber = equipment.partNumber, !partNumber.isEmpty {
                        EquipmentInfoCell(
                            title: "Part number",
                            value: partNumber,
                            symbol: "number"
                        )
                    }
                    if let softwareVersion = equipment.softwareVersion, !softwareVersion.isEmpty {
                        EquipmentInfoCell(
                            title: "Versión de software",
                            value: softwareVersion,
                            symbol: "cpu"
                        )
                    }
                    if let currentPosition = equipment.currentPosition, !currentPosition.isEmpty {
                        EquipmentInfoCell(
                            title: "Posición",
                            value: currentPosition,
                            symbol: "scope"
                        )
                    }
                }
            }
        }
    }

    private var sectionPicker: some View {
        Picker("Contenido del equipo", selection: $selectedSection) {
            ForEach(EquipmentDetailSection.allCases) { section in
                Text(section.title).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityHint("Selecciona la información que deseas consultar")
    }

    @ViewBuilder
    private func selectedSectionContent(_ equipment: EquipmentDTO) -> some View {
        switch selectedSection {
        case .components:
            componentTree(equipment)
        case .preventiveMaintenance:
            EquipmentPreventiveTemplatesPanel(
                assetID: assetID,
                equipmentName: equipment.name,
                location: equipment.physicalLocation
            )
        case .maintenanceHistory:
            maintenanceHistory
        }
    }

    private func componentTree(_ equipment: EquipmentDTO) -> some View {
        EquipmentComponentTreePanel(
            equipmentID: assetID,
            componentCount: equipment.componentCount,
            nodes: assetStore.trees[assetID] ?? [],
            canFullyAdminister: session.currentUser?.role == .administrator
        ) {
            isPresentingComponentAdmin = true
        }
    }

    private var maintenanceHistory: some View {
        ContentGlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Mantenimientos realizados",
                    subtitle: "Historico exclusivo de este equipo"
                )

                let entries = assetStore.histories[assetID] ?? []
                if entries.isEmpty {
                    Text("Aun no hay mantenimientos realizados para este equipo.")
                        .foregroundStyle(.secondary)
                } else {
                    GlassEffectContainer(spacing: AppSpacing.sm) {
                        LazyVStack(alignment: .leading, spacing: AppSpacing.sm) {
                            ForEach(entries) { entry in
                                if entry.versionNumber != nil {
                                    NavigationLink {
                                        PDFPreviewView(versionID: entry.reportID)
                                    } label: {
                                        EquipmentMaintenanceRow(entry: entry, showsDisclosure: true)
                                    }
                                    .buttonStyle(.plain)
                                } else if let activityID = entry.activityID {
                                    NavigationLink {
                                        if entry.reportType == "corrective" {
                                            CorrectiveDetailView(eventID: activityID)
                                        } else {
                                            PreventiveDetailView(activityID: activityID)
                                        }
                                    } label: {
                                        EquipmentMaintenanceRow(entry: entry, showsDisclosure: true)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    EquipmentMaintenanceRow(entry: entry, showsDisclosure: false)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @MainActor
    private func archiveEquipment() async {
        do {
            try await assetStore.archiveEquipment(id: assetID, session: session)
        } catch {
            administrationError = error.localizedDescription
        }
    }
}

private struct EquipmentComponentTreePanel: View {
    let equipmentID: String
    let componentCount: Int
    let nodes: [EquipmentTreeNodeDTO]
    let canFullyAdminister: Bool
    let onAdminister: () -> Void
    @State private var branches: [EquipmentTreeBranch]
    @State private var expandedNodeIDs: Set<String> = []

    init(
        equipmentID: String,
        componentCount: Int,
        nodes: [EquipmentTreeNodeDTO],
        canFullyAdminister: Bool,
        onAdminister: @escaping () -> Void
    ) {
        self.equipmentID = equipmentID
        self.componentCount = componentCount
        self.nodes = nodes
        self.canFullyAdminister = canFullyAdminister
        self.onAdminister = onAdminister
        self._branches = State(
            initialValue: EquipmentTreeBranch.build(
                nodes: nodes,
                rootID: equipmentID
            )
        )
    }

    var body: some View {
        ContentGlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .center, spacing: AppSpacing.md) {
                    SectionHeaderText(
                        title: "Componentes internos",
                        subtitle: "\(componentCount) activos descendientes"
                    )
                    Spacer()
                    Button(action: onAdminister) {
                        Label(
                            canFullyAdminister ? "Administrar componentes" : "Agregar componente",
                            systemImage: canFullyAdminister ? "slider.horizontal.3" : "plus"
                        )
                    }
                    .buttonStyle(.glass)
                }

                if branches.isEmpty {
                    Text("Este equipo no tiene componentes registrados.")
                        .foregroundStyle(.secondary)
                } else {
                    LazyVStack(alignment: .leading, spacing: AppSpacing.xs) {
                        ForEach(branches) { branch in
                            EquipmentTreeBranchView(
                                branch: branch,
                                expandedNodeIDs: $expandedNodeIDs
                            )
                        }
                    }
                }
            }
        }
        .onChange(of: nodeSignature) { _, _ in
            branches = EquipmentTreeBranch.build(
                nodes: nodes,
                rootID: equipmentID
            )
            expandedNodeIDs.removeAll()
        }
    }

    private var nodeSignature: String {
        nodes.map(\.id).joined(separator: "|")
    }
}

private struct ComponentAdministrationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var assetStore: AssetStore
    let equipment: EquipmentDTO
    let nodes: [EquipmentTreeNodeDTO]
    let canFullyAdminister: Bool

    @State private var mode: AssetComponentOperation.Action = .create
    @State private var selectedComponentID = ""
    @State private var selectedParentID = ""
    @State private var destinationEquipmentID = ""
    @State private var name = ""
    @State private var category = "Componente"
    @State private var assetType = "Componente no tipificado"
    @State private var status = "OPERATIVO"
    @State private var serialNumber = ""
    @State private var partNumber = ""
    @State private var model = ""
    @State private var position = ""
    @State private var operations: [AssetComponentOperation] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var selectedComponent: EquipmentTreeNodeDTO? {
        nodes.first { $0.id == selectedComponentID }
    }

    private var moveDestinations: [EquipmentDTO] {
        assetStore.equipments.filter { $0.id != equipment.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    header
                    operationPanel
                    editorPanel

                    GlassPanel {
                        ActionButtonGrid {
                            Button(action: stageOperation) {
                                Label("Agregar cambio al lote", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(ActionTileButtonStyle(prominent: true))
                            .disabled(!canStageOperation)
                        }
                    }

                    if !operations.isEmpty {
                        pendingOperationsPanel
                    }

                    if let errorMessage {
                        GlassPanel {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                                .foregroundStyle(BrandColor.red)
                        }
                    }
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: 900, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(MaintenanceScreenBackground())
            .navigationTitle(canFullyAdminister ? "Administrar componentes" : "Agregar componente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                GlassPanel {
                    ActionButtonGrid {
                        Button("Cancelar", action: dismiss.callAsFunction)
                            .buttonStyle(ActionTileButtonStyle())
                        Button {
                            Task { await save() }
                        } label: {
                            if isSaving {
                                ProgressView()
                            } else {
                                Label("Guardar cambios", systemImage: "checkmark.circle.fill")
                            }
                        }
                        .buttonStyle(ActionTileButtonStyle(prominent: true))
                        .disabled(operations.isEmpty || isSaving)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.sm)
            }
            .task {
                selectedParentID = equipment.id
                if assetStore.equipments.isEmpty {
                    await assetStore.loadEquipments(query: "", subsystem: nil, session: session)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Equipo")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(BrandColor.red)
            Text(canFullyAdminister ? "Administrar componentes" : "Agregar componente")
                .font(.system(.largeTitle, design: .rounded).weight(.black))
            Text(equipment.name)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(
                canFullyAdminister
                    ? "Agrupa cambios antes de guardarlos para agregar, editar, mover o eliminar componentes."
                    : "Registra uno o más componentes dentro de este equipo."
            )
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var operationPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Operación",
                    subtitle: "Elige el cambio que deseas preparar"
                )
                if canFullyAdminister {
                    Picker("Acción", selection: $mode) {
                        Text("Agregar").tag(AssetComponentOperation.Action.create)
                        Text("Editar").tag(AssetComponentOperation.Action.update)
                        Text("Mover").tag(AssetComponentOperation.Action.move)
                        Text("Eliminar").tag(AssetComponentOperation.Action.delete)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) { _, _ in resetForm() }
                } else {
                    Label("Agregar", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundStyle(BrandColor.red)
                }
            }
        }
    }

    @ViewBuilder
    private var editorPanel: some View {
        if mode == .create {
            GlassPanel {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    SectionHeaderText(
                        title: "Nuevo componente",
                        subtitle: "Define su padre y los datos disponibles"
                    )
                    componentParentPicker
                    componentFields
                }
            }
        } else {
            GlassPanel {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    SectionHeaderText(
                        title: "Componente",
                        subtitle: "Selecciona el componente que vas a modificar"
                    )
                    componentPicker

                    if mode == .update, !selectedComponentID.isEmpty {
                        Divider()
                        SectionHeaderText(title: "Datos del componente")
                        componentFields
                    }

                    if mode == .move, !selectedComponentID.isEmpty {
                        Divider()
                        destinationPicker
                    }

                    if mode == .delete, !selectedComponentID.isEmpty {
                        Divider()
                        Label(
                            "Solo se eliminan componentes sin hijos ni historial asociado.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var componentParentPicker: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            fieldLabel("Componente padre")
            Picker("Componente padre", selection: $selectedParentID) {
                Text("\(equipment.name) (raíz)").tag(equipment.id)
                ForEach(nodes) { node in
                    Text(nodeDisplayName(node)).tag(node.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.sm)
            .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var componentPicker: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            fieldLabel("Seleccionar componente")
            Picker("Seleccionar componente", selection: $selectedComponentID) {
                Text("Seleccione un componente").tag("")
                ForEach(nodes) { node in
                    Text(nodeDisplayName(node)).tag(node.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.sm)
            .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onChange(of: selectedComponentID) { _, _ in populateSelectedComponent() }
        }
    }

    private var destinationPicker: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            SectionHeaderText(
                title: "Equipo destino",
                subtitle: "El componente se moverá con sus datos actuales"
            )
            Picker("Mover a", selection: $destinationEquipmentID) {
                Text("Seleccione un equipo").tag("")
                ForEach(moveDestinations) { destination in
                    Text(destination.name).tag(destination.id)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.sm)
            .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var pendingOperationsPanel: some View {
        ContentGlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Cambios pendientes (\(operations.count))",
                    subtitle: "Se aplicarán juntos al guardar"
                )
                ForEach(operations) { operation in
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: symbol(for: operation.action))
                            .font(.title3)
                            .foregroundStyle(BrandColor.red)
                        Text(operationSummary(operation))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Button(role: .destructive) {
                            operations.removeAll { $0.id == operation.id }
                        } label: {
                            Image(systemName: "trash")
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(AppSpacing.sm)
                    .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private var componentFields: some View {
        field("Nombre", text: $name)
        field("Categoría", text: $category)
        field("Tipo", text: $assetType)
        field("Estado", text: $status)
        field("Número de serie", text: $serialNumber)
        field("Part number", text: $partNumber)
        field("Modelo", text: $model)
        field("Posición", text: $position)
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            fieldLabel(title)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }

    private var canStageOperation: Bool {
        switch mode {
        case .create:
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .update, .delete:
            return !selectedComponentID.isEmpty
        case .move:
            return !selectedComponentID.isEmpty && !destinationEquipmentID.isEmpty
        }
    }

    private func stageOperation() {
        errorMessage = nil
        let operation = AssetComponentOperation(
            action: mode,
            componentID: mode == .create ? nil : selectedComponentID,
            parentID: mode == .create
                ? selectedParentID
                : mode == .move ? destinationEquipmentID : nil,
            name: mode == .delete || mode == .move ? nil : name,
            category: mode == .create || mode == .update ? category : nil,
            assetType: mode == .create || mode == .update ? assetType : nil,
            status: mode == .create || mode == .update ? status : nil,
            serialNumber: mode == .create || mode == .update ? serialNumber : nil,
            partNumber: mode == .create || mode == .update ? partNumber : nil,
            model: mode == .create || mode == .update ? model : nil,
            currentPosition: mode == .create || mode == .update ? position : nil
        )
        operations.append(operation)
        resetForm()
    }

    private func populateSelectedComponent() {
        guard let node = selectedComponent else { return }
        name = node.name
        category = node.category
        assetType = node.assetType
        status = node.status
        serialNumber = node.serialNumber ?? ""
        partNumber = node.partNumber ?? ""
        model = node.model ?? ""
        position = node.position ?? ""
    }

    private func resetForm() {
        selectedComponentID = ""
        destinationEquipmentID = ""
        selectedParentID = equipment.id
        name = ""
        category = "Componente"
        assetType = "Componente no tipificado"
        status = "OPERATIVO"
        serialNumber = ""
        partNumber = ""
        model = ""
        position = ""
        errorMessage = nil
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            try await assetStore.applyComponentChanges(
                rootID: equipment.id,
                operations: operations,
                session: session
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private func nodeDisplayName(_ node: EquipmentTreeNodeDTO) -> String {
        "\(node.name) · \(node.assetType)"
    }

    private func operationSummary(_ operation: AssetComponentOperation) -> String {
        switch operation.action {
        case .create: return "Agregar \(operation.name ?? "componente")"
        case .update: return "Editar \(operation.name ?? selectedComponent?.name ?? "componente")"
        case .move: return "Mover componente a otro equipo"
        case .delete: return "Eliminar componente"
        }
    }

    private func symbol(for action: AssetComponentOperation.Action) -> String {
        switch action {
        case .create: return "plus.circle.fill"
        case .update: return "pencil.circle.fill"
        case .move: return "arrow.right.circle.fill"
        case .delete: return "trash.circle.fill"
        }
    }
}

private struct EquipmentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var assetStore: AssetStore

    let equipment: EquipmentDTO?
    let onSaved: () async -> Void

    @State private var name: String
    @State private var code: String
    @State private var selectedCategoryName: String
    @State private var selectedCategoryID: String
    @State private var selectedSubsystemID: String
    @State private var selectedStatusID: String
    @State private var locationLevel1ID = ""
    @State private var locationLevel2ID = ""
    @State private var locationLevel3ID = ""
    @State private var locationLevel4ID: String
    @State private var manufacturer: String
    @State private var model: String
    @State private var partNumber: String
    @State private var softwareVersion: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingImageData: Data?
    @State private var existingImages: [EquipmentImageDTO]
    @State private var showCamera = false
    @State private var isSaving = false
    @State private var deletingImageID: String?
    @State private var errorMessage: String?
    @State private var didResolveInitialCatalog = false

    init(equipment: EquipmentDTO?, onSaved: @escaping () async -> Void) {
        self.equipment = equipment
        self.onSaved = onSaved
        _name = State(initialValue: equipment?.name ?? "")
        _code = State(initialValue: equipment?.serialOrCode ?? "")
        _selectedCategoryName = State(initialValue: equipment?.category ?? "")
        _selectedCategoryID = State(initialValue: equipment?.equipmentCategoryID ?? "")
        _selectedSubsystemID = State(initialValue: equipment?.subsystemID ?? "")
        _selectedStatusID = State(initialValue: equipment?.statusID ?? "")
        _locationLevel4ID = State(initialValue: equipment?.geographicLocationID ?? "")
        _manufacturer = State(initialValue: equipment?.manufacturer ?? "")
        _model = State(initialValue: equipment?.model ?? "")
        _partNumber = State(initialValue: equipment?.partNumber ?? "")
        _softwareVersion = State(initialValue: equipment?.softwareVersion ?? "")
        _existingImages = State(initialValue: equipment?.galleryImages ?? [])
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        editorHeader
                        if geometry.size.width >= 820 {
                            HStack(alignment: .top, spacing: AppSpacing.lg) {
                                fieldsPanel
                                    .frame(maxWidth: .infinity)
                                imagesPanel
                                    .frame(width: 340)
                            }
                        } else {
                            fieldsPanel
                            imagesPanel
                        }
                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                                .foregroundStyle(BrandColor.red)
                                .padding(AppSpacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(BrandColor.red.opacity(0.08), in: .rect(cornerRadius: 10))
                        }
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: 1_120, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(MaintenanceScreenBackground())
            .navigationTitle(equipment == nil ? "Nuevo equipo" : "Editar equipo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Label("Guardar", systemImage: "checkmark")
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .onChange(of: selectedPhoto) { _, photo in
                guard let photo else { return }
                Task { await loadPhoto(photo) }
            }
            .task {
                await assetStore.loadAdministrationCatalog(session: session)
                resolveInitialCatalogSelection()
            }
            .onChange(of: assetStore.administrationCatalog != nil) { _, loaded in
                if loaded { resolveInitialCatalogSelection() }
            }
            .sheet(isPresented: $showCamera) {
                CameraPhotoPicker { image in
                    setImage(image)
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private var editorHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(equipment == nil ? "Registrar equipo" : "Información del equipo")
                .font(.title.bold())
            Text("Los cambios se reflejan en el inventario, la programación y los reportes futuros.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var fieldsPanel: some View {
        ContentGlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SectionHeaderText(
                    title: "Datos del equipo",
                    subtitle: "Identificación, clasificación y ubicación operativa"
                )
                catalogLoadState
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 220), spacing: AppSpacing.md)],
                    alignment: .leading,
                    spacing: AppSpacing.md
                ) {
                    editorField("Nombre", text: $name, symbol: "square.stack.3d.up")
                    editorField("Código o serie", text: $code, symbol: "barcode")
                    subsystemField
                    categoryField
                    typeField
                    statusField
                    locationField(
                        "Ubicación nivel 1",
                        selection: locationSelection(level: 1),
                        options: locationOptions(level: 1, parentID: nil)
                    )
                    locationField(
                        "Ubicación nivel 2",
                        selection: locationSelection(level: 2),
                        options: locationOptions(level: 2, parentID: locationLevel1ID)
                    )
                    locationField(
                        "Ubicación nivel 3",
                        selection: locationSelection(level: 3),
                        options: locationOptions(level: 3, parentID: locationLevel2ID)
                    )
                    locationField(
                        "Ubicación nivel 4",
                        selection: locationSelection(level: 4),
                        options: locationOptions(level: 4, parentID: locationLevel3ID)
                    )
                    editorField("Fabricante", text: $manufacturer, symbol: "building.2")
                    editorField("Modelo", text: $model, symbol: "tag")
                    editorField("Part number", text: $partNumber, symbol: "number")
                    editorField("Versión de software", text: $softwareVersion, symbol: "cpu")
                }
            }
        }
    }

    @ViewBuilder
    private var catalogLoadState: some View {
        if assetStore.isLoadingAdministrationCatalog {
            HStack(spacing: AppSpacing.sm) {
                ProgressView()
                Text("Cargando catálogos desde la base de datos...")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.md)
            .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 8))
        } else if let catalogError = assetStore.administrationCatalogError {
            HStack(spacing: AppSpacing.md) {
                Label(catalogError, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(BrandColor.red)
                Spacer()
                Button("Reintentar") {
                    Task {
                        await assetStore.loadAdministrationCatalog(session: session, force: true)
                        didResolveInitialCatalog = false
                        resolveInitialCatalogSelection()
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(AppSpacing.md)
            .background(BrandColor.red.opacity(0.08), in: .rect(cornerRadius: 8))
        }
    }

    private var subsystemField: some View {
        MaintenanceChoiceField(
            "Subsistema",
            systemImage: "square.3.layers.3d",
            selection: subsystemSelection
        ) {
            Text(catalog == nil ? "Cargando..." : "Seleccionar").tag("")
            ForEach(catalog?.subsystems ?? []) { option in
                Text(option.code ?? option.name).tag(option.id)
            }
        }
        .disabled(catalog == nil)
    }

    private var categoryField: some View {
        MaintenanceChoiceField("Categoría", systemImage: "tag", selection: categorySelection) {
            Text(catalog == nil ? "Cargando..." : "Seleccionar").tag("")
            ForEach(categoryNames, id: \.self) { name in
                Text(name).tag(name)
            }
        }
        .disabled(catalog == nil || selectedSubsystemID.isEmpty)
    }

    private var typeField: some View {
        MaintenanceChoiceField(
            "Tipo",
            systemImage: "point.3.connected.trianglepath.dotted",
            selection: $selectedCategoryID
        ) {
            Text(catalog == nil ? "Cargando..." : "Seleccionar").tag("")
            ForEach(typeOptions) { option in
                Text(option.nameN2).tag(option.id)
            }
        }
        .disabled(catalog == nil || selectedCategoryName.isEmpty)
    }

    private var statusField: some View {
        MaintenanceChoiceField("Estado", systemImage: "checkmark.seal", selection: $selectedStatusID) {
            Text(catalog == nil ? "Cargando..." : "Seleccionar").tag("")
            ForEach(catalog?.statuses ?? []) { option in
                Text(option.name).tag(option.id)
            }
        }
        .disabled(catalog == nil)
    }

    private func locationField(
        _ title: String,
        selection: Binding<String>,
        options: [EquipmentLocationOption]
    ) -> some View {
        MaintenanceChoiceField(title, systemImage: "mappin.and.ellipse", selection: selection) {
            Text(catalog == nil ? "Cargando..." : "Seleccionar").tag("")
            ForEach(options) { option in
                Text(option.name).tag(option.id)
            }
        }
        .disabled(catalog == nil || (title != "Ubicación nivel 1" && options.isEmpty))
    }

    private func editorField(
        _ title: String,
        text: Binding<String>,
        symbol: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
        }
    }

    private var catalog: EquipmentAdministrationCatalog? {
        assetStore.administrationCatalog
    }

    private var subsystemSelection: Binding<String> {
        Binding(
            get: { selectedSubsystemID },
            set: { value in
                guard value != selectedSubsystemID else { return }
                selectedSubsystemID = value
                selectedCategoryName = ""
                selectedCategoryID = ""
            }
        )
    }

    private var categorySelection: Binding<String> {
        Binding(
            get: { selectedCategoryName },
            set: { value in
                guard value != selectedCategoryName else { return }
                selectedCategoryName = value
                selectedCategoryID = ""
            }
        )
    }

    private func locationSelection(level: Int) -> Binding<String> {
        Binding(
            get: {
                switch level {
                case 1: return locationLevel1ID
                case 2: return locationLevel2ID
                case 3: return locationLevel3ID
                default: return locationLevel4ID
                }
            },
            set: { value in
                switch level {
                case 1:
                    guard value != locationLevel1ID else { return }
                    locationLevel1ID = value
                    locationLevel2ID = ""
                    locationLevel3ID = ""
                    locationLevel4ID = ""
                case 2:
                    guard value != locationLevel2ID else { return }
                    locationLevel2ID = value
                    locationLevel3ID = ""
                    locationLevel4ID = ""
                case 3:
                    guard value != locationLevel3ID else { return }
                    locationLevel3ID = value
                    locationLevel4ID = ""
                default:
                    locationLevel4ID = value
                }
            }
        )
    }

    private var categoryNames: [String] {
        Array(
            Set(
                (catalog?.categories ?? [])
                    .filter { $0.subsystemID == selectedSubsystemID }
                    .map(\.nameN1)
            )
        ).sorted()
    }

    private var typeOptions: [EquipmentCategoryOption] {
        (catalog?.categories ?? []).filter {
            $0.subsystemID == selectedSubsystemID && $0.nameN1 == selectedCategoryName
        }
    }

    private func locationOptions(level: Int, parentID: String?) -> [EquipmentLocationOption] {
        guard let catalog else { return [] }
        return catalog.locations.filter { option in
            guard option.level == level else { return false }
            if level == 1 { return option.parentID == nil }
            return !(parentID ?? "").isEmpty && option.parentID == parentID
        }
    }

    private func resolveInitialCatalogSelection() {
        guard !didResolveInitialCatalog, let catalog else { return }
        defer { didResolveInitialCatalog = true }

        if selectedSubsystemID.isEmpty, let equipment {
            selectedSubsystemID = catalog.subsystems.first {
                $0.code?.caseInsensitiveCompare(equipment.subsystem) == .orderedSame
                    || $0.name.caseInsensitiveCompare(equipment.subsystem) == .orderedSame
            }?.id ?? ""
        }
        if selectedCategoryID.isEmpty, let equipment {
            selectedCategoryID = catalog.categories.first {
                $0.subsystemID == selectedSubsystemID
                    && $0.nameN1.caseInsensitiveCompare(equipment.category) == .orderedSame
                    && equipment.assetType.localizedCaseInsensitiveContains($0.nameN2)
            }?.id ?? ""
        }
        if let selectedCategory = catalog.categories.first(where: { $0.id == selectedCategoryID }) {
            selectedCategoryName = selectedCategory.nameN1
        }
        if selectedStatusID.isEmpty, let equipment {
            selectedStatusID = catalog.statuses.first {
                $0.name.caseInsensitiveCompare(equipment.status) == .orderedSame
                    || $0.code?.caseInsensitiveCompare(equipment.status) == .orderedSame
            }?.id ?? ""
        }
        guard !locationLevel4ID.isEmpty else { return }
        let byID = Dictionary(uniqueKeysWithValues: catalog.locations.map { ($0.id, $0) })
        var location = byID[locationLevel4ID]
        while let current = location {
            switch current.level {
            case 1: locationLevel1ID = current.id
            case 2: locationLevel2ID = current.id
            case 3: locationLevel3ID = current.id
            case 4: locationLevel4ID = current.id
            default: break
            }
            location = current.parentID.flatMap { byID[$0] }
        }
    }

    private var imagesPanel: some View {
        ContentGlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Imágenes",
                    subtitle: "La primera fotografía funciona como portada"
                )
                pendingImagePreview
                HStack(spacing: AppSpacing.sm) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Fototeca", systemImage: "photo.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    Button {
                        showCamera = true
                    } label: {
                        Label("Cámara", systemImage: "camera")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                }
                if let equipment, !existingImages.isEmpty {
                    Divider()
                    Text("Galería actual")
                        .font(.subheadline.weight(.semibold))
                    ForEach(existingImages) { image in
                        HStack(spacing: AppSpacing.sm) {
                            EquipmentRemoteImage(assetID: equipment.id, image: image) {
                                ProgressView()
                            }
                            .frame(width: 64, height: 52)
                            .clipShape(.rect(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(image.fileName)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                if image.isPrimary {
                                    Text("Portada")
                                        .font(.caption2)
                                        .foregroundStyle(BrandColor.red)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                Task { await deleteImage(image) }
                            } label: {
                                if deletingImageID == image.id {
                                    ProgressView()
                                } else {
                                    Image(systemName: "trash")
                                }
                            }
                            .disabled(deletingImageID != nil || isSaving)
                            .accessibilityLabel("Eliminar \(image.fileName)")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var pendingImagePreview: some View {
        if let pendingImageData, let image = UIImage(data: pendingImageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .background(Color.primary.opacity(0.04))
                .clipShape(.rect(cornerRadius: 10))
        } else {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "photo")
                    .font(.largeTitle)
                Text(equipment?.galleryImages.isEmpty == false ? "Agregar otra imagen" : "Sin imagen seleccionada")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 140)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5]))
            }
        }
    }

    private var canSave: Bool {
        [
            name,
            code,
            selectedCategoryID,
            selectedSubsystemID,
            selectedStatusID,
            locationLevel1ID,
            locationLevel2ID,
            locationLevel3ID,
            locationLevel4ID
        ]
            .allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && catalog != nil
    }

    @MainActor
    private func loadPhoto(_ photo: PhotosPickerItem) async {
        do {
            guard let data = try await photo.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            setImage(image)
        } catch {
            errorMessage = "No se pudo cargar la imagen seleccionada."
        }
    }

    private func setImage(_ image: UIImage) {
        pendingImageData = image.equipmentJPEGData(maxDimension: 1_800)
    }

    @MainActor
    private func deleteImage(_ image: EquipmentImageDTO) async {
        guard let equipment else { return }
        deletingImageID = image.id
        defer { deletingImageID = nil }
        do {
            try await assetStore.deleteImage(
                assetID: equipment.id,
                imageID: image.id,
                session: session
            )
            existingImages.removeAll { $0.id == image.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let clean: (String) -> String? = {
            let value = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        do {
            _ = try await assetStore.saveEquipment(
                id: equipment?.id,
                payload: EquipmentWritePayload(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    serial_or_code: code.trimmingCharacters(in: .whitespacesAndNewlines),
                    part_number: clean(partNumber),
                    equipment_category_id: selectedCategoryID,
                    subsystem_id: selectedSubsystemID,
                    status_id: selectedStatusID,
                    geographic_location_id: locationLevel4ID,
                    business_label: equipment?.businessLabel ?? "Equipo",
                    manufacturer: clean(manufacturer),
                    model: clean(model),
                    software_version: clean(softwareVersion)
                ),
                imageData: pendingImageData,
                session: session
            )
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension UIImage {
    func equipmentJPEGData(maxDimension: CGFloat) -> Data? {
        let largest = max(size.width, size.height)
        guard largest > 0 else { return nil }
        let scale = min(1, maxDimension / largest)
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let rendered = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: 0.82)
    }
}

private struct EquipmentAssetPhotoPanel: View {
    let equipment: EquipmentDTO

    var body: some View {
        ContentGlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Imágenes del equipo")

                if equipment.galleryImages.isEmpty {
                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: symbol)
                            .font(.system(size: 68, weight: .semibold))
                            .foregroundStyle(BrandColor.red.opacity(0.78))
                        Text("Sin imágenes registradas")
                            .font(.headline)
                        Text("El administrador puede agregarlas desde Editar equipo.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 260)
                    }
                    .frame(maxWidth: .infinity, minHeight: 176)
                    .background(
                        BrandColor.graphite.opacity(0.055),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                } else {
                    TabView {
                        ForEach(equipment.galleryImages) { image in
                            EquipmentRemoteImage(
                                assetID: equipment.id,
                                image: image,
                                contentMode: .fit
                            ) {
                                ProgressView()
                            }
                            .padding(6)
                            .tag(image.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: equipment.galleryImages.count > 1 ? .automatic : .never))
                    .frame(height: 208)
                    .background(
                        BrandColor.graphite.opacity(0.055),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Imágenes de \(equipment.name): \(equipment.galleryImages.count) registradas")
    }

    private var symbol: String {
        switch equipment.category {
        case "Vehículo": "tram.fill"
        case "Servidor": "server.rack"
        case "Equipo de vía": "point.topleft.down.curvedto.point.bottomright.up"
        default: "square.stack.3d.up.fill"
        }
    }
}

private struct EquipmentRemoteImage<Placeholder: View>: View {
    @EnvironmentObject private var session: SessionStore
    let assetID: String
    let image: EquipmentImageDTO
    var contentMode: ContentMode = .fill
    @ViewBuilder let placeholder: () -> Placeholder
    @State private var data: Data?

    var body: some View {
        Group {
            if let data, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: image.id) {
            guard data == nil,
                  let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else { return }
            let service = AssetService(baseURLString: baseURL)
            data = try? await session.withValidAccessToken { token in
                try await service.imageData(
                    assetID: assetID,
                    imageID: image.id,
                    accessToken: token
                )
            }
        }
    }
}

private struct EquipmentTreeBranch: Identifiable {
    let node: EquipmentTreeNodeDTO
    let children: [EquipmentTreeBranch]

    var id: String { node.id }

    static func build(
        nodes: [EquipmentTreeNodeDTO],
        rootID: String
    ) -> [EquipmentTreeBranch] {
        let grouped = Dictionary(grouping: nodes) { $0.parentID ?? "" }

        func descendants(of parentID: String, visited: Set<String>) -> [EquipmentTreeBranch] {
            (grouped[parentID] ?? []).compactMap { node in
                guard !visited.contains(node.id) else { return nil }
                return EquipmentTreeBranch(
                    node: node,
                    children: descendants(
                        of: node.id,
                        visited: visited.union([node.id])
                    )
                )
            }
        }

        let roots = descendants(of: rootID, visited: [rootID])
        if !roots.isEmpty {
            return roots
        }
        return nodes
            .filter { $0.depth == 1 }
            .map { node in
                EquipmentTreeBranch(
                    node: node,
                    children: descendants(of: node.id, visited: [node.id])
                )
            }
    }
}

private struct EquipmentTreeBranchView: View {
    let branch: EquipmentTreeBranch
    @Binding var expandedNodeIDs: Set<String>

    var body: some View {
        if branch.children.isEmpty {
            row
        } else {
            DisclosureGroup(isExpanded: expansionBinding) {
                LazyVStack(alignment: .leading, spacing: AppSpacing.xs) {
                    ForEach(branch.children) { child in
                        EquipmentTreeBranchView(
                            branch: child,
                            expandedNodeIDs: $expandedNodeIDs
                        )
                    }
                }
                .padding(.leading, AppSpacing.lg)
            } label: {
                row
            }
            .tint(BrandColor.red)
        }
    }

    private var expansionBinding: Binding<Bool> {
        Binding(
            get: { expandedNodeIDs.contains(branch.id) },
            set: { isExpanded in
                if isExpanded {
                    expandedNodeIDs.insert(branch.id)
                } else {
                    expandedNodeIDs.remove(branch.id)
                }
            }
        )
    }

    private var row: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: branch.children.isEmpty ? "cpu" : "shippingbox.fill")
                .foregroundStyle(BrandColor.red)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(branch.node.name)
                    .font(.headline)
                Text(branch.node.assetType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let slotPath = branch.node.slotPath {
                    Text(slotPath)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(branch.node.status)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, AppSpacing.xs)
    }
}

private struct EquipmentMaintenanceRow: View {
    let entry: EquipmentMaintenanceDTO
    let showsDisclosure: Bool

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: entry.reportType == "corrective" ? "wrench.fill" : "checklist")
                .font(.headline)
                .foregroundStyle(BrandColor.red)
                .frame(width: 40, height: 40)
                .background(
                    BrandColor.red.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                Text("\(typeLabel) · \(entry.result)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedDate)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                if let version = entry.versionNumber {
                    Text("Version \(version)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, AppSpacing.sm)
        .background(
            .background.opacity(0.60),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .glassEffect(
            .regular.tint(BrandColor.red.opacity(0.025)).interactive(),
            in: .rect(cornerRadius: 12)
        )
    }

    private var typeLabel: String {
        entry.reportType == "corrective" ? "Correctivo" : "Preventivo"
    }

    private var formattedDate: String {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        guard let date = fractional.date(from: entry.performedAt)
            ?? standard.date(from: entry.performedAt) else {
            return entry.performedAt
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

struct AssetSearchView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AssetSearchView()
                .environmentObject(SessionStore())
                .environmentObject(AssetStore())
        }
    }
}
