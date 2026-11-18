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
    let parentID: String?
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
        case parentID = "parent_id"
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

struct EquipmentTreeNodeDTO: Identifiable, Codable, Equatable {
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
        case assign = "ASSIGN"
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
    var expectedParentID: String? = nil
    var assetTypeID: String? = nil
    var newTypeName: String? = nil
    var newTypePartNumber: String? = nil
    var destinationEquipmentID: String? = nil

    enum CodingKeys: String, CodingKey {
        case action, name, category, status, model
        case componentID = "component_id"
        case parentID = "parent_id"
        case assetType = "asset_type"
        case serialNumber = "serial_number"
        case partNumber = "part_number"
        case currentPosition = "current_position"
        case expectedParentID = "expected_parent_id"
        case assetTypeID = "asset_type_id"
        case newTypeName = "new_type_name"
        case newTypePartNumber = "new_type_part_number"
        case destinationEquipmentID = "destination_equipment_id"
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

private struct ComponentDetailDTO: Decodable {
    let asset: EquipmentDTO
    let asset_type_id: String?
    let internal_code: String?
    let serial_number: String?
    let parent_name: String?
    let inventory_location: String?
    let slot: String?
    let manufacture_date: String?
}

private struct ComponentMovementDTO: Decodable, Identifiable {
    let id: String
    let kind: String
    let moved_at: String
    let origin: String?
    let destination: String?
    let from_status: String?
    let to_status: String?
    let notes: String?
}

private struct ComponentMovementPage: Decodable {
    let items: [ComponentMovementDTO]
    let total: Int
}

private struct EquipmentInternalSlot: Decodable, Identifiable {
    let id: String
    let name: String
    let parent_id: String?
    let path: String
    let accepts_asset: Bool
    let occupant_id: String?
    let occupant_name: String?
}

private struct InternalSlotWrite: Encodable {
    let name: String
    let parent_id: String?
    let accepts_asset: Bool
}

private struct ComponentEditorOptions: Decodable {
    struct Classification: Decodable, Hashable {
        let id: String
        let category: String
        let type: String
        let part_number: String?
        let serial_number_policy: String
    }
    let classifications: [Classification]
    let statuses: [String]
}

private struct InternalSlotOccupancy: Encodable {
    let component_id: String?
    let expected_occupant_id: String?
}

private struct ComponentWritePayload: Encodable {
    let name: String
    let serial_number: String
    let part_number: String?
    let manufacturer: String
    let model: String
    let software_version: String
    let status_id: String?
}

private struct AssetService {
    private let client: APIClient

    init(baseURLString: String) {
        client = APIClient(baseURLString: baseURLString)
    }

    func slots(id: String, accessToken: String) async throws -> [EquipmentInternalSlot] {
        try await client.get("api/v1/assets/\(id)/internal-slots", bearerToken: accessToken)
    }

    func addSlot(id: String, payload: InternalSlotWrite, accessToken: String) async throws -> [EquipmentInternalSlot] {
        try await client.post("api/v1/assets/\(id)/internal-slots", body: payload, bearerToken: accessToken)
    }

    func placeComponent(id: String, slotID: String, payload: InternalSlotOccupancy, accessToken: String) async throws -> [EquipmentInternalSlot] {
        try await client.put("api/v1/assets/\(id)/internal-slots/\(slotID)", body: payload, bearerToken: accessToken)
    }

    func list(
        query: String,
        subsystem: String?,
        category: String? = nil,
        status: String? = nil,
        businessAnchor: Bool = true,
        limit: Int = 200,
        offset: Int = 0,
        accessToken: String
    ) async throws -> EquipmentPageDTO {
        var queryItems = [
            URLQueryItem(name: "business_anchor", value: String(businessAnchor)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
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

    func component(id: String, accessToken: String) async throws -> ComponentDetailDTO {
        try await client.get("api/v1/assets/\(id)/component-detail", bearerToken: accessToken)
    }

    func updateComponent(id: String, payload: ComponentWritePayload, accessToken: String) async throws -> ComponentDetailDTO {
        try await client.put("api/v1/assets/\(id)/component-detail", body: payload, bearerToken: accessToken)
    }

    func movements(id: String, limit: Int, offset: Int, accessToken: String) async throws -> ComponentMovementPage {
        try await client.get(
            "api/v1/assets/\(id)/movements", bearerToken: accessToken,
            queryItems: [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
        )
    }

    func administrationCatalog(accessToken: String) async throws -> EquipmentAdministrationCatalog {
        try await client.get("api/v1/assets/administration/catalog", bearerToken: accessToken)
    }

    func componentEditorOptions(id: String, accessToken: String) async throws -> ComponentEditorOptions {
        try await client.get("api/v1/assets/\(id)/component-editor-options", bearerToken: accessToken)
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
        let reassignedIDs = Set(operations.filter { $0.action == .assign }.compactMap(\.componentID))
        let staleTreeIDs = trees.compactMap { id, nodes in
            id != rootID && nodes.contains(where: { reassignedIDs.contains($0.id) }) ? id : nil
        }
        for id in staleTreeIDs {
            trees.removeValue(forKey: id)
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
    @State private var showingComponents = false
    @State private var componentsRefresh = 0

    private let pageSize = 10

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 850
            let isNarrow = geometry.size.width < 650

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    pageHeader
                    Picker("Inventario", selection: $showingComponents) {
                        Text("Equipos").tag(false)
                        Text("Componentes").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if showingComponents {
                        ComponentInventoryList(isNarrow: isNarrow, refresh: componentsRefresh)
                    } else {
                        filters
                        results(
                            isWide: geometry.size.width >= 1_000,
                            isCompact: isCompact,
                            isNarrow: isNarrow
                        )
                    }
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
            if showingComponents { componentsRefresh += 1 } else { await load() }
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
                if !showingComponents && session.canEdit(.equipment) {
                    newEquipmentButton
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                pageTitle
                if !showingComponents && session.canEdit(.equipment) {
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
            Text(showingComponents
                 ? "Consulta los componentes y sus movimientos"
                 : "Consulta los equipos, su ubicación y estado operativo")
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

    private var filters: some View {
        CompactInventoryFilters(
            prompt: "Buscar equipo",
            query: $query,
            canClear: !query.isEmpty || !selectedCategory.isEmpty
                || !selectedSubsystem.isEmpty || !selectedStatus.isEmpty,
            onClear: {
                query = ""
                selectedCategory = ""
                selectedSubsystem = ""
                selectedStatus = ""
            }
        ) {
            CompactInventoryFilter(title: "Categoría", systemImage: "square.stack.3d.up", allLabel: "Todas",
                                   selection: $selectedCategory, options: assetStore.availableCategories)
            CompactInventoryFilter(title: "Subsistema", systemImage: "square.stack.3d.up.fill", allLabel: "Todos",
                                   selection: $selectedSubsystem, options: assetStore.availableSubsystems)
            CompactInventoryFilter(title: "Estado", systemImage: "checkmark.seal", allLabel: "Todos",
                                   selection: $selectedStatus, options: assetStore.availableStatuses)
        }
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

@MainActor
private func componentRequest<T>(
    session: SessionStore,
    _ operation: @escaping (AssetService, String) async throws -> T
) async throws -> T {
    let service = AssetService(baseURLString: UserDefaults.standard.string(forKey: "apiBaseURL") ?? "")
    return try await session.withValidAccessToken { token in
        try await operation(service, token)
    }
}

private struct ComponentInventoryList: View {
    @EnvironmentObject private var session: SessionStore
    @State private var query = ""
    @State private var page = 0
    @State private var revision = 0
    @State private var result: EquipmentPageDTO?
    @State private var error: String?
    @State private var loading = true
    let isNarrow: Bool
    let refresh: Int
    private let pageSize = 15

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            GlassPanel {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField("Buscar componente", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .font(.subheadline)
                .padding(.horizontal, AppSpacing.sm)
                .frame(minHeight: 44)
                .background(.background.opacity(0.72), in: .rect(cornerRadius: 8))
            }
            if loading {
                ProgressView("Cargando componentes").frame(maxWidth: .infinity)
            } else if let error {
                ContentUnavailableView {
                    Label("No se pudieron cargar los componentes", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Reintentar") { revision += 1 }
                }
            } else if let result, !result.items.isEmpty {
                Text("\(result.total) componentes").font(.title3.bold())
                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(result.items) { component in
                        NavigationLink {
                            ComponentDetailView(component: component) { revision += 1 }
                        } label: {
                            EquipmentCompactRow(equipment: component, isNarrow: isNarrow)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Abre el detalle del componente")
                    }
                }
                PaginationBar(currentPage: page, pageCount: (result.total + pageSize - 1) / pageSize) {
                    page = $0
                }
            } else {
                ContentUnavailableView("Sin componentes", systemImage: "shippingbox")
            }
        }
        .onChange(of: query) { page = 0 }
        .task(id: "\(page):\(revision):\(refresh):\(query)") { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let offset = page * pageSize
        do {
            if !term.isEmpty { try await Task.sleep(for: .milliseconds(250)) }
            let response = try await componentRequest(session: session) { service, token in
                try await service.list(query: term, subsystem: nil, businessAnchor: false,
                                       limit: pageSize, offset: offset, accessToken: token)
            }
            guard !Task.isCancelled else { return }
            result = response
            page = min(page, max(0, (response.total - 1) / pageSize))
            loading = false
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
            loading = false
        }
    }
}

private struct ComponentDetailView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var editing = false
    @State private var detail: ComponentDetailDTO?
    @State private var error: String?
    let assetID: String
    let initialName: String
    let onSaved: () -> Void
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showCamera = false
    @State private var uploading = false

    init(component: EquipmentDTO, onSaved: @escaping () -> Void) {
        assetID = component.id
        initialName = component.name
        self.onSaved = onSaved
    }

    init(assetID: String, name: String, onSaved: @escaping () -> Void = {}) {
        self.assetID = assetID
        initialName = name
        self.onSaved = onSaved
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    if let detail {
                        header(detail.asset)
                        if geometry.size.width >= 900 {
                            HStack(alignment: .top, spacing: AppSpacing.md) {
                                detailsPanel(detail)
                                photos(detail.asset).frame(width: 330)
                            }
                        } else {
                            detailsPanel(detail)
                            photos(detail.asset)
                        }
                        ComponentMovementsPanel(id: assetID)
                        if let error { Text(error).foregroundStyle(BrandColor.red) }
                    } else if let error {
                        ContentUnavailableView {
                            Label("No se pudo cargar el componente", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(error)
                        } actions: {
                            Button("Reintentar") { Task { await load() } }
                        }
                    } else {
                        ProgressView(initialName).frame(maxWidth: .infinity)
                    }
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: 1_100)
                .frame(maxWidth: .infinity)
            }
            .refreshable { await load() }
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Detalle del componente")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onChange(of: selectedPhoto) { _, photo in
            guard let photo else { return }
            Task {
                do {
                    guard let data = try await photo.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    await upload(image)
                } catch { self.error = error.localizedDescription }
                selectedPhoto = nil
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPhotoPicker { image in
                showCamera = false
                Task { await upload(image) }
            }
        }
        .sheet(isPresented: $editing) {
            if let detail {
                ComponentEditorView(detail: detail) { updated in
                    self.detail = updated
                    onSaved()
                }
            }
        }
    }

    private func header(_ asset: EquipmentDTO) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.md) {
                identity(asset)
                Spacer(minLength: AppSpacing.sm)
                editButton
            }
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                identity(asset)
                editButton
            }
        }
    }

    private func identity(_ asset: EquipmentDTO) -> some View {
        HStack(spacing: AppSpacing.md) {
            EquipmentThumbnail(equipment: asset, size: 72)
            VStack(alignment: .leading, spacing: 4) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppSpacing.sm) {
                        Text(asset.serialOrCode).font(.title2.bold())
                        EquipmentStatusBadge(status: asset.status)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(asset.serialOrCode).font(.title2.bold())
                        EquipmentStatusBadge(status: asset.status)
                    }
                }
                Text(asset.name).font(.headline).foregroundStyle(.secondary)
                Label(asset.physicalLocation.activityLocationSummary, systemImage: "mappin.and.ellipse")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var editButton: some View {
        if session.currentUser?.role == .administrator {
            Button("Editar componente", systemImage: "pencil") { editing = true }
                .buttonStyle(.bordered)
                .tint(BrandColor.red)
                .fixedSize()
        }
    }

    private func photos(_ asset: EquipmentDTO) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            EquipmentAssetPhotoPanel(equipment: asset)
            if session.currentUser?.role == .administrator {
                HStack(spacing: AppSpacing.sm) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Fototeca", systemImage: "photo.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    Button("Cámara", systemImage: "camera") { showCamera = true }
                        .buttonStyle(.bordered)
                        .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                    if uploading { ProgressView() }
                }
                .disabled(uploading)
            }
        }
    }

    private func detailsPanel(_ detail: ComponentDetailDTO) -> some View {
        let asset = detail.asset
        return ContentGlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Información general")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), alignment: .leading)],
                          spacing: AppSpacing.md) {
                    field("Código interno", detail.internal_code ?? asset.serialOrCode, "barcode")
                    field("Número de serie", detail.serial_number, "number")
                    field("Número de parte", asset.partNumber, "tag")
                    field("Estado", asset.status, "checkmark.seal")
                    field("Categoría", asset.category, "square.stack.3d.up")
                    field("Tipo", asset.assetType, "shippingbox")
                    field("Subsistema", asset.subsystem, "square.3.layers.3d")
                    field("Equipo o componente padre", detail.parent_name, "point.3.connected.trianglepath.dotted")
                    field("Ubicación física", asset.physicalLocation, "mappin")
                    field("Ubicación de inventario", detail.inventory_location, "building.2")
                    field("Posición", detail.slot ?? asset.currentPosition, "scope")
                    field("Fabricante", asset.manufacturer, "building")
                    field("Modelo", asset.model, "wrench.and.screwdriver")
                    field("Versión de software", asset.softwareVersion, "cpu")
                    field("Fecha de fabricación", detail.manufacture_date, "calendar")
                    field("Clasificación", asset.businessLabel, "tag")
                }
            }
        }
    }

    private func field(_ title: String, _ value: String?, _ symbol: String) -> some View {
        EquipmentInfoCell(title: title, value: value.flatMap { $0.isEmpty ? nil : $0 } ?? "—",
                          symbol: symbol, maxLines: nil)
    }

    private func load() async {
        error = nil
        do {
            detail = try await componentRequest(session: session) { service, token in
                try await service.component(id: assetID, accessToken: token)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func upload(_ image: UIImage) async {
        guard !uploading else { return }
        uploading = true
        defer { uploading = false }
        error = nil
        do {
            let factor = min(1, 1800 / max(image.size.width, image.size.height, 1))
            let size = CGSize(width: image.size.width * factor, height: image.size.height * factor)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            guard let data = resized.jpegData(compressionQuality: 0.8) else { return }
            _ = try await componentRequest(session: session) { service, token in
                try await service.addImage(assetID: assetID, payload: EquipmentImageWritePayload(
                    image_base64: data.base64EncodedString(), file_name: "componente.jpg",
                    media_type: "image/jpeg", caption: nil,
                    is_primary: detail?.asset.galleryImages.isEmpty ?? true
                ), accessToken: token)
            }
            await load()
            onSaved()
        } catch { self.error = error.localizedDescription }
    }
}

private struct ComponentMovementsPanel: View {
    @EnvironmentObject private var session: SessionStore
    @State private var result: ComponentMovementPage?
    @State private var page = 0
    @State private var retry = 0
    @State private var loading = true
    @State private var error: String?
    let id: String
    private let pageSize = 15

    var body: some View {
        Group {
            if loading {
                ProgressView("Cargando movimientos").frame(maxWidth: .infinity)
            } else {
                panel
            }
        }
        .task(id: "\(page):\(retry)") { await load() }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeaderText(title: "Movimientos")
            if let error {
                ContentUnavailableView {
                    Label("No se pudieron cargar los movimientos", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Reintentar") { loading = true; retry += 1 }
                }
            } else if let result, !result.items.isEmpty {
                ForEach(result.items) { movement in
                    ContentGlassPanel {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text(movement.kind).font(.headline)
                            Text(assetTimestamp(movement.moved_at)?.formatted(date: .abbreviated, time: .shortened)
                                 ?? movement.moved_at)
                                .font(.caption).foregroundStyle(.secondary)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), alignment: .leading)],
                                      spacing: AppSpacing.sm) {
                                EquipmentInfoCell(title: "Origen", value: movement.origin ?? "No registrado",
                                                  symbol: "arrow.up.right", maxLines: nil)
                                EquipmentInfoCell(title: "Destino", value: movement.destination ?? "No registrado",
                                                  symbol: "arrow.down.left", maxLines: nil)
                            }
                            if let status = movement.to_status {
                                Text([movement.from_status, status].compactMap { $0 }.joined(separator: " → "))
                                    .font(.caption)
                            }
                            if let notes = movement.notes, !notes.isEmpty { Text(notes).font(.subheadline) }
                        }
                    }
                }
                PaginationBar(currentPage: page, pageCount: (result.total + pageSize - 1) / pageSize) {
                    page = $0
                    loading = true
                }
            } else {
                ContentUnavailableView("Sin movimientos registrados", systemImage: "arrow.left.arrow.right")
            }
        }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            let response = try await componentRequest(session: session) { service, token in
                try await service.movements(id: id, limit: pageSize, offset: page * pageSize, accessToken: token)
            }
            guard !Task.isCancelled else { return }
            result = response
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
        loading = false
    }
}

private struct ComponentEditorView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var serial: String
    @State private var manufacturer: String
    @State private var model: String
    @State private var software: String
    @State private var status = ""
    @State private var statuses: [EquipmentCatalogOption] = []
    @State private var saving = false
    @State private var error: String?
    let detail: ComponentDetailDTO
    let onSaved: (ComponentDetailDTO) -> Void

    init(detail: ComponentDetailDTO, onSaved: @escaping (ComponentDetailDTO) -> Void) {
        self.detail = detail
        self.onSaved = onSaved
        _name = State(initialValue: detail.asset.name)
        _serial = State(initialValue: detail.serial_number ?? "")
        _manufacturer = State(initialValue: detail.asset.manufacturer ?? "")
        _model = State(initialValue: detail.asset.model ?? "")
        _software = State(initialValue: detail.asset.softwareVersion ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identificación") {
                    TextField("Nombre", text: $name)
                    TextField("Número de serie", text: $serial)
                    LabeledContent("Part number del modelo", value: detail.asset.partNumber ?? "No registrado")
                }
                Section("Datos técnicos") {
                    TextField("Fabricante", text: $manufacturer)
                    TextField("Modelo", text: $model)
                    TextField("Versión de software", text: $software)
                    if statuses.isEmpty {
                        LabeledContent("Estado", value: detail.asset.status)
                    } else {
                        Picker("Estado", selection: $status) {
                            Text(detail.asset.status).tag("")
                            ForEach(statuses) { Text($0.name).tag($0.id) }
                        }
                    }
                }
                if let error { Text(error).foregroundStyle(BrandColor.red) }
            }
            .navigationTitle("Editar componente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }
                        .disabled(saving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .interactiveDismissDisabled(saving)
            .task {
                do {
                    let catalog = try await componentRequest(session: session) { service, token in
                        try await service.administrationCatalog(accessToken: token)
                    }
                    statuses = catalog.statuses.filter { $0.id != detail.asset.statusID }
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        error = nil
        let payload = ComponentWritePayload(
            name: name, serial_number: serial, part_number: nil, manufacturer: manufacturer,
            model: model, software_version: software, status_id: status.isEmpty ? nil : status
        )
        do {
            let updated = try await componentRequest(session: session) { service, token in
                try await service.updateComponent(id: detail.asset.id, payload: payload, accessToken: token)
            }
            onSaved(updated)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
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
    var maxLines: Int? = 2

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
                    .lineLimit(maxLines)
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
            await assetStore.loadDetail(id: assetID, session: session, force: true)
        }
        .sheet(isPresented: $isPresentingComponentAdmin) {
            if let equipment = assetStore.details[assetID] {
                ComponentAdministrationSheet(
                    equipment: equipment,
                    nodes: assetStore.trees[assetID] ?? [],
                    canFullyAdminister: session.canEdit(.equipment)
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
            if session.canEdit(.equipment) {
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
            canFullyAdminister: session.canEdit(.equipment)
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
    @EnvironmentObject private var assetStore: AssetStore
    @EnvironmentObject private var session: SessionStore
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
                                expandedNodeIDs: $expandedNodeIDs,
                                onComponentSaved: {
                                    Task { await assetStore.loadTree(id: equipmentID, session: session, force: true) }
                                }
                            )
                        }
                    }
                }
            }
        }
        .onChange(of: nodes) { _, _ in
            branches = EquipmentTreeBranch.build(
                nodes: nodes,
                rootID: equipmentID
            )
            expandedNodeIDs.formIntersection(nodes.map(\.id))
        }
    }
}

private struct ExistingComponentPicker: View {
    @EnvironmentObject private var session: SessionStore
    @State private var query = ""
    @State private var page = 0
    @State private var response: EquipmentPageDTO?
    @State private var loading = true
    @State private var error: String?
    @State private var retry = 0
    let root: EquipmentDTO
    let excludedIDs: Set<String>
    let onSelect: (EquipmentDTO) -> Void
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Nombre, código, serie o part number", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(AppSpacing.sm)
            .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                if loading {
                    ProgressView("Cargando componentes")
                } else if let error {
                    Text(error).foregroundStyle(BrandColor.red)
                    Button("Reintentar") { retry += 1 }
                } else if let response {
                    ForEach(response.items) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name).foregroundStyle(.primary)
                                Text(item.serialOrCode).font(.caption).foregroundStyle(.secondary)
                                Text(item.physicalLocation).font(.caption).foregroundStyle(.secondary)
                                if excludedIDs.contains(item.id) {
                                    Text("Ya pertenece al equipo").font(.caption).foregroundStyle(.secondary)
                                } else if session.currentUser?.role != .administrator {
                                    Text("La asignación requiere un administrador").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppSpacing.sm)
                            .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(excludedIDs.contains(item.id) || session.currentUser?.role != .administrator)
                    }
                    if response.items.isEmpty { Text("Sin componentes disponibles") }
                    PaginationBar(currentPage: page, pageCount: max(1, (response.total + 14) / 15)) { page = $0 }
                }
            }
            Button("No está registrado: crear unidad nueva", systemImage: "plus.circle") { onCreate() }
                .buttonStyle(.bordered)
        }
            .onChange(of: query) { page = 0 }
            .task(id: "\(query):\(page):\(retry)") {
                loading = true
                error = nil
                do {
                    if !query.isEmpty { try await Task.sleep(for: .milliseconds(250)) }
                    let result = try await componentRequest(session: session) { service, token in
                        try await service.list(query: query, subsystem: root.subsystem, businessAnchor: false,
                                               limit: 15, offset: page * 15, accessToken: token)
                    }
                    guard !Task.isCancelled else { return }
                    response = result
                    loading = false
                } catch {
                    guard !Task.isCancelled else { return }
                    self.error = error.localizedDescription
                    loading = false
                }
            }
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
    @State private var selectedTypeID = ""
    @State private var creatingType = false
    @State private var newTypeName = ""
    @State private var status = ""
    @State private var editorOptions: ComponentEditorOptions?
    @State private var internalSlots: [EquipmentInternalSlot] = []
    @State private var serialNumber = ""
    @State private var partNumber = ""
    @State private var model = ""
    @State private var position = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var existingComponent: EquipmentDTO?
    @State private var registeringNew = false
    @State private var destinationParentID = ""
    @State private var destinationNodes: [EquipmentTreeNodeDTO] = []
    @State private var destinationSlots: [EquipmentInternalSlot] = []
    @State private var loadingDestination = false
    @State private var confirmDeletion = false
    @State private var destinationLoadedID = ""
    @State private var editorReady = false
    @State private var selectedDetailID = ""
    @State private var selectedActualParentID: String?
    @State private var moveEquipments: [EquipmentDTO] = []
    @State private var loadingMoveEquipments = false
    @State private var managingSlots = false

    private var selectedComponent: EquipmentTreeNodeDTO? {
        nodes.first { $0.id == selectedComponentID }
    }

    private var moveDestinations: [EquipmentDTO] {
        [equipment] + moveEquipments.filter { $0.id != equipment.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    header
                    operationPanel
                    editorPanel

                    if let errorMessage {
                        GlassPanel {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                                .foregroundStyle(BrandColor.red)
                            if !editorReady {
                                Button("Reintentar carga") { Task { await loadEditorOptions() } }
                            }
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
            .interactiveDismissDisabled(isSaving)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.disabled(isSaving)
                }
                if session.currentUser?.role == .administrator {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Espacios internos", systemImage: "square.split.2x2") {
                            managingSlots = true
                        }
                        .disabled(isSaving)
                    }
                }
            }
            .sheet(isPresented: $managingSlots) {
                EquipmentSlotsSheet(equipment: equipment)
            }
            .onChange(of: managingSlots) { _, visible in
                if !visible { Task { await loadEditorOptions() } }
            }
            .safeAreaInset(edge: .bottom) {
                GlassPanel {
                    ActionButtonGrid {
                        Button("Cancelar", action: dismiss.callAsFunction)
                            .buttonStyle(ActionTileButtonStyle())
                            .disabled(isSaving)
                        Button {
                            if mode == .delete && !selectedComponentID.isEmpty { confirmDeletion = true }
                            else { Task { await save() } }
                        } label: {
                            if isSaving {
                                ProgressView()
                            } else {
                                Label("Guardar cambios", systemImage: "checkmark.circle.fill")
                            }
                        }
                        .buttonStyle(ActionTileButtonStyle(prominent: true))
                        .disabled(isSaving)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.sm)
            }
            .task {
                selectedParentID = equipment.id
                await loadEditorOptions()
                if assetStore.equipments.isEmpty {
                    await assetStore.loadEquipments(query: "", subsystem: nil, session: session)
                }
            }
            .task(id: destinationEquipmentID) { await loadDestination() }
            .task(id: mode) {
                if mode == .move { await loadMoveEquipments() }
            }
            .confirmationDialog("¿Eliminar esta unidad de componente?", isPresented: $confirmDeletion) {
                Button("Eliminar unidad", role: .destructive) { Task { await save() } }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("No se eliminará el modelo del catálogo. Solo se permite eliminar unidades sin hijos ni historial.")
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
                    ? "Registra una unidad física o administra un componente existente."
                    : "Registra una unidad física de un modelo del catálogo."
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
                    SectionHeaderText(title: "Agregar componente")
                    if let existingComponent {
                        Text(existingComponent.name).font(.headline)
                        Text(existingComponent.serialOrCode).font(.subheadline)
                        Text("Ubicación actual: \(existingComponent.physicalLocation)")
                            .font(.caption).foregroundStyle(.secondary)
                        LabeledContent("Part number", value: existingComponent.partNumber ?? "No registrado")
                        componentParentPicker
                        selectionField("Posición de destino", selection: $position, options: positionOptions,
                                       empty: "Seleccionar posición")
                        Button("Buscar otro componente", systemImage: "magnifyingglass") {
                            self.existingComponent = nil
                            position = ""
                        }.buttonStyle(.bordered)
                    } else if registeringNew {
                        componentParentPicker
                        componentFields
                        Button("Volver a buscar componentes", systemImage: "magnifyingglass") {
                            resetForm()
                        }.buttonStyle(.bordered)
                    } else {
                        ExistingComponentPicker(root: equipment,
                            excludedIDs: Set(nodes.filter { $0.selectable }.map(\.id)),
                            onSelect: { existingComponent = $0; position = "" },
                            onCreate: { registeringNew = true; position = "" })
                    }
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
                ForEach(nodes.filter { $0.selectable && $0.nodeKind == "ASSET" }) { node in
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
                ForEach(nodes.filter { $0.selectable && $0.nodeKind == "ASSET" }) { node in
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
            if loadingMoveEquipments { ProgressView("Cargando equipos") }
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
            if loadingDestination { ProgressView("Cargando ubicaciones") }
            if !destinationEquipmentID.isEmpty && !loadingDestination {
                Picker("Padre de destino", selection: $destinationParentID) {
                    Text("Raíz del equipo").tag(destinationEquipmentID)
                    ForEach(validDestinationParents) { node in
                        Text(nodeDisplayName(node)).tag(node.id)
                    }
                }
                .pickerStyle(.menu)
                selectionField("Posición de destino", selection: $position,
                    options: destinationSlots.filter { $0.accepts_asset && ($0.occupant_id == nil
                        || $0.occupant_id == selectedComponentID) }.map(\.path), empty: "Seleccionar posición")
            }
        }
    }

    private var validDestinationParents: [EquipmentTreeNodeDTO] {
        let byID = Dictionary(uniqueKeysWithValues: destinationNodes.map { ($0.id, $0) })
        return destinationNodes.filter { node in
            guard node.selectable && node.nodeKind == "ASSET" else { return false }
            var current: String? = node.id
            var visited = Set<String>()
            while let id = current, visited.insert(id).inserted {
                if id == selectedComponentID { return false }
                current = byID[id]?.parentID
            }
            return true
        }
    }

    private func loadMoveEquipments() async {
        loadingMoveEquipments = true
        defer { loadingMoveEquipments = false }
        do {
            var result: [EquipmentDTO] = []
            while !Task.isCancelled {
                let offset = result.count
                let page = try await componentRequest(session: session) { service, token in
                    try await service.list(query: "", subsystem: equipment.subsystem, businessAnchor: true,
                                           limit: 200, offset: offset, accessToken: token)
                }
                guard !Task.isCancelled else { return }
                result.append(contentsOf: page.items)
                if result.count >= page.total || page.items.isEmpty { break }
            }
            guard !Task.isCancelled else { return }
            moveEquipments = result
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func loadDestination() async {
        let id = destinationEquipmentID
        destinationParentID = id
        destinationNodes = []
        destinationSlots = []
        destinationLoadedID = ""
        position = ""
        guard !id.isEmpty else { return }
        loadingDestination = true
        defer { if destinationEquipmentID == id { loadingDestination = false } }
        do {
            let result = try await componentRequest(session: session) { service, token in
                let tree = try await service.tree(id: id, accessToken: token)
                let slots = try await service.slots(id: id, accessToken: token)
                return (tree, slots)
            }
            guard !Task.isCancelled && destinationEquipmentID == id else { return }
            destinationNodes = result.0
            destinationSlots = result.1
            destinationLoadedID = id
        } catch {
            guard !Task.isCancelled && destinationEquipmentID == id else { return }
            errorMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private var componentFields: some View {
        field("Nombre de la unidad", text: $name)
        LabeledContent("Categoría", value: "Componente")
        if mode == .create && session.currentUser?.role == .administrator {
            Toggle("Registrar un modelo con part number nuevo", isOn: $creatingType)
                .onChange(of: creatingType) { _, _ in partNumber = ""; serialNumber = "" }
        }
        if creatingType && mode == .create {
            field("Nombre del nuevo modelo", text: $newTypeName)
            field("Part number del nuevo modelo", text: $partNumber)
        } else {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                fieldLabel("Modelo del catálogo (tipo de componente)")
                Picker("Modelo del catálogo", selection: $selectedTypeID) {
                    Text("Seleccionar").tag("")
                    ForEach(editorOptions?.classifications ?? [], id: \.id) { option in
                        Text([option.type, option.part_number].compactMap { $0 }.joined(separator: " · ")).tag(option.id)
                    }
                }
                .labelsHidden().pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.sm)
                .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
                .disabled(editorOptions == nil)
                .onChange(of: selectedTypeID) { _, _ in
                    if selectedType?.serial_number_policy == "NOT_APPLICABLE" { serialNumber = "" }
                }
            }
            LabeledContent("Part number del modelo", value: selectedType?.part_number ?? "No registrado")
        }
        selectionField("Estado", selection: $status, options: editorOptions?.statuses ?? [])
        if creatingType || selectedType?.serial_number_policy != "NOT_APPLICABLE" {
            field("Número de serie de la unidad", text: $serialNumber)
        }
        field("Modelo", text: $model)
        selectionField("Posición", selection: $position, options: positionOptions, empty: "Seleccionar posición")
        if let error = errorMessage { Text(error).font(.caption).foregroundStyle(BrandColor.red) }
    }

    private var selectedType: ComponentEditorOptions.Classification? {
        editorOptions?.classifications.first { $0.id == selectedTypeID }
    }

    private var positionOptions: [String] {
        var options = internalSlots.filter {
            $0.accepts_asset && ($0.occupant_id == nil || $0.occupant_id == selectedComponentID)
        }.map(\.path)
        if let current = selectedComponent?.slotPath ?? selectedComponent?.position,
           !current.isEmpty { options.append(current) }
        return Array(Set(options)).sorted()
    }

    private func selectionField(_ title: String, selection: Binding<String>, options: [String],
                                empty: String = "Seleccionar") -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            fieldLabel(title)
            Picker(title, selection: selection) {
                Text(empty).tag("")
                if title.contains("Posición") {
                    Text("Sin posición específica").tag("__unplaced__")
                }
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.sm)
            .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
            .disabled(editorOptions == nil)
        }
    }

    private func loadEditorOptions() async {
        editorReady = false
        do {
            editorOptions = try await componentRequest(session: session) { service, token in
                try await service.componentEditorOptions(id: equipment.id, accessToken: token)
            }
            internalSlots = try await componentRequest(session: session) { service, token in
                try await service.slots(id: equipment.id, accessToken: token)
            }
            editorReady = true
        } catch { errorMessage = error.localizedDescription }
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

    private var canSave: Bool {
        if (mode == .create || mode == .update) && !editorReady { return false }
        switch mode {
        case .assign:
            return existingComponent != nil && !selectedParentID.isEmpty
        case .create:
            if existingComponent != nil {
                return !selectedParentID.isEmpty && (internalSlots.isEmpty || !position.isEmpty)
            }
            guard registeringNew else { return false }
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && (creatingType ? !newTypeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !partNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : selectedType != nil)
                && !status.isEmpty && editorOptions != nil && (internalSlots.isEmpty || !position.isEmpty)
        case .update:
            return selectedDetailID == selectedComponentID && !selectedComponentID.isEmpty
                && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedType != nil
                && !status.isEmpty && editorOptions != nil
        case .delete:
            return !selectedComponentID.isEmpty
        case .move:
            return !selectedComponentID.isEmpty && !destinationEquipmentID.isEmpty
                && !destinationParentID.isEmpty && !loadingDestination
                && !loadingMoveEquipments
                && destinationLoadedID == destinationEquipmentID && selectedDetailID == selectedComponentID
                && (destinationSlots.isEmpty || !position.isEmpty)
        }
    }

    private func currentOperation() -> AssetComponentOperation {
        let action: AssetComponentOperation.Action = mode == .create && existingComponent != nil ? .assign : mode
        let placement = position == "__unplaced__" ? "" : position
        var operation = AssetComponentOperation(
            action: action,
            componentID: action == .create ? nil : action == .assign ? existingComponent?.id : selectedComponentID,
            parentID: action == .create || action == .assign
                ? selectedParentID
                : mode == .move ? destinationParentID : nil,
            name: action == .create || action == .update ? name : nil,
            category: action == .create || action == .update ? "Componente" : nil,
            assetType: nil,
            status: action == .create || action == .update ? status : nil,
            serialNumber: action == .create || action == .update ? serialNumber : nil,
            partNumber: nil,
            model: action == .create || action == .update ? model : nil,
            currentPosition: action == .delete ? nil : placement
        )
        if action == .assign {
            operation.expectedParentID = existingComponent?.parentID
        }
        if action == .move {
            operation.destinationEquipmentID = destinationEquipmentID
            operation.expectedParentID = selectedActualParentID
        }
        if action == .create || action == .update {
            operation.assetTypeID = creatingType ? nil : selectedTypeID
            operation.newTypeName = creatingType ? newTypeName : nil
            operation.newTypePartNumber = creatingType ? partNumber : nil
        }
        return operation
    }

    private func populateSelectedComponent() {
        guard let node = selectedComponent else { return }
        selectedDetailID = ""
        selectedActualParentID = nil
        name = node.name
        selectedTypeID = editorOptions?.classifications.first { String($0.type.prefix(120)) == node.assetType }?.id ?? ""
        let identifier = node.id
        Task {
            do {
                let detail = try await componentRequest(session: session) { service, token in
                    try await service.component(id: identifier, accessToken: token)
                }
                if selectedComponentID == identifier {
                    if let typeID = detail.asset_type_id { selectedTypeID = typeID }
                    selectedActualParentID = detail.asset.parentID
                    selectedDetailID = identifier
                }
            } catch { errorMessage = error.localizedDescription }
        }
        status = node.status
        serialNumber = node.serialNumber ?? ""
        partNumber = node.partNumber ?? ""
        model = node.model ?? ""
        position = node.slotPath ?? node.position ?? "__unplaced__"
        if mode == .move { position = ""; destinationParentID = destinationEquipmentID }
    }

    private func resetForm() {
        existingComponent = nil
        registeringNew = false
        selectedComponentID = ""
        selectedDetailID = ""
        selectedActualParentID = nil
        destinationEquipmentID = ""
        loadingDestination = false
        selectedParentID = equipment.id
        name = ""
        selectedTypeID = ""
        creatingType = false
        newTypeName = ""
        status = ""
        serialNumber = ""
        partNumber = ""
        model = ""
        position = ""
        errorMessage = nil
    }

    private func save() async {
        guard !isSaving else { return }
        guard canSave else {
            if mode == .create && existingComponent == nil && !registeringNew {
                errorMessage = "Selecciona una unidad existente o elige crear una unidad nueva."
            } else if mode == .move || (mode == .create && existingComponent != nil) {
                errorMessage = "Selecciona un padre y una posición de destino, o elige Sin posición específica."
            } else {
                errorMessage = "Completa los datos obligatorios, el modelo y la posición de destino."
            }
            return
        }
        isSaving = true
        errorMessage = nil
        do {
            try await assetStore.applyComponentChanges(
                rootID: equipment.id,
                operations: [currentOperation()],
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

}

private struct EquipmentSlotsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var assetStore: AssetStore
    @State private var slots: [EquipmentInternalSlot] = []
    @State private var name = ""
    @State private var parentID = ""
    @State private var acceptsAsset = true
    @State private var selectingSlot: EquipmentInternalSlot?
    @State private var releasingSlot: EquipmentInternalSlot?
    @State private var query = ""
    @State private var busy = false
    @State private var loaded = false
    @State private var error: String?
    let equipment: EquipmentDTO

    var body: some View {
        NavigationStack {
            ScrollView {
              VStack(alignment: .leading, spacing: AppSpacing.xl) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Espacios internos").font(.system(.largeTitle, design: .rounded).weight(.black))
                    Text(equipment.assetType).font(.headline).foregroundStyle(.secondary)
                    Text("Estructura compartida por tipo de equipo. La ocupación pertenece a cada unidad.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                GlassPanel {
                  VStack(alignment: .leading, spacing: AppSpacing.md) {
                    SectionHeaderText(title: "Nuevo espacio")
                    LabeledContent("Nombre") {
                        TextField("Nombre", text: $name).textFieldStyle(.roundedBorder)
                    }
                    LabeledContent("Ubicación padre") {
                        Picker("Ubicación padre", selection: $parentID) {
                            Text(equipment.assetType).tag("")
                            ForEach(slots) { Text(displayPath($0.path)).tag($0.id) }
                        }
                        .labelsHidden().pickerStyle(.menu)
                    }
                    Toggle("Permite colocar un componente", isOn: $acceptsAsset)
                    Button("Agregar espacio al tipo de equipo", systemImage: "plus") { Task { await addSlot() } }
                        .buttonStyle(ActionTileButtonStyle(prominent: true))
                        .disabled(busy || !loaded || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                  }
                }
                ContentGlassPanel {
                  VStack(alignment: .leading, spacing: AppSpacing.md) {
                    SectionHeaderText(title: "Espacios de \(equipment.name)")
                    if !loaded && busy { ProgressView() }
                    if loaded && slots.isEmpty { Text("Sin espacios personalizados").foregroundStyle(.secondary) }
                    ForEach(slots) { slot in
                        LabeledContent {
                            if slot.accepts_asset {
                                if slot.occupant_id != nil {
                                    Button("Liberar") { releasingSlot = slot }.disabled(busy).buttonStyle(.bordered)
                                } else {
                                    Button("Asignar") { query = ""; selectingSlot = slot }.disabled(busy).buttonStyle(.bordered)
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayPath(slot.path))
                                Text(slot.occupant_name ?? (slot.accepts_asset ? "Libre" : "Contenedor"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(AppSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                    }
                  }
                }
                if let error {
                    GlassPanel { Text(error).foregroundStyle(BrandColor.red) }
                }
              }
              .padding(AppSpacing.lg)
              .frame(maxWidth: 900, alignment: .leading)
              .frame(maxWidth: .infinity)
            }
            .background(MaintenanceScreenBackground())
            .navigationTitle("Espacios internos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }.disabled(busy)
                }
            }
            .task { await load() }
            .refreshable { await load() }
            .sheet(item: $selectingSlot) { slot in
                NavigationStack {
                    List {
                        if matchingComponents.isEmpty {
                            Text("Sin componentes disponibles").foregroundStyle(.secondary)
                        }
                        ForEach(matchingComponents) { node in
                            Button {
                                selectingSlot = nil
                                Task { await place(node.id, in: slot) }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(node.name)
                                    if let serial = node.serialNumber {
                                        Text(serial).font(.caption).foregroundStyle(.secondary)
                                    }
                                    if let path = node.slotPath {
                                        Text(displayPath(path)).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .searchable(text: $query, prompt: "Nombre o número de serie")
                    .navigationTitle(displayPath(slot.path))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancelar") { selectingSlot = nil }
                        }
                    }
                }
            }
            .confirmationDialog("¿Liberar este espacio?", isPresented: Binding(
                get: { releasingSlot != nil },
                set: { if !$0 { releasingSlot = nil } }
            ), presenting: releasingSlot) { slot in
                Button("Liberar espacio") { Task { await place(nil, in: slot) } }
                Button("Cancelar", role: .cancel) {}
            } message: { _ in
                Text("El componente seguirá en el equipo, pero sin esta posición interna.")
            }
        }
    }

    private var matchingComponents: [EquipmentTreeNodeDTO] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return (assetStore.trees[equipment.id] ?? []).filter {
            $0.nodeKind == "ASSET" && $0.selectable && (term.isEmpty
                || $0.name.localizedCaseInsensitiveContains(term)
                || $0.serialNumber?.localizedCaseInsensitiveContains(term) == true)
        }
    }

    private func displayPath(_ path: String) -> String {
        path.split(separator: "/").joined(separator: " › ")
    }

    private func load() async {
        await update(reloadTree: false) { service, token in
            try await service.slots(id: equipment.id, accessToken: token)
        }
    }

    private func addSlot() async {
        let payload = InternalSlotWrite(name: name, parent_id: parentID.isEmpty ? nil : parentID,
                                        accepts_asset: acceptsAsset)
        await update { service, token in
            try await service.addSlot(id: equipment.id, payload: payload, accessToken: token)
        }
        if error == nil { name = "" }
    }

    private func place(_ componentID: String?, in slot: EquipmentInternalSlot) async {
        let payload = InternalSlotOccupancy(component_id: componentID, expected_occupant_id: slot.occupant_id)
        await update { service, token in
            try await service.placeComponent(id: equipment.id, slotID: slot.id, payload: payload, accessToken: token)
        }
    }

    private func update(
        reloadTree: Bool = true,
        _ operation: @escaping (AssetService, String) async throws -> [EquipmentInternalSlot]
    ) async {
        guard !busy else { return }
        busy = true
        error = nil
        defer { busy = false }
        do {
            slots = try await componentRequest(session: session, operation)
            loaded = true
            if reloadTree { await assetStore.loadTree(id: equipment.id, session: session, force: true) }
        } catch { self.error = error.localizedDescription }
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
                SectionHeaderText(title: equipment.isBusinessAnchor ? "Imágenes del equipo" : "Imágenes del componente")

                if equipment.galleryImages.isEmpty {
                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: symbol)
                            .font(.system(size: 68, weight: .semibold))
                            .foregroundStyle(BrandColor.red.opacity(0.78))
                        Text("Sin imágenes registradas")
                            .font(.headline)
                        Text(equipment.isBusinessAnchor
                             ? "El administrador puede agregarlas desde Editar equipo."
                             : "El administrador puede agregarlas desde Fototeca o Cámara.")
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
    let onComponentSaved: () -> Void

    var body: some View {
        if branch.children.isEmpty {
            row
        } else {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.xs) {
                    Button {
                        if expandedNodeIDs.contains(branch.id) {
                            expandedNodeIDs.remove(branch.id)
                        } else {
                            expandedNodeIDs.insert(branch.id)
                        }
                    } label: {
                        Image(systemName: expandedNodeIDs.contains(branch.id) ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .frame(width: 40, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(BrandColor.red)
                    .accessibilityLabel(expandedNodeIDs.contains(branch.id) ? "Contraer" : "Expandir")
                    .help(expandedNodeIDs.contains(branch.id) ? "Contraer" : "Expandir")
                    row
                }
                if expandedNodeIDs.contains(branch.id) {
                    LazyVStack(alignment: .leading, spacing: AppSpacing.xs) {
                        ForEach(branch.children) { child in
                            EquipmentTreeBranchView(
                                branch: child,
                                expandedNodeIDs: $expandedNodeIDs,
                                onComponentSaved: onComponentSaved
                            )
                        }
                    }
                    .padding(.leading, AppSpacing.lg)
                }
            }
        }
    }

    @ViewBuilder
    private var row: some View {
        if branch.node.nodeKind == "ASSET", branch.node.selectable {
            NavigationLink {
                ComponentDetailView(assetID: branch.node.id, name: branch.node.name, onSaved: onComponentSaved)
            } label: {
                rowContent
            }
            .buttonStyle(.plain)
            .accessibilityHint("Abre el detalle del componente")
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
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
            if branch.node.nodeKind == "ASSET", branch.node.selectable {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, AppSpacing.xs)
        .contentShape(Rectangle())
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
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
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
        assetTimestamp(entry.performedAt)?.formatted(date: .abbreviated, time: .omitted) ?? entry.performedAt
    }
}

private func assetTimestamp(_ value: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
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
