import SwiftUI

struct PreventiveDetailView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var activityStore: MaintenanceActivityStore
    @EnvironmentObject private var offlineStore: OfflineReportStore
    let activityID: String

    @State private var comments: [APIMaintenanceComment] = []
    @State private var commentText = ""
    @State private var isSendingComment = false
    @State private var commentError: String?
    @State private var guide: APIPreventiveGuide?
    @State private var isLoadingGuide = false
    @State private var guideError: String?
    @State private var isLoadingMoreHistory = false
    @State private var historyLoadError: String?

    private let previousReportsPageSize = 10

    private var downloadedDetail: APIActivityDetail? {
        offlineStore.workPackage(for: activityID)?.activityDetail
    }

    private var displayedDetail: APIActivityDetail? {
        if offlineStore.hasPendingWork(for: activityID), let downloadedDetail {
            return downloadedDetail
        }
        return activityStore.details[activityID] ?? downloadedDetail
    }

    var body: some View {
        Group {
            if let detail = displayedDetail {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        header(detail)
                        photoPanel(detail)
                        lifecycleActions(detail)
                        reportActions(detail)
                        offlineReportState
                        statusPanel(detail)
                        generalData(detail)
                        preventiveGuide
                        commentsPanel
                        reportVersions(detail)
                        previousReports
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: 900, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .refreshable {
                    guard offlineStore.isNetworkAvailable else { return }
                    await activityStore.loadDetail(id: activityID, session: session, force: true)
                    async let commentsTask: Void = loadComments()
                    async let guideTask: Void = loadGuide()
                    _ = await (commentsTask, guideTask)
                }
            } else if activityStore.loadingDetailIDs.contains(activityID) {
                ProgressView("Cargando detalle")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = activityStore.detailErrors[activityID] {
                ContentUnavailableView {
                    Label("No se pudo cargar el preventivo", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Reintentar") {
                        Task { await activityStore.loadDetail(id: activityID, session: session, force: true) }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Detalle preventivo")
        .task {
            if let downloadedDetail {
                activityStore.cacheDetail(downloadedDetail)
                await offlineStore.markWorkPackageOpened(activityID: activityID)
            }
            guard offlineStore.isNetworkAvailable else {
                await loadGuide()
                return
            }
            if offlineStore.isNetworkAvailable {
                await activityStore.loadDetail(id: activityID, session: session, force: true)
                if let detail = activityStore.details[activityID] {
                    await offlineStore.reconcileWorkPackage(with: detail)
                }
            }
            async let commentsTask: Void = loadComments()
            async let guideTask: Void = loadGuide()
            _ = await (commentsTask, guideTask)
        }
        .onChange(of: offlineStore.lastSyncEvent?.id) { _, _ in
            guard offlineStore.lastSyncEvent?.activityID == activityID,
                  offlineStore.isNetworkAvailable else { return }
            Task {
                await activityStore.loadDetail(id: activityID, session: session, force: true)
                if let detail = activityStore.details[activityID] {
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
            title: "Comentarios para futuras ejecuciones",
            subtitle: "Reutilizables por mantenimiento y equipo",
            onSend: { Task { await addComment() } }
        )
    }

    @MainActor
    private func loadComments() async {
        guard offlineStore.isNetworkAvailable else {
            comments = offlineStore.workPackage(for: activityID)?.editor.comments ?? []
            return
        }
        do {
            comments = try await session.withValidAccessToken { token in
                try await reportService.comments(activityID: activityID, accessToken: token)
            }
        } catch {
            commentError = error.localizedDescription
        }
    }

    @MainActor
    private func loadGuide() async {
        guard offlineStore.isNetworkAvailable else {
            if let package = offlineStore.workPackage(for: activityID) {
                guide = APIPreventiveGuide(
                    activityID: activityID,
                    templateName: nil,
                    templateSteps: package.editor.templateSteps,
                    previousReports: [],
                    previousReportsHasMore: false,
                    previousReportsOffset: 0
                )
            }
            return
        }
        guard !isLoadingGuide else { return }
        isLoadingGuide = true
        guideError = nil
        historyLoadError = nil
        defer { isLoadingGuide = false }
        do {
            guide = try await session.withValidAccessToken { token in
                try await reportService.preventiveGuide(
                    activityID: activityID,
                    accessToken: token,
                    previousReportsLimit: previousReportsPageSize,
                    previousReportsOffset: 0
                )
            }
        } catch {
            guideError = error.localizedDescription
        }
    }

    @MainActor
    private func loadMorePreviousReports() async {
        guard offlineStore.isNetworkAvailable else { return }
        guard let guide, guide.previousReportsHasMore, !isLoadingMoreHistory else {
            return
        }

        isLoadingMoreHistory = true
        historyLoadError = nil
        defer { isLoadingMoreHistory = false }

        do {
            let nextPage = try await session.withValidAccessToken { token in
                try await reportService.preventiveGuide(
                    activityID: activityID,
                    accessToken: token,
                    previousReportsLimit: previousReportsPageSize,
                    previousReportsOffset: guide.previousReports.count
                )
            }

            let existingIDs = Set(guide.previousReports.map(\.id))
            let newReports = nextPage.previousReports.filter {
                !existingIDs.contains($0.id)
            }
            self.guide = APIPreventiveGuide(
                activityID: guide.activityID,
                templateName: guide.templateName,
                templateSteps: guide.templateSteps,
                previousReports: guide.previousReports + newReports,
                previousReportsHasMore: nextPage.previousReportsHasMore,
                previousReportsOffset: nextPage.previousReportsOffset
            )
        } catch {
            historyLoadError = error.localizedDescription
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
                    activityID: activityID,
                    message: message,
                    accessToken: token
                )
            }
            comments.append(comment)
            commentText = ""
        } catch {
            if !offlineStore.isNetworkAvailable || error.isReportConnectivityFailure {
                await offlineStore.queueComment(activityID: activityID, message: message)
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
        let latestReport = detail.reports.first {
            $0.reportKind != "CALIBRATION"
        }

        if detail.status == "IN_PROGRESS", session.currentUser?.role != .boss {
            GlassPanel {
                ActionButtonGrid {
                    NavigationLink {
                        PreventiveReportFormView(activityID: activityID)
                    } label: {
                        Label(
                            offlineStore.draft(for: activityID) != nil
                                ? "Seguir editando"
                                : (detail.reportVersionCount == 0 ? "Crear reporte" : "Editar reporte"),
                            systemImage: "doc.text.fill"
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
        if offlineStore.draft(for: activityID) != nil {
            GlassPanel {
                Label(
                    "Borrador del reporte protegido en este iPad.",
                    systemImage: "externaldrive.fill"
                )
                .foregroundStyle(.secondary)
                if offlineStore.isNetworkAvailable {
                    Button("Sincronizar ahora") {
                        Task {
                            await offlineStore.retry(activityID: activityID)
                            await activityStore.loadDetail(id: activityID, session: session, force: true)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func header(_ detail: APIActivityDetail) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(detail.internalCode)
                .font(.caption.weight(.bold))
                .foregroundStyle(BrandColor.red)
            Text(detail.title)
                .font(.system(.largeTitle, design: .rounded).weight(.black))
                .lineLimit(3)
            HStack(spacing: AppSpacing.sm) {
                APIStatusBadge(status: detail.status)
                Text(detail.subsystem)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func photoPanel(_ detail: APIActivityDetail) -> some View {
        ZStack(alignment: .bottomLeading) {
            SignalMapLines()
                .stroke(BrandColor.red.opacity(0.28), lineWidth: 2)
                .padding(AppSpacing.lg)
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 104, weight: .bold))
                .foregroundStyle(BrandColor.red.opacity(0.72))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Label(detail.assets.first?.name ?? detail.subsystem, systemImage: "square.stack.3d.up.fill")
                .font(.headline)
                .foregroundStyle(BrandColor.signalInk)
                .padding(AppSpacing.sm)
                .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(AppSpacing.md)
        }
        .frame(height: 250)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityLabel("Imagen referencial del equipo del mantenimiento")
    }

    private func statusPanel(_ detail: APIActivityDetail) -> some View {
        GlassPanel {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.title)
                    .foregroundStyle(BrandColor.red)
                    .frame(width: 52, height: 52)
                    .background(BrandColor.red.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estado del mantenimiento")
                        .font(.headline)
                    Text("\(statusDescription(detail.status)) · \(detail.reportVersionCount) versión(es) de reporte")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                isWorking: activityStore.transitioningIDs.contains(activityID),
                errorMessage: activityStore.transitionErrors[activityID],
                onClearError: {
                    activityStore.clearTransitionError(id: activityID)
                },
                onPerform: { command, reason in
                    Task {
                        if offlineStore.isNetworkAvailable {
                            await activityStore.performLifecycle(
                                id: activityID, command: command, reason: reason, session: session
                            )
                            if let updated = activityStore.details[activityID] {
                                await offlineStore.reconcileWorkPackage(with: updated)
                            }
                        } else {
                            await offlineStore.queueLifecycle(
                                activityID: activityID, command: command, reason: reason
                            )
                            activityStore.applyOfflineLifecycle(id: activityID, command: command)
                        }
                    }
                }
            )
        }
    }

    private func generalData(_ detail: APIActivityDetail) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Datos generales", subtitle: "Contexto normalizado del mantenimiento")
                DetailTile(title: "Equipos", value: detail.assets.map(\.name).joined(separator: ", ").orFallback("Sin equipo relacionado"))
                DetailTile(title: "Sede", value: detail.site.orFallback("No registrada"))
                DetailTile(title: "Proyecto", value: detail.project.orFallback("No registrado"))
                DetailTile(title: "Etapa", value: detail.stage.orFallback("No registrada"))
                DetailTile(title: "Sistema", value: detail.system.orFallback("No registrado"))
                DetailTile(title: "Subsistema", value: detail.subsystem)
                DetailTile(title: "Ubicacion fisica", value: detail.locationPath.orFallback("No registrada"))
                if let scheduledAt = detail.scheduledAt {
                    DetailTile(title: "Programado", value: Self.dateTimeFormatter.string(from: scheduledAt))
                }
                if let startedAt = detail.actualStartAt {
                    DetailTile(title: "Inicio real", value: Self.dateTimeFormatter.string(from: startedAt))
                }
                if let endedAt = detail.actualEndAt {
                    DetailTile(title: "Fin real", value: Self.dateTimeFormatter.string(from: endedAt))
                }
            }
        }
    }

    private func reportVersions(_ detail: APIActivityDetail) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Versiones del reporte",
                    subtitle: "Versiones vinculadas a esta actividad programada"
                )
                if offlineStore.draft(for: activityID) != nil {
                    localDraftRow
                }
                if detail.reports.isEmpty && offlineStore.draft(for: activityID) == nil {
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
                                    Text(
                                        report.reportKind == "CALIBRATION"
                                            ? "Calibración · Versión \(report.versionNumber)"
                                            : "Preventivo · Versión \(report.versionNumber)"
                                    )
                                    .font(.headline)
                                    Text(report.summary.orFallback("Reporte \(report.reportKind)"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
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
                Text("Preventivo · Borrador local").font(.headline)
                Text("Protegido en este iPad; pendiente de sincronización")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("Borrador").font(.caption.weight(.bold)).foregroundStyle(.orange)
        }
        .padding(.vertical, AppSpacing.xs)
    }

    @ViewBuilder
    private var preventiveGuide: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Pasos y pruebas",
                    subtitle: guide?.templateName
                        ?? "Guia del procedimiento antes de iniciar el mantenimiento"
                )

                if isLoadingGuide, guide == nil {
                    ProgressView("Cargando guia")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let guideError {
                    Label(guideError, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Reintentar") {
                        Task { await loadGuide() }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } else if let steps = guide?.templateSteps, !steps.isEmpty {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        guideStep(step, number: index + 1)
                    }
                } else {
                    Text("Este tipo de mantenimiento aun no tiene pasos configurados.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func guideStep(_ step: APITemplateStep, number: Int) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Text("\(number)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(BrandColor.red, in: Circle())
                    .accessibilityLabel("Paso \(number)")
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(.headline)
                    if let page = step.manualPage {
                        Label("Manual, pagina \(page)", systemImage: "book.closed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if let instruction = step.defaultComment, !instruction.isEmpty {
                Text(instruction)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(step.tests) { test in
                VStack(alignment: .leading, spacing: 4) {
                    Label(test.name, systemImage: "checklist")
                        .font(.subheadline.weight(.semibold))
                    if !test.resultOptions.isEmpty {
                        Text("Resultados posibles: \(test.resultOptions.joined(separator: " / "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.sm)
                .background(
                    .background.opacity(0.72),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
            }
        }
        .padding(AppSpacing.md)
        .background(
            .background.opacity(0.72),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    private var previousReports: some View {
        ContentGlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Reportes anteriores",
                    subtitle: "Historico del mismo mantenimiento y equipo"
                )

                if isLoadingGuide, guide == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let reports = guide?.previousReports, !reports.isEmpty {
                    GlassEffectContainer(spacing: AppSpacing.sm) {
                        LazyVStack(alignment: .leading, spacing: AppSpacing.sm) {
                            ForEach(reports) { report in
                                NavigationLink {
                                    PDFPreviewView(versionID: report.versionID)
                                } label: {
                                    previousReportRow(report)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if let historyLoadError {
                        Label(historyLoadError, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(BrandColor.red)
                    }

                    if guide?.previousReportsHasMore == true {
                        Button {
                            Task { await loadMorePreviousReports() }
                        } label: {
                            if isLoadingMoreHistory {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label("Mostrar más reportes", systemImage: "ellipsis.circle")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(ActionTileButtonStyle())
                        .disabled(isLoadingMoreHistory)
                    }
                } else {
                    Text("Aun no hay reportes anteriores para este mantenimiento y equipo.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func previousReportRow(_ report: APIPreventiveHistoryReport) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.headline)
                .foregroundStyle(BrandColor.red)
                .frame(width: 42, height: 42)
                .background(
                    BrandColor.red.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(report.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(report.equipmentNames.joined(separator: ", ").orFallback("Equipo no registrado"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let result = report.finalResult, !result.isEmpty {
                    Text(result)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandColor.green)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(Self.historyDateFormatter.string(from: report.performedAt))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("Version \(report.versionNumber)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(
            .background.opacity(0.60),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .glassEffect(
            .regular.tint(BrandColor.red.opacity(0.025)).interactive(),
            in: .rect(cornerRadius: 12)
        )
        .contentShape(Rectangle())
    }

    private func statusDescription(_ status: String) -> String {
        switch status {
        case "SCHEDULED": return "Programado"
        case "IN_PROGRESS": return "En progreso"
        case "COMPLETED": return "Completado"
        case "CLOSED": return "Cerrado"
        default: return status
        }
    }

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es_PE")
        return formatter
    }()

    private static let historyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "es_PE")
        return formatter
    }()
}

struct PreventiveDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PreventiveDetailView(activityID: "activity")
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
