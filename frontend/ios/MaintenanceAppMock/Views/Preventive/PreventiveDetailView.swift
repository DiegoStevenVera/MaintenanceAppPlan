import SwiftUI

struct PreventiveDetailView: View {
    @EnvironmentObject private var store: MockMaintenanceStore
    let activityID: String
    @State private var newComment = ""

    private var activity: PreventiveActivity? {
        store.activities.first { $0.id == activityID }
    }

    var body: some View {
        Group {
            if let activity {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        header(activity)
                        EquipmentPhotoPanel(activity: activity)
                        actions(activity)
                        locationDetails(activity)
                        tools(activity)
                        currentReportVersions(activity)
                        previousReports(activity)
                        reusableComments(activity)
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: 900, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .background(MaintenanceScreenBackground())
                .navigationTitle("Detalle")
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
                .lineLimit(3)
            HStack(spacing: AppSpacing.sm) {
                StatusBadge(status: activity.status)
                Text(activity.subsystem)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.secondary)
                Text(activity.frequency)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func locationDetails(_ activity: PreventiveActivity) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "location.circle")
                        .font(.title2)
                        .foregroundStyle(BrandColor.red)
                    Text("Datos generales")
                        .font(.title3.weight(.bold))
                }

                DetailTile(title: "Equipos", value: activity.assets.joined(separator: ", "))
                DetailTile(title: "Ubicacion", value: activity.locationPath)
                DetailTile(title: "Duracion estimada", value: "\(activity.estimatedMinutes) min")
                DetailTile(title: "Personal requerido", value: "\(activity.requiredPersonnel)")
                DetailTile(title: "Manual", value: activity.manualReference)
            }
        }
    }

    private func tools(_ activity: PreventiveActivity) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Herramientas", subtitle: "Requeridas para este mantenimiento")
                ForEach(activity.requiredTools, id: \.self) { tool in
                    Label(tool, systemImage: "wrench.adjustable")
                        .font(.headline)
                }
            }
        }
    }

    private func currentReportVersions(_ activity: PreventiveActivity) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Versiones del reporte", subtitle: "Versiones del reporte actual")
                if activity.reportVersions.isEmpty {
                    Text("Aun no hay versiones generadas.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(activity.reportVersions) { version in
                        NavigationLink {
                            PDFPreviewView(activityID: activity.id, version: version)
                        } label: {
                            ReportVersionRow(version: version)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func previousReports(_ activity: PreventiveActivity) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Reportes anteriores", subtitle: "Historico de mantenimientos del equipo grande")
                let reports = store.previousReports(for: activity)
                if reports.isEmpty {
                    Text("Aun no hay reportes anteriores para este equipo.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(reports) { report in
                        NavigationLink {
                            HistoricalPDFPreviewView(report: report)
                        } label: {
                            HistoricalReportRow(report: report)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func reusableComments(_ activity: PreventiveActivity) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Comentarios para futuras ejecuciones", subtitle: "Notas reutilizables por mantenimiento o equipo")
                let comments = store.comments(for: activity)
                if comments.isEmpty {
                    Text("Aun no hay comentarios reutilizables para este mantenimiento o equipo.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(comments) { comment in
                        MaintenanceCommentBubble(comment: comment)
                    }
                }

                if store.currentUser.role.canEditMaintenance {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        TextField("Escribir comentario para futuros mantenimientos", text: $newComment, axis: .vertical)
                            .lineLimit(2, reservesSpace: true)
                            .padding(AppSpacing.sm)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        ActionButtonGrid {
                            Button {
                                store.addComment(to: activity, message: newComment)
                                newComment = ""
                            } label: {
                                Label("Guardar comentario", systemImage: "text.bubble.fill")
                            }
                            .buttonStyle(ActionTileButtonStyle())
                            .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
        }
    }

    private func actions(_ activity: PreventiveActivity) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Acciones")
                ActionButtonGrid {
                    actionButtons(activity)
                }
            }
        }
    }

    @ViewBuilder
    private func actionButtons(_ activity: PreventiveActivity) -> some View {
        let role = store.currentUser.role

        if activity.status == .scheduled, role.canEditMaintenance {
            Button {
                store.start(activity)
            } label: {
                Label("Iniciar", systemImage: "play.fill")
            }
            .buttonStyle(ActionTileButtonStyle(prominent: true))
        }

        if activity.status == .inProgress, role.canEditMaintenance {
            NavigationLink {
                PreventiveReportFormView(activityID: activity.id)
            } label: {
                Label("Editar reporte", systemImage: "square.and.pencil")
            }
            .buttonStyle(ActionTileButtonStyle(prominent: true))
            Button {
                store.complete(activity)
            } label: {
                Label("Completar", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(ActionTileButtonStyle())
        }

        if activity.status == .completed {
            if role.canEditMaintenance {
                Button {
                    store.reopen(activity)
                } label: {
                    Label("Reabrir", systemImage: "arrow.uturn.backward.circle.fill")
                }
                .buttonStyle(ActionTileButtonStyle(prominent: true))
            }
            if let version = activity.reportVersions.first {
                NavigationLink {
                    PDFPreviewView(activityID: activity.id, version: version)
                } label: {
                    Label("Compartir PDF", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(ActionTileButtonStyle())
            }
            if role.canCloseMaintenance {
                Button {
                    store.close(activity)
                } label: {
                    Label("Cerrar", systemImage: "lock.fill")
                }
                .buttonStyle(ActionTileButtonStyle())
            }
        }

        if activity.status == .closed, role.canCloseMaintenance {
            Button {
                store.reopen(activity)
            } label: {
                Label("Reabrir", systemImage: "lock.open.fill")
            }
            .buttonStyle(ActionTileButtonStyle(prominent: true))
        }

        if !role.canEditMaintenance {
            Text("Vista de solo lectura para Jefe.")
                .foregroundStyle(.secondary)
        }
    }
}

private struct ReportVersionRow: View {
    let version: ReportVersion

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Version \(version.versionNumber)")
                    .font(.headline)
                Text("Creado por \(version.createdBy)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "doc.richtext")
                .foregroundStyle(BrandColor.red)
        }
        .padding(.vertical, AppSpacing.xs)
    }
}

private struct HistoricalReportRow: View {
    let report: HistoricalMaintenanceReport

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(report.activityName)
                    .font(.headline)
                Text("Ingeniero de Mantenimiento: \(report.technicianName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(report.result)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandColor.red)
            }
            Spacer()
            Text(Self.dateFormatter.string(from: report.performedAt))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.md)
        .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

private struct MaintenanceCommentBubble: View {
    let comment: MaintenanceComment

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: comment.author.avatarSystemImage)
                .font(.title2)
                .foregroundStyle(BrandColor.red)
                .frame(width: 36, height: 36)
                .background(BrandColor.red.opacity(0.10))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.author.name)
                        .font(.subheadline.weight(.semibold))
                    Text(comment.author.role.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(comment.message)
                    .font(.body)
                Text(comment.scopeDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(AppSpacing.sm)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.vertical, 4)
    }
}

struct HistoricalPDFPreviewView: View {
    @EnvironmentObject private var store: MockMaintenanceStore
    let report: HistoricalMaintenanceReport

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Vista previa PDF")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))

                GlassPanel {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        SectionHeaderText(title: report.activityName, subtitle: "Reporte anterior")
                        DetailTile(title: "Equipo", value: report.equipmentName)
                        DetailTile(title: "Ingeniero de Mantenimiento", value: report.technicianName)
                        DetailTile(title: "Fecha", value: Self.dateFormatter.string(from: report.performedAt))
                        DetailTile(title: "Resultado", value: report.result)
                    }
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Pasos, pruebas y resultados")
                            .font(.headline)
                        ForEach(report.steps) { step in
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
                        ReportSignaturesPreview(signatures: report.participants)
                    }
                }

                GlassPanel {
                    ActionButtonGrid {
                        ShareLink(item: store.historicalPDFShareText(report: report)) {
                            Label("Compartir PDF", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(ActionTileButtonStyle(prominent: true))
                    }
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("PDF anterior")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

struct PreventiveDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PreventiveDetailView(activityID: "prv-001")
                .environmentObject(MockMaintenanceStore())
        }
    }
}
