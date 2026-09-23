import PhotosUI
import SwiftUI
import UIKit

private struct ToolCatalogEntry: Codable, Identifiable {
    var id: String
    var name: String
    var category: String
    var default_unit: String
    var requires_identified_unit: Bool
    var is_active: Bool
}

private struct ToolStockEntry: Decodable, Identifiable {
    let id: String
    let catalog_item_id: String
    let name: String
    let category: String
    let location: String
    let serial_number: String?
    let available: Double
    let unavailable: Double
    let calibration_until: String?
}

private struct ToolInventoryImageEntry: Decodable, Identifiable {
    let id: String
    let file_name: String
    let media_type: String
    let byte_size: Int
    let url: String
}

private struct ToolInventoryItemEntry: Decodable, Identifiable {
    let id: String
    let catalog_item_id: String?
    let tool_id: String?
    let model_code: String?
    let tool_code: String?
    let label: String?
    let quantity: Double
    let name: String
    let description: String?
    let cabinet: String?
    let cabinet_detail: String?
    let company: String?
    let classification: String?
    let category: String?
    let inventory_location_id: String?
    let location: String?
    let location_text: String?
    let status: String?
    let observations: String?
    let serial_number: String?
    let certification_number: String?
    let certification_valid_until: String?
    let certification_status: String?
    let images: [ToolInventoryImageEntry]
}

private struct ToolInventoryLocationEntry: Decodable, Identifiable {
    let id: String
    let name: String
    let description: String?
}

private struct ToolInventoryItemPayload: Encodable {
    let model_code: String?
    let tool_code: String?
    let label: String?
    let quantity: Double
    let name: String
    let description: String?
    let cabinet: String?
    let cabinet_detail: String?
    let company: String?
    let classification: String?
    let category: String?
    let inventory_location_id: String?
    let location_text: String?
    let status: String?
    let observations: String?
    let image_base64: String?
    let image_file_name: String?
    let image_media_type: String?
    let replace_image_ids: [String]
}

private struct ToolInventoryItemPage: Decodable {
    let items: [ToolInventoryItemEntry]
    let total: Int
    let limit: Int
    let offset: Int
}

private struct ToolMovementEntry: Decodable, Identifiable {
    let id: String
    let inventory_id: String
    let kind: String
    let name: String
    let location: String
    let serial_number: String?
    let responsible_name: String?
    let quantity: Double
    let outstanding: Double
    let created_at: String
    let notes: String?
}

private struct ToolPerson: Decodable, Identifiable { let id: String; let name: String }
private struct ToolWriteResult: Decodable { let id: String }

private struct ToolDeleteTarget: Identifiable {
    let id: String
    let name: String
    let code: String
    let quantity: Double
    let status: String
}

private enum InventorySheet: Identifiable {
    case create
    case edit(ToolInventoryItemEntry)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let item): return "edit-\(item.id)"
        }
    }
}

struct PreventiveTemplateEntry: Decodable, Identifiable {
    let id: String
    let name: String
    let subsystem: String
    let revision_id: String?
    let item_count: Int
}

private struct ChecklistRevisionEntry: Decodable, Identifiable {
    let id: String
    let number: Int
    let status: String
    let created_at: String
    let created_by_user_id: String?
}

private struct PreventiveTemplateDetail: Decodable, Identifiable {
    let id: String
    let name: String
    let manual_reference: String?
    let revision_id: String?
    let manual_checklist: [APIManualChecklistItem]
    let operational_checklist: [APIOperationalChecklistItem]
    let steps: [APITemplateStep]
    let revisions: [ChecklistRevisionEntry]
}

private func toolClient() -> APIClient {
    APIClient(baseURLString: UserDefaults.standard.string(forKey: "apiBaseURL") ?? "")
}

private let movementLabels = ["RECEIPT": "Ingreso", "ISSUE": "Salida", "RETURN": "Devolución",
    "CONSUMED": "Consumido", "DAMAGED": "Devuelto dañado", "LOST": "Extraviado",
    "ADJUST_ADD": "Ajuste positivo", "ADJUST_REMOVE": "Ajuste negativo"]

private func normalizedToolValue(_ value: String?) -> String {
    (value ?? "")
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        .uppercased()
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

struct ToolAdministrationView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var offlineStore: OfflineReportStore
    @State private var inventoryItems: [ToolInventoryItemEntry] = []
    @State private var stocks: [ToolStockEntry] = []
    @State private var movements: [ToolMovementEntry] = []
    @State private var mode = 0
    @State private var query = ""
    @State private var inventoryClassification = ""
    @State private var inventoryStatus = "all"
    @State private var inventoryLocations: [ToolInventoryLocationEntry] = []
    @State private var inventorySheet: InventorySheet?
    @State private var imageItem: ToolInventoryItemEntry?
    @State private var deleteTarget: ToolDeleteTarget?
    @State private var inventoryPage = 0
    @State private var error: String?
    @State private var loading = false
    @State private var movementStock: ToolStockEntry?
    @State private var settlement: ToolMovementEntry?
    @State private var hasMore = false

    private let inventoryPageSize = 10

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    header
                    Picker("Vista", selection: $mode) {
                        Text("Inventario").tag(0)
                        Text("Salidas pendientes").tag(1)
                        Text("Movimientos").tag(2)
                    }
                    .pickerStyle(.segmented)

                    if mode == 0 {
                        inventoryContent(isWide: geometry.size.width >= 900)
                    } else {
                        movementContent
                    }

                    if loading { ProgressView().frame(maxWidth: .infinity) }
                    if let error {
                        GlassPanel {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Label(error, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(BrandColor.red)
                                Button("Reintentar") { Task { await load() } }
                                    .buttonStyle(ActionTileButtonStyle())
                            }
                        }
                    }
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: 1200)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Herramientas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if mode == 0 {
                    Button { inventorySheet = .create } label: {
                        Label("Nueva herramienta", systemImage: "plus")
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!offlineStore.isNetworkAvailable)
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .onChange(of: query) { _, _ in inventoryPage = 0 }
        .onChange(of: inventoryClassification) { _, _ in inventoryPage = 0 }
        .onChange(of: inventoryStatus) { _, _ in inventoryPage = 0 }
        .sheet(item: $inventorySheet, onDismiss: { Task { await load() } }) { sheet in
            switch sheet {
            case .create:
                ToolInventoryEditorView(item: nil, locations: inventoryLocations)
            case .edit(let item):
                ToolInventoryEditorView(item: item, locations: inventoryLocations)
            }
        }
        .sheet(item: $imageItem) { item in
            ToolInventoryImageGalleryView(item: item)
        }
        .alert("Eliminar herramienta", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("Eliminar", role: .destructive) {
                guard let target = deleteTarget else { return }
                Task { await deleteInventoryItem(target) }
            }
            Button("Cancelar", role: .cancel) { deleteTarget = nil }
        } message: {
            if let target = deleteTarget {
                Text("Se eliminará \(target.name) (\(target.code)) y sus imágenes. Esta acción no se puede deshacer.")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Herramientas")
                    .font(.largeTitle.bold())
                Text("Gestiona el inventario físico del almacén")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            NavigationLink {
                PreventiveTemplateListView()
            } label: {
                Label("Checklists", systemImage: "checklist")
            }
            .buttonStyle(.glass)
        }
    }

    @ViewBuilder
    private func inventoryContent(isWide: Bool) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Buscar por nombre, código o categoría", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(AppSpacing.md)
                .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack(spacing: AppSpacing.md) {
                    MaintenanceChoiceField("Clasificación", systemImage: "square.stack.3d.up", selection: $inventoryClassification) {
                        Text("Todas").tag("")
                        Text("Herramientas manuales").tag("HERRAMIENTA MANUAL")
                        Text("Llaves / accesos").tag("LLAVE")
                        Text("Consumibles").tag("CONSUMIBLE")
                        Text("Equipos").tag("EQUIPO")
                    }
                    MaintenanceChoiceField("Estado", systemImage: "checkmark.seal", selection: $inventoryStatus) {
                        Text("Todos").tag("all")
                        Text("Disponible").tag("DISPONIBLE")
                        Text("Sin stock").tag("SIN STOCK")
                        Text("Averiado").tag("AVERIADO")
                    }
                    Spacer(minLength: 0)
                    Button {
                        query = ""
                        inventoryClassification = ""
                        inventoryStatus = "all"
                    } label: {
                        Label("Limpiar filtros", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(ActionTileButtonStyle())
                }
            }
        }

        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(filteredInventoryItems.count) herramientas")
                    .font(.title3.bold())
                Text("Mostrando \(pageItems.count) de \(filteredInventoryItems.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Inventario físico")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }

        if filteredInventoryItems.isEmpty && !loading {
            ContentUnavailableView("No hay herramientas", systemImage: "shippingbox", description: Text("Ajusta los filtros o registra una nueva herramienta."))
        } else {
            if isWide {
                inventoryTable
            } else {
                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(pageItems) { item in
                        ToolInventoryCompactRow(
                            item: item,
                            onImage: { imageItem = item },
                            onEdit: { inventorySheet = .edit(item) },
                            onDelete: { deleteTarget = makeDeleteTarget(item) }
                        )
                    }
                }
            }
            inventoryPagination
        }

    }

    private var inventoryTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.sm) {
                Text("Imagen").frame(width: 64, alignment: .leading)
                Text("Código").frame(width: 105, alignment: .leading)
                Text("Nombre").frame(minWidth: 170, maxWidth: .infinity, alignment: .leading)
                Text("Categoría").frame(width: 125, alignment: .leading)
                Text("Ubicación").frame(width: 150, alignment: .leading)
                Text("Stock").frame(width: 72, alignment: .trailing)
                Text("Estado").frame(width: 120, alignment: .leading)
                Text("Acciones").frame(width: 130, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)

            ForEach(pageItems) { item in
                ToolInventoryWideRow(
                    item: item,
                    onImage: { imageItem = item },
                    onEdit: { inventorySheet = .edit(item) },
                    onDelete: { deleteTarget = makeDeleteTarget(item) }
                )
            }
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(BrandColor.glassStroke) }
    }

    private var inventoryPagination: some View {
        PaginationBar(currentPage: inventoryPage, pageCount: pageCount) { selectedPage in
            inventoryPage = selectedPage
        }
        .padding(.vertical, AppSpacing.sm)
    }

    private var movementContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            ForEach(movements.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { movement in
                GlassPanel {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(movement.name).font(.headline)
                        Text("\(movementLabels[movement.kind] ?? movement.kind): \(movement.quantity.formatted())")
                        Text([movement.serial_number, movement.responsible_name, movement.location].compactMap { $0 }.joined(separator: " · "))
                            .foregroundStyle(.secondary)
                        Text(movement.created_at).font(.caption)
                        if let notes = movement.notes { Text(notes).font(.caption) }
                        if movement.kind == "ISSUE", movement.outstanding > 0 {
                            Text("Pendiente: \(movement.outstanding.formatted())")
                            Button("Registrar devolución / consumo") {
                                settlement = movement
                                movementStock = stocks.first { $0.id == movement.inventory_id }
                            }
                            .buttonStyle(ActionTileButtonStyle())
                            .disabled(!offlineStore.isNetworkAvailable)
                        }
                    }
                }
            }
            if hasMore {
                Button("Mostrar más") { Task { await loadMore() } }
                    .buttonStyle(ActionTileButtonStyle())
                    .disabled(loading)
            }
        }
    }

    private var pageItems: [ToolInventoryItemEntry] {
        let start = inventoryPage * inventoryPageSize
        guard start < filteredInventoryItems.count else { return [] }
        return Array(filteredInventoryItems[start..<min(start + inventoryPageSize, filteredInventoryItems.count)])
    }

    private var pageCount: Int {
        max(1, Int(ceil(Double(filteredInventoryItems.count) / Double(inventoryPageSize))))
    }

    private var filteredInventoryItems: [ToolInventoryItemEntry] {
        inventoryItems.filter { item in
            let matchesSearch = query.isEmpty
                || item.name.localizedCaseInsensitiveContains(query)
                || (item.tool_code?.localizedCaseInsensitiveContains(query) ?? false)
                || (item.label?.localizedCaseInsensitiveContains(query) ?? false)
                || (item.category?.localizedCaseInsensitiveContains(query) ?? false)
                || (item.location?.localizedCaseInsensitiveContains(query) ?? false)
            return matchesSearch
                && (inventoryClassification.isEmpty || normalizedToolValue(item.classification) == normalizedToolValue(inventoryClassification))
                && (inventoryStatus == "all" || normalizedToolValue(item.status) == normalizedToolValue(inventoryStatus))
        }
    }

    private func makeDeleteTarget(_ item: ToolInventoryItemEntry) -> ToolDeleteTarget {
        ToolDeleteTarget(
            id: item.id,
            name: item.name,
            code: item.tool_code ?? item.label ?? "Sin código",
            quantity: item.quantity,
            status: item.status ?? "Sin estado"
        )
    }

    @MainActor private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            let page: ToolInventoryItemPage = try await session.withValidAccessToken {
                try await toolClient().get(
                    "api/v1/tool-admin/items",
                    bearerToken: $0,
                    queryItems: [.init(name: "limit", value: "500")]
                )
            }
            inventoryItems = page.items
            inventoryPage = min(inventoryPage, max(0, pageCount - 1))
            inventoryLocations = try await session.withValidAccessToken {
                try await toolClient().get("api/v1/tool-admin/storage-locations", bearerToken: $0)
            }
            stocks = try await session.withValidAccessToken {
                try await toolClient().get("api/v1/tool-admin/inventory", bearerToken: $0)
            }
            movements = []
            if mode != 0 { await loadMore() }
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor private func loadMore() async {
        do {
            let rows: [ToolMovementEntry] = try await session.withValidAccessToken {
                try await toolClient().get(
                    "api/v1/tool-admin/movements",
                    bearerToken: $0,
                    queryItems: [
                        .init(name: "open_only", value: mode == 1 ? "true" : "false"),
                        .init(name: "offset", value: String(movements.count)),
                    ]
                )
            }
            movements += rows
            hasMore = rows.count == 100
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor private func deleteInventoryItem(_ target: ToolDeleteTarget) async {
        do {
            try await session.withValidAccessToken { token in
                try await toolClient().delete("api/v1/tool-admin/items/\(target.id)", bearerToken: token)
            }
            deleteTarget = nil
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct ToolInventoryWideRow: View {
    let item: ToolInventoryItemEntry
    let onImage: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ToolInventoryThumbnail(image: item.images.first, height: 52, onTap: onImage)
                .frame(width: 64)
            Text(item.tool_code ?? item.label ?? "—")
                .font(.caption.weight(.semibold))
                .frame(width: 105, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                if let model = item.model_code { Text(model).font(.caption).foregroundStyle(.secondary) }
                if let certificate = item.certification_number {
                    Text("Cert. \(certificate)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 170, maxWidth: .infinity, alignment: .leading)
            Text(item.category ?? "—").font(.caption).frame(width: 125, alignment: .leading)
            Text(item.location ?? item.location_text ?? "—").font(.caption).lineLimit(2).frame(width: 150, alignment: .leading)
            Text(item.quantity.formatted()).frame(width: 72, alignment: .trailing)
            ToolInventoryStatusBadge(status: item.status)
                .frame(width: 120, alignment: .leading)
            ToolInventoryRowActions(onImage: onImage, onEdit: onEdit, onDelete: onDelete)
                .frame(width: 130, alignment: .trailing)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(.background.opacity(0.40))
        .overlay(alignment: .bottom) { Divider().opacity(0.45) }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .clipped()
    }
}

private struct ToolInventoryCompactRow: View {
    let item: ToolInventoryItemEntry
    let onImage: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    ToolInventoryThumbnail(image: item.images.first, height: 64, onTap: onImage)
                        .frame(width: 76)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name).font(.headline).lineLimit(2)
                        Text(item.tool_code ?? item.label ?? "Sin código")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    ToolInventoryStatusBadge(status: item.status)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: AppSpacing.xs) {
                    ToolInventoryDetail(label: "Categoría", value: item.category ?? "—")
                    ToolInventoryDetail(label: "Stock", value: item.quantity.formatted())
                    ToolInventoryDetail(label: "Ubicación", value: item.location ?? item.location_text ?? "—")
                    ToolInventoryDetail(label: "Etiqueta", value: item.label ?? "—")
                    if item.tool_id != nil {
                        ToolInventoryDetail(
                            label: "Certificación",
                            value: inventoryCertificationLabel(item)
                        )
                    }
                }
                ToolInventoryRowActions(onImage: onImage, onEdit: onEdit, onDelete: onDelete)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipped()
    }
}

private struct ToolInventoryDetail: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.caption).lineLimit(2)
        }
    }
}

private func inventoryCertificationLabel(_ item: ToolInventoryItemEntry) -> String {
    switch item.certification_status {
    case "VALID":
        return "Vigente hasta \(item.certification_valid_until ?? "fecha no indicada")"
    case "EXPIRED":
        return "Vencida el \(item.certification_valid_until ?? "fecha no indicada")"
    case "MISSING":
        return "Sin certificado"
    default:
        return "No requerida"
    }
}

private struct ToolInventoryRowActions: View {
    let onImage: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Button(action: onImage) { Image(systemName: "eye") }
                .buttonStyle(.glass)
                .accessibilityLabel("Ver imágenes")
            Button(action: onEdit) { Image(systemName: "pencil") }
                .buttonStyle(.glass)
                .tint(BrandColor.red)
                .accessibilityLabel("Editar herramienta")
            Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                .buttonStyle(.glass)
                .accessibilityLabel("Eliminar herramienta")
        }
    }
}

private struct ToolInventoryStatusBadge: View {
    let status: String?

    private var normalizedStatus: String { normalizedToolValue(status) }

    private var color: Color {
        switch normalizedStatus {
        case "DISPONIBLE": return BrandColor.green
        case "SIN STOCK": return BrandColor.red
        case "AVERIADO": return BrandColor.red
        default: return BrandColor.amber
        }
    }

    private var label: String {
        switch normalizedStatus {
        case "DISPONIBLE": return "Disponible"
        case "SIN STOCK": return "Sin stock"
        case "AVERIADO": return "Averiado"
        default: return status?.capitalized ?? "Sin estado"
        }
    }

    var body: some View {
        Label(label, systemImage: "circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 6)
            .background(color.opacity(0.10), in: Capsule())
    }
}

private struct ToolInventoryThumbnail: View {
    @EnvironmentObject private var session: SessionStore
    let image: ToolInventoryImageEntry?
    let height: CGFloat
    let onTap: () -> Void
    @State private var loadedImage: UIImage?
    @State private var failed = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                if let loadedImage {
                    Image(uiImage: loadedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(4)
                        .clipped()
                } else if image != nil && !failed {
                    ProgressView()
                } else {
                    Image(systemName: failed ? "arrow.clockwise" : "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .clipped()
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .disabled(image == nil)
        .task(id: image?.id) {
            guard let image else { return }
            do {
                let data: Data = try await session.withValidAccessToken {
                    try await toolClient().getData(image.url, bearerToken: $0)
                }
                loadedImage = UIImage(data: data)
            } catch {
                failed = true
            }
        }
    }
}

private struct ToolInventoryImageGalleryView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    let item: ToolInventoryItemEntry
    @State private var currentIndex = 0
    @State private var loadedImage: UIImage?
    @State private var error: String?

    private var currentImage: ToolInventoryImageEntry? {
        guard item.images.indices.contains(currentIndex) else { return nil }
        return item.images[currentIndex]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Vista de imagen").font(.title2.bold())
                        Text(item.name).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(item.images.isEmpty ? 0 : currentIndex + 1) / \(item.images.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, AppSpacing.lg)

                HStack(spacing: AppSpacing.md) {
                    Button { currentIndex = max(0, currentIndex - 1) } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.glass)
                    .disabled(currentIndex == 0)

                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                        if let loadedImage {
                            Image(uiImage: loadedImage)
                                .resizable()
                                .scaledToFit()
                                .padding(AppSpacing.md)
                        } else if error != nil {
                            ContentUnavailableView("No se pudo cargar la imagen", systemImage: "photo.badge.exclamationmark")
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(maxWidth: 820, maxHeight: 560)

                    Button { currentIndex = min(item.images.count - 1, currentIndex + 1) } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.glass)
                    .disabled(currentIndex >= item.images.count - 1)
                }
                .padding(.horizontal, AppSpacing.lg)

                if let currentImage {
                    Text(currentImage.file_name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.top, AppSpacing.lg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } } }
            .task(id: currentImage?.id) { await loadCurrentImage() }
        }
    }

    @MainActor private func loadCurrentImage() async {
        loadedImage = nil
        error = nil
        guard let currentImage else { return }
        do {
            let data: Data = try await session.withValidAccessToken {
                try await toolClient().getData(currentImage.url, bearerToken: $0)
            }
            loadedImage = UIImage(data: data)
            if loadedImage == nil { error = "Formato de imagen no reconocido." }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct ToolInventoryEditorView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    let item: ToolInventoryItemEntry?
    let locations: [ToolInventoryLocationEntry]

    @State private var modelCode: String
    @State private var toolCode: String
    @State private var label: String
    @State private var quantity: String
    @State private var name: String
    @State private var description: String
    @State private var cabinet: String
    @State private var cabinetDetail: String
    @State private var company: String
    @State private var classification: String
    @State private var category: String
    @State private var locationID: String
    @State private var locationText: String
    @State private var status: String
    @State private var observations: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var imageFileName: String?
    @State private var imageMediaType: String?
    @State private var existingImages: [ToolInventoryImageEntry]
    @State private var showCamera = false
    @State private var isSaving = false
    @State private var isRemovingImage = false
    @State private var error: String?

    init(item: ToolInventoryItemEntry?, locations: [ToolInventoryLocationEntry]) {
        self.item = item
        self.locations = locations
        _modelCode = State(initialValue: item?.model_code ?? "")
        _toolCode = State(initialValue: item?.tool_code ?? "")
        _label = State(initialValue: item?.label ?? "")
        _quantity = State(initialValue: item.map { $0.quantity.formatted(.number.precision(.fractionLength(0...3))) } ?? "0")
        _name = State(initialValue: item?.name ?? "")
        _description = State(initialValue: item?.description ?? "")
        _cabinet = State(initialValue: item?.cabinet ?? "")
        _cabinetDetail = State(initialValue: item?.cabinet_detail ?? "")
        _company = State(initialValue: item?.company ?? "")
        _classification = State(initialValue: item?.classification ?? "HERRAMIENTA MANUAL")
        _category = State(initialValue: item?.category ?? "")
        _locationID = State(initialValue: item?.inventory_location_id ?? "")
        _locationText = State(initialValue: item?.location_text ?? item?.location ?? "")
        _status = State(initialValue: item?.status ?? "DISPONIBLE")
        _observations = State(initialValue: item?.observations ?? "")
        _existingImages = State(initialValue: item?.images ?? [])
    }

    private let classificationOptions = [
        "HERRAMIENTA MANUAL", "LLAVE", "CONSUMIBLE", "EQUIPO",
    ]
    private let categoryOptions = [
        "LLAVE", "DESTORNILLADOR", "INSTRUMENTO", "PERCUSIÓN", "GALGA",
        "LIMPIEZA", "COMUNICACIÓN", "OTRA",
    ]
    private let statusOptions = ["DISPONIBLE", "SIN STOCK", "AVERIADO"]

    private var categoryChoices: [String] {
        var values = categoryOptions
        if !category.isEmpty && !values.contains(category) { values.insert(category, at: 0) }
        return values
    }

    private var classificationChoices: [String] {
        var values = classificationOptions
        if !classification.isEmpty && !values.contains(classification) { values.insert(classification, at: 0) }
        return values
    }

    private var selectedLocationName: String {
        locations.first(where: { $0.id == locationID })?.name ?? locationText
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: AppSpacing.lg) {
                            imagePanel.frame(width: 220)
                            inventoryEditorFields
                        }
                        .frame(minWidth: 760)
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            imagePanel
                            inventoryEditorFields
                        }
                    }

                    MaintenanceTextArea(
                        title: "Descripción",
                        placeholder: "Nombre con más detalles...",
                        text: $description,
                        systemImage: "text.alignleft",
                        minimumLines: 3,
                        maximumLines: 5
                    )
                    MaintenanceTextArea(
                        title: "Observaciones",
                        placeholder: "Observaciones del inventario...",
                        text: $observations,
                        systemImage: "note.text",
                        minimumLines: 2,
                        maximumLines: 4
                    )

                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(BrandColor.red)
                    }
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
            .background(MaintenanceScreenBackground())
            .navigationTitle(item == nil ? "Nueva herramienta" : "Editar herramienta")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                GlassPanel {
                    ActionButtonGrid {
                        Button("Cancelar") { dismiss() }
                            .buttonStyle(ActionTileButtonStyle())
                        Button {
                            Task { await save() }
                        } label: {
                            if isSaving { ProgressView() } else { Label(item == nil ? "Guardar" : "Guardar cambios", systemImage: "checkmark.circle.fill") }
                        }
                        .buttonStyle(ActionTileButtonStyle(prominent: true))
                        .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.sm)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .disabled(isSaving)
                }
            }
            .onChange(of: selectedPhoto) { _, photo in
                guard let photo else { return }
                Task { await loadPhoto(photo) }
            }
            .sheet(isPresented: $showCamera) {
                CameraPhotoPicker { image in
                    setImage(image, fileName: "herramienta.jpg")
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private var imagePanel: some View {
        VStack(spacing: AppSpacing.sm) {
            imagePreview

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(existingImages.isEmpty && imageData == nil ? "Agregar imagen" : "Cambiar imagen", systemImage: "photo.badge.plus")
            }
            .buttonStyle(ActionTileButtonStyle())

            Button {
                showCamera = true
            } label: {
                Label("Tomar foto", systemImage: "camera.fill")
            }
            .buttonStyle(ActionTileButtonStyle())
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

            if !existingImages.isEmpty {
                Button(role: .destructive) {
                    Task { await removeFirstExistingImage() }
                } label: {
                    Label(isRemovingImage ? "Eliminando..." : "Eliminar imagen", systemImage: "trash")
                }
                .buttonStyle(ActionTileButtonStyle())
                .disabled(isRemovingImage || isSaving)
            }
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BrandColor.glassStroke)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipped()
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let imageData, let image = UIImage(data: imageData) {
            ZStack {
                Color.primary.opacity(0.05)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 175)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .clipped()
        } else if let image = existingImages.first {
            ToolInventoryThumbnail(image: image, height: 175, onTap: {})
        } else {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Agregar imagen")
                    .font(.subheadline.weight(.semibold))
                Text("JPG, PNG · máx. 5 MB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 175)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundStyle(Color.secondary.opacity(0.45))
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .clipped()
        }
    }

    private var inventoryEditorFields: some View {
        VStack(spacing: AppSpacing.md) {
            MaintenanceFieldGrid {
                MaintenanceTextField(title: "Código modelo", placeholder: "Ej. HT-0006", text: $modelCode, systemImage: "number")
                MaintenanceTextField(title: "Código", placeholder: "Código de la herramienta", text: $toolCode, systemImage: "barcode")
                MaintenanceTextField(title: "Etiqueta", placeholder: "001", text: $label, systemImage: "tag", autocapitalization: .never, disablesAutocorrection: true)
                MaintenanceTextField(title: "Nombre", placeholder: "Nombre de la herramienta", text: $name, systemImage: "wrench.and.screwdriver")
                MaintenanceTextField(title: "Empresa", placeholder: "Empresa de procedencia", text: $company, systemImage: "building.2")
                MaintenanceTextField(title: "Armario", placeholder: "Armario o almacén", text: $cabinet, systemImage: "cabinet")
                MaintenanceTextField(title: "Gabinete", placeholder: "Ubicación dentro del armario", text: $cabinetDetail, systemImage: "square.split.2x2")
            }
            MaintenanceFieldGrid {
                MaintenanceChoiceField("Clasificación", systemImage: "square.stack.3d.up", selection: $classification) {
                    ForEach(classificationChoices, id: \.self) { Text($0).tag($0) }
                }
                MaintenanceChoiceField("Categoría", systemImage: "tag", selection: $category) {
                    Text("Sin categoría").tag("")
                    ForEach(categoryChoices, id: \.self) { Text($0).tag($0) }
                }
                MaintenanceTextField(title: "Cantidad / stock", placeholder: "0", text: $quantity, systemImage: "number", autocapitalization: .never, disablesAutocorrection: true)
                MaintenanceChoiceField("Estado", systemImage: "checkmark.seal", selection: $status) {
                    ForEach(statusOptions, id: \.self) { Text($0).tag($0) }
                }
                MaintenanceChoiceField("Ubicación", systemImage: "shippingbox", selection: $locationID) {
                    Text("Sin ubicación").tag("")
                    ForEach(locations) { location in
                        Text(location.name).tag(location.id)
                    }
                }
            }
            if classification == "EQUIPO" {
                Label(
                    item?.tool_id == nil
                        ? "El código identifica la serie del equipo. La certificación se mostrará cuando esté registrada."
                        : inventoryCertificationLabel(item!),
                    systemImage: item?.certification_status == "VALID"
                        ? "checkmark.seal.fill"
                        : "exclamationmark.shield.fill"
                )
                .font(.caption)
                .foregroundStyle(item?.certification_status == "VALID" ? .green : .orange)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if locations.isEmpty {
                MaintenanceTextField(title: "Ubicación", placeholder: "Ubicación de almacenamiento", text: $locationText, systemImage: "shippingbox")
            } else if !selectedLocationName.isEmpty {
                Text("Ubicación seleccionada: \(selectedLocationName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @MainActor private func loadPhoto(_ photo: PhotosPickerItem) async {
        do {
            guard let data = try await photo.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            setImage(image, fileName: "herramienta.jpg")
        } catch {
            self.error = "No se pudo cargar la imagen seleccionada."
        }
    }

    private func setImage(_ image: UIImage, fileName: String) {
        let normalized = image.normalizedForInventory(maxDimension: 1800)
        imageData = normalized.jpegData(compressionQuality: 0.82)
        imageFileName = fileName
        imageMediaType = "image/jpeg"
    }

    @MainActor private func removeFirstExistingImage() async {
        guard let image = existingImages.first else { return }
        isRemovingImage = true
        defer { isRemovingImage = false }
        do {
            try await session.withValidAccessToken { token in
                try await toolClient().delete("api/v1/tool-admin/items/\(item?.id ?? "")/images/\(image.id)", bearerToken: token)
            }
            existingImages.removeFirst()
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor private func save() async {
        let parsedQuantity = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 0
        let payload = ToolInventoryItemPayload(
            model_code: optionalValue(modelCode),
            tool_code: optionalValue(toolCode),
            label: optionalValue(label),
            quantity: max(0, parsedQuantity),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: optionalValue(description),
            cabinet: optionalValue(cabinet),
            cabinet_detail: optionalValue(cabinetDetail),
            company: optionalValue(company),
            classification: optionalValue(classification),
            category: optionalValue(category),
            inventory_location_id: optionalValue(locationID),
            location_text: optionalValue(locationText),
            status: optionalValue(status),
            observations: optionalValue(observations),
            image_base64: imageData?.base64EncodedString(),
            image_file_name: imageFileName,
            image_media_type: imageMediaType,
            replace_image_ids: imageData != nil ? Array(existingImages.prefix(1).map(\.id)) : []
        )
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            _ = try await session.withValidAccessToken { token in
                if let item {
                    return try await toolClient().put("api/v1/tool-admin/items/\(item.id)", body: payload, bearerToken: token) as ToolWriteResult
                }
                return try await toolClient().post("api/v1/tool-admin/items", body: payload, bearerToken: token) as ToolWriteResult
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func optionalValue(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension UIImage {
    func normalizedForInventory(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: target).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

private struct CatalogEditorView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ToolCatalogEntry
    @State private var busy = false
    @State private var error: String?
    init(item: ToolCatalogEntry) { _draft = State(initialValue: item) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Definición compartida del catálogo") {
                    TextField("Nombre", text: $draft.name)
                    Picker("Categoría", selection: $draft.category) {
                        ForEach(OperationalChecklistCategory.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    TextField("Unidad de medida", text: $draft.default_unit)
                    Toggle("Identificar por código o serie", isOn: $draft.requires_identified_unit).disabled(draft.category == "EQUIPMENT")
                    Toggle("Activo", isOn: $draft.is_active)
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle(draft.id.isEmpty ? "Nueva herramienta" : "Editar herramienta")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() }.disabled(busy) }
                ToolbarItem(placement: .confirmationAction) { Button(busy ? "Guardando…" : "Guardar") { Task { await save() } }.disabled(busy || draft.name.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
            .onChange(of: draft.category) { _, value in if value == "EQUIPMENT" { draft.requires_identified_unit = true } }
            .interactiveDismissDisabled(busy)
        }
    }
    @MainActor private func save() async {
        busy = true; defer { busy = false }
        do {
            let _: ToolWriteResult = try await session.withValidAccessToken { token in
                if draft.id.isEmpty { return try await toolClient().post("api/v1/tool-admin/catalog", body: draft, bearerToken: token) }
                return try await toolClient().put("api/v1/tool-admin/catalog/\(draft.id)", body: draft, bearerToken: token)
            }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

private struct ToolStockEditorView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    let item: ToolCatalogEntry
    @State private var location = ""
    @State private var serial = ""
    @State private var model = ""
    @State private var brand = ""
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section(item.name) {
                    TextField("Ubicación de almacenamiento", text: $location)
                    if item.requires_identified_unit {
                        TextField("Código o número de serie", text: $serial)
                        TextField("Modelo", text: $model)
                        TextField("Fabricante", text: $brand)
                    }
                    Text("Después de registrar, utiliza Ingreso para registrar la cantidad recibida.").font(.caption).foregroundStyle(.secondary)
                }
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Registrar existencia")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() }.disabled(busy) }
                ToolbarItem(placement: .confirmationAction) { Button(busy ? "Guardando…" : "Guardar") { Task { await save() } }.disabled(busy || location.isEmpty || (item.requires_identified_unit && serial.isEmpty)) }
            }.interactiveDismissDisabled(busy)
        }
    }
    @MainActor private func save() async {
        busy = true; defer { busy = false }
        struct Payload: Encodable { let catalog_item_id: String; let location: String; let serial_number: String?; let model: String; let brand: String }
        do {
            let _: ToolWriteResult = try await session.withValidAccessToken {
                try await toolClient().post("api/v1/tool-admin/inventory", body: Payload(catalog_item_id: item.id, location: location,
                    serial_number: item.requires_identified_unit ? serial : nil, model: model, brand: brand), bearerToken: $0)
            }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

private struct ToolMovementEditorView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    let stock: ToolStockEntry
    let issue: ToolMovementEntry?
    @State private var kind = "RECEIPT"
    @State private var quantity = 1.0
    @State private var responsible = ""
    @State private var people: [ToolPerson] = []
    @State private var notes = ""
    @State private var busy = false
    @State private var error: String?
    @State private var requestID = UUID()
    @State private var linkedActivities: Set<String> = []
    @State private var choosingActivities = false
    var body: some View {
        NavigationStack {
            Form {
                Section(stock.name) {
                    Text(stock.serial_number ?? stock.location)
                    Picker("Movimiento", selection: $kind) {
                        ForEach(options, id: \.self) { Text(movementLabels[$0] ?? $0).tag($0) }
                    }
                    LabeledContent("Cantidad") { TextField("Cantidad", value: $quantity, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).disabled(stock.serial_number != nil) }
                    if kind == "ISSUE" {
                        Picker("Responsable", selection: $responsible) {
                            Text("Seleccionar").tag("")
                            ForEach(people) { Text($0.name).tag($0.id) }
                        }
                        Button("Vincular mantenimientos (\(linkedActivities.count))") { choosingActivities = true }
                    }
                    TextField("Motivo / observaciones", text: $notes, axis: .vertical).lineLimit(3...6)
                    if let issue { Text("Pendiente de esta salida: \(issue.outstanding.formatted())") }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Movimiento de herramientas")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() }.disabled(busy) }
                ToolbarItem(placement: .confirmationAction) { Button(busy ? "Guardando…" : "Confirmar") { Task { await save() } }.disabled(busy || quantity <= 0 || (kind == "ISSUE" && responsible.isEmpty)) }
            }
            .task {
                if issue != nil { kind = "RETURN" }
                do { people = try await session.withValidAccessToken { try await toolClient().get("api/v1/tool-admin/people", bearerToken: $0) } }
                catch { self.error = error.localizedDescription }
            }
            .sheet(isPresented: $choosingActivities) { ToolActivityPicker(selection: $linkedActivities) }
            .interactiveDismissDisabled(busy)
        }
    }
    private var options: [String] {
        if issue != nil { return stock.category == "CONSUMABLE" ? ["RETURN", "CONSUMED", "DAMAGED", "LOST"] : ["RETURN", "DAMAGED", "LOST"] }
        return ["RECEIPT", "ISSUE", "ADJUST_ADD", "ADJUST_REMOVE"]
    }
    @MainActor private func save() async {
        struct Payload: Encodable {
            let id: String; let inventory_id: String; let kind: String; let quantity: Double
            let issue_id: String?; let responsible_user_id: String?; let activity_ids: [String]; let notes: String
        }
        busy = true; defer { busy = false }
        do {
            let _: ToolWriteResult = try await session.withValidAccessToken {
                try await toolClient().post("api/v1/tool-admin/movements", body: Payload(id: requestID.uuidString, inventory_id: stock.id, kind: kind, quantity: quantity,
                    issue_id: issue?.id, responsible_user_id: kind == "ISSUE" ? responsible : nil, activity_ids: linkedActivities.sorted(), notes: notes), bearerToken: $0)
            }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

private struct ToolActivityPicker: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: Set<String>
    @State private var query = ""
    @State private var rows: [Activity] = []
    @State private var error: String?
    @State private var hasMore = false
    private struct Activity: Decodable, Identifiable { let id: String; let title: String; let status: String }
    private struct Page: Decodable { let items: [Activity]; let total: Int }
    var body: some View {
        NavigationStack {
            List {
                ForEach(rows) { row in
                    Button {
                        if selection.contains(row.id) { selection.remove(row.id) } else { selection.insert(row.id) }
                    } label: { Label(row.title, systemImage: selection.contains(row.id) ? "checkmark.circle.fill" : "circle") }
                }
                if hasMore { Button("Mostrar más") { Task { await load(reset: false) } } }
                if let error { Text(error) }
            }.navigationTitle("Mantenimientos vinculados")
            .searchable(text: $query)
            .task(id: query) { await load(reset: true) }
            .toolbar { Button("Listo") { dismiss() } }
        }
    }
    @MainActor private func load(reset: Bool) async {
        do {
            let page: Page = try await session.withValidAccessToken {
                try await toolClient().get("api/v1/maintenance-activities", bearerToken: $0,
                    queryItems: [.init(name: "q", value: query), .init(name: "offset", value: String(reset ? 0 : rows.count))])
            }
            if Task.isCancelled { return }
            rows = reset ? page.items : rows + page.items; hasMore = rows.count < page.total
        } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
}

struct PreventiveTemplateListView: View {
    @EnvironmentObject private var session: SessionStore
    var assetID: String? = nil
    var equipmentName: String? = nil
    var location: String? = nil
    @State private var rows: [PreventiveTemplateEntry] = []
    @State private var query = ""
    @State private var subsystem = ""
    @State private var checklistStatus = "all"
    @State private var page = 0
    @State private var error: String?
    @State private var loading = false
    private let pageSize = 10

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Checklist preventivos")
                            .font(.largeTitle.bold())
                        Text("Selecciona un tipo de mantenimiento para configurar su checklist de herramientas.")
                            .foregroundStyle(.secondary)
                    }

                    filters

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(filteredRows.count) tipos de mantenimiento")
                            .font(.title3.bold())
                        Text("Mostrando \(pageRows.count) de \(filteredRows.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if loading {
                        ProgressView("Cargando mantenimientos")
                            .frame(maxWidth: .infinity)
                    } else if let error {
                        ContentUnavailableView {
                            Label("No se pudieron cargar los checklists", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(error)
                        } actions: {
                            Button("Reintentar") { Task { await load() } }
                        }
                    } else if filteredRows.isEmpty {
                        ContentUnavailableView("Sin resultados", systemImage: "checklist", description: Text("Ajusta los filtros de búsqueda."))
                    } else if geometry.size.width >= 760 {
                        templateTable
                    } else {
                        LazyVStack(spacing: AppSpacing.sm) {
                            ForEach(pageRows) { templateCard($0) }
                        }
                    }

                    pagination
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .onChange(of: query) { page = 0 }
        .onChange(of: subsystem) { page = 0 }
        .onChange(of: checklistStatus) { page = 0 }
    }

    private var filters: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Buscar por nombre de mantenimiento o subsistema", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(AppSpacing.md)
                .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                MaintenanceFieldGrid {
                    MaintenanceChoiceField("Subsistema", systemImage: "square.stack.3d.up", selection: $subsystem) {
                        Text("Todos").tag("")
                        ForEach(subsystems, id: \.self) { Text($0).tag($0) }
                    }
                    MaintenanceChoiceField("Estado", systemImage: "checkmark.seal", selection: $checklistStatus) {
                        Text("Todos").tag("all")
                        Text("Con checklist").tag("configured")
                        Text("Sin checklist").tag("pending")
                    }
                    Button {
                        query = ""
                        subsystem = ""
                        checklistStatus = "all"
                    } label: {
                        Label("Limpiar filtros", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(ActionTileButtonStyle())
                }
            }
        }
    }

    private var templateTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.sm) {
                Text("Mantenimiento").frame(maxWidth: .infinity, alignment: .leading)
                Text("Subsistema").frame(width: 130, alignment: .leading)
                Text("Checklist operativo").frame(width: 220, alignment: .leading)
                Text("Acciones").frame(width: 80, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)

            ForEach(pageRows) { row in
                NavigationLink {
                    PreventiveTemplateDetailView(
                        templateID: row.id,
                        equipmentName: equipmentName,
                        location: location,
                        subsystem: row.subsystem
                    )
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Text(row.name).frame(maxWidth: .infinity, alignment: .leading)
                        Text(row.subsystem).frame(width: 130, alignment: .leading)
                        checklistBadge(row).frame(width: 220, alignment: .leading)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .trailing)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 11)
                    .background(.background.opacity(0.42))
                    .overlay(alignment: .bottom) { Divider().opacity(0.45) }
                }
                .buttonStyle(.plain)
            }
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(BrandColor.glassStroke) }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func templateCard(_ row: PreventiveTemplateEntry) -> some View {
        NavigationLink {
            PreventiveTemplateDetailView(
                templateID: row.id,
                equipmentName: equipmentName,
                location: location,
                subsystem: row.subsystem
            )
        } label: {
            GlassPanel {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Text(row.name).font(.headline).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                    Text(row.subsystem).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    checklistBadge(row)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func checklistBadge(_ row: PreventiveTemplateEntry) -> some View {
        let configured = row.item_count > 0
        return Label(
            configured ? "Con checklist (\(row.item_count) elementos)" : "Sin checklist",
            systemImage: "circle.fill"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(configured ? BrandColor.green : .secondary)
    }

    private var pagination: some View {
        PaginationBar(currentPage: page, pageCount: pageCount) { selectedPage in
            page = selectedPage
        }
    }

    private var subsystems: [String] {
        Array(Set(rows.map(\.subsystem))).sorted()
    }

    private var filteredRows: [PreventiveTemplateEntry] {
        rows.filter { row in
            let matchesSearch = query.isEmpty
                || row.name.localizedCaseInsensitiveContains(query)
                || row.subsystem.localizedCaseInsensitiveContains(query)
            let matchesStatus = checklistStatus == "all"
                || (checklistStatus == "configured" ? row.item_count > 0 : row.item_count == 0)
            return matchesSearch && (subsystem.isEmpty || row.subsystem == subsystem) && matchesStatus
        }
    }

    private var pageRows: [PreventiveTemplateEntry] {
        let start = page * pageSize
        guard start < filteredRows.count else { return [] }
        return Array(filteredRows[start..<min(start + pageSize, filteredRows.count)])
    }

    private var pageCount: Int {
        max(1, Int(ceil(Double(filteredRows.count) / Double(pageSize))))
    }

    @MainActor private func load() async {
        loading = true; error = nil; defer { loading = false }
        do {
            rows = try await session.withValidAccessToken {
                try await toolClient().get("api/v1/preventive-templates", bearerToken: $0,
                    queryItems: assetID.map { [.init(name: "asset_id", value: $0)] } ?? [])
            }
        } catch { self.error = error.localizedDescription }
    }
}

struct EquipmentPreventiveTemplatesPanel: View {
    @EnvironmentObject private var session: SessionStore
    let assetID: String
    let equipmentName: String
    let location: String?
    @State private var rows: [PreventiveTemplateEntry] = []
    @State private var error: String?
    @State private var loading = false

    var body: some View {
        ContentGlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Mantenimientos preventivos",
                    subtitle: "Tipos de mantenimiento definidos para este equipo"
                )
                ForEach(rows) { row in
                    NavigationLink {
                        PreventiveTemplateDetailView(
                            templateID: row.id,
                            equipmentName: equipmentName,
                            location: location,
                            subsystem: row.subsystem
                        )
                    } label: {
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: "book.closed.fill")
                                .font(.headline)
                                .foregroundStyle(BrandColor.red)
                                .frame(width: 42, height: 42)
                                .background(
                                    BrandColor.red.opacity(0.09),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("\(row.subsystem) · \(row.item_count) elemento(s) en checklist")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(AppSpacing.sm)
                        .background(
                            .background.opacity(0.62),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
                if loading {
                    ProgressView("Cargando mantenimientos")
                        .frame(maxWidth: .infinity)
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(BrandColor.red)
                    Button("Reintentar") { Task { await load() } }
                        .buttonStyle(ActionTileButtonStyle())
                }
                if rows.isEmpty && !loading && error == nil {
                    ContentUnavailableView(
                        "Sin mantenimientos definidos",
                        systemImage: "book.closed",
                        description: Text("Este equipo todavía no tiene tipos de mantenimiento preventivo asociados.")
                    )
                }
            }
        }
        .task(id: assetID) { await load() }
    }

    @MainActor private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            rows = try await session.withValidAccessToken {
                try await toolClient().get(
                    "api/v1/preventive-templates",
                    bearerToken: $0,
                    queryItems: [.init(name: "asset_id", value: assetID)]
                )
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct PreventiveTemplateDetailView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var offlineStore: OfflineReportStore
    let templateID: String
    var equipmentName: String? = nil
    var location: String? = nil
    var subsystem: String? = nil
    @State private var detail: PreventiveTemplateDetail?
    @State private var inventoryItems: [ToolInventoryItemEntry] = []
    @State private var error: String?
    @State private var selectedTab = 1
    @State private var adding = false
    @State private var editingItem: APIOperationalChecklistItem?
    @State private var deletingItem: APIOperationalChecklistItem?
    @State private var successMessage: String?
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                if let detail {
                    if let successMessage {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                            Text(successMessage).font(.subheadline.weight(.semibold))
                            Spacer()
                            Button { self.successMessage = nil } label: { Image(systemName: "xmark") }
                        }
                        .foregroundStyle(BrandColor.green)
                        .padding(AppSpacing.md)
                        .background(BrandColor.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    HStack(alignment: .top, spacing: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            HStack(spacing: AppSpacing.sm) {
                                Text(detail.name).font(.title2.bold())
                                if let subsystem {
                                    Text(subsystem)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, AppSpacing.sm)
                                        .padding(.vertical, 5)
                                        .background(.thinMaterial, in: Capsule())
                                }
                            }
                            Text("Consulta el manual y gestiona el checklist de herramientas para este mantenimiento.")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if detail.manual_reference != nil {
                            Button("Ver manual", systemImage: "doc.text") { selectedTab = 0 }
                                .buttonStyle(.glass)
                        }
                    }

                    Picker("Tipo de checklist", selection: $selectedTab) {
                        Text("Checklist según manual").tag(0)
                        Text("Checklist operativo").tag(1)
                    }
                    .pickerStyle(.segmented)

                    if selectedTab == 0 {
                        manualChecklist(detail)
                    } else {
                        operationalChecklist(detail)
                    }
                } else if error == nil { ProgressView("Cargando mantenimiento") }
                if let error {
                    ContentUnavailableView {
                        Label("No se pudo cargar el mantenimiento", systemImage: "exclamationmark.triangle")
                    } description: { Text(error) } actions: {
                        Button("Reintentar") { Task { await load() } }
                    }
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: templateID) { await load() }
        .sheet(isPresented: $adding, onDismiss: { Task { await load() } }) {
            if let detail {
                OperationalChecklistToolPicker(detail: detail) { count in
                    successMessage = count == 1
                        ? "Se agregó 1 herramienta al checklist."
                        : "Se agregaron \(count) herramientas al checklist."
                }
            }
        }
        .sheet(item: $editingItem, onDismiss: { Task { await load() } }) { item in
            if let detail {
                OperationalChecklistItemEditor(detail: detail, item: item)
            }
        }
        .alert("Eliminar herramienta", isPresented: Binding(
            get: { deletingItem != nil },
            set: { if !$0 { deletingItem = nil } }
        )) {
            Button("Eliminar", role: .destructive) {
                guard let item = deletingItem, let detail else { return }
                Task { await delete(item, from: detail) }
            }
            Button("Cancelar", role: .cancel) { deletingItem = nil }
        } message: {
            Text("La herramienta se quitará del checklist operativo y se creará una nueva revisión.")
        }
    }

    private func manualChecklist(_ detail: PreventiveTemplateDetail) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if let manual = detail.manual_reference {
                GlassPanel {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "doc.text.fill")
                            .font(.title2)
                            .foregroundStyle(BrandColor.red)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(manual).font(.headline)
                            Text("Referencia del manual del mantenimiento")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Manual")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrandColor.red)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Herramientas según manual").font(.title3.bold())
                Text("Lista de herramientas extraída del manual para este mantenimiento.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if detail.manual_checklist.isEmpty {
                ContentUnavailableView("Pendiente de agregar", systemImage: "book.closed")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(detail.manual_checklist.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: AppSpacing.md) {
                            Text(String(index + 1)).frame(width: 34, alignment: .leading)
                            Image(systemName: "wrench.and.screwdriver").foregroundStyle(.secondary).frame(width: 42)
                            Text(item.name).frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(item.quantity?.formatted() ?? "—") \(item.unit)")
                                .foregroundStyle(.secondary)
                        }
                        .padding(AppSpacing.md)
                        .overlay(alignment: .bottom) { Divider().opacity(0.45) }
                    }
                }
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(BrandColor.glassStroke) }
            }
        }
    }

    private func operationalChecklist(_ detail: PreventiveTemplateDetail) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(detail.operational_checklist.count) herramientas").font(.title3.bold())
                    Text("Herramientas definidas para el checklist operativo.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if session.currentUser?.role == .administrator {
                    Button("Agregar herramienta", systemImage: "plus") { adding = true }
                        .buttonStyle(.glassProminent)
                        .tint(BrandColor.red)
                        .disabled(!offlineStore.isNetworkAvailable || busy)
                }
            }

            if detail.operational_checklist.isEmpty {
                ContentUnavailableView("Pendiente de agregar", systemImage: "checklist", description: Text("Agrega herramientas desde el inventario físico."))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(detail.operational_checklist.enumerated()), id: \.element.id) { index, item in
                        operationalRow(index: index, item: item)
                    }
                }
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(BrandColor.glassStroke) }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func operationalRow(index: Int, item: APIOperationalChecklistItem) -> some View {
        let inventory = inventoryItems.first { $0.catalog_item_id == item.catalogItemID }
        return HStack(spacing: AppSpacing.md) {
            Text(String(index + 1)).frame(width: 28, alignment: .leading)
            ToolInventoryThumbnail(image: inventory?.images.first, height: 48, onTap: {})
                .frame(width: 58)
            Text(inventory?.tool_code ?? inventory?.label ?? "—")
                .font(.caption.weight(.semibold))
                .frame(width: 100, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.subheadline.weight(.semibold))
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(item.defaultQuantity?.formatted() ?? "—")
                .frame(width: 70, alignment: .trailing)
            if session.currentUser?.role == .administrator {
                HStack(spacing: AppSpacing.xs) {
                    Button { editingItem = item } label: { Image(systemName: "pencil") }
                        .buttonStyle(.glass)
                        .tint(BrandColor.red)
                        .accessibilityLabel("Editar \(item.name)")
                    Button(role: .destructive) { deletingItem = item } label: { Image(systemName: "trash") }
                        .buttonStyle(.glass)
                        .accessibilityLabel("Eliminar \(item.name)")
                }
                .disabled(!offlineStore.isNetworkAvailable || busy)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(.background.opacity(0.40))
        .overlay(alignment: .bottom) { Divider().opacity(0.45) }
    }

    @MainActor private func load() async {
        error = nil
        do {
            detail = try await session.withValidAccessToken {
                try await toolClient().get("api/v1/preventive-templates/\(templateID)", bearerToken: $0)
            }
            if session.currentUser?.role == .administrator {
                let page: ToolInventoryItemPage = try await session.withValidAccessToken {
                    try await toolClient().get(
                        "api/v1/tool-admin/items",
                        bearerToken: $0,
                        queryItems: [.init(name: "limit", value: "500")]
                    )
                }
                inventoryItems = page.items
            }
        }
        catch { self.error = error.localizedDescription }
    }

    @MainActor private func delete(_ item: APIOperationalChecklistItem, from detail: PreventiveTemplateDetail) async {
        busy = true
        defer { busy = false }
        do {
            let lines = OperationalChecklistPayload.lines(from: detail.operational_checklist.filter { $0.id != item.id })
            try await publishOperationalChecklist(detail: detail, lines: lines, session: session)
            deletingItem = nil
            successMessage = "Se eliminó \(item.name) del checklist."
            await load()
        } catch {
            deletingItem = nil
            self.error = error.localizedDescription
        }
    }
}

private struct OperationalChecklistLinePayload: Encodable {
    let catalog_item_id: String
    let default_quantity: Double?
    let unit: String
    let notes: String?
}

private struct OperationalChecklistPayload: Encodable {
    let base_revision_id: String?
    let items: [OperationalChecklistLinePayload]

    static func lines(from items: [APIOperationalChecklistItem]) -> [OperationalChecklistLinePayload] {
        items.compactMap { item in
            guard let catalogID = item.catalogItemID else { return nil }
            return OperationalChecklistLinePayload(
                catalog_item_id: catalogID,
                default_quantity: item.defaultQuantity,
                unit: item.unit,
                notes: item.notes
            )
        }
    }
}

@MainActor
private func publishOperationalChecklist(
    detail: PreventiveTemplateDetail,
    lines: [OperationalChecklistLinePayload],
    session: SessionStore
) async throws {
    let payload = OperationalChecklistPayload(base_revision_id: detail.revision_id, items: lines)
    let _: ToolWriteResult = try await session.withValidAccessToken {
        try await toolClient().put(
            "api/v1/preventive-templates/\(detail.id)/checklist",
            body: payload,
            bearerToken: $0
        )
    }
}

private struct OperationalChecklistToolPicker: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    let detail: PreventiveTemplateDetail
    let onSaved: (Int) -> Void

    @State private var items: [ToolInventoryItemEntry] = []
    @State private var selectedIDs: Set<String> = []
    @State private var query = ""
    @State private var classification = ""
    @State private var availability = "available"
    @State private var page = 0
    @State private var loading = false
    @State private var saving = false
    @State private var error: String?
    private let pageSize = 10

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        filters

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(filteredItems.count) herramientas").font(.title3.bold())
                            Text("Selecciona una o varias herramientas para agregar al checklist.")
                                .font(.caption).foregroundStyle(.secondary)
                        }

                        if loading {
                            ProgressView("Cargando inventario").frame(maxWidth: .infinity)
                        } else if filteredItems.isEmpty {
                            ContentUnavailableView("Sin herramientas disponibles", systemImage: "shippingbox")
                        } else if geometry.size.width >= 720 {
                            selectionTable
                        } else {
                            LazyVStack(spacing: AppSpacing.sm) {
                                ForEach(pageItems) { selectionCard($0) }
                            }
                        }

                        pagination
                        if let error {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(BrandColor.red)
                        }
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: 980)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(MaintenanceScreenBackground())
            .navigationTitle("Agregar herramientas al checklist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }.disabled(saving)
                }
            }
            .safeAreaInset(edge: .bottom) {
                GlassPanel {
                    HStack(spacing: AppSpacing.md) {
                        Spacer()
                        Text("\(selectedIDs.count) seleccionada(s)")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Cancelar") { dismiss() }
                            .buttonStyle(ActionTileButtonStyle())
                            .disabled(saving)
                        Button {
                            Task { await save() }
                        } label: {
                            if saving { ProgressView() } else { Text("Agregar seleccionadas") }
                        }
                        .buttonStyle(ActionTileButtonStyle(prominent: true))
                        .disabled(selectedIDs.isEmpty || saving)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.sm)
            }
            .task { await load() }
            .onChange(of: query) { page = 0 }
            .onChange(of: classification) { page = 0 }
            .onChange(of: availability) { page = 0 }
            .interactiveDismissDisabled(saving)
        }
    }

    private var filters: some View {
        GlassPanel {
            VStack(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Buscar por nombre, código o categoría", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(AppSpacing.md)
                .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                MaintenanceFieldGrid {
                    MaintenanceChoiceField("Clasificación", systemImage: "square.stack.3d.up", selection: $classification) {
                        Text("Todas").tag("")
                        Text("Herramientas manuales").tag("HERRAMIENTA MANUAL")
                        Text("Llaves / accesos").tag("LLAVE")
                        Text("Consumibles").tag("CONSUMIBLE")
                        Text("Equipos").tag("EQUIPO")
                    }
                    MaintenanceChoiceField("Estado", systemImage: "checkmark.seal", selection: $availability) {
                        Text("Todos").tag("all")
                        Text("Disponibles").tag("available")
                    }
                    Button {
                        query = ""
                        classification = ""
                        availability = "available"
                    } label: {
                        Label("Limpiar filtros", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(ActionTileButtonStyle())
                }
            }
        }
    }

    private var selectionTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.sm) {
                Text("").frame(width: 28)
                Text("Imagen").frame(width: 58, alignment: .leading)
                Text("Código").frame(width: 110, alignment: .leading)
                Text("Nombre").frame(maxWidth: .infinity, alignment: .leading)
                Text("Stock").frame(width: 70, alignment: .trailing)
                Text("Estado").frame(width: 120, alignment: .leading)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(AppSpacing.sm)

            ForEach(pageItems) { item in
                let unavailable = isAlreadyIncluded(item) || item.catalog_item_id == nil
                Button { toggle(item) } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: selectedIDs.contains(item.id) ? "checkmark.square.fill" : "square")
                            .foregroundStyle(selectedIDs.contains(item.id) ? BrandColor.red : .secondary)
                            .frame(width: 28)
                        ToolInventoryThumbnail(image: item.images.first, height: 42, onTap: {})
                            .frame(width: 58)
                        Text(item.tool_code ?? item.label ?? "—")
                            .font(.caption.weight(.semibold)).frame(width: 110, alignment: .leading)
                        Text(item.name).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                        Text(item.quantity.formatted()).frame(width: 70, alignment: .trailing)
                        ToolInventoryStatusBadge(status: item.status).frame(width: 120, alignment: .leading)
                    }
                    .font(.subheadline)
                    .foregroundStyle(unavailable ? .secondary : .primary)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 7)
                    .background(.background.opacity(0.40))
                    .overlay(alignment: .bottom) { Divider().opacity(0.45) }
                }
                .buttonStyle(.plain)
                .disabled(unavailable)
            }
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(BrandColor.glassStroke) }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func selectionCard(_ item: ToolInventoryItemEntry) -> some View {
        let unavailable = isAlreadyIncluded(item) || item.catalog_item_id == nil
        return Button { toggle(item) } label: {
            GlassPanel {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: selectedIDs.contains(item.id) ? "checkmark.square.fill" : "square")
                        .foregroundStyle(selectedIDs.contains(item.id) ? BrandColor.red : .secondary)
                    ToolInventoryThumbnail(image: item.images.first, height: 58, onTap: {})
                        .frame(width: 70)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name).font(.headline).lineLimit(2)
                        Text(item.tool_code ?? item.label ?? "Sin código")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("Stock: \(item.quantity.formatted())")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    ToolInventoryStatusBadge(status: item.status)
                }
                .foregroundStyle(unavailable ? .secondary : .primary)
            }
        }
        .buttonStyle(.plain)
        .disabled(unavailable)
    }

    private var existingCatalogIDs: Set<String> {
        Set(detail.operational_checklist.compactMap(\.catalogItemID))
    }

    private func isAlreadyIncluded(_ item: ToolInventoryItemEntry) -> Bool {
        item.catalog_item_id.map(existingCatalogIDs.contains) ?? false
    }

    private func toggle(_ item: ToolInventoryItemEntry) {
        guard let catalogID = item.catalog_item_id else { return }
        if selectedIDs.remove(item.id) != nil { return }
        if let duplicateID = selectedIDs.first(where: { selectedID in
            items.first(where: { $0.id == selectedID })?.catalog_item_id == catalogID
        }) {
            selectedIDs.remove(duplicateID)
        }
        selectedIDs.insert(item.id)
    }

    private var filteredItems: [ToolInventoryItemEntry] {
        items.filter { item in
            let matchesQuery = query.isEmpty
                || item.name.localizedCaseInsensitiveContains(query)
                || (item.tool_code?.localizedCaseInsensitiveContains(query) ?? false)
                || (item.label?.localizedCaseInsensitiveContains(query) ?? false)
                || (item.category?.localizedCaseInsensitiveContains(query) ?? false)
            let isAvailable = normalizedToolValue(item.status) == "DISPONIBLE" && item.quantity > 0
            return matchesQuery
                && (classification.isEmpty || normalizedToolValue(item.classification) == normalizedToolValue(classification))
                && (availability == "all" || isAvailable)
        }
    }

    private var pageItems: [ToolInventoryItemEntry] {
        let start = page * pageSize
        guard start < filteredItems.count else { return [] }
        return Array(filteredItems[start..<min(start + pageSize, filteredItems.count)])
    }

    private var pageCount: Int {
        max(1, Int(ceil(Double(filteredItems.count) / Double(pageSize))))
    }

    private var pagination: some View {
        PaginationBar(currentPage: page, pageCount: pageCount) { selectedPage in
            page = selectedPage
        }
    }

    @MainActor private func load() async {
        loading = true
        defer { loading = false }
        do {
            let result: ToolInventoryItemPage = try await session.withValidAccessToken {
                try await toolClient().get(
                    "api/v1/tool-admin/items",
                    bearerToken: $0,
                    queryItems: [.init(name: "limit", value: "500")]
                )
            }
            items = result.items
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor private func save() async {
        saving = true
        error = nil
        defer { saving = false }
        do {
            var lines = OperationalChecklistPayload.lines(from: detail.operational_checklist)
            let selectedItems = items.filter { selectedIDs.contains($0.id) }
            let existing = Set(lines.map(\.catalog_item_id))
            var addedCatalogs = Set<String>()
            for item in selectedItems {
                guard let catalogID = item.catalog_item_id,
                      !existing.contains(catalogID),
                      addedCatalogs.insert(catalogID).inserted else { continue }
                lines.append(
                    OperationalChecklistLinePayload(
                        catalog_item_id: catalogID,
                        default_quantity: 1,
                        unit: "unidad",
                        notes: nil
                    )
                )
            }
            try await publishOperationalChecklist(detail: detail, lines: lines, session: session)
            onSaved(addedCatalogs.count)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct OperationalChecklistItemEditor: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    let detail: PreventiveTemplateDetail
    let item: APIOperationalChecklistItem
    @State private var quantity: String
    @State private var unit: String
    @State private var notes: String
    @State private var saving = false
    @State private var error: String?

    init(detail: PreventiveTemplateDetail, item: APIOperationalChecklistItem) {
        self.detail = detail
        self.item = item
        _quantity = State(initialValue: item.defaultQuantity?.formatted() ?? "")
        _unit = State(initialValue: item.unit)
        _notes = State(initialValue: item.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Text(item.name).font(.title3.bold())
                    MaintenanceFieldGrid {
                        MaintenanceTextField(title: "Cantidad recomendada", placeholder: "1", text: $quantity, systemImage: "number")
                        MaintenanceTextField(title: "Unidad", placeholder: "unidad", text: $unit, systemImage: "ruler")
                    }
                    MaintenanceTextArea(
                        title: "Observaciones",
                        placeholder: "Observaciones del checklist",
                        text: $notes,
                        systemImage: "note.text",
                        minimumLines: 3,
                        maximumLines: 5
                    )
                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(BrandColor.red)
                    }
                }
                .padding(AppSpacing.lg)
            }
            .background(MaintenanceScreenBackground())
            .navigationTitle("Editar herramienta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Guardando…" : "Guardar cambios") { Task { await save() } }
                        .disabled(saving || unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .interactiveDismissDisabled(saving)
        }
    }

    @MainActor private func save() async {
        guard let catalogID = item.catalogItemID else { return }
        saving = true
        error = nil
        defer { saving = false }
        do {
            var lines = OperationalChecklistPayload.lines(from: detail.operational_checklist)
            guard let index = lines.firstIndex(where: { $0.catalog_item_id == catalogID }) else { return }
            lines[index] = OperationalChecklistLinePayload(
                catalog_item_id: catalogID,
                default_quantity: Double(quantity.replacingOccurrences(of: ",", with: ".")),
                unit: unit.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
            )
            try await publishOperationalChecklist(detail: detail, lines: lines, session: session)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
