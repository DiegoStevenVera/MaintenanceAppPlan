import SwiftUI

struct AssetSearchView: View {
    @EnvironmentObject private var store: MockMaintenanceStore
    @State private var query = ""

    private var results: [MaintenanceAsset] {
        guard !query.isEmpty else { return store.assets }
        return store.assets.filter {
            $0.name.localizedCaseInsensitiveContains(query)
            || $0.serialOrCode.localizedCaseInsensitiveContains(query)
            || $0.partNumber.localizedCaseInsensitiveContains(query)
            || $0.type.localizedCaseInsensitiveContains(query)
            || $0.category.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                GlassPanel {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        SectionHeaderText(title: "Equipos grandes", subtitle: "Busca por nombre, categoria, tipo o codigo")

                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Buscar equipo", text: $query)
                                .textInputAutocapitalization(.never)
                        }
                        .padding(AppSpacing.md)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    SectionHeaderText(title: "\(results.count) equipos", subtitle: "Activos marcados como business anchor")

                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(results) { asset in
                            NavigationLink {
                                AssetDetailView(assetID: asset.id)
                            } label: {
                                AssetResultCard(asset: asset)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Equipos")
    }
}

private struct AssetResultCard: View {
    let asset: MaintenanceAsset

    var body: some View {
        GlassPanel {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: symbolName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(BrandColor.red)
                    .frame(width: 48, height: 48)
                    .background(BrandColor.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(asset.name)
                        .font(.headline)
                    Text("\(asset.category) · \(asset.type)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(asset.serialOrCode) · \(asset.location)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var symbolName: String {
        switch asset.category {
        case "Vehículo":
            return "tram.fill"
        case "Servidor":
            return "server.rack"
        case "Equipo de vía":
            return "point.topleft.down.curvedto.point.bottomright.up"
        default:
            return "square.stack.3d.up.fill"
        }
    }
}

struct AssetDetailView: View {
    @EnvironmentObject private var store: MockMaintenanceStore
    let assetID: String

    private var asset: MaintenanceAsset? {
        store.assets.first { $0.id == assetID }
    }

    var body: some View {
        Group {
            if let asset {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        header(asset)
                        information(asset)
                        internalComponents(asset)
                        completedMaintenanceHistory(asset)
                        history(asset)
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: 900, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .background(MaintenanceScreenBackground())
                .navigationTitle("Detalle de equipo")
            } else {
                ContentUnavailableView("Equipo no encontrado", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private func header(_ asset: MaintenanceAsset) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(asset.serialOrCode)
                .font(.caption.weight(.bold))
                .foregroundStyle(BrandColor.red)
            Text(asset.name)
                .font(.system(.largeTitle, design: .rounded).weight(.black))
            HStack(spacing: AppSpacing.sm) {
                Text("\(asset.businessLabel) · \(asset.category)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(asset.status)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BrandColor.green)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 6)
                    .background(BrandColor.green.opacity(0.12), in: Capsule())
            }
        }
    }

    private func information(_ asset: MaintenanceAsset) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Informacion")
                DetailTile(title: "Etiqueta de negocio", value: asset.businessLabel)
                DetailTile(title: "Categoria", value: asset.category)
                DetailTile(title: "Tipo", value: asset.type)
                DetailTile(title: "Codigo mock", value: asset.serialOrCode)
                DetailTile(title: "Estado", value: asset.status)
                DetailTile(title: "Ubicacion", value: asset.location)
                DetailTile(title: "Rastreable como equipo", value: asset.isBusinessAnchor ? "Si" : "No")
            }
        }
    }

    private func internalComponents(_ asset: MaintenanceAsset) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Componentes internos")
                if asset.children.isEmpty {
                    Text("Pendiente de cargar arbol interno del equipo.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(asset.children, id: \.self) { child in
                        Label(child, systemImage: "chevron.right.circle")
                            .font(.headline)
                            .padding(AppSpacing.md)
                            .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    private func history(_ asset: MaintenanceAsset) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Historial")
                ForEach(asset.history, id: \.self) { entry in
                    Label(entry, systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                        .padding(AppSpacing.md)
                        .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private func completedMaintenanceHistory(_ asset: MaintenanceAsset) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Mantenimientos realizados", subtitle: "Reportes preventivos y correctivos ya generados")

                let preventiveActivitiesWithReports = store.activities.filter { activity in
                    activity.assets.contains { matchesEquipment($0, asset: asset) }
                }.filter { !$0.reportVersions.isEmpty }
                let historicalReports = store.historicalReports.filter { report in
                    matchesEquipment(report.equipmentName, asset: asset)
                }
                let correctiveEventsWithReports = store.correctiveEvents.filter { event in
                    matchesEquipment(event.affectedAsset, asset: asset)
                }.filter { !$0.reportVersions.isEmpty }

                if preventiveActivitiesWithReports.isEmpty && historicalReports.isEmpty && correctiveEventsWithReports.isEmpty {
                    Text("Aun no hay mantenimientos realizados para este equipo.")
                        .foregroundStyle(.secondary)
                }

                if !preventiveActivitiesWithReports.isEmpty || !historicalReports.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Preventivos")
                            .font(.headline)

                        ForEach(preventiveActivitiesWithReports) { activity in
                            ForEach(activity.reportVersions) { version in
                                NavigationLink {
                                    PDFPreviewView(activityID: activity.id, version: version)
                                } label: {
                                    MaintenanceHistoryRow(
                                        title: activity.name,
                                        subtitle: "Version \(version.versionNumber) · \(version.summary)",
                                        date: version.createdAt,
                                        icon: "doc.richtext"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        ForEach(historicalReports) { report in
                            NavigationLink {
                                HistoricalPDFPreviewView(report: report)
                            } label: {
                                MaintenanceHistoryRow(
                                    title: report.activityName,
                                    subtitle: "Historico · \(report.result)",
                                    date: report.performedAt,
                                    icon: "doc.richtext"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !correctiveEventsWithReports.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Correctivos")
                            .font(.headline)
                        ForEach(correctiveEventsWithReports) { event in
                            ForEach(event.reportVersions) { version in
                                NavigationLink {
                                    CorrectivePDFPreviewView(eventID: event.id, version: version)
                                } label: {
                                    MaintenanceHistoryRow(
                                        title: event.name,
                                        subtitle: "\(event.code) · Version \(version.versionNumber)",
                                        date: version.createdAt,
                                        icon: "doc.richtext"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private func matchesEquipment(_ candidate: String, asset: MaintenanceAsset) -> Bool {
        let candidateKey = normalized(candidate.components(separatedBy: " > ").first ?? candidate)
        let assetKey = normalized(asset.name)
        if candidateKey == assetKey {
            return true
        }
        for alias in equipmentAliases(for: asset) where candidateKey == normalized(alias) {
            return true
        }
        return false
    }

    private func equipmentAliases(for asset: MaintenanceAsset) -> [String] {
        let assetKey = normalized(asset.name)
        if assetKey.contains("frontam") && assetKey.contains("colectora") {
            return ["Frontam Colectora", "CUBICULO EQUIPADO DEL FRONTAM - COLECTORA"]
        }
        if assetKey.contains("frontam") && assetKey.contains("patio") {
            return ["Frontam Patio", "CUBICULO EQUIPADO DEL FRONTAM - PATIO"]
        }
        return []
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }
}

private struct MaintenanceHistoryRow: View {
    let title: String
    let subtitle: String
    let date: Date
    let icon: String

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(BrandColor.red)
                .frame(width: 40, height: 40)
                .background(BrandColor.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(Self.dateFormatter.string(from: date))
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.md)
        .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

struct AssetSearchView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AssetSearchView()
                .environmentObject(MockMaintenanceStore())
        }
    }
}
