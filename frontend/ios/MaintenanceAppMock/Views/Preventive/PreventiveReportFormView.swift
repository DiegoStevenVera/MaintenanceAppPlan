import PhotosUI
import SwiftUI
import UIKit

struct PreventiveReportFormView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var activityStore: MaintenanceActivityStore
    @EnvironmentObject private var offlineStore: OfflineReportStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let activityID: String

    @State private var editor: APIReportEditor?
    @State private var baseReportVersionID: String?
    @State private var steps: [APIPreventiveStepWrite] = []
    @State private var participants: [ReportFormParticipant] = []
    @State private var evidence: [APIReportEvidenceWrite] = []
    @State private var sapOrder = ""
    @State private var selectedToolIDs: Set<String> = []
    @State private var showsUnselectedTools = false
    @State private var conclusion = "Equipo operativo"
    @State private var additionalComments = ""
    @State private var endTime = Date()
    @State private var calibrationFrequency = ""
    @State private var transmitterJumpers = ""
    @State private var receiverCount = 1
    @State private var selectedReceiver = 1
    @State private var calibrationReceivers: [APICalibrationReceiverWrite] = [
        APICalibrationReceiverWrite(
            sequence: 1,
            jumpers: "",
            tca9: "",
            railCurrent: ""
        )
    ]
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
        activityStore.details[activityID]
    }

    private var currentPayload: APIReportDraftWrite {
        APIReportDraftWrite(
            baseReportVersionID: baseReportVersionID,
            enforceBaseVersion: true,
            preventive: APIPreventiveReportWrite(
                sapOrder: sapOrder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : sapOrder,
                activityEndedAt: endTime,
                finalResult: conclusion,
                additionalComments: additionalComments,
                steps: steps,
                participants: participants.map(\.apiWrite),
                evidence: evidence,
                tools: selectedToolIDs.sorted().map(APIReportToolUsageWrite.init(toolID:))
            ),
            corrective: nil,
            calibration: editor?.calibrationRequired == true
                ? APICalibrationReportWrite(
                    frequency: calibrationFrequency,
                    transmitterJumpers: transmitterJumpers,
                    receivers: calibrationReceivers
                )
                : nil
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
                            draft: offlineStore.draft(for: activityID),
                            isNetworkAvailable: offlineStore.isNetworkAvailable
                        ) {
                            Task { await offlineStore.retry(activityID: activityID) }
                        }
                        header(detail)
                        generalData(detail, editor: editor)
                        toolsPanel(editor)
                        stepsPanel
                        if editor.calibrationRequired {
                            calibrationPanel
                        }
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
                    description: Text(errorMessage ?? "No se encontró el mantenimiento.")
                )
            }
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Reporte preventivo")
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
                  event.activityID == activityID else {
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
            Text(detail.internalCode)
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

    private func generalData(_ detail: APIActivityDetail, editor: APIReportEditor) -> some View {
        return GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Datos generales", subtitle: "Datos definidos por la programación")
                DetailTile(title: "Actividad", value: detail.title)
                if editor.sapOrderEditable {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Orden SAP")
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                        TextField("Ingresar Orden SAP", text: $sapOrder)
                            .textFieldStyle(.roundedBorder)
                    }
                } else if let sapOrder = editor.sapOrder, !sapOrder.isEmpty {
                    DetailTile(title: "Orden SAP", value: sapOrder)
                }
                DetailTile(title: "Equipos", value: detail.assets.map(\.name).joined(separator: ", "))
                DetailTile(title: "Sede", value: detail.site ?? "No registrada")
                DetailTile(title: "Proyecto", value: detail.project ?? "No registrado")
                DetailTile(title: "Etapa", value: detail.stage ?? "No registrada")
                DetailTile(title: "Sistema", value: detail.system ?? "No registrado")
                DetailTile(title: "Subsistema", value: detail.subsystem)
                DetailTile(title: "Fecha", value: editor.actualDate)
                DetailTile(title: "Hora de inicio", value: Self.dateTimeFormatter.string(from: editor.activityStartedAt))
                DatePicker(
                    "Hora fin de la actividad",
                    selection: $endTime,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .padding(AppSpacing.md)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                DetailTile(title: "Ubicación física", value: detail.locationPath ?? "No registrada")
            }
        }
    }

    private var stepsPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Pasos del mantenimiento")
                ForEach($steps) { $step in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Toggle(step.title, isOn: $step.isCompleted)
                            .font(.headline)
                        if let page = step.manualPage {
                            Label("Manual, página \(page)", systemImage: "book.pages.fill")
                                .font(.subheadline)
                                .foregroundStyle(BrandColor.red)
                        }
                        TextField(
                            "Comentario del paso",
                            text: Binding($step.comment, replacingNilWith: ""),
                            axis: .vertical
                        )
                        .textFieldStyle(.roundedBorder)
                        ForEach($step.tests) { $test in
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(test.name).font(.subheadline.weight(.semibold))
                                Picker("Resultado", selection: $test.selectedResult) {
                                    ForEach(resultOptions(for: test), id: \.self) { option in
                                        Text(option).tag(option)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                /**
                                TextField(
                                    "Notas",
                                    text: Binding($test.notes, replacingNilWith: ""),
                                    axis: .vertical
                                )
                                .textFieldStyle(.roundedBorder)*/
                            }
                            .padding(AppSpacing.sm)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var evidencePanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Evidencias", subtitle: "Fotografías persistidas con esta versión")
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

    private func toolsPanel(_ editor: APIReportEditor) -> some View {
        let selectedTools = editor.availableTools.filter { selectedToolIDs.contains($0.id) }
        let unselectedTools = editor.availableTools.filter { !selectedToolIDs.contains($0.id) }

        return GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Herramientas usadas",
                    subtitle: "\(selectedTools.count) seleccionada(s)"
                )
                if !editor.requiredToolNames.isEmpty {
                    Text("Requeridas por el mantenimiento: \(editor.requiredToolNames.joined(separator: ", "))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if editor.availableTools.isEmpty {
                    Text("No hay herramientas disponibles registradas.")
                        .foregroundStyle(.secondary)
                } else {
                    if selectedTools.isEmpty {
                        Label(
                            "Seleccione las herramientas utilizadas",
                            systemImage: "wrench.and.screwdriver"
                        )
                        .foregroundStyle(.secondary)
                        .padding(.vertical, AppSpacing.sm)
                    }

                    ForEach(selectedTools) { tool in
                        toolToggle(tool)
                    }

                    if !unselectedTools.isEmpty {
                        DisclosureGroup(isExpanded: $showsUnselectedTools) {
                            VStack(spacing: AppSpacing.xs) {
                                ForEach(unselectedTools) { tool in
                                    toolToggle(tool)
                                        .padding(.vertical, AppSpacing.xs)
                                }
                            }
                            .padding(.top, AppSpacing.sm)
                        } label: {
                            Label(
                                "No seleccionadas (\(unselectedTools.count))",
                                systemImage: "wrench.and.screwdriver"
                            )
                            .font(.subheadline.weight(.semibold))
                        }
                        .padding(AppSpacing.md)
                        .background(
                            .background.opacity(0.58),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    }
                }
            }
        }
    }

    private func toolToggle(_ tool: APIEditorTool) -> some View {
        Toggle(isOn: Binding(
            get: { selectedToolIDs.contains(tool.id) },
            set: { selected in
                if selected { selectedToolIDs.insert(tool.id) }
                else { selectedToolIDs.remove(tool.id) }
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name).font(.headline)
                Text("Serie: \(tool.serialNumber)")
                    .font(.caption).foregroundStyle(.secondary)
                if let certification = tool.certificationNumber {
                    Text("Certificado: \(certification)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
    }

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var calibrationPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Calibración del circuito de vía",
                    subtitle: "Genera un reporte de calibración independiente"
                )

                LabeledContent("Frecuencia del circuito de vía") {
                    HStack(spacing: AppSpacing.xs) {
                        TextField("0", text: $calibrationFrequency)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(minWidth: 120)
                        Text("Hz").foregroundStyle(.secondary)
                    }
                }
                .padding(AppSpacing.md)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))

                TextField("Jumpers del transmisor", text: $transmitterJumpers)
                    .textFieldStyle(.roundedBorder)

                Stepper(
                    "Cantidad de receptores: \(receiverCount)",
                    value: $receiverCount,
                    in: 1...4
                )
                .padding(AppSpacing.md)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))

                if receiverCount > 1 {
                    Picker("Receptor", selection: $selectedReceiver) {
                        ForEach(1...receiverCount, id: \.self) { receiver in
                            Text("RX\(receiver)").tag(receiver)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if let index = calibrationReceivers.firstIndex(
                    where: { $0.sequence == selectedReceiver }
                ) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Label(
                            "Receptor \(selectedReceiver)",
                            systemImage: "dot.radiowaves.left.and.right"
                        )
                        .font(.headline)
                        .foregroundStyle(BrandColor.red)

                        TextField(
                            "Jumpers del receptor \(selectedReceiver)",
                            text: $calibrationReceivers[index].jumpers
                        )
                        .textFieldStyle(.roundedBorder)

                        TextField(
                            "TCA9 del receptor \(selectedReceiver)",
                            text: $calibrationReceivers[index].tca9
                        )
                        .textFieldStyle(.roundedBorder)

                        LabeledContent(
                            "Corriente de riel del receptor \(selectedReceiver)"
                        ) {
                            HStack(spacing: AppSpacing.xs) {
                                TextField(
                                    "0",
                                    text: $calibrationReceivers[index].railCurrent
                                )
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(minWidth: 120)
                                Text("mA").foregroundStyle(.secondary)
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(
                            .regularMaterial,
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    }
                    .padding(AppSpacing.md)
                    .background(
                        .background.opacity(0.72),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
            }
        }
        .onChange(of: receiverCount) { _, newCount in
            resizeCalibrationReceivers(to: newCount)
        }
    }

    private var participantsPanel: some View {
        ReportParticipantsPanel(participants: $participants) { participantID in
            signingParticipantID = participantID
        }
    }

    private var conclusionsPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Conclusiones")
                Picker("Estado final del equipo", selection: $conclusion) {
                    Text("Equipo operativo").tag("Equipo operativo")
                    Text("Equipo no operativo").tag("Equipo no operativo")
                    Text("Equipo medio operativo").tag("Equipo medio operativo")
                }
                .pickerStyle(.menu)
                TextField(
                    "Comentarios adicionales del mantenimiento",
                    text: $additionalComments,
                    axis: .vertical
                )
                .lineLimit(3, reservesSpace: true)
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
                    if offlineStore.isNetworkAvailable {
                        Button {
                            Task { await save(finalize: true) }
                        } label: {
                            Label("Finalizar versión", systemImage: "checkmark.seal.fill")
                        }
                        .buttonStyle(ActionTileButtonStyle(prominent: true))
                    }
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
        let localDraft = offlineStore.draft(for: activityID)
        let workPackage = offlineStore.workPackage(for: activityID)
        if let localDraft {
            activityStore.cacheDetail(localDraft.activityDetail)
        } else if let workPackage {
            activityStore.cacheDetail(workPackage.activityDetail)
        }
        if offlineStore.isNetworkAvailable {
            await activityStore.loadDetail(
                id: activityID,
                session: session,
                force: localDraft != nil
            )
        }
        do {
            let loaded: APIReportEditor
            if !offlineStore.isNetworkAvailable, let workPackage {
                loaded = workPackage.editor
                await offlineStore.markWorkPackageOpened(activityID: activityID)
            } else {
                loaded = try await session.withValidAccessToken { token in
                    try await service.editor(activityID: activityID, accessToken: token)
                }
            }
            editor = loaded
            baseReportVersionID = localDraft?.payload.baseReportVersionID
                ?? loaded.reportVersionID
            apply(editor: loaded, localPayload: localDraft?.payload)
            if localDraft != nil {
                successMessage = "Se recuperó el borrador guardado en este iPad."
            }
        } catch {
            if let localDraft {
                editor = localDraft.editor
                baseReportVersionID = localDraft.payload.baseReportVersionID
                activityStore.cacheDetail(localDraft.activityDetail)
                apply(
                    editor: localDraft.editor,
                    localPayload: localDraft.payload
                )
                successMessage = "Modo offline: se recuperó el borrador de este iPad."
            } else if let workPackage {
                editor = workPackage.editor
                activityStore.cacheDetail(workPackage.activityDetail)
                apply(editor: workPackage.editor, localPayload: nil)
                successMessage = "Modo offline: se abrió el trabajo descargado en este iPad."
            } else {
                errorMessage = error.localizedDescription
            }
        }
        hasLoadedState = editor != nil && detail != nil
        lastAutosavedPayload = hasLoadedState ? currentPayload : nil
        isLoading = false
    }

    @MainActor
    private func save(finalize: Bool) async {
        isSaving = true
        errorMessage = nil
        successMessage = nil
        let payload = currentPayload
        await persistOffline(
            payload: payload,
            queueForSync: true
        )
        if !offlineStore.isNetworkAvailable {
            lastAutosavedPayload = payload
            successMessage = "Borrador guardado en este iPad. Finaliza la versión al recuperar conexión."
            dismiss()
            isSaving = false
            return
        }
        do {
            let result = try await session.withValidAccessToken { token in
                try await service.save(
                    activityID: activityID,
                    draft: payload,
                    finalize: finalize,
                    accessToken: token
                )
            }
            await offlineStore.markSynchronized(
                activityID: activityID,
                synchronizedPayload: payload,
                reportVersionID: result.versionID,
                announce: false
            )
            baseReportVersionID = result.versionID
            lastAutosavedPayload = currentPayload
            successMessage = finalize
                ? "Versión \(result.versionNumber) finalizada."
                : "Borrador guardado."
            await activityStore.loadDetail(id: activityID, session: session, force: true)
            if let detail = activityStore.details[activityID] {
                await offlineStore.reconcileWorkPackage(with: detail)
            }
            if finalize {
                didFinalize = true
                dismiss()
            }
        } catch {
            await offlineStore.markFailed(activityID: activityID, error: error)
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

    private func apply(
        editor loaded: APIReportEditor,
        localPayload: APIReportDraftWrite?
    ) {
        let localReport = localPayload?.preventive
        endTime = localReport?.activityEndedAt
            ?? loaded.preventiveDraft?.activityEndedAt
            ?? loaded.activityEndedAt
            ?? Date()
        conclusion = localReport?.finalResult
            ?? loaded.preventiveDraft?.finalResult
            ?? "Equipo operativo"
        additionalComments = localReport?.additionalComments
            ?? loaded.preventiveDraft?.additionalComments
            ?? ""
        sapOrder = localReport?.sapOrder ?? loaded.preventiveDraft?.sapOrder ?? loaded.sapOrder ?? ""
        selectedToolIDs = Set((localReport?.tools ?? loaded.preventiveDraft?.tools ?? []).map(\.toolID))
        let calibration = localPayload?.calibration ?? loaded.calibrationDraft
        calibrationFrequency = calibration?.frequency ?? ""
        transmitterJumpers = calibration?.transmitterJumpers ?? ""
        calibrationReceivers = calibration?.receivers.isEmpty == false
            ? calibration?.receivers ?? []
            : [
                APICalibrationReceiverWrite(
                    sequence: 1,
                    jumpers: "",
                    tca9: "",
                    railCurrent: ""
                )
            ]
        receiverCount = max(1, min(calibrationReceivers.count, 4))
        resizeCalibrationReceivers(to: receiverCount)
        selectedReceiver = min(selectedReceiver, receiverCount)
        steps = localReport?.steps
            ?? loaded.preventiveDraft?.steps
            ?? loaded.templateSteps.map { step in
                APIPreventiveStepWrite(
                    templateStepID: step.id,
                    title: step.title,
                    manualPage: step.manualPage,
                    sequence: step.sequence,
                    isCompleted: true,
                    comment: step.defaultComment,
                    tests: step.tests.map {
                        APIPreventiveTestWrite(
                            templateTestID: $0.id,
                            name: $0.name,
                            selectedResult: $0.defaultResult,
                            numericValue: nil,
                            notes: nil
                        )
                    }
                )
            }
        if let localReport {
            participants = loaded.formParticipants(
                preferredWrites: localReport.participants
            )
            evidence = localReport.evidence
        } else {
            participants = participantDrafts(from: loaded)
            evidence = loaded.evidence.map {
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
            activityID: activityID,
            payload: payload,
            editor: editor,
            activityDetail: detail,
            queueForSync: queueForSync
        )
    }

    private func resizeCalibrationReceivers(to count: Int) {
        if calibrationReceivers.count < count {
            for sequence in (calibrationReceivers.count + 1)...count {
                calibrationReceivers.append(
                    APICalibrationReceiverWrite(
                        sequence: sequence,
                        jumpers: "",
                        tca9: "",
                        railCurrent: ""
                    )
                )
            }
        } else if calibrationReceivers.count > count {
            calibrationReceivers.removeAll { $0.sequence > count }
        }
        if selectedReceiver > count {
            selectedReceiver = count
        }
    }

    @MainActor
    private func addEvidence(from items: [PhotosPickerItem]) async {
        for item in items {
            do {
                guard let sourceData = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: sourceData) else {
                    throw EvidenceImportError.invalidImage
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
            errorMessage = EvidenceImportError.invalidImage.localizedDescription
            return
        }
        evidence.append(
            APIReportEvidenceWrite(
                clientID: UUID().uuidString,
                attachmentID: nil,
                originalFileName: "evidencia-\(evidence.count + 1).jpg",
                mediaType: "image/jpeg",
                title: "Evidencia de mantenimiento",
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

    private func resultOptions(for test: APIPreventiveTestWrite) -> [String] {
        let configured = editor?.templateSteps
            .flatMap(\.tests)
            .first(where: { $0.id == test.templateTestID })?
            .resultOptions ?? []
        if configured.contains(test.selectedResult) {
            return configured
        }
        return test.selectedResult.isEmpty
            ? configured
            : [test.selectedResult] + configured
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

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private enum EvidenceImportError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        "No se pudo procesar una de las imágenes seleccionadas."
    }
}

private extension Binding where Value == String {
    init(_ source: Binding<String?>, replacingNilWith fallback: String) {
        self.init(
            get: { source.wrappedValue ?? fallback },
            set: { source.wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}
