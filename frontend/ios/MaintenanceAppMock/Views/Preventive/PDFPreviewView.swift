import SwiftUI

struct PDFPreviewView: View {
    @EnvironmentObject private var store: MockMaintenanceStore
    let activityID: String
    let version: ReportVersion

    private var activity: PreventiveActivity? {
        store.activities.first { $0.id == activityID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Vista previa PDF")
                    .font(.largeTitle.weight(.bold))

                if let activity {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(activity.name)
                            .font(.title2.weight(.semibold))
                        Text("Version \(version.versionNumber)")
                        Text("Creado por \(version.createdBy)")
                        Divider()
                        Text("Activos: \(activity.assets.joined(separator: ", "))")
                        Text("Ubicacion: \(activity.location)")
                        Text("Subsistema: \(activity.subsystem)")
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Resumen de pasos")
                            .font(.headline)
                        ForEach(activity.steps) { step in
                            Label(step.title, systemImage: step.isCompleted ? "checkmark.circle.fill" : "circle")
                        }
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Firmas")
                            .font(.headline)
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.secondary, style: StrokeStyle(lineWidth: 1, dash: [6]))
                            .frame(height: 96)
                            .overlay(Text("Firma digitalizada"))
                    }

                    Button("Compartir PDF") {}
                        .buttonStyle(.borderedProminent)
                        .tint(BrandColor.red)
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("PDF")
    }
}

#Preview {
    NavigationStack {
        PDFPreviewView(
            activityID: "prv-002",
            version: ReportVersion(id: UUID(), versionNumber: 1, createdBy: "Diego Vera", createdAt: Date())
        )
        .environmentObject(MockMaintenanceStore())
    }
}

