import SwiftUI

struct CorrectiveDetailView: View {
    @EnvironmentObject private var store: MockMaintenanceStore
    let eventID: String
    @State private var newComment = ""

    private var event: CorrectiveEvent? {
        store.correctiveEvents.first { $0.id == eventID }
    }

    var body: some View {
        Group {
            if let event {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        header(event)
                        actions(event)
                        eventData(event)
                        failureDescription(event)
                        activities(event)
                        timeline(event)
                        comments(event)
                        reportVersions(event)
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: 900, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .background(MaintenanceScreenBackground())
                .navigationTitle("Detalle correctivo")
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
            Text(event.name)
                .font(.system(.largeTitle, design: .rounded).weight(.black))
            HStack(spacing: AppSpacing.sm) {
                StatusBadge(status: event.status)
                Text("Severidad: \(event.severity.label)")
                    .font(.headline)
                    .foregroundStyle(event.severity.color)
            }
        }
    }

    private func eventData(_ event: CorrectiveEvent) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Datos del evento")
                DetailTile(title: "Sede", value: event.site)
                DetailTile(title: "Proyecto", value: event.project)
                DetailTile(title: "Etapa", value: event.stage)
                DetailTile(title: "Sistema", value: event.system)
                DetailTile(title: "Codigo", value: event.code)
                DetailTile(title: "SAP", value: event.sapCode)
                DetailTile(title: "Activo", value: event.affectedAsset)
                DetailTile(title: "Ubicacion", value: event.location)
                DetailTile(title: "Subsistema", value: event.subsystem)
                DetailTile(title: "Creacion de aviso", value: Self.dateTimeFormatter.string(from: event.noticeCreatedAt))
                DetailTile(title: "Respuesta", value: Self.dateTimeFormatter.string(from: event.responseAt))
                DetailTile(title: "Impacto", value: event.operationalImpact)
            }
        }
    }

    private func failureDescription(_ event: CorrectiveEvent) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Descripcion de falla")
                Text(event.failureDescription)
                    .font(.headline)
            }
        }
    }

    private func activities(_ event: CorrectiveEvent) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Actividades realizadas")
                if event.activities.isEmpty {
                    Text("Aun no hay actividades registradas.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(event.activities) { activity in
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(activity.type.label)
                                .font(.headline)
                            Text(activity.description)
                            if let replacement = activity.replacement {
                                Text("\(replacement.removedAsset) -> \(replacement.installedAsset)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    private func timeline(_ event: CorrectiveEvent) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Timeline")
                ForEach(event.timeline) { entry in
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        Circle()
                            .fill(BrandColor.red)
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.timestamp)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text(entry.text)
                                .font(.headline)
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private func reportVersions(_ event: CorrectiveEvent) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Versiones del reporte")
                if event.reportVersions.isEmpty {
                    Text("Aun no hay versiones generadas.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(event.reportVersions) { version in
                        NavigationLink {
                            CorrectivePDFPreviewView(eventID: event.id, version: version)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Version \(version.versionNumber)")
                                        .font(.headline)
                                    Text(version.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "doc.richtext")
                                    .foregroundStyle(BrandColor.red)
                            }
                            .padding(.vertical, AppSpacing.xs)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func comments(_ event: CorrectiveEvent) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Comentarios del correctivo", subtitle: "Notas asociadas solo a este evento")
                let comments = store.comments(for: event)
                if comments.isEmpty {
                    Text("Aun no hay comentarios para este correctivo.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(comments) { comment in
                        CorrectiveCommentBubble(comment: comment, eventCode: event.code)
                    }
                }

                if store.currentUser.role.canEditMaintenance {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        TextField("Escribir comentario de este correctivo", text: $newComment, axis: .vertical)
                            .lineLimit(2, reservesSpace: true)
                            .padding(AppSpacing.sm)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        ActionButtonGrid {
                            Button {
                                store.addComment(to: event, message: newComment)
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

    private func actions(_ event: CorrectiveEvent) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Acciones")
                ActionButtonGrid {
                    actionButtons(event)
                }
            }
        }
    }

    @ViewBuilder
    private func actionButtons(_ event: CorrectiveEvent) -> some View {
        let role = store.currentUser.role

        if event.status == .scheduled, role.canEditMaintenance {
            Button {
                store.start(event)
            } label: {
                Label("Iniciar", systemImage: "play.fill")
            }
            .buttonStyle(ActionTileButtonStyle(prominent: true))
        }

        if event.status == .inProgress, role.canEditMaintenance {
            NavigationLink {
                CorrectiveReportFormView(eventID: event.id)
            } label: {
                Label(event.reportVersions.isEmpty ? "Crear reporte" : "Editar reporte", systemImage: "square.and.pencil")
            }
            .buttonStyle(ActionTileButtonStyle(prominent: true))
        }

        if event.status == .inProgress, role.canEditMaintenance {
            Button {
                store.complete(event)
            } label: {
                Label("Completar", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(ActionTileButtonStyle())
        }

        if event.status == .completed {
            if role.canEditMaintenance {
                Button {
                    store.reopen(event)
                } label: {
                    Label("Reabrir", systemImage: "arrow.uturn.backward.circle.fill")
                }
                .buttonStyle(ActionTileButtonStyle(prominent: true))
            }
            if let version = event.reportVersions.first {
                NavigationLink {
                    CorrectivePDFPreviewView(eventID: event.id, version: version)
                } label: {
                    Label("Compartir PDF", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(ActionTileButtonStyle())
            }
            if role.canCloseMaintenance {
                Button {
                    store.close(event)
                } label: {
                    Label("Cerrar", systemImage: "lock.fill")
                }
                .buttonStyle(ActionTileButtonStyle())
            }
        }

        if event.status == .closed, role.canCloseMaintenance {
            Button {
                store.reopen(event)
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

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct CorrectiveCommentBubble: View {
    let comment: CorrectiveComment
    let eventCode: String

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
                Text("Comentario asociado a \(eventCode)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(AppSpacing.sm)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.vertical, 4)
    }
}

struct CorrectiveDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CorrectiveDetailView(eventID: "cor-001")
                .environmentObject(MockMaintenanceStore())
        }
    }
}
