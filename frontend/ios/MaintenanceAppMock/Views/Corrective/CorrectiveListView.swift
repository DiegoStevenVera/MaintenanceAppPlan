import SwiftUI

struct CorrectiveListView: View {
    @EnvironmentObject private var store: MockMaintenanceStore
    @State private var isCreatingEvent = false
    @State private var selectedFilter: MaintenanceDateFilter?
    @State private var searchText = ""
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var selectedYear = Calendar.current.component(.year, from: Date())

    private var filteredEvents: [CorrectiveEvent] {
        store.correctiveEvents
            .filter { event in
                guard let selectedFilter else { return true }
                return matches(event.noticeCreatedAt, filter: selectedFilter)
            }
            .filter { event in
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !query.isEmpty else { return true }
                return event.name.localizedCaseInsensitiveContains(query) ||
                    event.code.localizedCaseInsensitiveContains(query) ||
                    event.sapCode.localizedCaseInsensitiveContains(query) ||
                    event.affectedAsset.localizedCaseInsensitiveContains(query)
            }
            .sorted { $0.noticeCreatedAt > $1.noticeCreatedAt }
    }

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
                            Text("Eventos correctivos")
                                .font(.title2.weight(.bold))
                            Text("Seguimiento de fallas, reemplazos y avances por turno")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }

                filterPanel

                correctiveSection("Abiertos", events: filteredEvents.filter { $0.status == .scheduled })
                correctiveSection("En progreso", events: filteredEvents.filter { $0.status == .inProgress })
                correctiveSection("Completados", events: filteredEvents.filter { $0.status == .completed })
                correctiveSection("Cerrados", events: filteredEvents.filter { $0.status == .closed })

                if filteredEvents.isEmpty {
                    GlassPanel {
                        Text("No hay correctivos para este filtro.")
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
            if store.currentUser.role.canEditMaintenance {
                Button {
                    isCreatingEvent = true
                } label: {
                    Label("Crear evento", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isCreatingEvent) {
            NavigationStack {
                CorrectiveEventCreateView()
                    .environmentObject(store)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
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
                            ForEach(1...12, id: \.self) { month in
                                Text(Self.monthName(month)).tag(month)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Anio", selection: $selectedYear) {
                            ForEach((selectedYear - 2)...(selectedYear + 1), id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(AppSpacing.md)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Buscar por evento, SAP o equipo", text: $searchText)
                        .textInputAutocapitalization(.never)
                }
                .padding(AppSpacing.md)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func correctiveSection(_ title: String, events: [CorrectiveEvent]) -> some View {
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: title, subtitle: "\(events.count) evento(s)")
                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(events) { event in
                        NavigationLink {
                            CorrectiveDetailView(eventID: event.id)
                        } label: {
                            CorrectiveEventRow(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func matches(_ date: Date, filter: MaintenanceDateFilter) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        switch filter {
        case .today:
            return calendar.isDate(date, inSameDayAs: now)
        case .thisWeek:
            return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .thisMonth:
            return calendar.isDate(date, equalTo: now, toGranularity: .month)
        case .specificMonth:
            return calendar.component(.month, from: date) == selectedMonth &&
                calendar.component(.year, from: date) == selectedYear
        }
    }

    private static func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        return formatter.monthSymbols[max(0, min(month - 1, 11))].capitalized
    }
}

private struct CorrectiveEventCreateView: View {
    @EnvironmentObject private var store: MockMaintenanceStore
    @Environment(\.dismiss) private var dismiss

    @State private var sapEventName = ""
    @State private var sapNotification = ""
    @State private var noticeCreatedAt = Date()
    @State private var responseAt = Date()
    @State private var selectedEquipmentID: String?
    @State private var selectedAssetPath: [String] = []
    @State private var selectedSubsystem = "CBTC"
    @State private var equipmentSearchText = ""
    @State private var severity: Severity = .medium

    private let site = "Metro Lima"
    private let project = "Linea 2"
    private let stage = "Etapa 1A"
    private let system = "Senalizacion"
    private let subsystemOptions = ["ATS", "CBTC", "IXL"]

    private var equipmentOptions: [MaintenanceAsset] {
        store.assets
            .filter(\.isBusinessAnchor)
            .filter { inferredSubsystem(for: $0) == selectedSubsystem }
            .filter { asset in
                let query = equipmentSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !query.isEmpty else { return true }
                return asset.name.localizedCaseInsensitiveContains(query) ||
                    asset.type.localizedCaseInsensitiveContains(query) ||
                    asset.category.localizedCaseInsensitiveContains(query) ||
                    asset.serialOrCode.localizedCaseInsensitiveContains(query)
            }
            .sorted { $0.name < $1.name }
    }

    private var selectedEquipment: MaintenanceAsset? {
        equipmentOptions.first { $0.id == selectedEquipmentID } ?? equipmentOptions.first
    }

    private var selectedAffectedAsset: String {
        if !selectedAssetPath.isEmpty {
            return selectedAssetPath.joined(separator: " > ")
        }
        return selectedEquipment?.name ?? "Equipo no seleccionado"
    }

    private var selectedLocation: String {
        selectedEquipment?.location ?? "Ubicacion fisica por confirmar"
    }

    private var canCreate: Bool {
        selectedEquipment != nil &&
        !sapEventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !sapNotification.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                header
                defaultDataPanel
                assetSelectorPanel
                sapPanel
                ActionButtonGrid {
                    Button {
                        store.createCorrectiveEvent(
                            sapEventName: sapEventName,
                            sapNotification: sapNotification,
                            affectedAsset: selectedAffectedAsset,
                            location: selectedLocation,
                            subsystem: selectedSubsystem,
                            severity: severity,
                            noticeCreatedAt: noticeCreatedAt,
                            responseAt: responseAt
                        )
                        dismiss()
                    } label: {
                        Label("Crear Correctivo", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(ActionTileButtonStyle(prominent: true))
                    .disabled(!canCreate)
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Nuevo correctivo")
        .toolbar {
            Button("Cerrar") {
                dismiss()
            }
        }
        .onAppear {
            if selectedEquipmentID == nil {
                selectedEquipmentID = equipmentOptions.first?.id
                if let selectedEquipment {
                    selectedAssetPath = [selectedEquipment.name]
                }
            }
            responseAt = Date()
        }
        .onChange(of: selectedEquipmentID) { _, _ in
            if let selectedEquipment {
                selectedAssetPath = [selectedEquipment.name]
            }
        }
        .onChange(of: selectedSubsystem) { _, _ in
            equipmentSearchText = ""
            selectedEquipmentID = equipmentOptions.first?.id
            if let selectedEquipment {
                selectedAssetPath = [selectedEquipment.name]
            } else {
                selectedAssetPath = []
            }
        }
        .onChange(of: equipmentSearchText) { _, _ in
            if let selectedEquipmentID,
               equipmentOptions.contains(where: { $0.id == selectedEquipmentID }) {
                return
            }
            selectedEquipmentID = equipmentOptions.first?.id
            if let selectedEquipment {
                selectedAssetPath = [selectedEquipment.name]
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Correctivo")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(BrandColor.red)
            Text("Crear evento correctivo")
                .font(.system(.largeTitle, design: .rounded).weight(.black))
            Text("Selecciona primero el subsistema, luego el equipo grande y baja por el arbol hasta marcar el asset especifico afectado.")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var defaultDataPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Datos del contexto", subtitle: "Valores definidos por el proyecto actual")
                DetailTile(title: "Sede", value: site)
                DetailTile(title: "Proyecto", value: project)
                DetailTile(title: "Etapa", value: stage)
                DetailTile(title: "Sistema", value: system)
                DetailTile(title: "Subsistema", value: selectedSubsystem)
                DetailTile(title: "Ubicacion fisica del asset", value: selectedLocation)
                Picker("Severidad", selection: $severity) {
                    ForEach(Severity.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var assetSelectorPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Equipo afectado", subtitle: "Arbol desde equipo grande hasta asset especifico")

                Picker("Subsistema", selection: $selectedSubsystem) {
                    ForEach(subsystemOptions, id: \.self) { subsystem in
                        Text(subsystem).tag(subsystem)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Buscar equipo grande", text: $equipmentSearchText)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Equipo grande")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)

                    if equipmentOptions.isEmpty {
                        Text("No hay equipos para este filtro.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppSpacing.md)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: AppSpacing.xs) {
                                ForEach(equipmentOptions.prefix(120)) { asset in
                                    Button {
                                        selectedEquipmentID = asset.id
                                    } label: {
                                        HStack(spacing: AppSpacing.sm) {
                                            Image(systemName: selectedEquipmentID == asset.id ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(selectedEquipmentID == asset.id ? BrandColor.red : .secondary)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(asset.name)
                                                    .font(.headline)
                                                    .foregroundStyle(.primary)
                                                Text("\(asset.type) · \(asset.category)")
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
                        .frame(maxHeight: 260)
                    }
                }
                .padding(AppSpacing.md)
                .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                if let selectedEquipment {
                    AssetTreePicker(
                        root: selectedEquipment,
                        selectedPath: $selectedAssetPath
                    )
                }

                DetailTile(title: "Asset seleccionado", value: selectedAffectedAsset)
            }
        }
    }

    private var sapPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Datos SAP y tiempos")
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Nombre del evento SAP")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    TextField("Ej. Falla de servidor Frontam", text: $sapEventName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Notificacion SAP")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    TextField("Ej. 110010514", text: $sapNotification)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                }

                DatePicker("Fecha y hora de creacion de aviso", selection: $noticeCreatedAt, displayedComponents: [.date, .hourAndMinute])
                    .padding(AppSpacing.md)
                    .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                DetailTile(title: "Fecha y hora de respuesta", value: Self.dateTimeFormatter.string(from: responseAt))
            }
        }
    }

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private func inferredSubsystem(for asset: MaintenanceAsset) -> String {
        let haystack = "\(asset.name) \(asset.type) \(asset.category)"
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        if haystack.contains("ats") ||
            haystack.contains("limsys") ||
            haystack.contains("limdbc") ||
            haystack.contains("limcom") ||
            haystack.contains("limcws") ||
            haystack.contains("limovw") ||
            haystack.contains("simulador") ||
            haystack.contains("crk") ||
            haystack.contains("erk") {
            return "ATS"
        }

        if haystack.contains("ixl") ||
            haystack.contains("puesto central") ||
            haystack.contains("puestos perifericos") ||
            haystack.contains("puestos perifericos rele") ||
            haystack.contains("maquinas de conmutacion") ||
            haystack.contains("circuito de via") ||
            haystack.contains("cbdac") ||
            haystack.contains("vhmi") ||
            haystack.contains("wsp") ||
            haystack.contains("sir") {
            return "IXL"
        }

        return "CBTC"
    }
}

struct AssetTreePicker: View {
    let root: MaintenanceAsset
    @Binding var selectedPath: [String]

    private var levels: [AssetTreeNode] {
        [
            AssetTreeNode(name: root.name, children: [
                AssetTreeNode(name: defaultCabinetName, children: [
                    AssetTreeNode(name: defaultModuleName, children: [
                        AssetTreeNode(name: "Fuente de poder"),
                        AssetTreeNode(name: "Tarjeta de comunicacion"),
                        AssetTreeNode(name: "Servidor / CPU"),
                        AssetTreeNode(name: "Cableado interno")
                    ]),
                    AssetTreeNode(name: "Ventilacion"),
                    AssetTreeNode(name: "Borneras")
                ])
            ])
        ]
    }

    private var defaultCabinetName: String {
        if root.category == "Vehículo" { return "Coche / cabina" }
        if root.category == "Equipo de vía" { return "Conjunto de via" }
        return "Gabinete / conjunto principal"
    }

    private var defaultModuleName: String {
        if root.type.contains("Servidor") { return "Servidor principal" }
        if root.type.contains("Circuito") { return "Modulo CBDAC" }
        if root.type.contains("conmutación") || root.name.contains("CONMUTACION") { return "Modulo de accionamiento" }
        return "Modulo interno"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            ForEach(levels) { node in
                AssetTreeNodeView(
                    node: node,
                    path: [],
                    selectedPath: $selectedPath
                )
            }
        }
        .padding(AppSpacing.md)
        .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct AssetTreeNode: Identifiable {
    let id = UUID()
    let name: String
    var children: [AssetTreeNode] = []
}

struct AssetTreeNodeView: View {
    let node: AssetTreeNode
    let path: [String]
    @Binding var selectedPath: [String]

    private var currentPath: [String] {
        path + [node.name]
    }

    private var isSelected: Bool {
        selectedPath == currentPath
    }

    var body: some View {
        if node.children.isEmpty {
            selectionRow
        } else {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    ForEach(node.children) { child in
                        AssetTreeNodeView(node: child, path: currentPath, selectedPath: $selectedPath)
                            .padding(.leading, AppSpacing.md)
                    }
                }
                .padding(.top, AppSpacing.xs)
            } label: {
                selectionRow
            }
        }
    }

    private var selectionRow: some View {
        Button {
            selectedPath = currentPath
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? BrandColor.red : .secondary)
                Text(node.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

struct CorrectiveEventRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let event: CorrectiveEvent

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color.white)
                .shadow(color: BrandColor.signalInk.opacity(colorScheme == .dark ? 0.0 : 0.06), radius: 16, x: 0, y: 8)

            if event.status == .inProgress || event.severity == .high {
                UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18)
                    .fill(BrandColor.red)
                    .frame(width: 6)
            }

            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(event.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Label(event.affectedAsset, systemImage: "square.stack.3d.up")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(event.failureDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: AppSpacing.md)

                    VStack(alignment: .trailing, spacing: AppSpacing.sm) {
                        StatusBadge(status: event.status)
                        Text(event.severity.label)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(event.severity.color)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, 6)
                            .background(event.severity.color.opacity(0.12), in: Capsule())
                    }
                }

                HStack {
                    Text(event.code)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BrandColor.red)
                    Text("SAP \(event.sapCode)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(event.subsystem)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, AppSpacing.lg)
            .padding(.vertical, AppSpacing.lg)
            .padding(.trailing, AppSpacing.lg)
        }
        .frame(minHeight: 154)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BrandColor.red.opacity(event.severity == .high ? 0.12 : 0.0), lineWidth: 1)
        }
        .glassEffect(.regular.tint(BrandColor.red.opacity(0.02)).interactive(), in: .rect(cornerRadius: 18))
    }
}

struct CorrectiveListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CorrectiveListView()
                .environmentObject(MockMaintenanceStore())
        }
    }
}
