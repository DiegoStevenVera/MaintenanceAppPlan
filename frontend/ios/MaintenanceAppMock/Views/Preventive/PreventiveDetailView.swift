import SwiftUI

private enum PreventiveDetailSection: Int, CaseIterable, Identifiable {
    case general
    case checklist
    case steps
    case comments
    case versions
    case previousReports

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .general: "Datos generales"
        case .checklist: "Checklist"
        case .steps: "Pasos"
        case .comments: "Comentarios"
        case .versions: "Versiones"
        case .previousReports: "Reportes anteriores"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "doc.text.fill"
        case .checklist: "checklist.checked"
        case .steps: "list.number"
        case .comments: "bubble.left.and.bubble.right.fill"
        case .versions: "doc.text.magnifyingglass"
        case .previousReports: "clock.arrow.circlepath"
        }
    }
}

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
    @State private var previousReportsPage = 0
    @State private var previousReportPages: [Int: [APIPreventiveHistoryReport]] = [:]
    @State private var previousReportsResolvedTotal: Int?
    @State private var selectedSection = PreventiveDetailSection.general

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
                            sectionSelector
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let downloadedDetail {
                activityStore.cacheDetail(downloadedDetail)
                await offlineStore.markWorkPackageOpened(activityID: activityID)
            }
            guard offlineStore.isNetworkAvailable else {
                async let commentsTask: Void = loadComments()
                async let guideTask: Void = loadGuide()
                _ = await (commentsTask, guideTask)
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

    private var sectionSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(PreventiveDetailSection.allCases.enumerated()), id: \.element.id) {
                    index, section in
                    Button {
                        withAnimation(.snappy) {
                            selectedSection = section
                        }
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: section.systemImage)
                                .font(.headline)
                            /**Text(String(index + 1))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)*/
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

                    if section != PreventiveDetailSection.allCases.last {
                        Divider().frame(height: 26)
                    }
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
        case .general:
            generalSection(detail)
        case .checklist:
            checklistSection
        case .steps:
            preventiveGuide
        case .comments:
            commentsPanel
        case .versions:
            reportVersions(detail)
        case .previousReports:
            previousReports
        }
    }

    private func generalSection(_ detail: APIActivityDetail) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 520), spacing: AppSpacing.md)],
            alignment: .leading,
            spacing: AppSpacing.md
        ) {
            generalData(detail)
            VStack(spacing: AppSpacing.md) {
                maintenanceStatusTimeline(detail)
                photoPanel(detail)
            }
        }
    }

    private var checklistSection: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 520), spacing: AppSpacing.md)],
            alignment: .leading,
            spacing: AppSpacing.md
        ) {
            manualChecklistGuide
            operationalChecklistGuide
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
                    manualChecklist: package.editor.manualChecklist,
                    operationalChecklist: package.editor.operationalChecklist,
                    previousReports: [],
                    previousReportsTotal: 0,
                    previousReportsHasMore: false,
                    previousReportsOffset: 0
                )
                previousReportsResolvedTotal = 0
            }
            return
        }
        guard !isLoadingGuide else { return }
        isLoadingGuide = true
        guideError = nil
        historyLoadError = nil
        previousReportsResolvedTotal = nil
        defer { isLoadingGuide = false }
        do {
            let loadedGuide = try await session.withValidAccessToken { token in
                try await reportService.preventiveGuide(
                    activityID: activityID,
                    accessToken: token,
                    previousReportsLimit: previousReportsPageSize,
                    previousReportsOffset: 0
                )
            }
            guide = loadedGuide
            previousReportsPage = 0
            previousReportPages = [0: loadedGuide.previousReports]
            previousReportsResolvedTotal = loadedGuide.previousReportsTotal
            if loadedGuide.previousReportsTotal == nil,
               loadedGuide.previousReportsHasMore {
                await resolveLegacyPreviousReportsTotal(from: loadedGuide)
            }
        } catch {
            guideError = error.localizedDescription
        }
    }

    @MainActor
    private func resolveLegacyPreviousReportsTotal(
        from initialGuide: APIPreventiveGuide
    ) async {
        var reports = initialGuide.previousReports
        var knownIDs = Set(reports.map(\.id))
        var offset = reports.count
        var hasMore = initialGuide.previousReportsHasMore

        while hasMore {
            do {
                let batch = try await session.withValidAccessToken { token in
                    try await reportService.preventiveGuide(
                        activityID: activityID,
                        accessToken: token,
                        previousReportsLimit: 50,
                        previousReportsOffset: offset
                    )
                }
                let uniqueReports = batch.previousReports.filter { knownIDs.insert($0.id).inserted }
                guard !uniqueReports.isEmpty else {
                    hasMore = false
                    continue
                }
                reports.append(contentsOf: uniqueReports)
                offset += batch.previousReports.count
                hasMore = batch.previousReportsHasMore
            } catch {
                historyLoadError = error.localizedDescription
                return
            }
        }

        var pages: [Int: [APIPreventiveHistoryReport]] = [:]
        for (index, report) in reports.enumerated() {
            pages[index / previousReportsPageSize, default: []].append(report)
        }
        previousReportPages = pages
        previousReportsResolvedTotal = reports.count
    }

    @MainActor
    private func showPreviousReportsPage(_ page: Int) async {
        guard offlineStore.isNetworkAvailable else { return }
        guard page >= 0, page < previousReportsPageCount, !isLoadingMoreHistory else {
            return
        }

        if previousReportPages[page] != nil {
            withAnimation(.snappy) { previousReportsPage = page }
            return
        }

        isLoadingMoreHistory = true
        historyLoadError = nil
        defer { isLoadingMoreHistory = false }

        do {
            let loadedPage = try await session.withValidAccessToken { token in
                try await reportService.preventiveGuide(
                    activityID: activityID,
                    accessToken: token,
                    previousReportsLimit: previousReportsPageSize,
                    previousReportsOffset: page * previousReportsPageSize
                )
            }
            previousReportPages[page] = loadedPage.previousReports
            withAnimation(.snappy) { previousReportsPage = page }
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
    private func reportActions(
        _ detail: APIActivityDetail,
        isCompact: Bool = false
    ) -> some View {
        let latestReport = detail.reports.first {
            $0.reportKind != "CALIBRATION"
        }

        if detail.status == "IN_PROGRESS", session.currentUser?.role != .boss {
            if isCompact {
                compactReportActionContent(detail, latestReport: latestReport)
            } else {
                GlassPanel {
                    reportActionContent(detail, latestReport: latestReport)
                }
            }
        } else if let latestReport,
                  latestReport.documentStatus == "FINALIZED" {
            if isCompact {
                compactFinalizedReportButton(latestReport)
            } else {
                GlassPanel {
                    finalizedReportButton(latestReport)
                }
            }
        }
    }

    private func compactReportActionContent(
        _ detail: APIActivityDetail,
        latestReport: APIReportVersion?
    ) -> some View {
        HStack(spacing: AppSpacing.sm) {
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
            .buttonStyle(CompactActionButtonStyle(prominent: true))

            if let latestReport,
               latestReport.documentStatus == "FINALIZED" {
                compactFinalizedReportButton(latestReport)
            }
        }
    }

    private func reportActionContent(
        _ detail: APIActivityDetail,
        latestReport: APIReportVersion?
    ) -> some View {
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
                finalizedReportButton(latestReport)
            }
        }
    }

    private func finalizedReportButton(_ report: APIReportVersion) -> some View {
        NavigationLink {
            PDFPreviewView(versionID: report.id)
        } label: {
            Label("Generar PDF", systemImage: "doc.badge.plus")
        }
        .buttonStyle(ActionTileButtonStyle())
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
                        Text("Estado del mantenimiento")
                            .font(.headline)
                        Text(statusDescription(detail.status))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BrandColor.red)
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
                                    .foregroundStyle(
                                        isReached ? Color.white : Color.secondary.opacity(0.55)
                                    )
                                    .frame(width: 30, height: 30)
                                    .background(
                                        isCurrent
                                            ? BrandColor.red
                                            : (isReached
                                                ? BrandColor.green
                                                : Color.secondary.opacity(0.14)),
                                        in: Circle()
                                    )
                                    .overlay {
                                        if isCurrent {
                                            Circle()
                                                .stroke(BrandColor.red.opacity(0.22), lineWidth: 6)
                                        }
                                    }
                                Text(stage.title)
                                    .font(.caption.weight(isCurrent ? .bold : .medium))
                                    .foregroundStyle(isCurrent ? BrandColor.red : .secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(stage.title)
                            .accessibilityValue(
                                isCurrent
                                    ? "Estado actual"
                                    : (isReached ? "Completado" : "Pendiente")
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity)
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
                },
                presentation: presentation
            )
        }
    }

    private func generalData(_ detail: APIActivityDetail) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Datos generales", subtitle: "Contexto normalizado del mantenimiento")
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 220), spacing: AppSpacing.sm)],
                    alignment: .leading,
                    spacing: AppSpacing.sm
                ) {
                    DetailTile(title: "Equipos", value: detail.assets.map(\.name).joined(separator: ", ").orFallback("Sin equipo relacionado"))
                    DetailTile(title: "Sede", value: detail.site.orFallback("No registrada"))
                    DetailTile(title: "Proyecto", value: detail.project.orFallback("No registrado"))
                    DetailTile(title: "Etapa", value: detail.stage.orFallback("No registrada"))
                    DetailTile(title: "Sistema", value: detail.system.orFallback("No registrado"))
                    DetailTile(title: "Subsistema", value: detail.subsystem)
                    DetailTile(title: "Ubicación física", value: detail.locationPath.orFallback("No registrada"))
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
    private var manualChecklistGuide: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Checklist según manual",
                    subtitle: "Requerimientos documentales del mantenimiento"
                )
                if let items = guide?.manualChecklist, !items.isEmpty {
                    ForEach(items.sorted { $0.sequence < $1.sequence }) { item in
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: "book.closed.fill")
                                .foregroundStyle(BrandColor.red)
                            Text(item.name)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(checklistQuantity(item.quantity, unit: item.unit))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(AppSpacing.md)
                        .background(
                            .background.opacity(0.62),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    }
                } else {
                    pendingChecklist
                }
            }
        }
    }

    @ViewBuilder
    private var operationalChecklistGuide: some View {
        let items = guide?.operationalChecklist ?? []
        let groupedItems = Dictionary(grouping: items, by: \.category).mapValues {
            $0.sorted { $0.sequence < $1.sequence }
        }
        let categories = OperationalChecklistCategory.allCases.filter { category in
            groupedItems[category.rawValue]?.isEmpty == false
        }
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Checklist operativo",
                    subtitle: "Elementos que deben prepararse antes de salir a campo"
                )
                if items.isEmpty {
                    pendingChecklist
                } else {
                    ForEach(categories) { category in
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Label(category.title, systemImage: category.systemImage)
                                .font(.headline)
                                .foregroundStyle(BrandColor.red)
                            ForEach(groupedItems[category.rawValue] ?? []) { item in
                                HStack(alignment: .top, spacing: AppSpacing.sm) {
                                    Image(systemName: "circle")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 3)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.name)
                                            .font(.subheadline.weight(.semibold))
                                        if let notes = item.notes, !notes.isEmpty {
                                            Text(notes)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text(
                                        checklistQuantity(
                                            item.defaultQuantity,
                                            unit: item.unit
                                        )
                                    )
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(
                            .background.opacity(0.62),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    }
                }
            }
        }
    }

    private var pendingChecklist: some View {
        Label("Pendiente de agregar", systemImage: "clock.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.md)
            .background(
                .background.opacity(0.58),
                in: RoundedRectangle(cornerRadius: 10)
            )
    }

    private func checklistQuantity(_ quantity: Double?, unit: String) -> String {
        guard let quantity else { return "Por definir" }
        return "\(quantity.formatted(.number.precision(.fractionLength(0...2)))) \(unit)"
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

    private var visiblePreviousReports: [APIPreventiveHistoryReport] {
        previousReportPages[previousReportsPage]
            ?? (previousReportsPage == 0 ? guide?.previousReports ?? [] : [])
    }

    private var showsPreviousReportsPagination: Bool {
        previousReportsPageCount > 1
    }

    private var previousReportsPageCount: Int {
        let total = previousReportsResolvedTotal
            ?? guide?.previousReportsTotal
            ?? ((guide?.previousReports.count ?? 0) + (guide?.previousReportsHasMore == true ? 1 : 0))
        return max(
            1,
            Int(ceil(Double(total) / Double(previousReportsPageSize)))
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
                } else if !visiblePreviousReports.isEmpty {
                    GlassEffectContainer(spacing: AppSpacing.sm) {
                        LazyVStack(alignment: .leading, spacing: AppSpacing.sm) {
                            ForEach(visiblePreviousReports) { report in
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

                    if showsPreviousReportsPagination {
                        PaginationBar(
                            currentPage: previousReportsPage,
                            pageCount: previousReportsPageCount,
                            isLoading: isLoadingMoreHistory
                        ) { selectedPage in
                            Task { await showPreviousReportsPage(selectedPage) }
                        }
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
