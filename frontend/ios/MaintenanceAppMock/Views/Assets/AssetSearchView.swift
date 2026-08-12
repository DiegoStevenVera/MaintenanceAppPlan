import SwiftUI

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
    let componentCount: Int

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
        case componentCount = "component_count"
    }
}

struct EquipmentTreeNodeDTO: Identifiable, Decodable {
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

    enum CodingKeys: String, CodingKey {
        case id, name, category, status, model, manufacturer, depth, position
        case assetType = "asset_type"
        case serialNumber = "serial_number"
        case partNumber = "part_number"
        case parentID = "parent_id"
        case slotPath = "slot_path"
    }
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
        return try await client.get(
            "api/v1/assets",
            bearerToken: accessToken,
            queryItems: queryItems
        )
    }

    func detail(id: String, accessToken: String) async throws -> EquipmentDTO {
        try await client.get("api/v1/assets/\(id)", bearerToken: accessToken)
    }

    func tree(id: String, accessToken: String) async throws -> [EquipmentTreeNodeDTO] {
        try await client.get("api/v1/assets/\(id)/tree", bearerToken: accessToken)
    }

    func history(id: String, accessToken: String) async throws -> [EquipmentMaintenanceDTO] {
        try await client.get("api/v1/assets/\(id)/history", bearerToken: accessToken)
    }
}

@MainActor
final class AssetStore: ObservableObject {
    @Published private(set) var equipments: [EquipmentDTO] = []
    @Published private(set) var total = 0
    @Published private(set) var isLoadingList = false
    @Published private(set) var listError: String?
    @Published private(set) var details: [String: EquipmentDTO] = [:]
    @Published private(set) var trees: [String: [EquipmentTreeNodeDTO]] = [:]
    @Published private(set) var histories: [String: [EquipmentMaintenanceDTO]] = [:]
    @Published private(set) var loadingDetailIDs: Set<String> = []
    @Published private(set) var detailErrors: [String: String] = [:]

    func loadEquipments(
        query: String,
        subsystem: String?,
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
                    accessToken: token
                )
            }
            guard !Task.isCancelled else { return }
            equipments = page.items
            total = page.total
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
}

struct AssetSearchView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var assetStore: AssetStore
    @State private var query = ""
    @State private var selectedSubsystem = "Todos"

    private let subsystems = ["Todos", "ATS", "CBTC", "IXL"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                filters
                results
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Equipos")
        .refreshable {
            await load()
        }
        .task(id: "\(query)|\(selectedSubsystem)") {
            if !query.isEmpty {
                try? await Task.sleep(for: .milliseconds(300))
            }
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    private var filters: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Equipos grandes",
                    subtitle: "Busca por nombre, categoria, tipo o codigo"
                )

                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Buscar equipo", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(AppSpacing.md)
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

                Picker("Subsistema", selection: $selectedSubsystem) {
                    ForEach(subsystems, id: \.self) { subsystem in
                        Text(subsystem).tag(subsystem)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeaderText(
                title: "\(assetStore.total) equipos",
                subtitle: "Activos marcados como business anchor"
            )

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
            } else {
                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(assetStore.equipments) { equipment in
                        NavigationLink {
                            AssetDetailView(assetID: equipment.id)
                        } label: {
                            EquipmentResultCard(equipment: equipment)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func load() async {
        await assetStore.loadEquipments(
            query: query.trimmingCharacters(in: .whitespacesAndNewlines),
            subsystem: selectedSubsystem == "Todos" ? nil : selectedSubsystem,
            session: session
        )
    }
}

private struct EquipmentResultCard: View {
    let equipment: EquipmentDTO

    var body: some View {
        GlassPanel {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: symbolName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(BrandColor.red)
                    .frame(width: 48, height: 48)
                    .background(
                        BrandColor.red.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(equipment.name)
                        .font(.headline)
                    Text("\(equipment.category) · \(equipment.assetType)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(equipment.serialOrCode) · \(equipment.physicalLocation)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Text(equipment.subsystem)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BrandColor.red)

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var symbolName: String {
        switch equipment.category {
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
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var assetStore: AssetStore
    let assetID: String

    var body: some View {
        Group {
            if let equipment = assetStore.details[assetID] {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        header(equipment)
                        EquipmentAssetPhotoPanel(equipment: equipment)
                        information(equipment)
                        componentTree(equipment)
                        maintenanceHistory
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: 900, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .refreshable {
                    await assetStore.loadDetail(id: assetID, session: session, force: true)
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
    }

    private func header(_ equipment: EquipmentDTO) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(equipment.serialOrCode)
                .font(.caption.weight(.bold))
                .foregroundStyle(BrandColor.red)
            Text(equipment.name)
                .font(.system(.largeTitle, design: .rounded).weight(.black))
            HStack(spacing: AppSpacing.sm) {
                Text("\(equipment.businessLabel ?? "Equipo") · \(equipment.category)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(equipment.status)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BrandColor.green)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 6)
                    .background(BrandColor.green.opacity(0.12), in: Capsule())
            }
        }
    }

    private func information(_ equipment: EquipmentDTO) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Informacion")
                DetailTile(title: "Subsistema", value: equipment.subsystem)
                DetailTile(title: "Categoria", value: equipment.category)
                DetailTile(title: "Tipo", value: equipment.assetType)
                DetailTile(title: "Codigo", value: equipment.serialOrCode)
                DetailTile(title: "Estado", value: equipment.status)
                DetailTile(title: "Ubicacion fisica", value: equipment.physicalLocation)
                optionalTile(title: "Fabricante", value: equipment.manufacturer)
                optionalTile(title: "Modelo", value: equipment.model)
                optionalTile(title: "Part number", value: equipment.partNumber)
                optionalTile(title: "Version de software", value: equipment.softwareVersion)
            }
        }
    }

    @ViewBuilder
    private func optionalTile(title: String, value: String?) -> some View {
        if let value, !value.isEmpty {
            DetailTile(title: title, value: value)
        }
    }

    private func componentTree(_ equipment: EquipmentDTO) -> some View {
        EquipmentComponentTreePanel(
            equipmentID: assetID,
            componentCount: equipment.componentCount,
            nodes: assetStore.trees[assetID] ?? []
        )
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
}

private struct EquipmentComponentTreePanel: View {
    let equipmentID: String
    let componentCount: Int
    let nodes: [EquipmentTreeNodeDTO]
    @State private var branches: [EquipmentTreeBranch]
    @State private var expandedNodeIDs: Set<String> = []

    init(
        equipmentID: String,
        componentCount: Int,
        nodes: [EquipmentTreeNodeDTO]
    ) {
        self.equipmentID = equipmentID
        self.componentCount = componentCount
        self.nodes = nodes
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
                SectionHeaderText(
                    title: "Componentes internos",
                    subtitle: "\(componentCount) activos descendientes"
                )

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

private struct EquipmentAssetPhotoPanel: View {
    let equipment: EquipmentDTO

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if equipment.subsystem == "ATS" {
                maintenanceBundleImage("ats-cabinet-reference")
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(BrandColor.graphite.opacity(0.12))
                Image(systemName: symbol)
                    .font(.system(size: 108, weight: .bold))
                    .foregroundStyle(BrandColor.red.opacity(0.78))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Label(equipment.subsystem, systemImage: "square.stack.3d.up.fill")
                .font(.headline)
                .foregroundStyle(BrandColor.signalInk)
                .padding(AppSpacing.sm)
                .background(
                    Color.white.opacity(0.92),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .padding(AppSpacing.md)
        }
        .frame(height: 260)
        .frame(maxWidth: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel("Imagen referencial del equipo \(equipment.name)")
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
