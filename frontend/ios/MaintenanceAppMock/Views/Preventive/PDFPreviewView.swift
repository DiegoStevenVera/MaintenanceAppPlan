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
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))

                if let activity {
                    GlassPanel {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text(activity.name)
                                .font(.title2.weight(.semibold))
                            Text("Version \(version.versionNumber)")
                            Text("Creado por \(version.createdBy)")
                            Text(version.summary)
                                .foregroundStyle(.secondary)
                            Divider()
                            Text("Proyecto: \(activity.project) · \(activity.stage)")
                            Text("Sistema: \(activity.system) · \(activity.subsystem)")
                            Text("Equipos: \(activity.assets.joined(separator: ", "))")
                            Text("Ubicacion: \(activity.locationPath)")
                        }
                    }

                    GlassPanel {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Pasos, pruebas y resultados")
                                .font(.headline)
                            ForEach(activity.steps) { step in
                                VStack(alignment: .leading, spacing: 6) {
                                    Label(step.title, systemImage: step.isCompleted ? "checkmark.circle.fill" : "circle")
                                    if !step.comment.isEmpty {
                                        Text(step.comment)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    ForEach(step.tests) { test in
                                        Text("- \(test.name): \(test.selectedResult)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    GlassPanel {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Firmas")
                                .font(.headline)
                            ReportSignaturesPreview(signatures: store.preventiveReportSignatures[activity.id] ?? [])
                        }
                    }

                    GlassPanel {
                        ActionButtonGrid {
                            ShareLink(item: store.preventivePDFShareText(activity: activity, version: version)) {
                                Label("Compartir PDF", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(ActionTileButtonStyle(prominent: true))
                        }
                    }
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 860, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("PDF")
    }
}

struct PDFPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PDFPreviewView(
                activityID: "prv-002",
                version: ReportVersion(id: UUID(), versionNumber: 1, createdBy: "Diego Vera", createdAt: Date())
            )
            .environmentObject(MockMaintenanceStore())
        }
    }
}
