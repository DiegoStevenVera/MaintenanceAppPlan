import SwiftUI

struct PreventiveDetailView: View {
    @EnvironmentObject private var store: MockMaintenanceStore
    let activityID: String

    private var activity: PreventiveActivity? {
        store.activities.first { $0.id == activityID }
    }

    var body: some View {
        Group {
            if let activity {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text(activity.name)
                                .font(.title2.weight(.bold))
                            StatusBadge(status: activity.status)
                        }
                        .padding(.vertical, AppSpacing.xs)
                    }

                    Section("Datos generales") {
                        LabeledContent("Activos", value: activity.assets.joined(separator: ", "))
                        LabeledContent("Ubicacion", value: activity.location)
                        LabeledContent("Subsistema", value: activity.subsystem)
                        LabeledContent("Frecuencia", value: activity.frequency)
                        LabeledContent("Duracion estimada", value: "\(activity.estimatedMinutes) min")
                        LabeledContent("Personal requerido", value: "\(activity.requiredPersonnel)")
                        LabeledContent("Manual", value: activity.manualReference)
                    }

                    Section("Herramientas") {
                        ForEach(activity.requiredTools, id: \.self) { tool in
                            Label(tool, systemImage: "wrench.adjustable")
                        }
                    }

                    Section("Versiones del reporte") {
                        if activity.reportVersions.isEmpty {
                            Text("Aun no hay versiones generadas.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(activity.reportVersions) { version in
                                NavigationLink {
                                    PDFPreviewView(activityID: activity.id, version: version)
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text("Version \(version.versionNumber)")
                                        Text("Creado por \(version.createdBy)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    Section("Acciones") {
                        actionButtons(activity)
                    }
                }
                .navigationTitle("Detalle")
            } else {
                ContentUnavailableView("Actividad no encontrada", systemImage: "exclamationmark.triangle")
            }
        }
    }

    @ViewBuilder
    private func actionButtons(_ activity: PreventiveActivity) -> some View {
        let role = store.currentUser.role

        if activity.status == .scheduled, role.canEditMaintenance {
            Button("Iniciar") {
                store.start(activity)
            }
        }

        if activity.status == .inProgress, role.canEditMaintenance {
            NavigationLink("Editar reporte") {
                PreventiveReportFormView(activityID: activity.id)
            }
            Button("Completar") {
                store.complete(activity)
            }
        }

        if activity.status == .completed {
            if role.canEditMaintenance {
                NavigationLink("Editar reporte") {
                    PreventiveReportFormView(activityID: activity.id)
                }
            }
            if let version = activity.reportVersions.first {
                NavigationLink("Compartir PDF") {
                    PDFPreviewView(activityID: activity.id, version: version)
                }
            }
            if role.canCloseMaintenance {
                Button("Cerrar") {
                    store.close(activity)
                }
            }
        }

        if activity.status == .closed, role.canCloseMaintenance {
            Button("Reabrir") {
                store.reopen(activity)
            }
        }

        if !role.canEditMaintenance {
            Text("Vista de solo lectura para Jefe.")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        PreventiveDetailView(activityID: "prv-001")
            .environmentObject(MockMaintenanceStore())
    }
}

