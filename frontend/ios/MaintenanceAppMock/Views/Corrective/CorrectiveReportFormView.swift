import PhotosUI
import SwiftUI
import UIKit

struct CorrectiveReportFormView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var activityStore: MaintenanceActivityStore
    @EnvironmentObject private var offlineStore: OfflineReportStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let eventID: String

    @State private var editor: APIReportEditor?
    @State private var baseReportVersionID: String?
    @State private var symptom = ""
    @State private var technicalDescription = ""
    @State private var operationalImpact = "Degradado"
    @State private var failureAnalysis = "Hardware"
    @State private var activities: [APICorrectiveActivityWrite] = []
    @State private var functionalTests = ""
    @State private var validationResult = "Conforme"
    @State private var serviceReleased = false
    @State private var serviceReleasedAt = Date()
    @State private var validationResponsible = ""
    @State private var technicalStatus = "Operativo"
    @State private var observations = ""
    @State private var participants: [ReportFormParticipant] = []
    @State private var evidence: [APIReportEvidenceWrite] = []
    @State private var signingParticipantID: String?
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isShowingCamera = false
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var hasLoadedState = false
    @State private var didFinalize = false
    @State private var lastAutosavedPayload: APIReportDraftWrite?
    @State private var autosaveTask: Task<Void, Never>?

    private var detail: APIActivityDetail? {
        activityStore.details[eventID]
    }

    private var currentPayload: APIReportDraftWrite {
        APIReportDraftWrite(
            baseReportVersionID: baseReportVersionID,
            enforceBaseVersion: true,
            preventive: nil,
            corrective: APICorrectiveReportWrite(
                symptom: symptom,
                technicalDescription: technicalDescription,
                operationalImpact: operationalImpact,
                failureAnalysisType: failureAnalysis,
                functionalTests: functionalTests,
                validationResult: validationResult,
                serviceReleased: serviceReleased,
                serviceReleasedAt: serviceReleased ? serviceReleasedAt : nil,
                validationResponsible: validationResponsible,
                technicalStatus: technicalStatus,
                conclusion: observations,
                additionalComments: nil,
                correctiveEndedAt: activities.compactMap(\.endedAt).max(),
                stopAfterBlockOrder: nil,
                activities: activities,
                participants: participants.map(\.apiWrite),
                evidence: evidence
            ),
            calibration: nil
        )
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Cargando formulario")
            } else if let detail, let editor {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        OfflineDraftBanner(
                            draft: offlineStore.draft(for: eventID),
                            isNetworkAvailable: offlineStore.isNetworkAvailable
                        ) {
                            Task { await offlineStore.retry(activityID: eventID) }
                        }
                        header(detail)
                        eventData(detail)
                        failurePanel
                        analysisPanel
                        activitiesPanel(editor: editor)
                        validationPanel
                        evidencePanel
                        participantsPanel
                        conclusionsPanel
                        savePanel
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: 900, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            } else {
                ContentUnavailableView(
                    "No se pudo cargar el reporte",
                    systemImage: "doc.badge.exclamationmark",
                    description: Text(errorMessage ?? "No se encontró el correctivo.")
                )
            }
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Reporte correctivo")
        .task { await load() }
        .onChange(of: currentPayload) { _, payload in
            scheduleAutosave(payload)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active,
                  hasLoadedState,
                  currentPayload != lastAutosavedPayload else {
                return
            }
            autosaveTask?.cancel()
            Task {
                await persistOffline(
                    payload: currentPayload,
                    queueForSync: true
                )
            }
        }
        .onChange(of: offlineStore.lastSyncEvent?.id) { _, _ in
            guard let event = offlineStore.lastSyncEvent,
                  event.activityID == eventID else {
                return
            }
            baseReportVersionID = event.reportVersionID
            successMessage = "Borrador sincronizado con el servidor."
            lastAutosavedPayload = currentPayload
        }
        .onDisappear {
            autosaveTask?.cancel()
            guard hasLoadedState,
                  !didFinalize,
                  currentPayload != lastAutosavedPayload else {
                return
            }
            Task {
                await persistOffline(
                    payload: currentPayload,
                    queueForSync: false
                )
            }
        }
        .onChange(of: selectedPhotos) { _, items in
            guard !items.isEmpty else { return }
            Task { await addEvidence(from: items) }
        }
        .sheet(isPresented: signatureSheetBinding) {
            if let participantID = signingParticipantID,
               let index = participants.firstIndex(where: { $0.id == participantID }) {
                SignatureCaptureSheet(
                    participantName: participants[index].name,
                    strokes: signatureBinding(for: participantID)
                ) {
                    signingParticipantID = nil
                }
            }
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraPhotoPicker { image in
                Task { await addEvidence(from: image) }
            }
            .ignoresSafeArea()
        }
    }

    private func header(_ detail: APIActivityDetail) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(detail.eventCode ?? detail.internalCode)
                .font(.caption.weight(.bold))
                .foregroundStyle(BrandColor.red)
            Text(detail.title)
                .font(.system(.largeTitle, design: .rounded).weight(.black))
            HStack {
                APIStatusBadge(status: detail.status)
                Text(detail.subsystem).foregroundStyle(.secondary)
            }
        }
    }

    private func eventData(_ detail: APIActivityDetail) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Datos del evento", subtitle: "Información registrada en el aviso")
                DetailTile(title: "Proyecto", value: detail.project ?? "No registrado")
                DetailTile(title: "Etapa", value: detail.stage ?? "No registrada")
                DetailTile(title: "Sistema", value: detail.system ?? "No registrado")
                DetailTile(title: "Subsistema", value: detail.subsystem)
                DetailTile(title: "Asset afectado", value: detail.assets.map(\.name).joined(separator: ", "))
                DetailTile(title: "Ubicación física", value: detail.locationPath ?? "No registrada")
            }
        }
    }

    private var failurePanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Descripción de falla e impacto")
                TextField("Síntoma registrado", text: $symptom, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                TextField("Descripción técnica detallada", text: $technicalDescription, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
                    .textFieldStyle(.roundedBorder)
                Picker("Impacto operacional", selection: $operationalImpact) {
                    Text("Sin impacto").tag("Sin impacto")
                    Text("Degradado").tag("Degradado")
                    Text("Interrupción parcial").tag("Interrupción parcial")
                    Text("Interrupción total").tag("Interrupción total")
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var analysisPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Análisis de la falla")
                Picker("Tipo de falla", selection: $failureAnalysis) {
                    ForEach(["Funcional", "Hardware", "Software", "Comunicaciones", "Energía"], id: \.self) {
                        Text($0).tag($0)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func activitiesPanel(editor: APIReportEditor) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Actividades realizadas")
                ForEach($activities) { $activity in
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack {
                            Picker("Tipo de actividad", selection: $activity.actionTypeCode) {
                                ForEach(editor.actionTypes) { item in
                                    Text(item.name).tag(item.code)
                                }
                            }
                            .onChange(of: activity.actionTypeCode) { _, code in
                                activity.name = editor.actionTypes.first(where: { $0.code == code })?.name ?? "Actividad correctiva"
                                if code != "CAMBIO_DE_COMPONENTE_CON_UNO_EXTERNO" {
                                    activity.replacement = nil
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                activities.removeAll { $0.id == activity.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                        DatePicker(
                            "Inicio",
                            selection: $activity.startedAt,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        TextField("Descripción", text: $activity.description, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                        if activity.actionTypeCode == "CAMBIO_DE_COMPONENTE_CON_UNO_EXTERNO" {
                            ComponentReplacementEditor(
                                replacement: replacementBinding(for: $activity),
                                equipmentAssets: editor.equipmentAssets,
                                stockAssets: editor.stockAssets,
                                inventoryLocations: editor.inventoryLocations
                            )
                        }
                        DatePicker(
                            "Fin",
                            selection: Binding(
                                get: { activity.endedAt ?? activity.startedAt },
                                set: { activity.endedAt = $0 }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                    .padding(AppSpacing.md)
                    .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
                }
                Button {
                    activities.append(
                        Self.newActivity(
                            actionType: editor.actionTypes.first {
                                !$0.code.contains("CAMBIO")
                            } ?? editor.actionTypes.first
                        )
                    )
                } label: {
                    Label("Agregar actividad", systemImage: "plus.circle.fill")
                }
                .buttonStyle(ActionTileButtonStyle(prominent: true))
            }
        }
    }

    private var validationPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Pruebas y validación")
                TextField("Pruebas funcionales realizadas", text: $functionalTests, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Picker("Resultado", selection: $validationResult) {
                    Text("Conforme").tag("Conforme")
                    Text("No Conforme").tag("No Conforme")
                }
                .pickerStyle(.segmented)
                Toggle("Liberación para servicio", isOn: $serviceReleased)
                if serviceReleased {
                    DatePicker(
                        "Fecha de liberación",
                        selection: $serviceReleasedAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                TextField("Responsable de validación", text: $validationResponsible)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var evidencePanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Evidencias")
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 20,
                    matching: .images
                ) {
                    Label("Agregar desde galería", systemImage: "photo.badge.plus")
                }
                .buttonStyle(ActionTileButtonStyle(prominent: true))
                Button {
                    isShowingCamera = true
                } label: {
                    Label("Tomar foto", systemImage: "camera.fill")
                }
                .buttonStyle(ActionTileButtonStyle(prominent: true))
                .disabled(!isCameraAvailable)
                .opacity(isCameraAvailable ? 1 : 0.55)
                EditableReportEvidenceGrid(evidence: $evidence)
            }
        }
    }

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var participantsPanel: some View {
        ReportParticipantsPanel(participants: $participants) { participantID in
            signingParticipantID = participantID
        }
    }

    private var conclusionsPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Conclusiones / Comentarios")
                Picker("Estado técnico del equipo", selection: $technicalStatus) {
                    Text("Operativo").tag("Operativo")
                    Text("Operativo con restricciones").tag("Operativo con restricciones")
                    Text("Inoperativo").tag("Inoperativo")
                }
                .pickerStyle(.menu)
                TextField("Observaciones / comentarios", text: $observations, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var savePanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(BrandColor.red)
                }
                if let successMessage {
                    Label(successMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(BrandColor.green)
                }
                ActionButtonGrid {
                    Button {
                        Task { await save(finalize: false) }
                    } label: {
                        Label("Guardar borrador", systemImage: "square.and.arrow.down.fill")
                    }
                    .buttonStyle(ActionTileButtonStyle())
                    Button {
                        Task { await save(finalize: true) }
                    } label: {
                        Label("Finalizar versión", systemImage: "checkmark.seal.fill")
                    }
                    .buttonStyle(ActionTileButtonStyle(prominent: true))
                }
                .disabled(isSaving)
                if isSaving { ProgressView("Guardando reporte") }
            }
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        hasLoadedState = false
        let localDraft = offlineStore.draft(for: eventID)
        let workPackage = offlineStore.workPackage(for: eventID)
        if let localDraft {
            activityStore.cacheDetail(localDraft.activityDetail)
        } else if let workPackage {
            activityStore.cacheDetail(workPackage.activityDetail)
        }
        if offlineStore.isNetworkAvailable {
            await activityStore.loadDetail(
                id: eventID,
                session: session,
                force: localDraft != nil
            )
        }
        do {
            let loaded: APIReportEditor
            if !offlineStore.isNetworkAvailable, let workPackage {
                loaded = workPackage.editor
                await offlineStore.markWorkPackageOpened(activityID: eventID)
            } else {
                loaded = try await session.withValidAccessToken { token in
                    try await service.editor(activityID: eventID, accessToken: token)
                }
            }
            editor = loaded
            baseReportVersionID = localDraft?.payload.baseReportVersionID
                ?? loaded.reportVersionID
            apply(
                localDraft?.payload.corrective ?? loaded.correctiveDraft,
                actionTypes: loaded.actionTypes
            )
            if let localReport = localDraft?.payload.corrective {
                participants = loaded.formParticipants(
                    preferredWrites: localReport.participants
                )
                evidence = localReport.evidence
                successMessage = "Se recuperó el borrador guardado en este iPad."
            } else {
                participants = participantDrafts(from: loaded)
                evidence = storedEvidenceWrites(from: loaded)
            }
        } catch {
            if let localDraft {
                editor = localDraft.editor
                baseReportVersionID = localDraft.payload.baseReportVersionID
                activityStore.cacheDetail(localDraft.activityDetail)
                apply(
                    localDraft.payload.corrective,
                    actionTypes: localDraft.editor.actionTypes
                )
                if let localReport = localDraft.payload.corrective {
                    participants = localDraft.editor.formParticipants(
                        preferredWrites: localReport.participants
                    )
                    evidence = localReport.evidence
                }
                successMessage = "Modo offline: se recuperó el borrador de este iPad."
            } else if let workPackage {
                editor = workPackage.editor
                activityStore.cacheDetail(workPackage.activityDetail)
                apply(
                    workPackage.editor.correctiveDraft,
                    actionTypes: workPackage.editor.actionTypes
                )
                participants = participantDrafts(from: workPackage.editor)
                evidence = storedEvidenceWrites(from: workPackage.editor)
                successMessage = "Modo offline: se abrió el trabajo descargado en este iPad."
            } else {
                errorMessage = error.localizedDescription
            }
        }
        hasLoadedState = editor != nil && detail != nil
        lastAutosavedPayload = hasLoadedState ? currentPayload : nil
        isLoading = false
    }

    private func apply(
        _ draft: APICorrectiveReportWrite?,
        actionTypes: [APIEditorActionType]
    ) {
        guard let draft else {
            activities = [
                Self.newActivity(
                    actionType: actionTypes.first {
                        !$0.code.contains("CAMBIO")
                    } ?? actionTypes.first
                )
            ]
            return
        }
        symptom = draft.symptom ?? ""
        technicalDescription = draft.technicalDescription ?? ""
        operationalImpact = draft.operationalImpact ?? "Degradado"
        failureAnalysis = draft.failureAnalysisType ?? "Hardware"
        activities = draft.activities
        functionalTests = draft.functionalTests ?? ""
        validationResult = draft.validationResult ?? "Conforme"
        serviceReleased = draft.serviceReleased
        serviceReleasedAt = draft.serviceReleasedAt ?? Date()
        validationResponsible = draft.validationResponsible ?? ""
        technicalStatus = draft.technicalStatus ?? "Operativo"
        observations = draft.conclusion ?? ""
    }

    @MainActor
    private func save(finalize: Bool) async {
        isSaving = true
        errorMessage = nil
        successMessage = nil
        let payload = currentPayload
        await persistOffline(payload: payload, queueForSync: true)
        if finalize && !offlineStore.isNetworkAvailable {
            successMessage = "Borrador protegido en este iPad."
            errorMessage = "La versión solo puede finalizarse cuando vuelva la conexión."
            isSaving = false
            return
        }
        do {
            let result = try await session.withValidAccessToken { token in
                try await service.save(
                    activityID: eventID,
                    draft: payload,
                    finalize: finalize,
                    accessToken: token
                )
            }
            await offlineStore.markSynchronized(
                activityID: eventID,
                synchronizedPayload: payload,
                reportVersionID: result.versionID
            )
            baseReportVersionID = result.versionID
            lastAutosavedPayload = currentPayload
            successMessage = finalize
                ? "Versión \(result.versionNumber) finalizada."
                : "Borrador guardado."
            await activityStore.loadDetail(id: eventID, session: session, force: true)
            if finalize {
                didFinalize = true
                dismiss()
            }
        } catch {
            await offlineStore.markFailed(activityID: eventID, error: error)
            if error.isReportConnectivityFailure {
                successMessage = "Borrador protegido en este iPad."
                errorMessage = finalize
                    ? "No se pudo finalizar sin conexión. Reintenta cuando el servidor esté disponible."
                    : nil
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isSaving = false
    }

    private func storedEvidenceWrites(
        from editor: APIReportEditor
    ) -> [APIReportEvidenceWrite] {
        editor.evidence.map {
            APIReportEvidenceWrite(
                clientID: $0.id,
                attachmentID: $0.id,
                originalFileName: $0.originalFileName ?? "evidencia",
                mediaType: $0.mediaType ?? "application/octet-stream",
                title: $0.title,
                description: $0.description,
                capturedAt: $0.capturedAt,
                contentBase64: nil,
                preventiveStepID: nil,
                correctiveActivityClientID: nil
            )
        }
    }

    @MainActor
    private func scheduleAutosave(_ payload: APIReportDraftWrite) {
        guard hasLoadedState, payload != lastAutosavedPayload else { return }
        autosaveTask?.cancel()
        autosaveTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await persistOffline(
                payload: payload,
                queueForSync: !offlineStore.isNetworkAvailable
            )
            lastAutosavedPayload = payload
        }
    }

    @MainActor
    private func persistOffline(
        payload: APIReportDraftWrite,
        queueForSync: Bool
    ) async {
        guard let editor, let detail else { return }
        await offlineStore.persist(
            activityID: eventID,
            payload: payload,
            editor: editor,
            activityDetail: detail,
            queueForSync: queueForSync
        )
    }

    @MainActor
    private func addEvidence(from items: [PhotosPickerItem]) async {
        for item in items {
            do {
                guard let sourceData = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: sourceData) else {
                    throw CorrectiveEvidenceImportError.invalidImage
                }
                await addEvidence(from: image)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        selectedPhotos = []
    }

    @MainActor
    private func addEvidence(from image: UIImage) async {
        guard let jpegData = normalizedJPEGData(for: image) else {
            errorMessage = CorrectiveEvidenceImportError.invalidImage.localizedDescription
            return
        }
        evidence.append(
            APIReportEvidenceWrite(
                clientID: UUID().uuidString,
                attachmentID: nil,
                originalFileName: "evidencia-correctiva-\(evidence.count + 1).jpg",
                mediaType: "image/jpeg",
                title: "Evidencia correctiva",
                description: nil,
                capturedAt: Date(),
                contentBase64: jpegData.base64EncodedString(),
                preventiveStepID: nil,
                correctiveActivityClientID: nil
            )
        )
    }

    private func normalizedJPEGData(for image: UIImage) -> Data? {
        let maximumDimension: CGFloat = 1_920
        let largestDimension = max(image.size.width, image.size.height)
        let scale = min(1, maximumDimension / largestDimension)
        let targetSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let normalizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return normalizedImage.jpegData(compressionQuality: 0.86)
    }

    private func participantDrafts(from editor: APIReportEditor) -> [ReportFormParticipant] {
        let stored = Dictionary(uniqueKeysWithValues: editor.participants.map { ($0.userID, $0) })
        return editor.availableParticipants.map { user in
            let participant = stored[user.id]
            return ReportFormParticipant(
                id: user.id,
                name: user.name,
                role: user.role,
                isSelected: participant?.selected ?? false,
                strokes: participant?.signatureStrokes.map(\.cgPoints) ?? []
            )
        }
    }

    private func replacementBinding(
        for activity: Binding<APICorrectiveActivityWrite>
    ) -> Binding<APIComponentReplacementWrite> {
        Binding {
            activity.wrappedValue.replacement ?? APIComponentReplacementWrite(
                parentAssetID: "",
                removedAssetID: "",
                installedAssetID: "",
                removedPartNumber: nil,
                removedSerialNumber: nil,
                removedModel: nil,
                removedManufacturer: nil,
                installedPartNumber: nil,
                installedSerialNumber: nil,
                installedModel: nil,
                installedManufacturer: nil,
                sourceDescription: "Almacenamiento SPV",
                destinationDescription: "Almacenamiento Mantto Hitachi",
                removedCondition: "Inoperativo",
                installedCondition: "Operativo",
                removedNotes: nil,
                installedNotes: nil,
                reason: "Reemplazo durante mantenimiento correctivo"
            )
        } set: {
            activity.wrappedValue.replacement = $0
        }
    }

    private var service: ReportAPIService {
        ReportAPIService(
            baseURLString: UserDefaults.standard.string(forKey: "apiBaseURL") ?? ""
        )
    }

    private var signatureSheetBinding: Binding<Bool> {
        Binding(
            get: { signingParticipantID != nil },
            set: { if !$0 { signingParticipantID = nil } }
        )
    }

    private func signatureBinding(for participantID: String) -> Binding<[[CGPoint]]> {
        Binding {
            participants.first(where: { $0.id == participantID })?.strokes ?? []
        } set: { value in
            guard let index = participants.firstIndex(where: { $0.id == participantID }) else { return }
            participants[index].strokes = value
        }
    }

    private static func newActivity(
        actionType: APIEditorActionType?
    ) -> APICorrectiveActivityWrite {
        APICorrectiveActivityWrite(
            clientID: UUID().uuidString,
            actionTypeCode: actionType?.code ?? "",
            name: actionType?.name ?? "Actividad correctiva",
            description: "",
            startedAt: Date(),
            endedAt: Date(),
            replacement: nil
        )
    }

}

private enum CorrectiveEvidenceImportError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        "No se pudo procesar una de las imágenes seleccionadas."
    }
}

private struct ComponentReplacementEditor: View {
    @Binding var replacement: APIComponentReplacementWrite
    let equipmentAssets: [APIEditorAsset]
    let stockAssets: [APIEditorAsset]
    let inventoryLocations: [String]
    @State private var isSelectingRemovedAsset = false
    @State private var isSelectingStock = false
    @State private var removedSearch = ""
    @State private var stockSearch = ""

    private var selectedRemovedAsset: APIEditorAsset? {
        equipmentAssets.first { $0.id == replacement.removedAssetID }
    }

    private var selectedInstalledAsset: APIEditorAsset? {
        stockAssets.first { $0.id == replacement.installedAssetID }
    }

    private var locations: [String] {
        Array(Set(inventoryLocations + stockAssets.map(\.path)))
            .filter { !$0.isEmpty }
            .sorted()
    }

    private var availableStock: [APIEditorAsset] {
        stockAssets.filter { $0.path == replacement.sourceDescription }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeaderText(
                title: "Cambio de componente",
                subtitle: "El inventario se actualiza al completar el correctivo"
            )

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Componente a retirar",
                    subtitle: "Seleccione el asset dentro del equipo afectado"
                )
                Button {
                    removedSearch = ""
                    isSelectingRemovedAsset = true
                } label: {
                    ReplacementSelectionButtonLabel(
                        title: selectedRemovedAsset?.name ?? "Seleccionar componente",
                        subtitle: selectedRemovedAsset.map(assetBreadcrumb)
                            ?? "Abrir árbol del equipo",
                        systemImage: "square.3.layers.3d.down.right"
                    )
                }
                .buttonStyle(.plain)

                if let selectedRemovedAsset {
                    DetailTile(
                        title: "Asset seleccionado para retirar",
                        value: assetBreadcrumb(selectedRemovedAsset)
                    )
                    ReplacementAssetMetadataEditor(
                        asset: selectedRemovedAsset,
                        partNumber: $replacement.removedPartNumber,
                        serialNumber: $replacement.removedSerialNumber,
                        model: $replacement.removedModel,
                        manufacturer: $replacement.removedManufacturer
                    )
                }

                Picker(
                    "Estado del componente",
                    selection: Binding(
                        get: { replacement.removedCondition ?? "Inoperativo" },
                        set: { replacement.removedCondition = $0 }
                    )
                ) {
                    Text("Operativo").tag("Operativo")
                    Text("Inoperativo").tag("Inoperativo")
                }
                .pickerStyle(.menu)

                Picker("Se enviará a", selection: $replacement.destinationDescription) {
                    ForEach(locations, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)

                TextField(
                    "Notas adicionales del componente retirado",
                    text: Binding(
                        get: { replacement.removedNotes ?? "" },
                        set: { replacement.removedNotes = $0.isEmpty ? nil : $0 }
                    ),
                    axis: .vertical
                )
                .lineLimit(2, reservesSpace: true)
                .textFieldStyle(.roundedBorder)
            }
            .padding(AppSpacing.md)
            .background(
                .background.opacity(0.72),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Componente a reponer",
                    subtitle: "Seleccione primero el almacén de origen"
                )

                Picker("Se obtiene de", selection: $replacement.sourceDescription) {
                    ForEach(locations, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .onChange(of: replacement.sourceDescription) { _, source in
                    guard let selectedInstalledAsset,
                          selectedInstalledAsset.path != source else { return }
                    replacement.installedAssetID = ""
                }

                Button {
                    stockSearch = ""
                    isSelectingStock = true
                } label: {
                    ReplacementSelectionButtonLabel(
                        title: selectedInstalledAsset?.name ?? "Seleccionar de stock",
                        subtitle: selectedInstalledAsset?.serialNumber
                            ?? replacement.sourceDescription,
                        systemImage: "shippingbox.fill"
                    )
                }
                .buttonStyle(.plain)
                .disabled(replacement.sourceDescription.isEmpty)

                if let selectedInstalledAsset {
                    DetailTile(
                        title: "Componente seleccionado para reponer",
                        value: "\(selectedInstalledAsset.name) · \(selectedInstalledAsset.serialNumber ?? "Sin serie")"
                    )
                    ReplacementAssetMetadataEditor(
                        asset: selectedInstalledAsset,
                        partNumber: $replacement.installedPartNumber,
                        serialNumber: $replacement.installedSerialNumber,
                        model: $replacement.installedModel,
                        manufacturer: $replacement.installedManufacturer
                    )
                }

                Picker(
                    "Estado del componente",
                    selection: Binding(
                        get: { replacement.installedCondition ?? "Operativo" },
                        set: { replacement.installedCondition = $0 }
                    )
                ) {
                    Text("Operativo").tag("Operativo")
                    Text("Inoperativo").tag("Inoperativo")
                }
                .pickerStyle(.menu)

                TextField(
                    "Notas adicionales del componente instalado",
                    text: Binding(
                        get: { replacement.installedNotes ?? "" },
                        set: { replacement.installedNotes = $0.isEmpty ? nil : $0 }
                    ),
                    axis: .vertical
                )
                .lineLimit(2, reservesSpace: true)
                .textFieldStyle(.roundedBorder)
            }
            .padding(AppSpacing.md)
            .background(
                .background.opacity(0.72),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )

            TextField("Motivo del reemplazo", text: $replacement.reason, axis: .vertical)
                .lineLimit(2, reservesSpace: true)
                .textFieldStyle(.roundedBorder)
        }
        .padding(AppSpacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $isSelectingRemovedAsset) {
            ReplacementAssetSelectionSheet(
                title: "Seleccionar componente a retirar",
                subtitle: "Árbol del equipo afectado",
                assets: equipmentAssets,
                searchText: $removedSearch,
                selectedAssetID: replacement.removedAssetID,
                showsHierarchy: true
            ) { asset in
                if replacement.removedAssetID != asset.id {
                    replacement.removedPartNumber = nil
                    replacement.removedSerialNumber = nil
                    replacement.removedModel = nil
                    replacement.removedManufacturer = nil
                }
                replacement.removedAssetID = asset.id
                replacement.parentAssetID = asset.parentID ?? ""
                isSelectingRemovedAsset = false
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $isSelectingStock) {
            ReplacementAssetSelectionSheet(
                title: "Seleccionar el componente a reemplazar",
                subtitle: replacement.sourceDescription,
                assets: availableStock,
                searchText: $stockSearch,
                selectedAssetID: replacement.installedAssetID,
                showsHierarchy: false
            ) { asset in
                if replacement.installedAssetID != asset.id {
                    replacement.installedPartNumber = nil
                    replacement.installedSerialNumber = nil
                    replacement.installedModel = nil
                    replacement.installedManufacturer = nil
                }
                replacement.installedAssetID = asset.id
                replacement.sourceDescription = asset.path
                isSelectingStock = false
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            if replacement.sourceDescription.isEmpty
                || !locations.contains(replacement.sourceDescription) {
                replacement.sourceDescription = locations.first ?? ""
            }
            if replacement.destinationDescription.isEmpty
                || !locations.contains(replacement.destinationDescription) {
                replacement.destinationDescription = locations.first ?? ""
            }
        }
    }

    private func assetBreadcrumb(_ asset: APIEditorAsset) -> String {
        var names = [asset.name]
        var parentID = asset.parentID
        var visited = Set([asset.id])
        while let currentParentID = parentID,
              !visited.contains(currentParentID),
              let parent = equipmentAssets.first(where: { $0.id == currentParentID }) {
            names.insert(parent.name, at: 0)
            visited.insert(parent.id)
            parentID = parent.parentID
        }
        return names.joined(separator: " > ")
    }
}

private struct ReplacementSelectionButtonLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(BrandColor.red)
                .frame(width: 44, height: 44)
                .background(BrandColor.red.opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
}

private struct ReplacementAssetMetadataEditor: View {
    let asset: APIEditorAsset
    @Binding var partNumber: String?
    @Binding var serialNumber: String?
    @Binding var model: String?
    @Binding var manufacturer: String?
    private let columns = [
        GridItem(.adaptive(minimum: 180), spacing: AppSpacing.sm)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
            metadataField(
                title: "Part number",
                storedValue: asset.partNumber,
                value: $partNumber
            )
            metadataField(
                title: "Serial number",
                storedValue: asset.serialNumber,
                value: $serialNumber
            )
            metadataField(
                title: "Modelo",
                storedValue: asset.model,
                value: $model
            )
            metadataField(
                title: "Fabricante",
                storedValue: asset.manufacturer,
                value: $manufacturer
            )
        }
    }

    @ViewBuilder
    private func metadataField(
        title: String,
        storedValue: String?,
        value: Binding<String?>
    ) -> some View {
        if let storedValue, !storedValue.isEmpty {
            DetailTile(title: title, value: storedValue)
        } else {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField(
                    "Ingresar \(title.lowercased())",
                    text: Binding(
                        get: { value.wrappedValue ?? "" },
                        set: {
                            value.wrappedValue = $0.isEmpty ? nil : $0
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)
            }
            .padding(AppSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                BrandColor.amber.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
    }
}

private struct ReplacementAssetSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let subtitle: String
    let assets: [APIEditorAsset]
    @Binding var searchText: String
    let selectedAssetID: String
    let showsHierarchy: Bool
    let onSelect: (APIEditorAsset) -> Void
    @State private var expandedAssetIDs: Set<String> = []

    private var normalizedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var rootAssetIDs: Set<String> {
        let ids = Set(assets.map(\.id))
        return Set(
            assets
                .filter { $0.parentID == nil || !ids.contains($0.parentID ?? "") }
                .map(\.id)
        )
    }

    private var roots: [ReplacementAssetBranch] {
        ReplacementAssetBranch.roots(from: assets)
    }

    private var visibleRoots: [ReplacementAssetBranch] {
        guard showsHierarchy, !normalizedQuery.isEmpty else { return roots }
        return roots.filter(matchesOrContainsMatch)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    GlassPanel {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            SectionHeaderText(title: title, subtitle: subtitle)
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField("Filtrar por nombre, serie o part number", text: $searchText)
                                    .textInputAutocapitalization(.never)
                            }
                            .padding(AppSpacing.md)
                            .background(
                                .regularMaterial,
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                        }
                    }

                    if visibleRoots.isEmpty {
                        ContentUnavailableView(
                            "No hay componentes disponibles",
                            systemImage: "shippingbox"
                        )
                    } else {
                        LazyVStack(spacing: AppSpacing.sm) {
                            ForEach(visibleRoots) { branch in
                                ReplacementAssetTreeBranchView(
                                    branch: branch,
                                    selectedAssetID: selectedAssetID,
                                    expandedAssetIDs: $expandedAssetIDs,
                                    query: normalizedQuery,
                                    rootAssetIDs: rootAssetIDs,
                                    onSelect: onSelect
                                )
                            }
                        }
                    }
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: 860)
                .frame(maxWidth: .infinity)
            }
            .background(MaintenanceScreenBackground())
            .navigationTitle("Selección de componente")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .onChange(of: normalizedQuery) { _, query in
                guard showsHierarchy, !query.isEmpty else { return }
                expandedAssetIDs = Set(
                    roots.flatMap { $0.expandableIDs(keepingMatchesFor: query) }
                )
            }
        }
    }

    private func matchesOrContainsMatch(_ branch: ReplacementAssetBranch) -> Bool {
        branch.matches(normalizedQuery)
            || branch.children.contains { matchesOrContainsMatch($0) }
    }
}

private struct ReplacementAssetBranch: Identifiable {
    let asset: APIEditorAsset
    let children: [ReplacementAssetBranch]

    var id: String { asset.id }

    static func roots(from assets: [APIEditorAsset]) -> [ReplacementAssetBranch] {
        let ids = Set(assets.map(\.id))
        let grouped = Dictionary(grouping: assets) { $0.parentID }
        var visited = Set<String>()

        func build(_ asset: APIEditorAsset) -> ReplacementAssetBranch? {
            guard visited.insert(asset.id).inserted else { return nil }
            let children = (grouped[asset.id] ?? [])
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                .compactMap(build)
            return ReplacementAssetBranch(asset: asset, children: children)
        }

        return assets
            .filter { $0.parentID == nil || !ids.contains($0.parentID ?? "") }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .compactMap(build)
    }

    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return asset.name.localizedCaseInsensitiveContains(query)
            || asset.path.localizedCaseInsensitiveContains(query)
            || (asset.partNumber?.localizedCaseInsensitiveContains(query) ?? false)
            || (asset.serialNumber?.localizedCaseInsensitiveContains(query) ?? false)
    }

    func expandableIDs(keepingMatchesFor query: String) -> [String] {
        guard !children.isEmpty else { return [] }
        let childMatches = children.contains { $0.matches(query) || !$0.expandableIDs(keepingMatchesFor: query).isEmpty }
        let nested = children.flatMap { $0.expandableIDs(keepingMatchesFor: query) }
        return (childMatches ? [id] : []) + nested
    }
}

private struct ReplacementAssetTreeBranchView: View {
    let branch: ReplacementAssetBranch
    let selectedAssetID: String
    @Binding var expandedAssetIDs: Set<String>
    let query: String
    let rootAssetIDs: Set<String>
    let onSelect: (APIEditorAsset) -> Void

    private var visibleChildren: [ReplacementAssetBranch] {
        guard !query.isEmpty else { return branch.children }
        return branch.children.filter { $0.matches(query) || $0.children.containsDescendantMatch(query) }
    }

    private var canSelect: Bool {
        branch.asset.selectable && !rootAssetIDs.contains(branch.asset.id)
    }

    var body: some View {
        if visibleChildren.isEmpty {
            row
        } else {
            DisclosureGroup(isExpanded: expansionBinding) {
                LazyVStack(alignment: .leading, spacing: AppSpacing.xs) {
                    ForEach(visibleChildren) { child in
                        ReplacementAssetTreeBranchView(
                            branch: child,
                            selectedAssetID: selectedAssetID,
                            expandedAssetIDs: $expandedAssetIDs,
                            query: query,
                            rootAssetIDs: rootAssetIDs,
                            onSelect: onSelect
                        )
                        .padding(.leading, AppSpacing.lg)
                    }
                }
                .padding(.top, AppSpacing.xs)
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
                if isExpanded { expandedAssetIDs.insert(branch.id) }
                else { expandedAssetIDs.remove(branch.id) }
            }
        )
    }

    private var row: some View {
        Button {
            guard canSelect else { return }
            onSelect(branch.asset)
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: branch.asset.nodeKind == "LOCATION" || !visibleChildren.isEmpty ? "folder.fill" : "cpu")
                    .foregroundStyle(
                        branch.asset.id == selectedAssetID ? BrandColor.red : .secondary
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text(branch.asset.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(branch.asset.serialNumber ?? branch.asset.partNumber ?? branch.asset.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if branch.asset.id == selectedAssetID {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BrandColor.red)
                } else if canSelect {
                    Image(systemName: "circle")
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(!canSelect)
    }
}

private extension Array where Element == ReplacementAssetBranch {
    func containsDescendantMatch(_ query: String) -> Bool {
        contains { branch in
            branch.matches(query) || branch.children.containsDescendantMatch(query)
        }
    }
}
