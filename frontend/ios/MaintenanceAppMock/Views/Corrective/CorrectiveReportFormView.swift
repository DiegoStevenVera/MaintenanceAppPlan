import SwiftUI

struct CorrectiveReportFormView: View {
    @EnvironmentObject private var store: MockMaintenanceStore
    @Environment(\.dismiss) private var dismiss
    let eventID: String

    @State private var activities: [CorrectiveActivityEntry] = []
    @State private var stopHere = false
    @State private var symptom = ""
    @State private var technicalDescription = ""
    @State private var impactSelection: CorrectiveImpact = .degraded
    @State private var failureAnalysis: FailureAnalysisType = .hardware
    @State private var functionalTests = ""
    @State private var validationResult: CorrectiveValidationResult = .compliant
    @State private var serviceRelease = false
    @State private var serviceReleaseAt = Date()
    @State private var validationResponsible = ""
    @State private var technicalStatus: CorrectiveTechnicalStatus = .operational
    @State private var observations = ""
    @State private var participants: [ReportParticipantDraft] = []
    @State private var signingParticipantID: UUID?
    @State private var signatureStrokes: [UUID: [[CGPoint]]] = [:]

    private var event: CorrectiveEvent? {
        store.correctiveEvents.first { $0.id == eventID }
    }

    var body: some View {
        Group {
            if let event {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        header(event)
                        eventData(event)
                        physicalLocationPanel(event)
                        failurePanel(event)
                        analysisPanel
                        activitiesPanel
                        validationPanel
                        attachmentsPanel
                        conclusionPanel
                        signaturesPanel
                        finalizePanel(event)
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: 900, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .background(MaintenanceScreenBackground())
                .navigationTitle("Reporte correctivo")
                .sheet(isPresented: signatureSheetBinding) {
                    if let signingParticipantID,
                       let index = participants.firstIndex(where: { $0.id == signingParticipantID }) {
                        SignatureCaptureSheet(
                            participantName: participants[index].user.name,
                            strokes: signatureBinding(for: signingParticipantID)
                        ) {
                            participants[index].hasSignature = !(signatureStrokes[signingParticipantID] ?? []).isEmpty
                            self.signingParticipantID = nil
                        }
                    }
                }
                .onAppear {
                    if activities.isEmpty {
                        activities = event.activities.isEmpty ? [
                            CorrectiveActivityEntry(id: UUID(), type: .inspection, description: "", notes: "", replacement: nil)
                        ] : event.activities
                    }
                    if participants.isEmpty {
                        participants = store.defaultParticipants()
                    }
                    if symptom.isEmpty {
                        symptom = event.symptom
                        technicalDescription = event.technicalDescription.isEmpty ? event.failureDescription : event.technicalDescription
                        impactSelection = event.impactSelection
                        failureAnalysis = event.failureAnalysis
                        functionalTests = event.functionalTests
                        validationResult = event.validationResult
                        serviceRelease = event.serviceRelease
                        serviceReleaseAt = event.serviceReleaseAt
                        validationResponsible = event.validationResponsible
                        technicalStatus = event.technicalStatus
                        observations = event.observations
                    }
                }
            } else {
                ContentUnavailableView("Evento no encontrado", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private func header(_ event: CorrectiveEvent) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(event.code)
                .font(.caption.weight(.bold))
                .foregroundStyle(BrandColor.red)
            Text("Reporte correctivo")
                .font(.system(.largeTitle, design: .rounded).weight(.black))
            HStack(spacing: AppSpacing.sm) {
                StatusBadge(status: event.status)
                Text(event.affectedAsset)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func eventData(_ event: CorrectiveEvent) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Datos del evento")
                DetailTile(title: "Evento", value: event.code)
                DetailTile(title: "SAP", value: event.sapCode)
                DetailTile(title: "Activo", value: event.affectedAsset)
                DetailTile(title: "Ubicacion", value: event.location)
                DetailTile(title: "Subsistema", value: event.subsystem)
            }
        }
    }

    private func physicalLocationPanel(_ event: CorrectiveEvent) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Ubicacion fisica", subtitle: "Ubicacion ligada al equipo grande")
                DetailTile(title: "Equipo grande / asset", value: event.affectedAsset.components(separatedBy: " > ").first ?? event.affectedAsset)
                DetailTile(title: "Ubicacion fisica del equipo grande", value: event.location)
            }
        }
    }

    private func failurePanel(_ event: CorrectiveEvent) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Descripcion de falla e impacto")
                TextField("Sintoma registrado", text: $symptom, axis: .vertical)
                    .lineLimit(2, reservesSpace: true)
                    .textFieldStyle(.roundedBorder)
                TextField("Descripcion tecnica detallada", text: $technicalDescription, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
                    .textFieldStyle(.roundedBorder)
                Picker("Impacto operacional", selection: $impactSelection) {
                    ForEach(CorrectiveImpact.allCases) { impact in
                        Text(impact.rawValue).tag(impact)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var analysisPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Analisis de la falla")
                Picker("Tipo de falla", selection: $failureAnalysis) {
                    ForEach(FailureAnalysisType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var activitiesPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Actividades realizadas")
                ForEach($activities) { $activity in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack(alignment: .top, spacing: AppSpacing.md) {
                            Picker("Tipo de actividad", selection: $activity.type) {
                                ForEach(CorrectiveActivityType.allCases) { type in
                                    Text(type.label).tag(type)
                                }
                            }

                            Spacer()

                            Button {
                                activities.removeAll { $0.id == activity.id }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.headline)
                                    .foregroundStyle(BrandColor.red)
                                    .frame(width: 42, height: 42)
                                    .background(BrandColor.red.opacity(0.10), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Eliminar actividad")
                        }

                        DatePicker("Fecha y hora de inicio de actividad", selection: $activity.startedAt, displayedComponents: [.date, .hourAndMinute])
                            .padding(AppSpacing.md)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                        if activity.type == .replacement {
                            ReplacementFields(
                                replacement: replacementBinding(for: $activity),
                                event: event
                            )
                        } else {
                            TextField("Descripcion", text: $activity.description, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                                .padding(AppSpacing.sm)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        DatePicker("Fecha y hora de fin de actividad", selection: $activity.endedAt, displayedComponents: [.date, .hourAndMinute])
                            .padding(AppSpacing.md)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .padding(AppSpacing.md)
                    .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                ActionButtonGrid {
                    Button {
                        activities.append(
                            CorrectiveActivityEntry(
                                id: UUID(),
                                type: .inspection,
                                description: "",
                                notes: "",
                                startedAt: Date(),
                                endedAt: Date(),
                                replacement: nil
                            )
                        )
                    } label: {
                        Label("Agregar actividad", systemImage: "plus.circle")
                    }
                    .buttonStyle(ActionTileButtonStyle())
                }
            }
        }
    }

    private var validationPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Pruebas y validacion")
                TextField("Pruebas funcionales realizadas", text: $functionalTests, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .textFieldStyle(.roundedBorder)
                Picker("Resultado", selection: $validationResult) {
                    ForEach(CorrectiveValidationResult.allCases) { result in
                        Text(result.rawValue).tag(result)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Liberacion para servicio", isOn: $serviceRelease)
                DatePicker("Fecha y hora de liberacion para servicio", selection: $serviceReleaseAt, displayedComponents: [.date, .hourAndMinute])
                    .padding(AppSpacing.md)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                TextField("Responsable de validacion", text: $validationResponsible)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var attachmentsPanel: some View {
        GlassPanel {
            Label("Agregar foto de evidencia", systemImage: "camera")
                .font(.headline)
                .foregroundStyle(BrandColor.red)
        }
    }

    private var conclusionPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Conclusiones / Comentarios")
                Picker("Estado tecnico del equipo", selection: $technicalStatus) {
                    ForEach(CorrectiveTechnicalStatus.allCases) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .pickerStyle(.menu)
                TextField("Observaciones / comentarios", text: $observations, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
                    .padding(AppSpacing.sm)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Toggle("Stop Here despues de actividades", isOn: $stopHere)
            }
        }
    }

    private var signaturesPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Participantes / Firmas")
                ParticipantsSignaturePanel(
                    participants: $participants,
                    signingParticipantID: $signingParticipantID,
                    signatureStrokes: $signatureStrokes
                )
            }
        }
    }

    private func finalizePanel(_ event: CorrectiveEvent) -> some View {
        GlassPanel {
            ActionButtonGrid {
                Button {
                    store.finalizeCorrectiveReport(
                        eventID: event.id,
                        activities: activities,
                        symptom: symptom,
                        technicalDescription: technicalDescription,
                        impactSelection: impactSelection,
                        failureAnalysis: failureAnalysis,
                        functionalTests: functionalTests,
                        validationResult: validationResult,
                        serviceRelease: serviceRelease,
                        serviceReleaseAt: serviceReleaseAt,
                        validationResponsible: validationResponsible,
                        technicalStatus: technicalStatus,
                        observations: observations,
                        stopHere: stopHere,
                        participants: participants,
                        signatureStrokes: signatureStrokes
                    )
                    dismiss()
                } label: {
                    Label("Finalizar version", systemImage: "checkmark.seal.fill")
                }
                .buttonStyle(ActionTileButtonStyle(prominent: true))
            }
        }
    }

    private var signatureSheetBinding: Binding<Bool> {
        Binding {
            signingParticipantID != nil
        } set: { isPresented in
            if !isPresented {
                signingParticipantID = nil
            }
        }
    }

    private func signatureBinding(for participantID: UUID) -> Binding<[[CGPoint]]> {
        Binding {
            signatureStrokes[participantID] ?? []
        } set: { newValue in
            signatureStrokes[participantID] = newValue
            if let index = participants.firstIndex(where: { $0.id == participantID }) {
                participants[index].hasSignature = !newValue.isEmpty
            }
        }
    }

    private func replacementBinding(for activity: Binding<CorrectiveActivityEntry>) -> Binding<ReplacementDraft> {
        Binding {
            if let replacement = activity.wrappedValue.replacement {
                return replacement
            }
            return ReplacementDraft(
                id: UUID(),
                parentAsset: event?.affectedAsset ?? "",
                removedAsset: "",
                installedAsset: "",
                source: "Almacen SPV",
                destination: "Almacenamiento Mantto Hitachi",
                reason: ""
            )
        } set: { newValue in
            activity.wrappedValue.replacement = newValue
        }
    }
}

private struct ReplacementFields: View {
    @EnvironmentObject private var store: MockMaintenanceStore
    @Binding var replacement: ReplacementDraft
    let event: CorrectiveEvent?
    @State private var isSelectingStock = false
    @State private var stockSearchText = ""

    private var rootEquipmentName: String {
        event?.affectedAsset.components(separatedBy: " > ").first ?? event?.affectedAsset ?? replacement.parentAsset
    }

    private var rootAsset: MaintenanceAsset {
        store.assets.first { $0.name == rootEquipmentName } ??
        MaintenanceAsset(
            id: "temporary-root",
            name: rootEquipmentName.isEmpty ? "Equipo afectado" : rootEquipmentName,
            type: "Equipo",
            category: "Equipo",
            businessLabel: "Equipo",
            isBusinessAnchor: true,
            serialOrCode: "",
            partNumber: "",
            status: "Activo",
            location: event?.location ?? "",
            parent: nil,
            children: [],
            history: []
        )
    }

    private var removedPathBinding: Binding<[String]> {
        Binding {
            replacement.removedAsset.isEmpty ? [rootAsset.name] : replacement.removedAsset.components(separatedBy: " > ")
        } set: { newPath in
            replacement.removedAsset = newPath.joined(separator: " > ")
            applyRemovedAssetMetadata(name: newPath.last ?? "")
        }
    }

    private var stockLocations: [String] {
        Array(Set(store.stockAssets.map(\.location))).sorted()
    }

    private var filteredStock: [StockAsset] {
        store.stockAssets.filter { $0.location == replacement.source }
    }

    private var selectedRemovedAssetLabel: String {
        replacement.removedAsset.isEmpty ? rootAsset.name : replacement.removedAsset
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Cambio de componente")
                .font(.headline)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Componente a retirar", subtitle: rootAsset.name)
                AssetTreePicker(root: rootAsset, selectedPath: removedPathBinding)
                DetailTile(title: "Asset seleccionado para retirar", value: selectedRemovedAssetLabel)
                TextField("Part number", text: $replacement.removedPartNumber)
                TextField("Serial number", text: $replacement.removedSerialNumber)
                TextField("Modelo", text: $replacement.removedModel)
                TextField("Fabricante", text: $replacement.removedManufacturer)
                Picker("Estado del componente", selection: $replacement.removedCondition) {
                    ForEach(ComponentCondition.allCases) { condition in
                        Text(condition.rawValue).tag(condition)
                    }
                }
                Picker("Se enviara a", selection: $replacement.removedDestination) {
                    ForEach(stockLocations, id: \.self) { location in
                        Text(location).tag(location)
                    }
                }
                TextField("Notas adicionales", text: $replacement.removedNotes, axis: .vertical)
                    .lineLimit(2, reservesSpace: true)
            }
            .padding(AppSpacing.md)
            .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Componente a reponer", subtitle: "Seleccionar desde stock")
                Picker("Se obtiene de", selection: $replacement.source) {
                    ForEach(stockLocations, id: \.self) { location in
                        Text(location).tag(location)
                    }
                }

                ActionButtonGrid {
                    Button {
                        stockSearchText = ""
                        isSelectingStock = true
                    } label: {
                        Label("Seleccionar de stock", systemImage: "shippingbox.fill")
                    }
                    .buttonStyle(ActionTileButtonStyle(prominent: true))
                }

                TextField("Activo instalado", text: $replacement.installedAsset)
                TextField("Part number", text: $replacement.installedPartNumber)
                TextField("Serial number", text: $replacement.installedSerialNumber)
                TextField("Modelo", text: $replacement.installedModel)
                TextField("Fabricante", text: $replacement.installedManufacturer)
                Picker("Estado del componente", selection: $replacement.installedCondition) {
                    ForEach(ComponentCondition.allCases) { condition in
                        Text(condition.rawValue).tag(condition)
                    }
                }
                TextField("Notas adicionales", text: $replacement.installedNotes, axis: .vertical)
                    .lineLimit(2, reservesSpace: true)
            }
            .padding(AppSpacing.md)
            .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .textFieldStyle(.roundedBorder)
        .padding(.vertical, AppSpacing.xs)
        .sheet(isPresented: $isSelectingStock) {
            NavigationStack {
                StockSelectionSheet(
                    title: "Seleccionar el componente a reemplazar",
                    source: replacement.source,
                    searchText: $stockSearchText,
                    stockItems: filteredStock,
                    onSelect: { stock in
                        applyInstalledStock(stock)
                        isSelectingStock = false
                    }
                )
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            if replacement.source.isEmpty {
                replacement.source = stockLocations.first ?? "Almacen SPV"
            }
            if replacement.removedDestination.isEmpty {
                replacement.removedDestination = stockLocations.first ?? "Almacenamiento Mantto Hitachi"
            }
            if replacement.parentAsset.isEmpty {
                replacement.parentAsset = rootAsset.name
            }
        }
    }

    private func applyRemovedAssetMetadata(name: String) {
        let normalized = name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        if normalized.contains("tarjeta de comunicacion") {
            replacement.removedPartNumber = "COMM-FRONTAM-001"
            replacement.removedSerialNumber = "FTM-COMM-COLECTORA-01"
            replacement.removedModel = "Modulo de comunicacion Frontam"
            replacement.removedManufacturer = "Hitachi Rail"
            return
        }

        guard let asset = store.assets.first(where: { $0.name == name }) else { return }
        replacement.removedPartNumber = asset.partNumber == "-" ? "" : asset.partNumber
        replacement.removedSerialNumber = asset.serialOrCode
        replacement.removedModel = asset.type
        replacement.removedManufacturer = "Hitachi Rail"
    }

    private func applyInstalledStock(_ stock: StockAsset) {
        replacement.installedAsset = stock.name
        replacement.installedPartNumber = stock.partNumber
        replacement.installedSerialNumber = stock.serialOrCode
        replacement.installedModel = stock.type
        replacement.installedManufacturer = "Hitachi Rail"
        replacement.source = stock.location
    }
}

private struct StockSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let source: String
    @Binding var searchText: String
    let stockItems: [StockAsset]
    let onSelect: (StockAsset) -> Void

    private var results: [StockAsset] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return stockItems }
        return stockItems.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.serialOrCode.localizedCaseInsensitiveContains(query) ||
            $0.partNumber.localizedCaseInsensitiveContains(query) ||
            $0.type.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                GlassPanel {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        SectionHeaderText(title: title, subtitle: source)
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Filtrar componentes", text: $searchText)
                                .textInputAutocapitalization(.never)
                        }
                        .padding(AppSpacing.md)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                if results.isEmpty {
                    GlassPanel {
                        Text("No hay componentes disponibles para este filtro.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(results) { stock in
                            GlassPanel {
                                HStack(spacing: AppSpacing.md) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(stock.name)
                                            .font(.headline)
                                        Text("\(stock.type) · \(stock.serialOrCode)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Text(stock.partNumber)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(BrandColor.red)
                                    }
                                    Spacer()
                                    Button {
                                        onSelect(stock)
                                    } label: {
                                        Label("Seleccionar", systemImage: "checkmark.circle.fill")
                                    }
                                    .buttonStyle(ActionTileButtonStyle(prominent: true))
                                    .frame(maxWidth: 220)
                                }
                            }
                        }
                    }
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 860, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Stock")
        .toolbar {
            Button("Cerrar") {
                dismiss()
            }
        }
    }
}

struct CorrectiveReportFormView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CorrectiveReportFormView(eventID: "cor-001")
                .environmentObject(MockMaintenanceStore())
        }
    }
}
