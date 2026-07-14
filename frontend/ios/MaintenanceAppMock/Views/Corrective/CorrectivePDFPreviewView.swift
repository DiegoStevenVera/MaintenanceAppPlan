import SwiftUI

struct CorrectivePDFPreviewView: View {
    @EnvironmentObject private var store: MockMaintenanceStore
    let eventID: String
    let version: ReportVersion

    private var event: CorrectiveEvent? {
        store.correctiveEvents.first { $0.id == eventID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("PDF del reporte correctivo")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))

                if let event {
                    GlassPanel {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text(event.name)
                                .font(.title2.weight(.semibold))
                            Text("Version \(version.versionNumber) · \(version.createdBy)")
                            Text(version.summary)
                                .foregroundStyle(.secondary)
                            Divider()
                            Text("Evento: \(event.code)")
                            Text("SAP: \(event.sapCode)")
                            Text("Activo afectado: \(event.affectedAsset)")
                            Text("Ubicacion fisica: \(event.location)")
                            Text("Subsistema: \(event.subsystem)")
                            Text("Severidad: \(event.severity.label)")
                        }
                    }

                    GlassPanel {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Descripcion de falla e impacto")
                                .font(.headline)
                            DetailTile(title: "Sintoma registrado", value: event.symptom.isEmpty ? "Sin registro" : event.symptom)
                            DetailTile(title: "Descripcion tecnica detallada", value: event.technicalDescription.isEmpty ? event.failureDescription : event.technicalDescription)
                            DetailTile(title: "Impacto operacional", value: event.impactSelection.rawValue)
                        }
                    }

                    GlassPanel {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Analisis de la falla")
                                .font(.headline)
                            DetailTile(title: "Tipo de falla", value: event.failureAnalysis.rawValue)
                        }
                    }

                    GlassPanel {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Actividades realizadas")
                                .font(.headline)
                            ForEach(event.activities) { activity in
                                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                    Label(activity.type.label, systemImage: activity.type == .replacement ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                                        .font(.headline)
                                    Text("Inicio: \(Self.dateTimeFormatter.string(from: activity.startedAt))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if activity.type == .replacement, let replacement = activity.replacement {
                                        Text("Retira: \(replacement.removedAsset)")
                                            .font(.caption)
                                        Text("Retirado PN \(replacement.removedPartNumber) · SN \(replacement.removedSerialNumber)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("Estado retirado: \(replacement.removedCondition.rawValue) · Se enviara a \(replacement.removedDestination)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("Instala: \(replacement.installedAsset)")
                                            .font(.caption)
                                        Text("Instalado PN \(replacement.installedPartNumber) · SN \(replacement.installedSerialNumber)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("Estado instalado: \(replacement.installedCondition.rawValue) · Origen \(replacement.source)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text(activity.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("Fin: \(Self.dateTimeFormatter.string(from: activity.endedAt))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(AppSpacing.sm)
                                .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }

                    GlassPanel {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Pruebas y validacion")
                                .font(.headline)
                            DetailTile(title: "Pruebas funcionales realizadas", value: event.functionalTests.isEmpty ? "Sin registro" : event.functionalTests)
                            DetailTile(title: "Resultado", value: event.validationResult.rawValue)
                            DetailTile(title: "Liberacion para servicio", value: event.serviceRelease ? "Si" : "No")
                            DetailTile(title: "Fecha y hora de liberacion", value: Self.dateTimeFormatter.string(from: event.serviceReleaseAt))
                            DetailTile(title: "Responsable de validacion", value: event.validationResponsible.isEmpty ? "Sin registro" : event.validationResponsible)
                        }
                    }

                    GlassPanel {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Conclusiones / Comentarios")
                                .font(.headline)
                            DetailTile(title: "Estado tecnico del equipo", value: event.technicalStatus.rawValue)
                            DetailTile(title: "Observaciones / comentarios", value: event.observations.isEmpty ? "Sin observaciones" : event.observations)
                        }
                    }

                    GlassPanel {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Firmas")
                                .font(.headline)
                            ReportSignaturesPreview(signatures: store.correctiveReportSignatures[event.id] ?? [])
                        }
                    }

                    GlassPanel {
                        ActionButtonGrid {
                            ShareLink(item: store.correctivePDFShareText(event: event, version: version)) {
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

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

struct CorrectivePDFPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CorrectivePDFPreviewView(
                eventID: "cor-001",
                version: ReportVersion(id: UUID(), versionNumber: 1, createdBy: "Diego Vera", createdAt: Date())
            )
            .environmentObject(MockMaintenanceStore())
        }
    }
}
