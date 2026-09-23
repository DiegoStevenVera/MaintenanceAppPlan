import SwiftUI

private enum CorrectiveDetailSection: Int, Identifiable {
    case event
    case failure
    case analysis
    case activities
    case validation
    case conclusions
    case comments
    case versions

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .event: "Datos del evento"
        case .failure: "Descripción de falla"
        case .analysis: "Análisis de falla"
        case .activities: "Actividades realizadas"
        case .validation: "Pruebas y validación"
        case .conclusions: "Conclusiones y comentarios"
        case .comments: "Comentarios internos"
        case .versions: "Versiones del reporte"
        }
    }

    var systemImage: String {
        switch self {
        case .event: "doc.text.fill"
        case .failure: "exclamationmark.bubble.fill"
        case .analysis: "waveform.path.ecg"
        case .activities: "wrench.and.screwdriver.fill"
        case .validation: "checkmark.seal.fill"
        case .conclusions: "text.bubble.fill"
        case .comments: "bubble.left.and.bubble.right.fill"
        case .versions: "doc.text.magnifyingglass"
        }
    }
}

struct CorrectiveDetailView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var activityStore: MaintenanceActivityStore
    @EnvironmentObject private var offlineStore: OfflineReportStore
    let eventID: String

    @State private var comments: [APIMaintenanceComment] = []
    @State private var commentText = ""
    @State private var isSendingComment = false
    @State private var commentError: String?
    @State private var selectedSection = CorrectiveDetailSection.event

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
                    LazyVStack(
                        alignment: .leading,
                        spacing: AppSpacing.md,
                        pinnedViews: [.sectionHeaders]
                    ) {
                        detailHeader(detail)
                        offlineReportState
                        Section {
                            selectedSectionContent(detail)
                        } header: {
                            sectionSelector(detail)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                        }
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: 1_420, alignment: .leading)
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
        .navigationTitle("")
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
        .onChange(of: displayedDetail?.reports.map(\.documentStatus)) { _, _ in
            guard let detail = displayedDetail,
                  availableSections(for: detail).contains(selectedSection) else {
                selectedSection = .event
                return
            }
        }
    }

    private func availableSections(for detail: APIActivityDetail) -> [CorrectiveDetailSection] {
        var sections: [CorrectiveDetailSection] = [.event]
        if hasFinalizedReport(detail) {
            sections += [.failure, .analysis, .activities, .validation, .conclusions]
        }
        sections += [.comments, .versions]
        return sections
    }

    private func hasFinalizedReport(_ detail: APIActivityDetail) -> Bool {
        detail.correctiveReport != nil
            && detail.reports.contains { $0.documentStatus == "FINALIZED" }
    }

    private func detailHeader(_ detail: APIActivityDetail) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: AppSpacing.xl) {
                maintenanceIdentity(detail)
                    .layoutPriority(1)
                Spacer(minLength: AppSpacing.lg)
                detailActions(detail)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                maintenanceIdentity(detail)
                detailActions(detail)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func maintenanceIdentity(_ detail: APIActivityDetail) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(detail.title)
                .font(.system(.title, design: .rounded).weight(.black))
                .lineLimit(2)
            HStack(spacing: AppSpacing.sm) {
                APIStatusBadge(status: detail.status)
                Text(detail.subsystem)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                if let severity = detail.severity {
                    Text("Severidad: \(severity)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(severity == "HIGH" ? BrandColor.red : BrandColor.amber)
                }
            }
        }
    }

    private func detailActions(_ detail: APIActivityDetail) -> some View {
        HStack(spacing: AppSpacing.sm) {
            reportActions(detail, isCompact: true)
            lifecycleActions(detail, presentation: .compact)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func sectionSelector(_ detail: APIActivityDetail) -> some View {
        let sections = availableSections(for: detail)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    Button {
                        withAnimation(.snappy) { selectedSection = section }
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: section.systemImage)
                            Text(section.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selectedSection == section ? BrandColor.red : .primary)
                        .frame(minWidth: 185, minHeight: 48)
                        .padding(.horizontal, AppSpacing.sm)
                        .background(
                            selectedSection == section ? BrandColor.red.opacity(0.08) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay {
                            if selectedSection == section {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(BrandColor.red.opacity(0.45), lineWidth: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Sección \(index + 1), \(section.title)")

                    if section != sections.last { Divider().frame(height: 26) }
                }
            }
            .padding(4)
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(BrandColor.glassStroke, lineWidth: 1)
        }
        .sensoryFeedback(.selection, trigger: selectedSection)
    }

    @ViewBuilder
    private func selectedSectionContent(_ detail: APIActivityDetail) -> some View {
        switch selectedSection {
        case .event:
            eventSection(detail)
        case .failure:
            if let report = detail.correctiveReport { failurePanel(report) }
        case .analysis:
            if let report = detail.correctiveReport { analysisPanel(report) }
        case .activities:
            if let report = detail.correctiveReport { activitiesPanel(report) }
        case .validation:
            if let report = detail.correctiveReport { validationPanel(report) }
        case .conclusions:
            if let report = detail.correctiveReport { conclusionsPanel(report) }
        case .comments:
            commentsPanel
        case .versions:
            reportVersions(detail)
        }
    }

    private func eventSection(_ detail: APIActivityDetail) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                eventData(detail)
                    .frame(minWidth: 680, maxWidth: .infinity, alignment: .topLeading)
                    .layoutPriority(3)
                VStack(spacing: AppSpacing.md) {
                    maintenanceStatusTimeline(detail)
                    statusPanel(detail)
                }
                .frame(minWidth: 380, maxWidth: 520, alignment: .top)
                .layoutPriority(2)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                eventData(detail)
                maintenanceStatusTimeline(detail)
                statusPanel(detail)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
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
    private func reportActions(
        _ detail: APIActivityDetail,
        isCompact: Bool = false
    ) -> some View {
        let latestReport = detail.reports.first

        if detail.status == "IN_PROGRESS", session.currentUser?.role != .boss {
            if isCompact {
                compactReportActions(detail, latestReport: latestReport)
            } else {
                GlassPanel {
                    standardReportActions(detail, latestReport: latestReport)
                }
            }
        } else if let latestReport,
                  latestReport.documentStatus == "FINALIZED" {
            if isCompact {
                compactFinalizedReportButton(latestReport)
            } else {
                GlassPanel {
                    finalizedReportButton(latestReport, prominent: true)
                }
            }
        }
    }

    private func compactReportActions(
        _ detail: APIActivityDetail,
        latestReport: APIReportVersion?
    ) -> some View {
        HStack(spacing: AppSpacing.sm) {
            NavigationLink {
                CorrectiveReportFormView(eventID: eventID)
            } label: {
                Label(reportActionTitle(detail), systemImage: "wrench.and.screwdriver.fill")
            }
            .buttonStyle(CompactActionButtonStyle(prominent: true))

            if let latestReport, latestReport.documentStatus == "FINALIZED" {
                compactFinalizedReportButton(latestReport)
            }
        }
    }

    private func standardReportActions(
        _ detail: APIActivityDetail,
        latestReport: APIReportVersion?
    ) -> some View {
        ActionButtonGrid {
            NavigationLink {
                CorrectiveReportFormView(eventID: eventID)
            } label: {
                Label(reportActionTitle(detail), systemImage: "wrench.and.screwdriver.fill")
            }
            .buttonStyle(ActionTileButtonStyle(prominent: true))

            if let latestReport, latestReport.documentStatus == "FINALIZED" {
                finalizedReportButton(latestReport)
            }
        }
    }

    private func reportActionTitle(_ detail: APIActivityDetail) -> String {
        if offlineStore.draft(for: eventID) != nil { return "Seguir editando" }
        return detail.reportVersionCount == 0 ? "Crear reporte" : "Editar reporte"
    }

    private func finalizedReportButton(
        _ report: APIReportVersion,
        prominent: Bool = false
    ) -> some View {
        NavigationLink {
            PDFPreviewView(versionID: report.id)
        } label: {
            Label("Generar PDF", systemImage: "doc.badge.plus")
        }
        .buttonStyle(ActionTileButtonStyle(prominent: prominent))
    }

    private func compactFinalizedReportButton(_ report: APIReportVersion) -> some View {
        NavigationLink {
            PDFPreviewView(versionID: report.id)
        } label: {
            Label("Generar PDF", systemImage: "doc.badge.plus")
        }
        .buttonStyle(CompactActionButtonStyle())
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
    private func lifecycleActions(
        _ detail: APIActivityDetail,
        presentation: MaintenanceLifecycleActionPanel.Presentation = .panel
    ) -> some View {
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
                },
                presentation: presentation
            )
        }
    }

    private func maintenanceStatusTimeline(_ detail: APIActivityDetail) -> some View {
        let stages = [
            (status: "SCHEDULED", title: "Programado"),
            (status: "IN_PROGRESS", title: "En progreso"),
            (status: "COMPLETED", title: "Completado"),
            (status: "CLOSED", title: "Cerrado")
        ]
        let currentIndex = stages.firstIndex { $0.status == detail.status } ?? 0

        return GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.title2)
                        .foregroundStyle(BrandColor.red)
                        .frame(width: 46, height: 46)
                        .background(BrandColor.red.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Estado del correctivo").font(.headline)
                        APIStatusBadge(status: detail.status)
                    }
                    Spacer()
                    Text("\(currentIndex + 1) de \(stages.count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.22))
                        .frame(height: 2)
                        .padding(.horizontal, 48)
                        .padding(.top, 14)
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                            let isCurrent = index == currentIndex
                            let isReached = index <= currentIndex
                            VStack(spacing: AppSpacing.xs) {
                                Image(systemName: isReached ? "checkmark" : "circle.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(isReached ? Color.white : Color.secondary.opacity(0.55))
                                    .frame(width: 30, height: 30)
                                    .background(
                                        isCurrent ? BrandColor.red : (isReached ? BrandColor.green : Color.secondary.opacity(0.14)),
                                        in: Circle()
                                    )
                                    .overlay {
                                        if isCurrent {
                                            Circle().stroke(BrandColor.red.opacity(0.22), lineWidth: 6)
                                        }
                                    }
                                Text(stage.title)
                                    .font(.caption.weight(isCurrent ? .bold : .medium))
                                    .foregroundStyle(isCurrent ? BrandColor.red : .secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func eventData(_ detail: APIActivityDetail) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Datos del evento", subtitle: "Contexto normalizado del aviso")
                MaintenanceFieldGrid {
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
                        DetailTile(title: "Elemento crítico", value: "Sí")
                    }
                    DetailTile(
                        title: "Ubicación física",
                        value: detail.locationPath.orFallback("No registrada")
                    )
                    if let start = detail.actualStartAt {
                        DetailTile(title: "Inicio real", value: Self.dateFormatter.string(from: start))
                    }
                    if let end = detail.actualEndAt {
                        DetailTile(title: "Fin real", value: Self.dateFormatter.string(from: end))
                    }
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
