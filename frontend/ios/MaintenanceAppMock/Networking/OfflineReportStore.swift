import Foundation
import Network
import SwiftUI

enum OfflineDraftState: String, Codable {
    case localOnly
    case pending
    case syncing
    case needsAttention
}

struct OfflineReportDraft: Codable, Identifiable {
    let id: UUID
    let activityID: String
    let ownerUserID: String
    let baseURL: String
    var payload: APIReportDraftWrite
    var editor: APIReportEditor
    var activityDetail: APIActivityDetail
    var state: OfflineDraftState
    var createdAt: Date
    var updatedAt: Date
    var attemptCount: Int
    var nextRetryAt: Date?
    var lastError: String?
}

struct OfflineSyncEvent: Identifiable {
    let id = UUID()
    let activityID: String
    let reportVersionID: String
    let synchronizedAt: Date
}

actor OfflineReportDiskStore {
    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        let root = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        directory = root.appendingPathComponent(
            "OfflineReportDrafts",
            isDirectory: true
        )

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadAll() throws -> [OfflineReportDraft] {
        try ensureDirectory()
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(OfflineReportDraft.self, from: data)
            }
    }

    func write(_ draft: OfflineReportDraft) throws {
        try ensureDirectory()
        let data = try encoder.encode(draft)
        let destination = fileURL(for: draft.id)
        try data.write(to: destination, options: [.atomic])
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: destination.path
        )
    }

    func delete(id: UUID) throws {
        let destination = fileURL(for: id)
        guard FileManager.default.fileExists(atPath: destination.path) else {
            return
        }
        try FileManager.default.removeItem(at: destination)
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [
                .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
            ]
        )
    }

    private func fileURL(for id: UUID) -> URL {
        directory
            .appendingPathComponent(id.uuidString)
            .appendingPathExtension("json")
    }
}

@MainActor
final class OfflineReportStore: ObservableObject {
    @Published private(set) var draftsByActivity: [String: OfflineReportDraft] = [:]
    @Published private(set) var isNetworkAvailable = false
    @Published private(set) var isSynchronizing = false
    @Published private(set) var lastSyncEvent: OfflineSyncEvent?

    private let diskStore: OfflineReportDiskStore
    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "maintenance.network-monitor")
    private weak var session: SessionStore?
    private var currentUserID: String?
    private var currentBaseURL: String?
    private var retryLoop: Task<Void, Never>?

    var pendingCount: Int {
        draftsByActivity.values.filter {
            $0.state == .pending
                || $0.state == .syncing
                || $0.state == .needsAttention
        }.count
    }

    init(
        diskStore: OfflineReportDiskStore = OfflineReportDiskStore(),
        monitor: NWPathMonitor = NWPathMonitor()
    ) {
        self.diskStore = diskStore
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                await self?.connectivityChanged(
                    isAvailable: path.status == .satisfied
                )
            }
        }
        monitor.start(queue: monitorQueue)
        retryLoop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                await self?.retryDueDrafts()
            }
        }
    }

    deinit {
        monitor.cancel()
        retryLoop?.cancel()
    }

    func configure(session: SessionStore) async {
        self.session = session
        currentUserID = session.currentUser?.id
        currentBaseURL = Self.normalizedBaseURL(
            UserDefaults.standard.string(forKey: "apiBaseURL")
        )
        await reloadVisibleDrafts()
        await synchronizePending()
    }

    func draft(for activityID: String) -> OfflineReportDraft? {
        draftsByActivity[activityID]
    }

    func persist(
        activityID: String,
        payload: APIReportDraftWrite,
        editor: APIReportEditor,
        activityDetail: APIActivityDetail,
        queueForSync: Bool
    ) async {
        guard let ownerUserID = currentUserID,
              let baseURL = currentBaseURL else {
            return
        }
        let now = Date()
        let existing = draftsByActivity[activityID]
        let shouldRemainQueued = existing?.state == .pending
            || existing?.state == .syncing
        var record = OfflineReportDraft(
            id: existing?.id ?? UUID(),
            activityID: activityID,
            ownerUserID: ownerUserID,
            baseURL: baseURL,
            payload: payload,
            editor: editor,
            activityDetail: activityDetail,
            state: queueForSync || shouldRemainQueued ? .pending : .localOnly,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            attemptCount: queueForSync ? existing?.attemptCount ?? 0 : 0,
            nextRetryAt: nil,
            lastError: nil
        )
        if existing?.state == .needsAttention && !queueForSync {
            record.state = .localOnly
        }
        do {
            try await diskStore.write(record)
            draftsByActivity[activityID] = record
        } catch {
            record.state = .needsAttention
            record.lastError = "No se pudo proteger el borrador en este iPad."
            draftsByActivity[activityID] = record
        }
    }

    func markSynchronized(
        activityID: String,
        synchronizedPayload: APIReportDraftWrite,
        reportVersionID: String
    ) async {
        guard let record = draftsByActivity[activityID] else { return }
        guard record.payload == synchronizedPayload else {
            var changedRecord = record
            changedRecord.payload.baseReportVersionID = reportVersionID
            changedRecord.state = .pending
            changedRecord.nextRetryAt = nil
            changedRecord.lastError = nil
            try? await diskStore.write(changedRecord)
            draftsByActivity[activityID] = changedRecord
            return
        }
        try? await diskStore.delete(id: record.id)
        draftsByActivity.removeValue(forKey: activityID)
        lastSyncEvent = OfflineSyncEvent(
            activityID: activityID,
            reportVersionID: reportVersionID,
            synchronizedAt: Date()
        )
    }

    func markFailed(activityID: String, error: Error) async {
        guard var record = draftsByActivity[activityID] else { return }
        record.attemptCount += 1
        record.updatedAt = Date()
        record.lastError = error.localizedDescription
        if error.isReportConnectivityFailure {
            record.state = .pending
            record.nextRetryAt = Date().addingTimeInterval(
                Self.retryDelay(attempt: record.attemptCount)
            )
        } else {
            record.state = .needsAttention
            record.nextRetryAt = nil
        }
        try? await diskStore.write(record)
        draftsByActivity[activityID] = record
    }

    func retry(activityID: String) async {
        guard var record = draftsByActivity[activityID] else { return }
        record.state = .pending
        record.nextRetryAt = nil
        record.lastError = nil
        try? await diskStore.write(record)
        draftsByActivity[activityID] = record
        await synchronizePending(activityID: activityID)
    }

    func retryAll() async {
        for activityID in draftsByActivity.keys {
            guard var record = draftsByActivity[activityID] else { continue }
            record.state = .pending
            record.nextRetryAt = nil
            try? await diskStore.write(record)
            draftsByActivity[activityID] = record
        }
        await synchronizePending()
    }

    func queueLocalDraftsForSync() async {
        for activityID in draftsByActivity.keys {
            guard var record = draftsByActivity[activityID],
                  record.state == .localOnly else {
                continue
            }
            record.state = .pending
            record.nextRetryAt = nil
            try? await diskStore.write(record)
            draftsByActivity[activityID] = record
        }
        await synchronizePending()
    }

    private func reloadVisibleDrafts() async {
        guard let currentUserID, let currentBaseURL else {
            draftsByActivity = [:]
            return
        }
        let allDrafts = (try? await diskStore.loadAll()) ?? []
        var visibleDrafts: [String: OfflineReportDraft] = [:]
        for var draft in allDrafts where
            draft.ownerUserID == currentUserID
                && draft.baseURL == currentBaseURL {
            if draft.state == .localOnly {
                draft.state = .pending
                draft.nextRetryAt = nil
                try? await diskStore.write(draft)
            }
            visibleDrafts[draft.activityID] = draft
        }
        draftsByActivity = visibleDrafts
    }

    private func connectivityChanged(isAvailable: Bool) async {
        isNetworkAvailable = isAvailable
        if isAvailable {
            await synchronizePending()
        }
    }

    private func retryDueDrafts() async {
        guard isNetworkAvailable else { return }
        let now = Date()
        let hasDueDraft = draftsByActivity.values.contains {
            $0.state == .pending
                && ($0.nextRetryAt == nil || $0.nextRetryAt! <= now)
        }
        if hasDueDraft {
            await synchronizePending()
        }
    }

    private func synchronizePending(activityID: String? = nil) async {
        guard isNetworkAvailable,
              !isSynchronizing,
              let session,
              session.isAuthenticated else {
            return
        }
        let now = Date()
        let records = draftsByActivity.values
            .filter {
                $0.state == .pending
                    && (activityID == nil || $0.activityID == activityID)
                    && ($0.nextRetryAt == nil || $0.nextRetryAt! <= now)
            }
            .sorted { $0.updatedAt < $1.updatedAt }
        guard !records.isEmpty else { return }

        isSynchronizing = true
        defer { isSynchronizing = false }

        for initialRecord in records {
            guard var record = draftsByActivity[initialRecord.activityID] else {
                continue
            }
            record.state = .syncing
            record.lastError = nil
            try? await diskStore.write(record)
            draftsByActivity[record.activityID] = record

            let service = ReportAPIService(baseURLString: record.baseURL)
            do {
                let result = try await session.withValidAccessToken { token in
                    try await service.save(
                        activityID: record.activityID,
                        draft: record.payload,
                        finalize: false,
                        accessToken: token
                    )
                }
                await markSynchronized(
                    activityID: record.activityID,
                    synchronizedPayload: record.payload,
                    reportVersionID: result.versionID
                )
            } catch {
                await markFailed(activityID: record.activityID, error: error)
                if error.isReportConnectivityFailure {
                    break
                }
            }
        }
    }

    private static func normalizedBaseURL(_ value: String?) -> String? {
        let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return normalized?.isEmpty == false ? normalized : nil
    }

    private static func retryDelay(attempt: Int) -> TimeInterval {
        min(60, pow(2, Double(max(0, min(attempt - 1, 4)))) * 5)
    }
}

struct OfflineStatusBar: View {
    @EnvironmentObject private var offlineStore: OfflineReportStore
    @State private var isShowingDrafts = false

    var body: some View {
        if !offlineStore.isNetworkAvailable || offlineStore.pendingCount > 0 {
            HStack(spacing: AppSpacing.sm) {
                Image(
                    systemName: offlineStore.isNetworkAvailable
                        ? "arrow.triangle.2.circlepath"
                        : "wifi.slash"
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(
                        offlineStore.isNetworkAvailable
                            ? "Sincronización pendiente"
                            : "Trabajando sin conexión"
                    )
                    .font(.caption.weight(.bold))
                    Text(statusDetail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if offlineStore.pendingCount > 0 {
                    Button("Ver") { isShowingDrafts = true }
                    .font(.caption.weight(.bold))
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(.regularMaterial)
            .sheet(isPresented: $isShowingDrafts) {
                OfflineDraftListView()
            }
        }
    }

    private var statusDetail: String {
        if !offlineStore.isNetworkAvailable {
            return "Los borradores permanecen protegidos en este iPad."
        }
        return "\(offlineStore.pendingCount) borrador(es) por enviar."
    }
}

private struct OfflineDraftListView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var offlineStore: OfflineReportStore

    private var drafts: [OfflineReportDraft] {
        offlineStore.draftsByActivity.values.sorted {
            $0.updatedAt > $1.updatedAt
        }
    }

    var body: some View {
        NavigationStack {
            List(drafts) { draft in
                NavigationLink {
                    if draft.editor.activityType == "PREVENTIVE" {
                        PreventiveReportFormView(activityID: draft.activityID)
                    } else {
                        CorrectiveReportFormView(eventID: draft.activityID)
                    }
                } label: {
                    HStack(spacing: AppSpacing.md) {
                        Image(
                            systemName: draft.editor.activityType == "PREVENTIVE"
                                ? "checklist"
                                : "wrench.and.screwdriver"
                        )
                        .foregroundStyle(BrandColor.red)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(draft.activityDetail.title)
                                .font(.headline)
                            Text(
                                "Actualizado \(draft.updatedAt.formatted(date: .abbreviated, time: .shortened))"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            Text(stateLabel(draft.state))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(
                                    draft.state == .needsAttention
                                        ? BrandColor.red
                                        : .orange
                                )
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)
                }
            }
            .navigationTitle("Borradores pendientes")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await offlineStore.retryAll() }
                    } label: {
                        Label("Reintentar", systemImage: "arrow.clockwise")
                    }
                    .disabled(
                        !offlineStore.isNetworkAvailable
                            || offlineStore.isSynchronizing
                    )
                }
            }
        }
    }

    private func stateLabel(_ state: OfflineDraftState) -> String {
        switch state {
        case .localOnly:
            return "Guardado en este iPad"
        case .pending:
            return "Pendiente de sincronización"
        case .syncing:
            return "Sincronizando"
        case .needsAttention:
            return "Necesita revisión"
        }
    }
}

struct OfflineDraftBanner: View {
    let draft: OfflineReportDraft?
    let isNetworkAvailable: Bool
    let retry: () -> Void

    var body: some View {
        if let draft {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                stateIcon(for: draft.state)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title(for: draft.state))
                        .font(.headline)
                    Text(detail(for: draft))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if draft.state == .needsAttention
                    || (draft.state == .pending && isNetworkAvailable) {
                    Button("Reintentar", action: retry)
                        .buttonStyle(.bordered)
                }
            }
            .padding(AppSpacing.md)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        } else if !isNetworkAvailable {
            Label(
                "Sin conexión. Los cambios se guardarán en este iPad.",
                systemImage: "wifi.slash"
            )
            .font(.subheadline.weight(.semibold))
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
    }

    @ViewBuilder
    private func stateIcon(for state: OfflineDraftState) -> some View {
        switch state {
        case .localOnly:
            Image(systemName: "ipad.and.arrow.forward")
                .foregroundStyle(.orange)
        case .pending:
            Image(systemName: "icloud.and.arrow.up")
                .foregroundStyle(.orange)
        case .syncing:
            ProgressView()
        case .needsAttention:
            Image(systemName: "exclamationmark.icloud.fill")
                .foregroundStyle(BrandColor.red)
        }
    }

    private func title(for state: OfflineDraftState) -> String {
        switch state {
        case .localOnly:
            return "Autoguardado en este iPad"
        case .pending:
            return "Borrador pendiente de sincronización"
        case .syncing:
            return "Sincronizando borrador"
        case .needsAttention:
            return "El borrador necesita revisión"
        }
    }

    private func detail(for draft: OfflineReportDraft) -> String {
        if let lastError = draft.lastError, !lastError.isEmpty {
            return lastError
        }
        switch draft.state {
        case .localOnly:
            return "Último cambio local: \(draft.updatedAt.formatted(date: .omitted, time: .shortened))."
        case .pending:
            return isNetworkAvailable
                ? "Se enviará automáticamente al servidor."
                : "Se enviará cuando vuelva la conexión."
        case .syncing:
            return "Mantén la aplicación abierta mientras termina el envío."
        case .needsAttention:
            return "Revisa el reporte y vuelve a intentar."
        }
    }
}

extension Error {
    var isReportConnectivityFailure: Bool {
        guard let apiError = self as? APIClient.APIError else {
            return self is URLError
        }
        switch apiError {
        case .requestTimedOut, .localServerUnavailable:
            return true
        default:
            return false
        }
    }
}
