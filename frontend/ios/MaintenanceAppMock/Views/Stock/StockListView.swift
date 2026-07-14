import SwiftUI

struct StockListView: View {
    @EnvironmentObject private var store: MockMaintenanceStore
    var selectionMode = false
    @State private var query = ""

    private var results: [StockAsset] {
        guard !query.isEmpty else { return store.stockAssets }
        return store.stockAssets.filter {
            $0.name.localizedCaseInsensitiveContains(query)
            || $0.serialOrCode.localizedCaseInsensitiveContains(query)
            || $0.partNumber.localizedCaseInsensitiveContains(query)
            || $0.type.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                GlassPanel {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        SectionHeaderText(title: selectionMode ? "Seleccionar activo de stock" : "Stock disponible")
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Buscar por serie, tipo o part number", text: $query)
                                .textInputAutocapitalization(.never)
                        }
                        .padding(AppSpacing.md)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(results) { asset in
                        StockAssetCard(asset: asset, selectionMode: selectionMode)
                    }
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle(selectionMode ? "Seleccionar stock" : "Stock")
    }
}

private struct StockAssetCard: View {
    let asset: StockAsset
    let selectionMode: Bool

    var body: some View {
        GlassPanel {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "shippingbox.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(BrandColor.red)
                    .frame(width: 48, height: 48)
                    .background(BrandColor.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(asset.name)
                        .font(.headline)
                    Text("\(asset.serialOrCode) · \(asset.status) · \(asset.location)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(asset.type) · \(asset.partNumber) · \(asset.subsystem)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if selectionMode {
                    Text("Seleccionar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandColor.red)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 6)
                        .background(BrandColor.red.opacity(0.12), in: Capsule())
                }
            }
        }
    }
}

struct StockListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            StockListView()
                .environmentObject(MockMaintenanceStore())
        }
    }
}
