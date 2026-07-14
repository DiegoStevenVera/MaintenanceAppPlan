import SwiftUI

struct PreventiveReportFormView: View {
    @EnvironmentObject private var store: MockMaintenanceStore
    @Environment(\.dismiss) private var dismiss
    let activityID: String

    @State private var conclusion: PreventiveConclusion = .operational
    @State private var additionalComments = ""
    @State private var endTime = Date()
    @State private var participants: [ReportParticipantDraft] = []
    @State private var draftSteps: [MaintenanceStep] = []
    @State private var signingParticipantID: UUID?
    @State private var signatureStrokes: [UUID: [[CGPoint]]] = [:]

    private var activity: PreventiveActivity? {
        store.activities.first { $0.id == activityID }
    }

    var body: some View {
        Group {
            if let activity {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        header(activity)
                        generalData(activity)
                        toolsPanel(activity)
                        stepsPanel
                        evidencePanel
                        participantsPanel
                        conclusionsPanel
                        finalizePanel(activity)
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: 900, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .background(MaintenanceScreenBackground())
                .navigationTitle("Reporte preventivo")
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
                    if draftSteps.isEmpty {
                        draftSteps = activity.steps
                    }
                    if participants.isEmpty {
                        participants = store.defaultParticipants()
                    }
                    endTime = activity.endedAt ?? Date()
                }
            } else {
                ContentUnavailableView("Actividad no encontrada", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private func header(_ activity: PreventiveActivity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("ID: \(activity.id.uppercased())")
                .font(.caption.weight(.bold))
                .foregroundStyle(BrandColor.red)
            Text(activity.name)
                .font(.system(.largeTitle, design: .rounded).weight(.black))
            HStack(spacing: AppSpacing.sm) {
                StatusBadge(status: activity.status)
                Text(activity.subsystem)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func generalData(_ activity: PreventiveActivity) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Datos generales")
                DetailTile(title: "Actividad", value: activity.name)
                DetailTile(title: "Equipos", value: activity.assets.joined(separator: ", "))
                DetailTile(title: "Sede", value: activity.site)
                DetailTile(title: "Proyecto", value: activity.project)
                DetailTile(title: "Etapa", value: activity.stage)
                DetailTile(title: "Sistema", value: activity.system)
                DetailTile(title: "Subsistema", value: activity.subsystem)
                DetailTile(title: "Fecha", value: Self.dateFormatter.string(from: Date()))
                DetailTile(title: "Hora inicio", value: activity.startedAt.map(Self.timeFormatter.string(from:)) ?? "Pendiente de inicio")
                DatePicker("Hora fin", selection: $endTime, displayedComponents: .hourAndMinute)
                    .padding(AppSpacing.md)
                    .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                DetailTile(title: "Ubicacion", value: activity.locationPath)
                DetailTile(title: "Manual", value: activity.manualReference)
            }
        }
    }

    private var participantsPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Participantes y firmas")
                ParticipantsSignaturePanel(
                    participants: $participants,
                    signingParticipantID: $signingParticipantID,
                    signatureStrokes: $signatureStrokes
                )
            }
        }
    }

    private func toolsPanel(_ activity: PreventiveActivity) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Herramientas")
                ForEach(activity.requiredTools, id: \.self) { tool in
                    Label(tool, systemImage: "wrench.adjustable")
                        .font(.headline)
                }
            }
        }
    }

    private var stepsPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Pasos del mantenimiento")
                ForEach($draftSteps) { $step in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Toggle(step.title, isOn: $step.isCompleted)
                            .font(.headline)

                        ActionButtonGrid {
                            Button {} label: {
                                Label("Abrir manual pagina \(step.manualPage)", systemImage: "book.pages.fill")
                            }
                            .buttonStyle(ActionTileButtonStyle())
                        }

                        TextField("Comentario del paso", text: $step.comment, axis: .vertical)
                            .lineLimit(2, reservesSpace: true)
                            .padding(AppSpacing.sm)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Divider()

                        Text("Pruebas y resultados")
                            .font(.subheadline.weight(.semibold))

                        ForEach($step.tests) { $test in
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(test.name)
                                    .font(.subheadline)
                                Picker("Resultado", selection: $test.selectedResult) {
                                    ForEach(test.resultOptions, id: \.self) { option in
                                        Text(option).tag(option)
                                    }
                                }
                                .pickerStyle(.menu)
                                TextField("Nota de prueba", text: $test.notes, axis: .vertical)
                                    .lineLimit(1...2)
                                    .padding(AppSpacing.sm)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private var evidencePanel: some View {
        GlassPanel {
            Label("Agregar foto desde camara o galeria", systemImage: "camera")
                .font(.headline)
                .foregroundStyle(BrandColor.red)
        }
    }

    private var conclusionsPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Conclusiones")
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Estado final del equipo")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    Picker("Estado final del equipo", selection: $conclusion) {
                        ForEach(PreventiveConclusion.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(AppSpacing.md)
                .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Comentarios adicionales del mantenimiento")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    TextField("Comentarios adicionales del mantenimiento", text: $additionalComments, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
                .padding(AppSpacing.md)
                .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func finalizePanel(_ activity: PreventiveActivity) -> some View {
        GlassPanel {
            ActionButtonGrid {
                Button {
                    store.finalizePreventiveReport(
                        activityID: activity.id,
                        steps: draftSteps,
                        conclusion: conclusion,
                        additionalComments: additionalComments,
                        endedAt: endTime,
                        participants: participants,
                        signatureStrokes: signatureStrokes
                    )
                    dismiss()
                } label: {
                    Label("Finalizar version del reporte", systemImage: "checkmark.seal.fill")
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

struct PreventiveReportFormView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PreventiveReportFormView(activityID: "prv-001")
                .environmentObject(MockMaintenanceStore())
        }
    }
}
