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

struct DatabaseCorrectiveListView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var activityStore: MaintenanceActivityStore
    @EnvironmentObject private var assetStore: AssetStore
    @State private var isCreatingEvent = false
    @State private var selectedFilter: MaintenanceDateFilter?
    @State private var searchText = ""
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var selectedYear = Calendar.current.component(.year, from: Date())

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
                section("Abiertos", statuses: ["SCHEDULED"])
                section("En progreso", statuses: ["IN_PROGRESS"])
                section("Completados", statuses: ["COMPLETED"])
                section("Cerrados", statuses: ["CLOSED"])

                if let error = activityStore.correctiveError {
                    ContentUnavailableView {
                        Label("No se pudieron cargar los correctivos", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Reintentar") { Task { await load() } }
                    }
                } else if activityStore.isLoadingCorrectives && activityStore.correctiveActivities.isEmpty {
                    ProgressView("Cargando correctivos")
                        .frame(maxWidth: .infinity)
                        .padding(AppSpacing.xl)
                } else if activityStore.correctiveActivities.isEmpty {
                    GlassPanel { Text("No hay correctivos para este filtro.").foregroundStyle(.secondary) }
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Correctivos")
        .toolbar {
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
        let activities = activityStore.correctiveActivities.filter { statuses.contains($0.status) }
        if !activities.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: title, subtitle: "\(activities.count) evento(s)")
                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(activities) { activity in
                        NavigationLink { CorrectiveDetailView(eventID: activity.id) } label: {
                            CorrectiveAPIActivityCard(activity: activity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func load() async {
        let range = dateRange
        await activityStore.load(
            type: "CORRECTIVE",
            query: searchText.trimmingCharacters(in: .whitespacesAndNewlines),
            dateFrom: range?.lowerBound,
            dateTo: range?.upperBound,
            session: session
        )
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

private struct CorrectiveCreationContext: Decodable {
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

private struct CorrectiveCreateRequest: Encodable {
    let sapEventName: String
    let sapNotification: String
    let businessAnchorAssetID: String
    let affectedAssetID: String
    let affectedAssetPath: String
    let subsystem: String
    let severity: String
    let noticeCreatedAt: Date
    let responseAt: Date
    let physicalLocation: String

    enum CodingKeys: String, CodingKey {
        case subsystem, severity
        case sapEventName = "sap_event_name"
        case sapNotification = "sap_notification"
        case businessAnchorAssetID = "business_anchor_asset_id"
        case affectedAssetID = "affected_asset_id"
        case affectedAssetPath = "affected_asset_path"
        case noticeCreatedAt = "notice_created_at"
        case responseAt = "response_at"
        case physicalLocation = "physical_location"
    }
}

private struct CorrectiveCreateResult: Decodable {
    let id: String
    let code: String
    let status: String
}

private struct CorrectiveCreationAPIService {
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
    @Environment(\.dismiss) private var dismiss

    let onCreated: () -> Void

    @State private var selectedSubsystem = "ATS"
    @State private var equipmentSearchText = ""
    @State private var selectedEquipmentID: String?
    @State private var selectedAssetID: String?
    @State private var context: CorrectiveCreationContext?
    @State private var sapEventName = ""
    @State private var sapNotification = ""
    @State private var severity: Severity = .medium
    @State private var noticeCreatedAt = Date()
    @State private var responseAt = Date()
    @State private var isCreating = false
    @State private var creationError: String?

    private let subsystemOptions = ["ATS", "CBTC", "IXL"]

    private var selectedEquipment: EquipmentDTO? {
        guard let selectedEquipmentID else { return nil }
        return assetStore.details[selectedEquipmentID]
            ?? assetStore.equipments.first { $0.id == selectedEquipmentID }
    }

    private var selectedAssetPath: String {
        guard let equipment = selectedEquipment,
              let selectedAssetID else {
            return "Asset no seleccionado"
        }
        guard selectedAssetID != equipment.id else {
            return equipment.name
        }

        let nodes = assetStore.trees[equipment.id] ?? []
        let byID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        var names: [String] = []
        var currentID: String? = selectedAssetID
        var visited: Set<String> = []
        while let id = currentID,
              id != equipment.id,
              !visited.contains(id),
              let node = byID[id] {
            names.insert(node.name, at: 0)
            visited.insert(id)
            currentID = node.parentID
        }
        return ([equipment.name] + names).joined(separator: " > ")
    }

    private var canCreate: Bool {
        selectedEquipmentID != nil
            && selectedAssetID != nil
            && context != nil
            && !sapEventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !sapNotification.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isCreating
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                header
                assetSelector
                contextPanel
                sapPanel

                if let creationError {
                    Label(creationError, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(BrandColor.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                ActionButtonGrid {
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
            .padding(AppSpacing.lg)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Nuevo correctivo")
        .toolbar {
            Button("Cerrar") { dismiss() }
        }
        .task(id: "\(selectedSubsystem)|\(equipmentSearchText)") {
            if !equipmentSearchText.isEmpty {
                try? await Task.sleep(for: .milliseconds(300))
            }
            guard !Task.isCancelled else { return }
            await assetStore.loadEquipments(
                query: equipmentSearchText.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                subsystem: selectedSubsystem,
                session: session
            )
        }
        .task(id: selectedEquipmentID) {
            guard let selectedEquipmentID else {
                context = nil
                selectedAssetID = nil
                return
            }
            selectedAssetID = selectedEquipmentID
            async let treeTask: Void = assetStore.loadTree(
                id: selectedEquipmentID,
                session: session,
                force: true
            )
            async let contextTask: Void = loadContext(
                equipmentID: selectedEquipmentID
            )
            _ = await (treeTask, contextTask)
        }
        .onChange(of: selectedSubsystem) { _, _ in
            equipmentSearchText = ""
            selectedEquipmentID = nil
            selectedAssetID = nil
            context = nil
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
            Text("Selecciona el equipo grande y baja por su arbol hasta el asset afectado.")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var assetSelector: some View {
        ContentGlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Equipo afectado",
                    subtitle: "Seleccion desde el equipo grande hasta el componente"
                )

                Picker("Subsistema", selection: $selectedSubsystem) {
                    ForEach(subsystemOptions, id: \.self) { subsystem in
                        Text(subsystem).tag(subsystem)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Buscar equipo grande", text: $equipmentSearchText)
                    .textFieldStyle(.roundedBorder)

                if assetStore.isLoadingList {
                    ProgressView("Cargando equipos")
                        .frame(maxWidth: .infinity)
                } else if let error = assetStore.listError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if assetStore.equipments.isEmpty {
                    Text("No hay equipos para este filtro.")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: AppSpacing.xs) {
                            ForEach(assetStore.equipments) { equipment in
                                Button {
                                    selectedEquipmentID = equipment.id
                                } label: {
                                    HStack(spacing: AppSpacing.sm) {
                                        Image(
                                            systemName: selectedEquipmentID == equipment.id
                                                ? "checkmark.circle.fill"
                                                : "circle"
                                        )
                                        .foregroundStyle(
                                            selectedEquipmentID == equipment.id
                                                ? BrandColor.red
                                                : .secondary
                                        )
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(equipment.name)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Text(equipment.assetType)
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

                if let equipment = selectedEquipment {
                    CorrectiveAssetTreePicker(
                        equipment: equipment,
                        nodes: assetStore.trees[equipment.id] ?? [],
                        selectedAssetID: $selectedAssetID
                    )
                    DetailTile(
                        title: "Asset seleccionado",
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
                    subtitle: "Valores obtenidos del equipo grande"
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
                        title: "Ubicacion fisica",
                        value: context.physicalLocation
                    )
                } else if selectedEquipmentID != nil {
                    ProgressView("Cargando contexto")
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Selecciona un equipo grande para cargar su contexto.")
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

    @MainActor
    private func loadContext(equipmentID: String) async {
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
        } catch {
            context = nil
            creationError = error.localizedDescription
        }
    }

    @MainActor
    private func createCorrective() async {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL"),
              let selectedEquipmentID,
              let selectedAssetID,
              let context else {
            return
        }

        isCreating = true
        creationError = nil
        defer { isCreating = false }
        do {
            let responseTime = Date()
            responseAt = responseTime
            _ = try await session.withValidAccessToken { token in
                try await CorrectiveCreationAPIService(
                    baseURLString: baseURL
                ).create(
                    request: CorrectiveCreateRequest(
                        sapEventName: sapEventName.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ),
                        sapNotification: sapNotification.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ),
                        businessAnchorAssetID: selectedEquipmentID,
                        affectedAssetID: selectedAssetID,
                        affectedAssetPath: selectedAssetPath,
                        subsystem: context.subsystem,
                        severity: severity.rawValue.uppercased(),
                        noticeCreatedAt: noticeCreatedAt,
                        responseAt: responseTime,
                        physicalLocation: context.physicalLocation
                    ),
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
                type: "Equipo grande"
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
            selectedAssetID = branch.id
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(
                    systemName: selectedAssetID == branch.id
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .foregroundStyle(
                    selectedAssetID == branch.id ? BrandColor.red : .secondary
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(branch.asset.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(branch.asset.assetType)
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
                    Text(activity.eventCode ?? activity.internalCode).font(.caption.weight(.bold)).foregroundStyle(BrandColor.red)
                    Text(activity.assets.map(\.name).joined(separator: ", ")).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    Label(activity.locationPath ?? "Ubicacion no registrada", systemImage: "mappin.and.ellipse")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: AppSpacing.sm)
                VStack(alignment: .trailing, spacing: AppSpacing.sm) {
                    APIStatusBadge(status: activity.status)
                    if let severity = activity.severity {
                        Text(severity).font(.caption.weight(.bold)).foregroundStyle(severity == "HIGH" ? BrandColor.red : BrandColor.amber)
                    }
                }
            }
        }
    }
}
