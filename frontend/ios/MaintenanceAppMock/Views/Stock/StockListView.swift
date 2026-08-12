import SwiftUI

private struct APIStockAsset: Identifiable, Decodable {
    let id: String
    let name: String
    let assetType: String
    let serialNumber: String?
    let internalCode: String?
    let partNumber: String?
    let status: String
    let inventoryLocation: String
    let subsystem: String
    let manufacturer: String?
    let model: String?

    enum CodingKeys: String, CodingKey {
        case id, name, status, subsystem, manufacturer, model
        case assetType = "asset_type"
        case serialNumber = "serial_number"
        case internalCode = "internal_code"
        case partNumber = "part_number"
        case inventoryLocation = "inventory_location"
    }

    var primaryIdentifier: String {
        serialNumber?.nilIfBlank
            ?? internalCode?.nilIfBlank
            ?? "Sin serie registrada"
    }
}

private struct APIStockPage: Decodable {
    let items: [APIStockAsset]
    let total: Int
}

private struct StockAPIService {
    let client: APIClient

    init(baseURLString: String) {
        client = APIClient(baseURLString: baseURLString)
    }

    func list(query: String, accessToken: String) async throws -> [APIStockAsset] {
        var items: [APIStockAsset] = []
        var offset = 0
        let limit = 200

        while true {
            var queryItems = [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
            if !query.isEmpty {
                queryItems.append(URLQueryItem(name: "q", value: query))
            }
            let page: APIStockPage = try await client.get(
                "api/v1/assets/stock",
                bearerToken: accessToken,
                queryItems: queryItems
            )
            items.append(contentsOf: page.items)
            offset += page.items.count
            if page.items.isEmpty || offset >= page.total {
                return items
            }
        }
    }
}

@MainActor
private final class StockStore: ObservableObject {
    @Published private(set) var assets: [APIStockAsset] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func load(query: String, session: SessionStore) async {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else {
            errorMessage = "No se encontro la URL de la API."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            assets = try await session.withValidAccessToken { token in
                try await StockAPIService(baseURLString: baseURL).list(
                    query: query.trimmingCharacters(in: .whitespacesAndNewlines),
                    accessToken: token
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct StockListView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var stockStore = StockStore()
    @State private var query = ""

    var selectionMode = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                searchPanel

                if stockStore.isLoading && stockStore.assets.isEmpty {
                    ProgressView("Consultando stock")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xl)
                } else if let errorMessage = stockStore.errorMessage,
                          stockStore.assets.isEmpty {
                    ContentUnavailableView {
                        Label("No se pudo cargar el stock", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Reintentar") {
                            Task { await load() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if stockStore.assets.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    inventorySummary
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(stockStore.assets) { asset in
                            StockAssetCard(asset: asset, selectionMode: selectionMode)
                        }
                    }
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle(selectionMode ? "Seleccionar stock" : "Stock")
        .refreshable {
            await load()
        }
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    private var searchPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: selectionMode ? "Seleccionar activo de stock" : "Stock disponible",
                    subtitle: "Componentes ubicados actualmente en almacenes"
                )
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(
                        "Buscar por serie, código, tipo o part number",
                        text: $query
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Limpiar busqueda")
                    }
                }
                .padding(AppSpacing.md)
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
            }
        }
    }

    private var inventorySummary: some View {
        HStack {
            Label(
                "\(stockStore.assets.count) componentes",
                systemImage: "shippingbox.fill"
            )
            .font(.subheadline.weight(.semibold))
            Spacer()
            if stockStore.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, AppSpacing.xs)
    }

    private func load() async {
        await stockStore.load(query: query, session: session)
    }
}

private struct StockAssetCard: View {
    let asset: APIStockAsset
    let selectionMode: Bool

    var body: some View {
        GlassPanel {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Image(systemName: "shippingbox.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(BrandColor.red)
                    .frame(width: 48, height: 48)
                    .background(
                        BrandColor.red.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        Text(asset.name)
                            .font(.headline)
                        Spacer()
                        Text(asset.status)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, 5)
                            .background(.thinMaterial, in: Capsule())
                    }

                    Label(asset.inventoryLocation, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("\(asset.primaryIdentifier) · \(asset.assetType)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: AppSpacing.sm) {
                        metadata(asset.subsystem)
                        if let partNumber = asset.partNumber?.nilIfBlank {
                            metadata("PN \(partNumber)")
                        }
                        if let manufacturer = asset.manufacturer?.nilIfBlank {
                            metadata(manufacturer)
                        }
                    }

                    if selectionMode {
                        Label("Seleccionar", systemImage: "checkmark.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrandColor.red)
                    }
                }
            }
        }
    }

    private func metadata(_ value: String) -> some View {
        Text(value)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 4)
            .background(BrandColor.graphite.opacity(0.10), in: Capsule())
    }
}

private extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

struct StockListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            StockListView()
                .environmentObject(SessionStore())
        }
    }
}
