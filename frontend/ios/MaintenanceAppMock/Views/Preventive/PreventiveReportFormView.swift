import SwiftUI

struct PreventiveReportFormView: View {
    @EnvironmentObject private var store: MockMaintenanceStore
    @Environment(\.dismiss) private var dismiss
    let activityID: String

    @State private var conclusion = ""
    @State private var participantDiego = true
    @State private var participantJoab = false

    private var activity: PreventiveActivity? {
        store.activities.first { $0.id == activityID }
    }

    var body: some View {
        Form {
            if let activity {
                Section("Datos generales") {
                    LabeledContent("Actividad", value: activity.name)
                    LabeledContent("Activos", value: activity.assets.joined(separator: ", "))
                    LabeledContent("Ubicacion", value: activity.location)
                    LabeledContent("Manual", value: activity.manualReference)
                }

                Section("Personal participante") {
                    Toggle("Diego Vera", isOn: $participantDiego)
                    Toggle("Joab Apaza", isOn: $participantJoab)
                }

                Section("Pasos del mantenimiento") {
                    ForEach(activity.steps) { step in
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Label(step.title, systemImage: step.isCompleted ? "checkmark.circle.fill" : "circle")
                            Button("Abrir manual pagina \(step.manualPage)") {}
                                .font(.caption)
                        }
                    }
                }

                Section("Conclusiones") {
                    TextField("Agregar conclusion u observacion", text: $conclusion, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section("Firmas") {
                    Label("Firma de Diego Vera pendiente de captura real", systemImage: "pencil.and.scribble")
                    if participantJoab {
                        Label("Firma de Joab Apaza pendiente de captura real", systemImage: "pencil.and.scribble")
                    }
                }

                Section {
                    Button("Finalizar version del reporte") {
                        store.finalizeReport(for: activity)
                        dismiss()
                    }
                    .font(.headline)
                }
            }
        }
        .navigationTitle("Reporte preventivo")
    }
}

#Preview {
    NavigationStack {
        PreventiveReportFormView(activityID: "prv-001")
            .environmentObject(MockMaintenanceStore())
    }
}

