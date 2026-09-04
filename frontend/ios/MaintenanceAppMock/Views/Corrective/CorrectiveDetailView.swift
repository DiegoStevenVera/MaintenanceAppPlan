import SwiftUI

struct CorrectiveDetailView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var activityStore: MaintenanceActivityStore
    @EnvironmentObject private var offlineStore: OfflineReportStore
    let eventID: String

    @State private var comments: [APIMaintenanceComment] = []
    @State private var commentText = ""
    @State private var isSendingComment = false
    @State private var commentError: String?

    private var downloadedDetail: APIActivityDetail? {
        offlineStore.workPackage(for: eventID)?.activityDetail
    }

    private var displayedDetail: APIActivityDetail? {
        if offlineStore.hasPendingWork(for: eventID), let downloadedDetail {
            return downloadedDetail
        }
        return activityStore.details[eventID] ?? downloadedDetail
    }

    var body: some View {
        Group {
            if let detail = displayedDetail {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        header(detail)
                        lifecycleActions(detail)
                        reportActions(detail)
                        offlineReportState
                        statusPanel(detail)
                        eventData(detail)
                        correctiveReport(detail)
                        commentsPanel
                        reportVersions(detail)
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: 900, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .refreshable {
                    guard offlineStore.isNetworkAvailable else { return }
                    await activityStore.loadDetail(id: eventID, session: session, force: true)
                    await loadComments()
                }
            } else if activityStore.loadingDetailIDs.contains(eventID) {
                ProgressView("Cargando detalle")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = activityStore.detailErrors[eventID] {
                ContentUnavailableView {
                    Label("No se pudo cargar el correctivo", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Reintentar") {
                        Task { await activityStore.loadDetail(id: eventID, session: session, force: true) }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Detalle correctivo")
        .task {
            if let downloadedDetail {
                activityStore.cacheDetail(downloadedDetail)
                await offlineStore.markWorkPackageOpened(activityID: eventID)
            }
            if offlineStore.isNetworkAvailable {
                await activityStore.loadDetail(id: eventID, session: session, force: true)
                if let detail = activityStore.details[eventID] {
                    await offlineStore.reconcileWorkPackage(with: detail)
                }
            }
            guard offlineStore.isNetworkAvailable else {
                await loadComments()
                return
            }
            await loadComments()
        }
        .onChange(of: offlineStore.lastSyncEvent?.id) { _, _ in
            guard offlineStore.lastSyncEvent?.activityID == eventID,
                  offlineStore.isNetworkAvailable else { return }
            Task {
                await activityStore.loadDetail(id: eventID, session: session, force: true)
                if let detail = activityStore.details[eventID] {
                    await offlineStore.reconcileWorkPackage(with: detail)
                }
            }
        }
    }

    private var commentsPanel: some View {
        MaintenanceCommentsPanel(
            comments: comments,
            message: $commentText,
            isSending: isSendingComment,
            errorMessage: commentError,
            title: "Comentarios del correctivo",
            subtitle: "Pertenecen únicamente a esta actividad correctiva",
            onSend: { Task { await addComment() } }
        )
    }

    @MainActor
    private func loadComments() async {
        guard offlineStore.isNetworkAvailable else {
            comments = offlineStore.workPackage(for: eventID)?.editor.comments ?? []
            return
        }
        do {
            comments = try await session.withValidAccessToken { token in
                try await reportService.comments(activityID: eventID, accessToken: token)
            }
        } catch {
            commentError = error.localizedDescription
        }
    }

    @MainActor
    private func addComment() async {
        let message = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !isSendingComment else { return }

        isSendingComment = true
        commentError = nil
        defer { isSendingComment = false }
        do {
            let comment = try await session.withValidAccessToken { token in
                try await reportService.addComment(
                    activityID: eventID,
                    message: message,
                    accessToken: token
                )
            }
            comments.append(comment)
            commentText = ""
        } catch {
            if !offlineStore.isNetworkAvailable || error.isReportConnectivityFailure {
                await offlineStore.queueComment(activityID: eventID, message: message)
                comments.append(localComment(message))
                commentText = ""
                commentError = "Comentario guardado en el iPad. Se enviará al recuperar conexión."
            } else {
                commentError = error.localizedDescription
            }
        }
    }

    private func localComment(_ message: String) -> APIMaintenanceComment {
        APIMaintenanceComment(id: "local-\(UUID().uuidString)", scope: "OFFLINE", authorUserID: session.currentUser?.id ?? "local", authorName: session.currentUser?.name ?? "Usuario", authorRole: session.currentUser?.role.label ?? "", message: message, createdAt: Date())
    }

    private var reportService: ReportAPIService {
        ReportAPIService(
            baseURLString: UserDefaults.standard.string(forKey: "apiBaseURL") ?? ""
        )
    }

    @ViewBuilder
    private func reportActions(_ detail: APIActivityDetail) -> some View {
        let latestReport = detail.reports.first

        if detail.status == "IN_PROGRESS", session.currentUser?.role != .boss {
            GlassPanel {
                ActionButtonGrid {
                    NavigationLink {
                        CorrectiveReportFormView(eventID: eventID)
                    } label: {
                        Label(
                            offlineStore.draft(for: eventID) != nil
                                ? "Seguir editando"
                                : (detail.reportVersionCount == 0 ? "Crear reporte" : "Editar reporte"),
                            systemImage: "wrench.and.screwdriver.fill"
                        )
                    }
                    .buttonStyle(ActionTileButtonStyle(prominent: true))

                    if let latestReport,
                       latestReport.documentStatus == "FINALIZED" {
                        NavigationLink {
                            PDFPreviewView(versionID: latestReport.id)
                        } label: {
                            Label("Generar PDF", systemImage: "doc.badge.plus")
                        }
                        .buttonStyle(ActionTileButtonStyle())
                    }
                }
            }
        } else if let latestReport,
                  latestReport.documentStatus == "FINALIZED" {
            GlassPanel {
                ActionButtonGrid {
                    NavigationLink {
                        PDFPreviewView(versionID: latestReport.id)
                    } label: {
                        Label("Generar PDF", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(ActionTileButtonStyle(prominent: true))
                }
            }
        }
    }

    @ViewBuilder
    private var offlineReportState: some View {
        if offlineStore.draft(for: eventID) != nil {
            GlassPanel {
                Label(
                    "Borrador del reporte protegido en este iPad.",
                    systemImage: "externaldrive.fill"
                )
                .foregroundStyle(.secondary)
                if offlineStore.isNetworkAvailable {
                    Button("Sincronizar ahora") {
                        Task {
                            await offlineStore.retry(activityID: eventID)
                            await activityStore.loadDetail(id: eventID, session: session, force: true)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func header(_ detail: APIActivityDetail) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(detail.eventCode ?? detail.internalCode)
                .font(.caption.weight(.bold))
                .foregroundStyle(BrandColor.red)
            Text(detail.title)
                .font(.system(.largeTitle, design: .rounded).weight(.black))
                .lineLimit(3)
            HStack(spacing: AppSpacing.sm) {
                APIStatusBadge(status: detail.status)
                if let severity = detail.severity {
                    Text("Severidad: \(severity)")
                        .font(.headline)
                        .foregroundStyle(severity == "HIGH" ? BrandColor.red : BrandColor.amber)
                }
            }
        }
    }

    private func statusPanel(_ detail: APIActivityDetail) -> some View {
        GlassPanel {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.title)
                    .foregroundStyle(BrandColor.red)
                    .frame(width: 52, height: 52)
                    .background(BrandColor.red.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("Evento correctivo").font(.headline)
                    Text("\(detail.reportVersionCount) versión(es) de reporte registrada(s)")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func lifecycleActions(_ detail: APIActivityDetail) -> some View {
        if let role = session.currentUser?.role,
           MaintenanceLifecycleActionPanel.hasActions(
               status: detail.status,
               role: role
           ) {
            MaintenanceLifecycleActionPanel(
                status: detail.status,
                role: role,
                completionAllowed: detail.reports.contains { $0.documentStatus == "FINALIZED" },
                isWorking: activityStore.transitioningIDs.contains(eventID),
                errorMessage: activityStore.transitionErrors[eventID],
                onClearError: {
                    activityStore.clearTransitionError(id: eventID)
                },
                onPerform: { command, reason in
                    Task {
                        if offlineStore.isNetworkAvailable {
                            await activityStore.performLifecycle(
                                id: eventID, command: command, reason: reason, session: session
                            )
                            if let updated = activityStore.details[eventID] {
                                await offlineStore.reconcileWorkPackage(with: updated)
                            }
                        } else {
                            await offlineStore.queueLifecycle(
                                activityID: eventID, command: command, reason: reason
                            )
                            activityStore.applyOfflineLifecycle(id: eventID, command: command)
                        }
                    }
                }
            )
        }
    }

    private func eventData(_ detail: APIActivityDetail) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Datos del evento", subtitle: "Contexto normalizado del aviso")
                DetailTile(title: "Sede", value: detail.site.orFallback("No registrada"))
                DetailTile(title: "Proyecto", value: detail.project.orFallback("No registrado"))
                DetailTile(title: "Etapa", value: detail.stage.orFallback("No registrada"))
                DetailTile(title: "Sistema", value: detail.system.orFallback("No registrado"))
                DetailTile(title: "Subsistema", value: detail.subsystem)
                DetailTile(
                    title: "Nombre del evento SAP",
                    value: detail.sapEventName.orFallback("No registrado")
                )
                DetailTile(
                    title: "Notificación SAP",
                    value: detail.sapNotification.orFallback("No registrada")
                )
                if let noticeCreatedAt = detail.noticeCreatedAt {
                    DetailTile(
                        title: "Fecha y hora de creación de aviso",
                        value: Self.dateFormatter.string(from: noticeCreatedAt)
                    )
                }
                if let responseAt = detail.responseAt {
                    DetailTile(
                        title: "Fecha y hora de respuesta",
                        value: Self.dateFormatter.string(from: responseAt)
                    )
                }
                DetailTile(
                    title: "Equipo / asset",
                    value: detail.affectedAssets.isEmpty
                        ? detail.assets.map(\.name).joined(separator: ", ").orFallback("No registrado")
                        : detail.affectedAssets.map(\.path).joined(separator: "\n")
                )
                if detail.isCritical {
                    DetailTile(
                        title: "Elemento crítico",
                        value: "Sí"
                    )
                }
                DetailTile(title: "Ubicacion fisica", value: detail.locationPath.orFallback("No registrada"))
                if let start = detail.actualStartAt {
                    DetailTile(title: "Inicio real", value: Self.dateFormatter.string(from: start))
                }
                if let end = detail.actualEndAt {
                    DetailTile(title: "Fin real", value: Self.dateFormatter.string(from: end))
                }
            }
        }
    }

    @ViewBuilder
    private func correctiveReport(_ detail: APIActivityDetail) -> some View {
        if let report = detail.correctiveReport {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                failurePanel(report)
                analysisPanel(report)
                activitiesPanel(report)
                validationPanel(report)
                conclusionsPanel(report)
            }
        } else {
            GlassPanel {
                SectionHeaderText(title: "Reporte correctivo", subtitle: "Aun no existe una versión normalizada para este evento")
            }
        }
    }

    private func failurePanel(_ report: APICorrectiveReport) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Descripcion de falla")
                DetailTile(title: "Sintoma registrado", value: report.symptom.orFallback("No registrado"))
                DetailTile(title: "Descripcion tecnica", value: report.technicalDescription.orFallback("No registrada"))
                DetailTile(title: "Impacto operacional", value: report.operationalImpact.orFallback("No registrado"))
            }
        }
    }

    private func analysisPanel(_ report: APICorrectiveReport) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Analisis de la falla")
                DetailTile(title: "Tipo", value: report.failureAnalysisType.orFallback("No registrado"))
            }
        }
    }

    private func activitiesPanel(_ report: APICorrectiveReport) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Actividades realizadas")
                if report.activities.isEmpty {
                    Text("No hay actividades registradas.").foregroundStyle(.secondary)
                } else {
                    ForEach(report.activities) { activity in
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text(activity.name).font(.headline)
                            Text(activity.description).font(.body)
                            HStack {
                                Label(Self.dateFormatter.string(from: activity.startedAt), systemImage: "clock")
                                Spacer()
                                if let endedAt = activity.endedAt {
                                    Text(Self.dateFormatter.string(from: endedAt))
                                }
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(AppSpacing.md)
                        .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    private func validationPanel(_ report: APICorrectiveReport) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Pruebas y validacion")
                DetailTile(title: "Pruebas funcionales", value: report.functionalTests.orFallback("No registradas"))
                DetailTile(title: "Resultado", value: report.validationResult.orFallback("No registrado"))
                DetailTile(title: "Liberacion para servicio", value: report.serviceReleased ? "Si" : "No")
                if let releasedAt = report.serviceReleasedAt {
                    DetailTile(title: "Fecha de liberacion", value: Self.dateFormatter.string(from: releasedAt))
                }
                DetailTile(title: "Responsable de validacion", value: report.validationResponsible.orFallback("No registrado"))
            }
        }
    }

    private func conclusionsPanel(_ report: APICorrectiveReport) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Conclusiones / Comentarios")
                DetailTile(title: "Estado tecnico del equipo", value: report.technicalStatus.orFallback("No registrado"))
                DetailTile(title: "Observaciones", value: report.conclusion.orFallback("No registradas"))
                if let comments = report.additionalComments, !comments.isEmpty {
                    DetailTile(title: "Comentarios adicionales", value: comments)
                }
            }
        }
    }

    private func reportVersions(_ detail: APIActivityDetail) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Versiones del reporte", subtitle: "Historial normalizado")
                if offlineStore.draft(for: eventID) != nil {
                    localDraftRow
                }
                if detail.reports.isEmpty && offlineStore.draft(for: eventID) == nil {
                    Text("Aun no hay versiones generadas.").foregroundStyle(.secondary)
                } else {
                    ForEach(detail.reports) { report in
                        NavigationLink {
                            PDFPreviewView(versionID: report.id)
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .foregroundStyle(BrandColor.red)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Version \(report.versionNumber)").font(.headline)
                                    Text(report.summary.orFallback("Reporte \(report.reportKind)"))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(report.documentStatus == "DRAFT" ? "Borrador" : report.documentStatus)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(BrandColor.green)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, AppSpacing.xs)
                    }
                }
            }
        }
    }

    private var localDraftRow: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "externaldrive.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Correctivo · Borrador local").font(.headline)
                Text("Protegido en este iPad; pendiente de sincronización")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("Borrador").font(.caption.weight(.bold)).foregroundStyle(.orange)
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es_PE")
        return formatter
    }()
}

struct CorrectiveDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CorrectiveDetailView(eventID: "event")
                .environmentObject(SessionStore())
                .environmentObject(MaintenanceActivityStore())
        }
    }
}

private extension Optional where Wrapped == String {
    func orFallback(_ fallback: String) -> String {
        guard let value = self, !value.isEmpty else { return fallback }
        return value
    }
}

private extension String {
    func orFallback(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
