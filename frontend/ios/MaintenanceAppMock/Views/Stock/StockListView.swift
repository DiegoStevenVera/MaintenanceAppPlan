import PhotosUI
import SwiftUI
import UIKit

private struct APIStockAsset: Identifiable, Decodable {
    let id: String
    let name: String
    let category: String
    let assetType: String
    let serialNumber: String?
    let internalCode: String?
    let partNumber: String?
    let status: String
    let inventoryLocation: String
    let subsystem: String
    let manufacturer: String?
    let model: String?
    let softwareVersion: String?
    let equipmentCategoryID: String?
    let subsystemID: String?
    let statusID: String?
    let inventoryLocationID: String
    let images: [EquipmentImageDTO]?

    enum CodingKeys: String, CodingKey {
        case id, name, category, status, subsystem, manufacturer, model, images
        case assetType = "asset_type"
        case serialNumber = "serial_number"
        case internalCode = "internal_code"
        case partNumber = "part_number"
        case inventoryLocation = "inventory_location"
        case softwareVersion = "software_version"
        case equipmentCategoryID = "equipment_category_id"
        case subsystemID = "subsystem_id"
        case statusID = "status_id"
        case inventoryLocationID = "inventory_location_id"
    }

    var primaryIdentifier: String {
        serialNumber?.stockNonBlank ?? internalCode?.stockNonBlank ?? "Sin código registrado"
    }
}

private struct APIStockPage: Decodable {
    let items: [APIStockAsset]
    let total: Int
}

private struct StockAdministrationCatalog: Decodable {
    let categories: [EquipmentCategoryOption]
    let subsystems: [EquipmentCatalogOption]
    let statuses: [EquipmentCatalogOption]
    let inventoryLocations: [EquipmentCatalogOption]

    enum CodingKeys: String, CodingKey {
        case categories, subsystems, statuses
        case inventoryLocations = "inventory_locations"
    }
}

private struct StockWritePayload: Encodable {
    let name: String
    let serial_or_code: String
    let part_number: String?
    let equipment_category_id: String
    let subsystem_id: String
    let status_id: String
    let inventory_location_id: String
    let manufacturer: String?
    let model: String?
    let software_version: String?
}

private struct StockAPIService {
    let client: APIClient

    init(baseURLString: String) {
        client = APIClient(baseURLString: baseURLString)
    }

    func list(
        query: String,
        subsystem: String?,
        status: String?,
        inventoryLocation: String?,
        accessToken: String
    ) async throws -> APIStockPage {
        var assets: [APIStockAsset] = []
        var offset = 0
        let limit = 200
        var total = 0
        repeat {
            var queryItems = [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
            if !query.isEmpty { queryItems.append(URLQueryItem(name: "q", value: query)) }
            if let subsystem { queryItems.append(URLQueryItem(name: "subsystem", value: subsystem)) }
            if let status { queryItems.append(URLQueryItem(name: "status", value: status)) }
            if let inventoryLocation {
                queryItems.append(URLQueryItem(name: "inventory_location", value: inventoryLocation))
            }
            let page: APIStockPage = try await client.get(
                "api/v1/assets/stock",
                bearerToken: accessToken,
                queryItems: queryItems
            )
            assets.append(contentsOf: page.items)
            total = page.total
            offset += page.items.count
            if page.items.isEmpty { break }
        } while offset < total
        return APIStockPage(items: assets, total: total)
    }

    func detail(id: String, accessToken: String) async throws -> APIStockAsset {
        try await client.get("api/v1/assets/stock/\(id)", bearerToken: accessToken)
    }

    func catalog(accessToken: String) async throws -> StockAdministrationCatalog {
        try await client.get(
            "api/v1/assets/stock/administration/catalog",
            bearerToken: accessToken
        )
    }

    func update(
        id: String,
        payload: StockWritePayload,
        accessToken: String
    ) async throws -> APIStockAsset {
        try await client.put(
            "api/v1/assets/stock/\(id)",
            body: payload,
            bearerToken: accessToken
        )
    }

    func create(
        payload: StockWritePayload,
        accessToken: String
    ) async throws -> APIStockAsset {
        try await client.post(
            "api/v1/assets/stock",
            body: payload,
            bearerToken: accessToken
        )
    }

    func addImage(
        assetID: String,
        imageData: Data,
        isPrimary: Bool,
        accessToken: String
    ) async throws -> EquipmentImageDTO {
        try await client.post(
            "api/v1/assets/\(assetID)/images",
            body: EquipmentImageWritePayload(
                image_base64: imageData.base64EncodedString(),
                file_name: "stock.jpg",
                media_type: "image/jpeg",
                caption: nil,
                is_primary: isPrimary
            ),
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
private final class StockStore: ObservableObject {
    @Published private(set) var assets: [APIStockAsset] = []
    @Published private(set) var total = 0
    @Published private(set) var details: [String: APIStockAsset] = [:]
    @Published private(set) var catalog: StockAdministrationCatalog?
    @Published private(set) var isLoadingList = false
    @Published private(set) var loadingDetailIDs: Set<String> = []
    @Published private(set) var listError: String?
    @Published private(set) var detailErrors: [String: String] = [:]

    var availableSubsystems: [String] {
        catalog?.subsystems.compactMap { $0.code?.stockNonBlank ?? $0.name.stockNonBlank } ?? []
    }

    var availableStatuses: [String] {
        catalog?.statuses.compactMap { $0.name.stockNonBlank } ?? []
    }

    var availableLocations: [String] {
        catalog?.inventoryLocations.compactMap { $0.name.stockNonBlank } ?? []
    }

    func loadCatalog(session: SessionStore) async {
        guard catalog == nil else { return }
        do {
            catalog = try await request(session: session) { service, token in
                try await service.catalog(accessToken: token)
            }
        } catch {
            listError = error.localizedDescription
        }
    }

    func load(
        query: String,
        subsystem: String?,
        status: String?,
        inventoryLocation: String?,
        session: SessionStore
    ) async {
        isLoadingList = true
        listError = nil
        do {
            let page = try await request(session: session) { service, token in
                try await service.list(
                    query: query,
                    subsystem: subsystem,
                    status: status,
                    inventoryLocation: inventoryLocation,
                    accessToken: token
                )
            }
            assets = page.items
            total = page.total
        } catch {
            listError = error.localizedDescription
        }
        isLoadingList = false
    }

    func loadDetail(id: String, session: SessionStore, force: Bool = false) async {
        guard force || details[id] == nil else { return }
        loadingDetailIDs.insert(id)
        detailErrors[id] = nil
        do {
            let detail = try await request(session: session) { service, token in
                try await service.detail(id: id, accessToken: token)
            }
            details[id] = detail
            if let index = assets.firstIndex(where: { $0.id == id }) {
                assets[index] = detail
            }
        } catch {
            detailErrors[id] = error.localizedDescription
        }
        loadingDetailIDs.remove(id)
    }

    func save(
        id: String?,
        payload: StockWritePayload,
        imageData: Data?,
        session: SessionStore
    ) async throws -> APIStockAsset {
        var saved = try await request(session: session) { service, token in
            if let id {
                return try await service.update(id: id, payload: payload, accessToken: token)
            }
            return try await service.create(payload: payload, accessToken: token)
        }
        if let imageData {
            _ = try await request(session: session) { service, token in
                try await service.addImage(
                    assetID: saved.id,
                    imageData: imageData,
                    isPrimary: saved.images?.isEmpty != false,
                    accessToken: token
                )
            }
            saved = try await request(session: session) { service, token in
                try await service.detail(id: saved.id, accessToken: token)
            }
        }
        details[saved.id] = saved
        if let index = assets.firstIndex(where: { $0.id == saved.id }) {
            assets[index] = saved
        } else {
            assets.append(saved)
            total += 1
        }
        assets.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return saved
    }

    func update(id: String, payload: StockWritePayload, session: SessionStore) async throws {
        let updated = try await request(session: session) { service, token in
            try await service.update(id: id, payload: payload, accessToken: token)
        }
        details[id] = updated
        if let index = assets.firstIndex(where: { $0.id == id }) {
            assets[index] = updated
        }
    }

    func create(payload: StockWritePayload, session: SessionStore) async throws {
        let created = try await request(session: session) { service, token in
            try await service.create(payload: payload, accessToken: token)
        }
        assets.append(created)
        assets.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        details[created.id] = created
        total += 1
    }

    func imageData(assetID: String, imageID: String, session: SessionStore) async throws -> Data {
        try await request(session: session) { service, token in
            try await service.imageData(assetID: assetID, imageID: imageID, accessToken: token)
        }
    }

    private func request<T>(
        session: SessionStore,
        operation: @escaping (StockAPIService, String) async throws -> T
    ) async throws -> T {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else {
            throw APIClient.APIError.invalidBaseURL
        }
        return try await session.withValidAccessToken { token in
            try await operation(StockAPIService(baseURLString: baseURL), token)
        }
    }
}

struct StockListView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var stockStore = StockStore()
    @State private var query = ""
    @State private var selectedSubsystem = ""
    @State private var selectedStatus = ""
    @State private var selectedLocation = ""
    @State private var page = 0
    @State private var isPresentingNewElement = false

    var selectionMode = false
    private let pageSize = 10

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 850
            let isNarrow = geometry.size.width < 650
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    pageTitle
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
        .navigationTitle(selectionMode ? "Seleccionar stock" : "Stock")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await stockStore.loadCatalog(session: session) }
        .task(id: "\(query)|\(selectedSubsystem)|\(selectedStatus)|\(selectedLocation)") {
            if !query.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
            guard !Task.isCancelled else { return }
            await load()
        }
        .onChange(of: query) { _, _ in page = 0 }
        .onChange(of: selectedSubsystem) { _, _ in page = 0 }
        .onChange(of: selectedStatus) { _, _ in page = 0 }
        .onChange(of: selectedLocation) { _, _ in page = 0 }
        .fullScreenCover(
            isPresented: $isPresentingNewElement,
            onDismiss: { Task { await load() } }
        ) {
            StockEditorView(asset: nil)
                .environmentObject(session)
                .environmentObject(stockStore)
        }
    }

    private var pageTitle: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                titleText
                Spacer()
                newElementButton
            }
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                titleText
                newElementButton.frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var titleText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(selectionMode ? "Seleccionar stock" : "Stock").font(.largeTitle.bold())
            Text("Consulta repuestos y componentes, su ubicación y estado")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var newElementButton: some View {
        Button { isPresentingNewElement = true } label: {
            Label("Nuevo elemento", systemImage: "plus")
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
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: AppSpacing.sm
                    ) {
                        subsystemFilter
                        locationFilter
                        statusFilter
                        clearFiltersButton.frame(maxWidth: .infinity, minHeight: 52)
                    }
                }
            } else {
                HStack(spacing: AppSpacing.sm) {
                    searchField.frame(minWidth: 180, maxWidth: .infinity)
                    subsystemFilter.frame(minWidth: 130, maxWidth: 160)
                    locationFilter.frame(minWidth: 150, maxWidth: 190)
                    statusFilter.frame(minWidth: 130, maxWidth: 160)
                    clearFiltersButton.frame(minWidth: 104)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Buscar en stock", text: $query)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
    }

    private var subsystemFilter: some View {
        MaintenanceChoiceField("Subsistema", systemImage: "square.3.layers.3d", selection: $selectedSubsystem) {
            Text("Todos").tag("")
            ForEach(stockStore.availableSubsystems, id: \.self) { Text($0).tag($0) }
        }
    }

    private var locationFilter: some View {
        MaintenanceChoiceField("Ubicación", systemImage: "shippingbox", selection: $selectedLocation) {
            Text("Todas").tag("")
            ForEach(stockStore.availableLocations, id: \.self) { Text($0).tag($0) }
        }
    }

    private var statusFilter: some View {
        MaintenanceChoiceField("Estado", systemImage: "checkmark.seal", selection: $selectedStatus) {
            Text("Todos").tag("")
            ForEach(stockStore.availableStatuses, id: \.self) { Text($0).tag($0) }
        }
    }

    private var clearFiltersButton: some View {
        Button {
            query = ""
            selectedSubsystem = ""
            selectedLocation = ""
            selectedStatus = ""
        } label: {
            Label("Limpiar", systemImage: "arrow.counterclockwise")
        }
        .buttonStyle(CompactActionButtonStyle())
        .disabled(query.isEmpty && selectedSubsystem.isEmpty && selectedLocation.isEmpty && selectedStatus.isEmpty)
    }

    @ViewBuilder
    private func results(isWide: Bool, isCompact: Bool, isNarrow: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(stockStore.total) elementos").font(.title3.bold())
                    if !stockStore.assets.isEmpty {
                        Text("Mostrando \(pageItems.count) de \(stockStore.total)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !isCompact {
                    Text("Inventario de stock").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            StockStatusLegend()

            if stockStore.isLoadingList && stockStore.assets.isEmpty {
                ProgressView("Cargando stock").frame(maxWidth: .infinity).padding(AppSpacing.xl)
            } else if let error = stockStore.listError, stockStore.assets.isEmpty {
                ContentUnavailableView {
                    Label("No se pudo cargar el stock", systemImage: "wifi.exclamationmark")
                } description: { Text(error) } actions: {
                    Button("Reintentar") { Task { await load() } }
                }
            } else if stockStore.assets.isEmpty {
                ContentUnavailableView.search(text: query)
            } else if isWide {
                stockTable
            } else {
                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(pageItems) { asset in
                        NavigationLink {
                            StockDetailView(assetID: asset.id).environmentObject(stockStore)
                        } label: {
                            StockCompactRow(asset: asset, isNarrow: isNarrow)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !stockStore.assets.isEmpty { pagination }
        }
    }

    private var stockTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.sm) {
                Text("Icono").frame(width: 62, alignment: .leading)
                Text("Código").frame(width: 120, alignment: .leading)
                Text("Nombre").frame(minWidth: 210, maxWidth: .infinity, alignment: .leading)
                Text("Categoría").frame(width: 150, alignment: .leading)
                Text("Ubicación").frame(width: 180, alignment: .leading)
                Text("Estado").frame(width: 140, alignment: .leading)
                Text("Ver").frame(width: 44, alignment: .trailing)
            }
            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            .padding(.horizontal, AppSpacing.md).padding(.vertical, AppSpacing.sm)

            ForEach(pageItems) { asset in
                NavigationLink {
                    StockDetailView(assetID: asset.id).environmentObject(stockStore)
                } label: {
                    StockWideRow(asset: asset)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(BrandColor.glassStroke) }
    }

    private var pageItems: [APIStockAsset] {
        let start = page * pageSize
        guard start < stockStore.assets.count else { return [] }
        return Array(stockStore.assets[start..<min(start + pageSize, stockStore.assets.count)])
    }

    private var pageCount: Int {
        max(1, Int(ceil(Double(stockStore.assets.count) / Double(pageSize))))
    }

    private var pagination: some View {
        PaginationBar(currentPage: page, pageCount: pageCount) { page = $0 }
            .padding(.vertical, AppSpacing.sm)
    }

    private func load() async {
        await stockStore.load(
            query: query.trimmingCharacters(in: .whitespacesAndNewlines),
            subsystem: selectedSubsystem.stockNonBlank,
            status: selectedStatus.stockNonBlank,
            inventoryLocation: selectedLocation.stockNonBlank,
            session: session
        )
        page = min(page, max(0, pageCount - 1))
    }
}

private struct StockWideRow: View {
    let asset: APIStockAsset

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            StockThumbnail(asset: asset, size: 48).frame(width: 62, alignment: .leading)
            Text(asset.primaryIdentifier).font(.subheadline.weight(.semibold))
                .frame(width: 120, alignment: .leading).lineLimit(2)
            VStack(alignment: .leading, spacing: 3) {
                Text(asset.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                Text(asset.assetType).font(.caption).foregroundStyle(.secondary)
            }
            .frame(minWidth: 210, maxWidth: .infinity, alignment: .leading)
            Text(asset.category).font(.subheadline).frame(width: 150, alignment: .leading).lineLimit(2)
            Text(asset.inventoryLocation).font(.subheadline).frame(width: 180, alignment: .leading).lineLimit(2)
            StockStatusBadge(status: asset.status).frame(width: 140, alignment: .leading)
            Image(systemName: "chevron.right").font(.caption.weight(.bold))
                .foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, AppSpacing.md).padding(.vertical, AppSpacing.sm)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Abre el detalle del elemento de stock")
    }
}

private struct StockCompactRow: View {
    let asset: APIStockAsset
    let isNarrow: Bool

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            StockThumbnail(asset: asset, size: isNarrow ? 52 : 58)
            VStack(alignment: .leading, spacing: 3) {
                Text(asset.primaryIdentifier).font(.subheadline.bold())
                Text(asset.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                Text("\(asset.category) · \(asset.assetType)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Text(asset.inventoryLocation).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                if isNarrow { StockStatusBadge(status: asset.status).padding(.top, 3) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !isNarrow { StockStatusBadge(status: asset.status) }
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.secondary)
        }
        .padding(AppSpacing.md)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(BrandColor.glassStroke) }
        .contentShape(.rect)
    }
}

private struct StockIcon: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "shippingbox.fill")
            .font(.system(size: size * 0.36, weight: .semibold))
            .foregroundStyle(BrandColor.red)
            .frame(width: size, height: size)
            .background(BrandColor.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct StockThumbnail: View {
    let asset: APIStockAsset
    let size: CGFloat

    var body: some View {
        Group {
            if let image = asset.images?.first {
                StockRemoteImage(assetID: asset.id, image: image) {
                    StockIcon(size: size)
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                StockIcon(size: size)
            }
        }
    }
}

private struct StockRemoteImage<Placeholder: View>: View {
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
            data = try? await session.withValidAccessToken { token in
                try await StockAPIService(baseURLString: baseURL).imageData(
                    assetID: assetID,
                    imageID: image.id,
                    accessToken: token
                )
            }
        }
    }
}

private struct StockStatusBadge: View {
    let status: String

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(statusColor).frame(width: 7, height: 7)
            Text(status.capitalized).font(.caption.weight(.semibold)).lineLimit(1)
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(statusColor.opacity(0.10), in: Capsule())
    }

    private var statusColor: Color {
        let value = status.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if value.contains("sin stock") || value == "sin_stock"
            || value.contains("no disponible") || value.contains("baja")
            || value.contains("falla") {
            return BrandColor.red
        }
        if value.contains("en stock") || value == "en_stock"
            || value.contains("operativo") || value == "disponible" {
            return BrandColor.green
        }
        return BrandColor.amber
    }
}

private struct StockStatusLegend: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.md) { legendItems }
            VStack(alignment: .leading, spacing: AppSpacing.xs) { legendItems }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Leyenda de estados de stock")
    }

    @ViewBuilder
    private var legendItems: some View {
        legend("En Stock", color: BrandColor.green)
        legend("Otros estados", color: BrandColor.amber)
        legend("Sin stock, falla o baja", color: BrandColor.red)
    }

    private func legend(_ title: String, color: Color) -> some View {
        Label {
            Text(title)
        } icon: {
            Circle().fill(color).frame(width: 8, height: 8)
        }
    }
}

private struct StockDetailView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var stockStore: StockStore
    let assetID: String
    @State private var isPresentingEditor = false

    var body: some View {
        Group {
            if let asset = stockStore.details[assetID] {
                GeometryReader { geometry in
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppSpacing.lg) {
                            header(asset)
                            overview(asset, isWide: geometry.size.width >= 850)
                        }
                        .padding(geometry.size.width < 650 ? AppSpacing.md : AppSpacing.lg)
                        .frame(maxWidth: 1_100, alignment: .leading)
                        .frame(maxWidth: .infinity)
                    }
                    .refreshable {
                        await stockStore.loadDetail(id: assetID, session: session, force: true)
                    }
                }
            } else if stockStore.loadingDetailIDs.contains(assetID) {
                ProgressView("Cargando detalle de stock").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = stockStore.detailErrors[assetID] {
                ContentUnavailableView {
                    Label("No se pudo cargar el elemento", systemImage: "wifi.exclamationmark")
                } description: { Text(error) } actions: {
                    Button("Reintentar") {
                        Task { await stockStore.loadDetail(id: assetID, session: session, force: true) }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Detalle de stock")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await stockStore.loadCatalog(session: session)
            await stockStore.loadDetail(id: assetID, session: session)
        }
        .fullScreenCover(isPresented: $isPresentingEditor) {
            if let asset = stockStore.details[assetID] {
                StockEditorView(asset: asset)
                    .environmentObject(session)
                    .environmentObject(stockStore)
            }
        }
    }

    private func header(_ asset: APIStockAsset) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.md) {
                identity(asset)
                Spacer()
                editButton
            }
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                identity(asset)
                editButton.frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func identity(_ asset: APIStockAsset) -> some View {
        HStack(spacing: AppSpacing.md) {
            StockThumbnail(asset: asset, size: 72)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: AppSpacing.sm) {
                    Text(asset.primaryIdentifier).font(.title2.bold())
                    StockStatusBadge(status: asset.status)
                }
                Text(asset.name).font(.headline).foregroundStyle(.secondary)
                Label(asset.inventoryLocation, systemImage: "shippingbox")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var editButton: some View {
        if session.currentUser?.role == .administrator {
            Button { isPresentingEditor = true } label: {
                Label("Editar elemento", systemImage: "pencil")
            }
            .buttonStyle(.borderedProminent).tint(BrandColor.red)
        }
    }

    @ViewBuilder
    private func overview(_ asset: APIStockAsset, isWide: Bool) -> some View {
        if isWide {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                information(asset).frame(maxWidth: .infinity)
                StockPhotoPanel(asset: asset).frame(width: 340)
            }
        } else {
            VStack(spacing: AppSpacing.md) {
                information(asset)
                StockPhotoPanel(asset: asset)
            }
        }
    }

    private func information(_ asset: APIStockAsset) -> some View {
        ContentGlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Información general",
                    subtitle: "Datos maestros y ubicación actual del elemento"
                )
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 190), spacing: AppSpacing.md)],
                    spacing: AppSpacing.md
                ) {
                    StockInfoCell(title: "Categoría", value: asset.category, symbol: "square.stack.3d.up")
                    StockInfoCell(title: "Tipo", value: asset.assetType, symbol: "tag")
                    StockInfoCell(title: "Subsistema", value: asset.subsystem, symbol: "square.3.layers.3d")
                    StockInfoCell(title: "Ubicación de stock", value: asset.inventoryLocation, symbol: "shippingbox")
                    if let value = asset.manufacturer?.stockNonBlank {
                        StockInfoCell(title: "Fabricante", value: value, symbol: "building.2")
                    }
                    if let value = asset.model?.stockNonBlank {
                        StockInfoCell(title: "Modelo", value: value, symbol: "cube")
                    }
                    if let value = asset.partNumber?.stockNonBlank {
                        StockInfoCell(title: "Part number", value: value, symbol: "number")
                    }
                    if let value = asset.softwareVersion?.stockNonBlank {
                        StockInfoCell(title: "Versión de software", value: value, symbol: "cpu")
                    }
                }
            }
        }
    }
}

private struct StockPhotoPanel: View {
    let asset: APIStockAsset

    var body: some View {
        ContentGlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Imágenes")
                if let images = asset.images, !images.isEmpty {
                    TabView {
                        ForEach(images) { image in
                            StockRemoteImage(
                                assetID: asset.id,
                                image: image,
                                contentMode: .fit
                            ) {
                                ProgressView()
                            }
                            .padding(6)
                            .tag(image.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))
                    .frame(height: 210)
                    .background(BrandColor.graphite.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
                } else {
                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: "photo").font(.system(size: 52)).foregroundStyle(.secondary)
                        Text("Sin imágenes registradas").font(.headline)
                        Text("Puedes agregar una fotografía al editar este elemento.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 190)
                    .background(BrandColor.graphite.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

private struct StockInfoCell: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: symbol).foregroundStyle(BrandColor.red).frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                Text(value).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct StockEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var stockStore: StockStore

    let asset: APIStockAsset?
    @State private var name: String
    @State private var code: String
    @State private var partNumber: String
    @State private var manufacturer: String
    @State private var model: String
    @State private var softwareVersion: String
    @State private var subsystemID: String
    @State private var selectedCategoryName: String
    @State private var categoryID: String
    @State private var statusID: String
    @State private var locationID: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingImageData: Data?
    @State private var showCamera = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(asset: APIStockAsset?) {
        self.asset = asset
        _name = State(initialValue: asset?.name ?? "")
        _code = State(initialValue: asset?.primaryIdentifier ?? "")
        _partNumber = State(initialValue: asset?.partNumber ?? "")
        _manufacturer = State(initialValue: asset?.manufacturer ?? "")
        _model = State(initialValue: asset?.model ?? "")
        _softwareVersion = State(initialValue: asset?.softwareVersion ?? "")
        _subsystemID = State(initialValue: asset?.subsystemID ?? "")
        _selectedCategoryName = State(initialValue: asset?.category ?? "")
        _categoryID = State(initialValue: asset?.equipmentCategoryID ?? "")
        _statusID = State(initialValue: asset?.statusID ?? "")
        _locationID = State(initialValue: asset?.inventoryLocationID ?? "")
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        editorHeader
                        if geometry.size.width >= 820 {
                            HStack(alignment: .top, spacing: AppSpacing.lg) {
                                fieldsPanel.frame(maxWidth: .infinity)
                                imagesPanel.frame(width: 340)
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
                                .background(BrandColor.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: 1_120, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(MaintenanceScreenBackground())
            .navigationTitle(asset == nil ? "Nuevo elemento" : "Administrar stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await save() } } label: {
                        if isSaving { ProgressView() } else { Text("Guardar") }
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .task { await stockStore.loadCatalog(session: session) }
            .onChange(of: subsystemID) { _, _ in
                if !typeOptions.contains(where: { $0.id == categoryID }) {
                    selectedCategoryName = ""
                    categoryID = ""
                }
            }
            .onChange(of: selectedPhoto) { _, photo in
                guard let photo else { return }
                Task { await loadPhoto(photo) }
            }
            .sheet(isPresented: $showCamera) {
                CameraPhotoPicker { image in setImage(image) }
            }
            .alert("No se pudo guardar", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("Aceptar", role: .cancel) {}
            } message: { Text(errorMessage ?? "Error desconocido") }
        }
    }

    private var editorHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(asset == nil ? "Registrar elemento de stock" : "Información del elemento")
                .font(.title.bold())
            Text("Los cambios se reflejan en el inventario y en las consultas de stock.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var fieldsPanel: some View {
        ContentGlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SectionHeaderText(
                    title: "Datos del elemento",
                    subtitle: "Identificación, clasificación y ubicación en stock"
                )
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 220), spacing: AppSpacing.md)],
                    alignment: .leading,
                    spacing: AppSpacing.md
                ) {
                    editorField("Nombre", text: $name, symbol: "shippingbox")
                    editorField("Código o serie", text: $code, symbol: "barcode")
                    subsystemField
                    categoryField
                    typeField
                    statusField
                    locationField
                    editorField("Fabricante", text: $manufacturer, symbol: "building.2")
                    editorField("Modelo", text: $model, symbol: "tag")
                    editorField("Part number", text: $partNumber, symbol: "number")
                    editorField("Versión de software", text: $softwareVersion, symbol: "cpu")
                }
            }
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
                    Button { showCamera = true } label: {
                        Label("Cámara", systemImage: "camera")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                }
                if let asset, let images = asset.images, !images.isEmpty {
                    Divider()
                    Text("Galería actual").font(.subheadline.weight(.semibold))
                    ForEach(images) { image in
                        HStack(spacing: AppSpacing.sm) {
                            StockRemoteImage(assetID: asset.id, image: image) { ProgressView() }
                                .frame(width: 64, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text(image.fileName).font(.caption.weight(.semibold)).lineLimit(1)
                            Spacer()
                            if image.isPrimary {
                                Text("Portada").font(.caption2).foregroundStyle(BrandColor.red)
                            }
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
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "photo").font(.largeTitle)
                Text(asset?.images?.isEmpty == false ? "Agregar otra imagen" : "Sin imagen seleccionada")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 140)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5]))
            }
        }
    }

    private func editorField(_ title: String, text: Binding<String>, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
        }
    }

    private var subsystemField: some View {
        MaintenanceChoiceField(
            "Subsistema",
            systemImage: "square.3.layers.3d",
            selection: subsystemSelection
        ) {
            Text(stockStore.catalog == nil ? "Cargando..." : "Seleccionar").tag("")
            ForEach(stockStore.catalog?.subsystems ?? []) { option in
                Text(option.code ?? option.name).tag(option.id)
            }
        }
        .disabled(stockStore.catalog == nil)
    }

    private var categoryField: some View {
        MaintenanceChoiceField("Categoría", systemImage: "tag", selection: categorySelection) {
            Text(stockStore.catalog == nil ? "Cargando..." : "Seleccionar").tag("")
            ForEach(categoryNames, id: \.self) { Text($0).tag($0) }
        }
        .disabled(stockStore.catalog == nil || subsystemID.isEmpty)
    }

    private var typeField: some View {
        MaintenanceChoiceField(
            "Tipo",
            systemImage: "point.3.connected.trianglepath.dotted",
            selection: $categoryID
        ) {
            Text(stockStore.catalog == nil ? "Cargando..." : "Seleccionar").tag("")
            ForEach(typeOptions) { Text($0.nameN2).tag($0.id) }
        }
        .disabled(stockStore.catalog == nil || selectedCategoryName.isEmpty)
    }

    private var statusField: some View {
        MaintenanceChoiceField(
            "Estado",
            systemImage: "checkmark.seal",
            selection: $statusID
        ) {
            Text(stockStore.catalog == nil ? "Cargando..." : "Seleccionar").tag("")
            ForEach(stockStore.catalog?.statuses ?? []) { Text($0.name).tag($0.id) }
        }
        .disabled(stockStore.catalog == nil)
    }

    private var locationField: some View {
        MaintenanceChoiceField(
            "Ubicación de stock",
            systemImage: "shippingbox",
            selection: $locationID
        ) {
            Text(stockStore.catalog == nil ? "Cargando..." : "Seleccionar").tag("")
            ForEach(stockStore.catalog?.inventoryLocations ?? []) { Text($0.name).tag($0.id) }
        }
        .disabled(stockStore.catalog == nil)
    }

    private var subsystemSelection: Binding<String> {
        Binding(
            get: { subsystemID },
            set: { value in
                guard value != subsystemID else { return }
                subsystemID = value
                selectedCategoryName = ""
                categoryID = ""
            }
        )
    }

    private var categorySelection: Binding<String> {
        Binding(
            get: { selectedCategoryName },
            set: { value in
                guard value != selectedCategoryName else { return }
                selectedCategoryName = value
                categoryID = ""
            }
        )
    }

    private var categoryNames: [String] {
        Array(Set((stockStore.catalog?.categories ?? [])
            .filter { $0.subsystemID == subsystemID }
            .map(\.nameN1)))
            .sorted()
    }

    private var typeOptions: [EquipmentCategoryOption] {
        (stockStore.catalog?.categories ?? []).filter {
            $0.subsystemID == subsystemID && $0.nameN1 == selectedCategoryName
        }
    }

    private var isValid: Bool {
        name.stockNonBlank != nil && code.stockNonBlank != nil
            && !subsystemID.isEmpty && !categoryID.isEmpty
            && !statusID.isEmpty && !locationID.isEmpty
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
        pendingImageData = image.stockJPEGData(maxDimension: 1_800)
    }

    private func save() async {
        guard isValid else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let payload = StockWritePayload(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                serial_or_code: code.trimmingCharacters(in: .whitespacesAndNewlines),
                part_number: partNumber.stockNonBlank,
                equipment_category_id: categoryID,
                subsystem_id: subsystemID,
                status_id: statusID,
                inventory_location_id: locationID,
                manufacturer: manufacturer.stockNonBlank,
                model: model.stockNonBlank,
                software_version: softwareVersion.stockNonBlank
            )
            _ = try await stockStore.save(
                id: asset?.id,
                payload: payload,
                imageData: pendingImageData,
                session: session
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension UIImage {
    func stockJPEGData(maxDimension: CGFloat) -> Data? {
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

private extension String {
    var stockNonBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

struct StockListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            StockListView().environmentObject(SessionStore())
        }
    }
}
