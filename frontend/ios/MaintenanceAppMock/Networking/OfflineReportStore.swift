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
    /// Kept only to decode drafts created by older app versions. New drafts are
    /// always synchronized as drafts and must be finalized while connected.
    var finalizeWhenSynced: Bool?
}

/// Snapshot downloaded deliberately while connected. It lets a report form open
/// with its complete reference data when the iPad is later out in the field.
struct OfflineWorkPackage: Codable, Identifiable {
    let id: UUID
    let activityID: String
    let ownerUserID: String
    let environment: String
    let baseURL: String
    var activityDetail: APIActivityDetail
    let editor: APIReportEditor
    let downloadedAt: Date
    var lastOpenedAt: Date?
}

enum OfflineOperationState: String, Codable {
    case pending
    case syncing
    case needsAttention
}

struct OfflineLifecycleOperation: Codable, Identifiable {
    let id: UUID
    let activityID: String
    let command: MaintenanceLifecycleCommand
    let reason: String?
    let ownerUserID: String
    let environment: String
    let baseURL: String
    var state: OfflineOperationState
    var createdAt: Date
    var lastError: String?
}

struct OfflineCommentOperation: Codable, Identifiable {
    let id: UUID
    let activityID: String
    let message: String
    let ownerUserID: String
    let environment: String
    let baseURL: String
    var state: OfflineOperationState
    var createdAt: Date
    var lastError: String?
}

struct OfflineCorrectiveCatalog: Codable {
    let ownerUserID: String
    let environment: String
    let baseURL: String
    let downloadedAt: Date
    let targets: [CorrectiveTarget]
    let contexts: [String: CorrectiveCreationContext]
    let trees: [String: [EquipmentTreeNodeDTO]]
    let locationOptions: [CorrectiveLocationOption]?
}

struct OfflineCorrectiveOperation: Codable, Identifiable {
    let id: UUID
    let localCode: String
    let ownerUserID: String
    let environment: String
    let baseURL: String
    let request: CorrectiveCreateRequest
    var state: OfflineOperationState
    var createdAt: Date
    var lastError: String?
}

struct OfflineDownloadProgress: Equatable {
    let total: Int
    var completed: Int
    var failedTitles: [String]

    var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}

struct OfflineSyncEvent: Identifiable {
    let id = UUID()
    let activityID: String
    let reportVersionID: String
    let synchronizedAt: Date
}

struct OfflineActivityReconciliation: Identifiable {
    let id = UUID()
    let detail: APIActivityDetail
}

struct OfflineSynchronizationNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
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

actor OfflineWorkDiskStore {
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        directory = root.appendingPathComponent("OfflineWorkPackages", isDirectory: true)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load<T: Codable>(_ type: T.Type, collection: String) throws -> [T] {
        try ensureDirectory()
        let url = fileURL(collection)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try decoder.decode([T].self, from: Data(contentsOf: url))
    }

    func write<T: Codable>(_ value: [T], collection: String) throws {
        try ensureDirectory()
        try encoder.encode(value).write(to: fileURL(collection), options: [.atomic])
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
    }

    private func fileURL(_ collection: String) -> URL {
        directory.appendingPathComponent(collection).appendingPathExtension("json")
    }
}

@MainActor
final class OfflineReportStore: ObservableObject {
    @Published private(set) var draftsByActivity: [String: OfflineReportDraft] = [:]
    @Published private(set) var workPackagesByActivity: [String: OfflineWorkPackage] = [:]
    @Published private(set) var lifecycleOperations: [OfflineLifecycleOperation] = []
    @Published private(set) var commentOperations: [OfflineCommentOperation] = []
    @Published private(set) var correctiveCatalog: OfflineCorrectiveCatalog?
    @Published private(set) var correctiveOperations: [OfflineCorrectiveOperation] = []
    @Published private(set) var downloadProgress: OfflineDownloadProgress?
    @Published private(set) var lastDownloadFailedTitles: [String] = []
    @Published private(set) var isNetworkAvailable = false
    @Published private(set) var isSynchronizing = false
    @Published private(set) var lastSyncEvent: OfflineSyncEvent?
    @Published private(set) var lastReconciledActivity: OfflineActivityReconciliation?
    @Published private(set) var lastSynchronizationNotice: OfflineSynchronizationNotice?

    private let diskStore: OfflineReportDiskStore
    private let workDiskStore: OfflineWorkDiskStore
    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "maintenance.network-monitor")
    private weak var session: SessionStore?
    private var currentUserID: String?
    private var currentBaseURL: String?
    private var currentEnvironment: String?
    private var retryLoop: Task<Void, Never>?

    var pendingCount: Int {
        let reportCount = draftsByActivity.values.filter {
            $0.state == .pending
                || $0.state == .syncing
                || $0.state == .needsAttention
        }.count
        return reportCount + lifecycleOperations.count + commentOperations.count + correctiveOperations.count
    }

    var pendingLifecycleOperations: [OfflineLifecycleOperation] {
        lifecycleOperations.filter {
            $0.state == .pending || $0.state == .syncing || $0.state == .needsAttention
        }
    }

    var pendingCommentOperations: [OfflineCommentOperation] {
        commentOperations.filter {
            $0.state == .pending || $0.state == .syncing || $0.state == .needsAttention
        }
    }

    var pendingCorrectiveOperations: [OfflineCorrectiveOperation] {
        correctiveOperations.filter {
            $0.state == .pending || $0.state == .syncing || $0.state == .needsAttention
        }
    }

    init(
        diskStore: OfflineReportDiskStore = OfflineReportDiskStore(),
        monitor: NWPathMonitor = NWPathMonitor(),
        workDiskStore: OfflineWorkDiskStore = OfflineWorkDiskStore()
    ) {
        self.diskStore = diskStore
        self.workDiskStore = workDiskStore
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
        currentEnvironment = AppEnvironment.name
        await reloadVisibleDrafts()
        await reloadWorkPackages()
        await reloadOperations()
        await synchronizePending()
        await reconcileAcknowledgedLifecycleOperations()
        if isNetworkAvailable {
            await refreshDownloadedPackages()
        }
    }

    func draft(for activityID: String) -> OfflineReportDraft? {
        draftsByActivity[activityID]
    }

    func workPackage(for activityID: String) -> OfflineWorkPackage? {
        workPackagesByActivity[activityID]
    }

    func displayActivity(_ serverActivity: APIActivity) -> APIActivity {
        guard hasPendingWork(for: serverActivity.id),
              let package = workPackagesByActivity[serverActivity.id] else {
            return serverActivity
        }
        return APIActivity(detail: package.activityDetail)
    }

    func hasPendingWork(for activityID: String) -> Bool {
        draftsByActivity[activityID] != nil
            || lifecycleOperations.contains(where: { $0.activityID == activityID })
            || commentOperations.contains(where: { $0.activityID == activityID })
    }

    func downloadWorkPackage(
        activityID: String,
        detail: APIActivityDetail,
        session: SessionStore
    ) async throws {
        guard let ownerUserID = currentUserID,
              let baseURL = currentBaseURL,
              let environment = currentEnvironment else {
            throw OfflineWorkError.sessionUnavailable
        }
        let editor = try await session.withValidAccessToken { token in
            try await ReportAPIService(baseURLString: baseURL).editor(
                activityID: activityID,
                accessToken: token
            )
        }
        let package = OfflineWorkPackage(
            id: workPackagesByActivity[activityID]?.id ?? UUID(),
            activityID: activityID,
            ownerUserID: ownerUserID,
            environment: environment,
            baseURL: baseURL,
            activityDetail: detail,
            editor: editor,
            downloadedAt: Date(),
            lastOpenedAt: nil
        )
        workPackagesByActivity[activityID] = package
        try await persistWorkPackages()
    }

    func downloadWorkPackages(
        activities: [APIActivity],
        session: SessionStore,
        activityStore: MaintenanceActivityStore
    ) async {
        guard let baseURL = currentBaseURL, isNetworkAvailable else { return }
        lastDownloadFailedTitles = []
        downloadProgress = OfflineDownloadProgress(total: activities.count, completed: 0, failedTitles: [])
        defer {
            lastDownloadFailedTitles = downloadProgress?.failedTitles ?? []
            downloadProgress = nil
        }

        for activity in activities {
            do {
                let detail = try await session.withValidAccessToken { token in
                    try await MaintenanceAPIService(baseURLString: baseURL).detail(
                        id: activity.id, accessToken: token
                    )
                }
                activityStore.cacheDetail(detail)
                try await downloadWorkPackage(
                    activityID: activity.id, detail: detail, session: session
                )
            } catch {
                downloadProgress?.failedTitles.append(activity.title)
            }
            downloadProgress?.completed += 1
        }
    }

    func removeWorkPackage(activityID: String) async {
        guard draftsByActivity[activityID] == nil,
              !lifecycleOperations.contains(where: { $0.activityID == activityID }),
              !commentOperations.contains(where: { $0.activityID == activityID }) else {
            return
        }
        workPackagesByActivity.removeValue(forKey: activityID)
        try? await persistWorkPackages()
    }

    func markWorkPackageOpened(activityID: String) async {
        guard var package = workPackagesByActivity[activityID] else { return }
        package.lastOpenedAt = Date()
        workPackagesByActivity[activityID] = package
        try? await persistWorkPackages()
    }

    /// Keeps a downloaded package aligned with the authoritative response once
    /// connectivity returns. Finished work is removed only after there is no
    /// local work left to upload, preventing stale copies from accumulating.
    func reconcileWorkPackage(with detail: APIActivityDetail) async {
        guard workPackagesByActivity[detail.id] != nil else { return }
        lastReconciledActivity = OfflineActivityReconciliation(detail: detail)
        let hasPendingLocalWork = hasPendingWork(for: detail.id)
        let hasFinalizedReport = detail.reports.contains {
            $0.documentStatus == "FINALIZED"
        }
        if ["COMPLETED", "CLOSED"].contains(detail.status),
           hasFinalizedReport,
           !hasPendingLocalWork {
            workPackagesByActivity.removeValue(forKey: detail.id)
        } else if var package = workPackagesByActivity[detail.id] {
            package.activityDetail = detail
            workPackagesByActivity[detail.id] = package
        }
        try? await persistWorkPackages()
    }

    func queueLifecycle(
        activityID: String,
        command: MaintenanceLifecycleCommand,
        reason: String?
    ) async {
        guard let ownerUserID = currentUserID,
              let baseURL = currentBaseURL,
              let environment = currentEnvironment else { return }
        // Keep lifecycle commands in their original order. A report completed
        // offline may depend on its queued start reaching the server first.
        lifecycleOperations.removeAll {
            $0.activityID == activityID && $0.command == command
        }
        let operation = OfflineLifecycleOperation(
            id: UUID(), activityID: activityID, command: command, reason: reason,
            ownerUserID: ownerUserID, environment: environment, baseURL: baseURL,
            state: .pending, createdAt: Date(), lastError: nil
        )
        lifecycleOperations.append(operation)
        await persistLocalLifecycle(
            activityID: activityID,
            command: command,
            at: operation.createdAt
        )
        try? await persistOperations()
    }

    private func persistLocalLifecycle(
        activityID: String,
        command: MaintenanceLifecycleCommand,
        at date: Date = Date()
    ) async {
        if var package = workPackagesByActivity[activityID] {
            package.activityDetail = package.activityDetail.applyingOfflineLifecycle(command, at: date)
            workPackagesByActivity[activityID] = package
            try? await persistWorkPackages()
        }
        if var draft = draftsByActivity[activityID] {
            draft.activityDetail = draft.activityDetail.applyingOfflineLifecycle(command, at: date)
            try? await diskStore.write(draft)
            draftsByActivity[activityID] = draft
        }
    }

    func queueComment(activityID: String, message: String) async {
        guard let ownerUserID = currentUserID,
              let baseURL = currentBaseURL,
              let environment = currentEnvironment else { return }
        commentOperations.append(OfflineCommentOperation(
            id: UUID(), activityID: activityID, message: message,
            ownerUserID: ownerUserID, environment: environment, baseURL: baseURL,
            state: .pending, createdAt: Date(), lastError: nil
        ))
        try? await persistOperations()
    }

    func downloadCorrectiveCatalog(
        session: SessionStore,
        assetStore: AssetStore
    ) async throws {
        guard let ownerUserID = currentUserID,
              let baseURL = currentBaseURL,
              let environment = currentEnvironment else {
            throw OfflineWorkError.sessionUnavailable
        }
        var targets: [CorrectiveTarget] = []
        var contexts: [String: CorrectiveCreationContext] = [:]
        var trees: [String: [EquipmentTreeNodeDTO]] = [:]
        let locationOptions = try await session.withValidAccessToken { token in
            try await CorrectiveCreationAPIService(baseURLString: baseURL).locationOptions(
                accessToken: token
            )
        }
        for subsystem in ["ATS", "CBTC", "IXL"] {
            let subsystemTargets = try await session.withValidAccessToken { token in
                try await CorrectiveCreationAPIService(baseURLString: baseURL).targets(
                    subsystem: subsystem, accessToken: token
                )
            }
            targets.append(contentsOf: subsystemTargets)
            for target in subsystemTargets {
                for root in target.roots {
                    try await session.withValidAccessToken { token in
                        let context = try await CorrectiveCreationAPIService(baseURLString: baseURL).context(
                            equipmentID: root.id, accessToken: token
                        )
                        contexts[root.id] = context
                    }
                    await assetStore.loadTree(id: root.id, session: session, force: true)
                    trees[root.id] = assetStore.trees[root.id] ?? []
                }
            }
        }
        let catalog = OfflineCorrectiveCatalog(
            ownerUserID: ownerUserID, environment: environment, baseURL: baseURL,
            downloadedAt: Date(), targets: targets, contexts: contexts, trees: trees,
            locationOptions: locationOptions
        )
        correctiveCatalog = catalog
        try await workDiskStore.write([catalog], collection: "corrective-catalog")
    }

    func queueCorrective(request: CorrectiveCreateRequest) async {
        guard let ownerUserID = currentUserID,
              let baseURL = currentBaseURL,
              let environment = currentEnvironment else { return }
        let operation = OfflineCorrectiveOperation(
            id: UUID(), localCode: "LOCAL-COR-\(UUID().uuidString.prefix(8).uppercased())",
            ownerUserID: ownerUserID, environment: environment, baseURL: baseURL,
            request: request, state: .pending, createdAt: Date(), lastError: nil
        )
        correctiveOperations.append(operation)
        try? await persistOperations()
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
            lastError: nil,
            finalizeWhenSynced: false
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
        reportVersionID: String,
        announce: Bool = true
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
        if announce {
            lastSynchronizationNotice = OfflineSynchronizationNotice(
                title: "Borrador sincronizado",
                message: "\(record.activityDetail.title) ya se guardó en el servidor."
            )
        }
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

    func discardPendingWork(activityID: String) async {
        if let draft = draftsByActivity.removeValue(forKey: activityID) {
            try? await diskStore.delete(id: draft.id)
        }
        lifecycleOperations.removeAll { $0.activityID == activityID }
        commentOperations.removeAll { $0.activityID == activityID }
        workPackagesByActivity.removeValue(forKey: activityID)
        try? await persistOperations()
        try? await persistWorkPackages()
    }

    func retryAll() async {
        for activityID in draftsByActivity.keys {
            guard var record = draftsByActivity[activityID] else { continue }
            record.state = .pending
            record.nextRetryAt = nil
            try? await diskStore.write(record)
            draftsByActivity[activityID] = record
        }
        for index in lifecycleOperations.indices {
            lifecycleOperations[index].state = .pending
            lifecycleOperations[index].lastError = nil
        }
        for index in commentOperations.indices {
            commentOperations[index].state = .pending
            commentOperations[index].lastError = nil
        }
        for index in correctiveOperations.indices {
            correctiveOperations[index].state = .pending
            correctiveOperations[index].lastError = nil
        }
        try? await persistOperations()
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
        guard let currentUserID, let currentEnvironment else {
            draftsByActivity = [:]
            return
        }
        let allDrafts = (try? await diskStore.loadAll()) ?? []
        var visibleDrafts: [String: OfflineReportDraft] = [:]
        for var draft in allDrafts where
            draft.ownerUserID == currentUserID
                && Self.environmentMatches(
                    recordEnvironment: draft.baseURL,
                    currentEnvironment: currentEnvironment
                ) {
            if draft.finalizeWhenSynced == true {
                // Finalization must always be explicitly confirmed online.
                draft.finalizeWhenSynced = false
                try? await diskStore.write(draft)
            }
            if draft.state == .localOnly {
                draft.state = .pending
                draft.nextRetryAt = nil
                try? await diskStore.write(draft)
            }
            visibleDrafts[draft.activityID] = draft
        }
        draftsByActivity = visibleDrafts
    }

    private func reloadWorkPackages() async {
        guard let currentUserID, let currentEnvironment else {
            workPackagesByActivity = [:]
            return
        }
        let packages = (try? await workDiskStore.load(
            OfflineWorkPackage.self,
            collection: "packages"
        )) ?? []
        workPackagesByActivity = Dictionary(
            uniqueKeysWithValues: packages.filter { package in
                // The URL fallback keeps a package usable when a local server
                // changes from a numeric IP address to its Bonjour hostname.
                package.ownerUserID == currentUserID
                    && (package.environment == currentEnvironment
                        || currentBaseURL.map { normalizedCurrentBaseURL in
                            Self.normalizedBaseURL(package.baseURL) == normalizedCurrentBaseURL
                        } ?? false)
            }.map { ($0.activityID, $0) }
        )
    }

    private func reloadOperations() async {
        guard let currentUserID, let currentEnvironment else {
            lifecycleOperations = []
            commentOperations = []
            return
        }
        lifecycleOperations = ((try? await workDiskStore.load(
            OfflineLifecycleOperation.self,
            collection: "lifecycle"
        )) ?? []).filter {
            $0.ownerUserID == currentUserID && $0.environment == currentEnvironment
        }
        commentOperations = ((try? await workDiskStore.load(
            OfflineCommentOperation.self,
            collection: "comments"
        )) ?? []).filter {
            $0.ownerUserID == currentUserID && $0.environment == currentEnvironment
        }
        correctiveOperations = ((try? await workDiskStore.load(
            OfflineCorrectiveOperation.self,
            collection: "corrective-events"
        )) ?? []).filter {
            $0.ownerUserID == currentUserID && $0.environment == currentEnvironment
        }
        correctiveCatalog = ((try? await workDiskStore.load(
            OfflineCorrectiveCatalog.self,
            collection: "corrective-catalog"
        )) ?? []).first {
            $0.ownerUserID == currentUserID && $0.environment == currentEnvironment
        }
        await reconcilePendingLifecycleSnapshots()
    }

    private func reconcilePendingLifecycleSnapshots() async {
        let pending = lifecycleOperations
            .filter { $0.state == .pending || $0.state == .needsAttention }
            .sorted { $0.createdAt < $1.createdAt }
        guard !pending.isEmpty else { return }
        for operation in pending {
            if var package = workPackagesByActivity[operation.activityID] {
                package.activityDetail = package.activityDetail.applyingOfflineLifecycle(
                    operation.command,
                    at: operation.createdAt
                )
                workPackagesByActivity[operation.activityID] = package
            }
            if var draft = draftsByActivity[operation.activityID] {
                draft.activityDetail = draft.activityDetail.applyingOfflineLifecycle(
                    operation.command,
                    at: operation.createdAt
                )
                try? await diskStore.write(draft)
                draftsByActivity[operation.activityID] = draft
            }
        }
        try? await persistWorkPackages()
    }

    private func persistWorkPackages() async throws {
        let all = (try? await workDiskStore.load(
            OfflineWorkPackage.self,
            collection: "packages"
        )) ?? []
        let retained = all.filter { package in
            package.ownerUserID != currentUserID || package.environment != currentEnvironment
        }
        try await workDiskStore.write(
            retained + Array(workPackagesByActivity.values),
            collection: "packages"
        )
    }

    private func persistOperations() async throws {
        let storedLifecycle = (try? await workDiskStore.load(
            OfflineLifecycleOperation.self,
            collection: "lifecycle"
        )) ?? []
        let storedComments = (try? await workDiskStore.load(
            OfflineCommentOperation.self,
            collection: "comments"
        )) ?? []
        let storedCorrectives = (try? await workDiskStore.load(
            OfflineCorrectiveOperation.self,
            collection: "corrective-events"
        )) ?? []
        let otherLifecycle = storedLifecycle.filter {
            $0.ownerUserID != currentUserID || $0.environment != currentEnvironment
        }
        let otherComments = storedComments.filter {
            $0.ownerUserID != currentUserID || $0.environment != currentEnvironment
        }
        let otherCorrectives = storedCorrectives.filter {
            $0.ownerUserID != currentUserID || $0.environment != currentEnvironment
        }
        try await workDiskStore.write(otherLifecycle + lifecycleOperations, collection: "lifecycle")
        try await workDiskStore.write(otherComments + commentOperations, collection: "comments")
        try await workDiskStore.write(otherCorrectives + correctiveOperations, collection: "corrective-events")
    }

    private func connectivityChanged(isAvailable: Bool) async {
        isNetworkAvailable = isAvailable
        if isAvailable {
            await synchronizePending()
            await reconcileAcknowledgedLifecycleOperations()
            await refreshDownloadedPackages()
        }
    }

    /// Removes obsolete downloaded copies only after verifying that they carry
    /// no unsynchronized work. This keeps a completed activity from lingering
    /// in the offline list while protecting field data from accidental loss.
    private func refreshDownloadedPackages() async {
        guard let session else { return }
        for package in workPackagesByActivity.values.sorted(by: { $0.downloadedAt < $1.downloadedAt }) {
            guard !hasPendingWork(for: package.activityID) else { continue }
            do {
                let detail = try await session.withValidAccessToken { token in
                    try await MaintenanceAPIService(baseURLString: package.baseURL).detail(
                        id: package.activityID,
                        accessToken: token
                    )
                }
                await reconcileWorkPackage(with: detail)
            } catch {
                guard error.isMissingServerResource else { continue }
                workPackagesByActivity.removeValue(forKey: package.activityID)
                try? await persistWorkPackages()
            }
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
        guard !records.isEmpty || !lifecycleOperations.isEmpty || !commentOperations.isEmpty || !correctiveOperations.isEmpty else { return }

        isSynchronizing = true
        defer { isSynchronizing = false }

        // A report cannot be created until a locally queued start/reopen has
        // reached the server. Completion/closure deliberately remain after the
        // report so component changes are validated first.
        await synchronizeLifecycleOperations(commands: [.start, .reopen])

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
                    reportVersionID: result.versionID,
                    announce: true
                )
            } catch {
                await markFailed(activityID: record.activityID, error: error)
                if error.isReportConnectivityFailure {
                    break
                }
            }
        }

        await synchronizeOperations()
    }

    private func synchronizeOperations() async {
        guard isNetworkAvailable, let session else { return }
        await synchronizeLifecycleOperations(commands: [.complete, .close])

        for operation in commentOperations where operation.state == .pending {
            do {
                _ = try await session.withValidAccessToken { token in
                    try await ReportAPIService(baseURLString: operation.baseURL).addComment(
                        activityID: operation.activityID,
                        message: operation.message,
                        accessToken: token
                    )
                }
                commentOperations.removeAll { $0.id == operation.id }
                try? await persistOperations()
            } catch {
                guard let index = commentOperations.firstIndex(where: { $0.id == operation.id }) else { continue }
                commentOperations[index].state = .needsAttention
                commentOperations[index].lastError = error.localizedDescription
                try? await persistOperations()
                if error.isReportConnectivityFailure { return }
            }
        }

        for operation in correctiveOperations where operation.state == .pending {
            do {
                _ = try await session.withValidAccessToken { token in
                    try await CorrectiveCreationAPIService(baseURLString: operation.baseURL).create(
                        request: operation.request, accessToken: token
                    )
                }
                correctiveOperations.removeAll { $0.id == operation.id }
                try? await persistOperations()
            } catch {
                guard let index = correctiveOperations.firstIndex(where: { $0.id == operation.id }) else { continue }
                correctiveOperations[index].state = .needsAttention
                correctiveOperations[index].lastError = error.localizedDescription
                try? await persistOperations()
                if error.isReportConnectivityFailure { return }
            }
        }
    }

    private func synchronizeLifecycleOperations(
        commands: Set<MaintenanceLifecycleCommand>
    ) async {
        guard isNetworkAvailable, let session else { return }
        for operation in lifecycleOperations where operation.state == .pending {
            guard commands.contains(operation.command) else { continue }
            do {
                let detail = try await session.withValidAccessToken { token in
                    try await MaintenanceAPIService(baseURLString: operation.baseURL).transition(
                        id: operation.activityID,
                        command: operation.command,
                        reason: operation.reason,
                        occurredAt: operation.createdAt,
                        accessToken: token
                    )
                }
                lifecycleOperations.removeAll { $0.id == operation.id }
                try? await persistOperations()
                await reconcileWorkPackage(with: detail)
                lastSynchronizationNotice = OfflineSynchronizationNotice(
                    title: "Mantenimiento sincronizado",
                    message: "\(detail.title) actualizó su estado en el servidor."
                )
            } catch {
                if !error.isReportConnectivityFailure,
                   let detail = try? await session.withValidAccessToken({ token in
                       try await MaintenanceAPIService(baseURLString: operation.baseURL).detail(
                           id: operation.activityID,
                           accessToken: token
                       )
                   }),
                   Self.lifecycle(operation.command, isSatisfiedBy: detail.status) {
                    lifecycleOperations.removeAll { $0.id == operation.id }
                    try? await persistOperations()
                    await reconcileWorkPackage(with: detail)
                    continue
                }
                guard let index = lifecycleOperations.firstIndex(where: { $0.id == operation.id }) else { continue }
                lifecycleOperations[index].state = error.isReportConnectivityFailure
                    ? .pending
                    : .needsAttention
                lifecycleOperations[index].lastError = error.isReportConnectivityFailure
                    ? nil
                    : error.localizedDescription
                try? await persistOperations()
                if error.isReportConnectivityFailure { return }
            }
        }
    }

    /// A request can reach the server while the client loses the response. On
    /// the next connection, remove that local command if the server is already
    /// at the requested state instead of leaving a misleading pending action.
    private func reconcileAcknowledgedLifecycleOperations() async {
        guard isNetworkAvailable, let session else { return }
        for operation in lifecycleOperations {
            do {
                let detail = try await session.withValidAccessToken { token in
                    try await MaintenanceAPIService(baseURLString: operation.baseURL).detail(
                        id: operation.activityID,
                        accessToken: token
                    )
                }
                guard Self.lifecycle(operation.command, isSatisfiedBy: detail.status) else {
                    continue
                }
                lifecycleOperations.removeAll { $0.id == operation.id }
                try? await persistOperations()
                await reconcileWorkPackage(with: detail)
            } catch {
                // Keep the operation: a later connection can reconcile it
                // without losing work that was performed in the field.
                continue
            }
        }
    }

    private static func lifecycle(
        _ command: MaintenanceLifecycleCommand,
        isSatisfiedBy status: String
    ) -> Bool {
        switch command {
        case .start, .reopen:
            return ["IN_PROGRESS", "COMPLETED", "CLOSED"].contains(status)
        case .complete:
            return ["COMPLETED", "CLOSED"].contains(status)
        case .close:
            return status == "CLOSED"
        }
    }

    private static func normalizedBaseURL(_ value: String?) -> String? {
        let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return normalized?.isEmpty == false ? normalized : nil
    }

    private static func environmentMatches(
        recordEnvironment: String,
        currentEnvironment: String
    ) -> Bool {
        // Older drafts were keyed by URL. New packages use the build environment;
        // changing a DHCP address therefore never hides the user's offline work.
        recordEnvironment == currentEnvironment
            || recordEnvironment == normalizedBaseURL(
                UserDefaults.standard.string(forKey: "apiBaseURL")
            )
    }

    private static func retryDelay(attempt: Int) -> TimeInterval {
        min(60, pow(2, Double(max(0, min(attempt - 1, 4)))) * 5)
    }
}

enum OfflineWorkError: LocalizedError {
    case sessionUnavailable

    var errorDescription: String? {
        switch self {
        case .sessionUnavailable:
            return "Inicia sesión con conexión antes de descargar trabajo offline."
        }
    }
}

struct OfflineStatusBar: View {
    @EnvironmentObject private var offlineStore: OfflineReportStore
    @State private var isShowingDrafts = false
    @State private var synchronizationNotice: OfflineSynchronizationNotice?

    var body: some View {
        Group {
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
        .onChange(of: offlineStore.lastSynchronizationNotice?.id) { _, _ in
            synchronizationNotice = offlineStore.lastSynchronizationNotice
        }
        .alert(item: $synchronizationNotice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("Aceptar"))
            )
        }
    }

    private var statusDetail: String {
        if !offlineStore.isNetworkAvailable {
            return "Los borradores permanecen protegidos en este iPad."
        }
        return "\(offlineStore.pendingCount) cambio(s) por sincronizar."
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
            List {
                if !drafts.isEmpty {
                    Section("Reportes") {
                        ForEach(drafts) { draft in
                            NavigationLink {
                                if draft.editor.activityType == "PREVENTIVE" {
                                    PreventiveReportFormView(activityID: draft.activityID)
                                } else {
                                    CorrectiveReportFormView(eventID: draft.activityID)
                                }
                        } label: {
                            draftRow(draft)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await offlineStore.discardPendingWork(activityID: draft.activityID) }
                            } label: {
                                Label("Descartar", systemImage: "trash")
                            }
                        }
                        }
                    }
                }
                if !offlineStore.pendingLifecycleOperations.isEmpty {
                    Section("Estados de mantenimiento") {
                        ForEach(offlineStore.pendingLifecycleOperations) { operation in
                            operationRow(
                                title: activityTitle(for: operation.activityID),
                                label: operation.command.label,
                                date: operation.createdAt,
                                state: operation.state
                            )
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await offlineStore.discardPendingWork(activityID: operation.activityID) }
                                } label: {
                                    Label("Descartar", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                if !offlineStore.pendingCommentOperations.isEmpty {
                    Section("Comentarios") {
                        ForEach(offlineStore.pendingCommentOperations) { operation in
                            operationRow(
                                title: activityTitle(for: operation.activityID),
                                label: "Comentario pendiente",
                                date: operation.createdAt,
                                state: operation.state
                            )
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await offlineStore.discardPendingWork(activityID: operation.activityID) }
                                } label: {
                                    Label("Descartar", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                if !offlineStore.pendingCorrectiveOperations.isEmpty {
                    Section("Eventos correctivos") {
                        ForEach(offlineStore.pendingCorrectiveOperations) { operation in
                            operationRow(
                                title: operation.localCode,
                                label: "Crear correctivo",
                                date: operation.createdAt,
                                state: operation.state
                            )
                        }
                    }
                }
                if drafts.isEmpty,
                   offlineStore.pendingLifecycleOperations.isEmpty,
                   offlineStore.pendingCommentOperations.isEmpty,
                   offlineStore.pendingCorrectiveOperations.isEmpty {
                    ContentUnavailableView(
                        "No hay cambios pendientes",
                        systemImage: "checkmark.circle",
                        description: Text("Todos los datos locales ya están sincronizados."))
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

    private func draftRow(_ draft: OfflineReportDraft) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: draft.editor.activityType == "PREVENTIVE" ? "checklist" : "wrench.and.screwdriver")
                .foregroundStyle(BrandColor.red)
            VStack(alignment: .leading, spacing: 3) {
                Text(draft.activityDetail.title).font(.headline)
                Text("Actualizado \(draft.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
                Text(stateLabel(draft.state))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(draft.state == .needsAttention ? BrandColor.red : .orange)
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private func operationRow(
        title: String,
        label: String,
        date: Date,
        state: OfflineOperationState
    ) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: state == .needsAttention ? "exclamationmark.triangle.fill" : "arrow.triangle.2.circlepath")
                .foregroundStyle(state == .needsAttention ? BrandColor.red : BrandColor.amber)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(label).font(.subheadline)
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private func activityTitle(for activityID: String) -> String {
        offlineStore.draftsByActivity[activityID]?.activityDetail.title
            ?? offlineStore.workPackagesByActivity[activityID]?.activityDetail.title
            ?? "Mantenimiento \(activityID.prefix(8))"
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

struct OfflineWorkCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var offlineStore: OfflineReportStore
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var assetStore: AssetStore
    @State private var isDownloadingCatalog = false
    @State private var catalogMessage: String?

    private var packages: [OfflineWorkPackage] {
        offlineStore.workPackagesByActivity.values.sorted { $0.downloadedAt > $1.downloadedAt }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(
                        offlineStore.isNetworkAvailable
                            ? "Puedes actualizar paquetes antes de salir a campo."
                            : "Los paquetes descargados siguen disponibles sin red.",
                        systemImage: offlineStore.isNetworkAvailable ? "arrow.down.circle" : "wifi.slash"
                    )
                    .font(.subheadline)
                } header: {
                    Text("Estado")
                }

                Section("Nuevo correctivo sin conexión") {
                    Text(offlineStore.correctiveCatalog == nil
                        ? "Descarga el catálogo de equipos y componentes para poder registrar correctivos en campo."
                        : "Catálogo disponible desde \(offlineStore.correctiveCatalog!.downloadedAt.formatted(date: .abbreviated, time: .shortened)).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await downloadCatalog() }
                    } label: {
                        if isDownloadingCatalog { ProgressView() }
                        else { Label("Descargar catálogo correctivo", systemImage: "externaldrive.badge.plus") }
                    }
                    .disabled(!offlineStore.isNetworkAvailable || isDownloadingCatalog)
                    if let catalogMessage {
                        Text(catalogMessage).font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Trabajos descargados") {
                    if packages.isEmpty {
                        ContentUnavailableView(
                            "Aún no hay trabajos descargados",
                            systemImage: "tray",
                            description: Text("Desde el detalle de un preventivo o correctivo elige Descargar trabajo."))
                    }
                    ForEach(packages) { package in
                        NavigationLink {
                            if package.editor.activityType == "PREVENTIVE" {
                                PreventiveReportFormView(activityID: package.activityID)
                            } else {
                                CorrectiveReportFormView(eventID: package.activityID)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(package.activityDetail.title).font(.headline)
                                Text(package.editor.activityType == "PREVENTIVE" ? "Preventivo" : "Correctivo")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BrandColor.red)
                                Text("Descargado \(package.downloadedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { indexes in
                        Task {
                            for index in indexes {
                                await offlineStore.removeWorkPackage(activityID: packages[index].activityID)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Trabajo offline")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await offlineStore.retryAll() }
                    } label: {
                        Label("Sincronizar", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(!offlineStore.isNetworkAvailable || offlineStore.isSynchronizing)
                }
            }
        }
    }

    @MainActor
    private func downloadCatalog() async {
        isDownloadingCatalog = true
        catalogMessage = nil
        defer { isDownloadingCatalog = false }
        do {
            try await offlineStore.downloadCorrectiveCatalog(session: session, assetStore: assetStore)
            catalogMessage = "Catálogo descargado. Ya puedes crear correctivos sin red."
        } catch {
            catalogMessage = error.localizedDescription
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

struct OfflineActivityDownloadMetadata: View {
    @EnvironmentObject private var offlineStore: OfflineReportStore
    let activity: APIActivity

    var body: some View {
        if offlineStore.workPackage(for: activity.id) != nil {
            HStack(spacing: AppSpacing.sm) {
            Label(estimatedSize, systemImage: "externaldrive")
            Text("Disponible sin conexión")
            Spacer()
            Image(systemName: "checkmark.icloud.fill")
                .foregroundStyle(BrandColor.green)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.top, 2)
        }
    }

    private var estimatedSize: String {
        let kilobytes = 180 + activity.assets.count * 90
        return "Aprox. \(kilobytes < 1024 ? "\(kilobytes) KB" : String(format: "%.1f MB", Double(kilobytes) / 1024))"
    }
}

struct OfflinePackageBatchPanel: View {
    @EnvironmentObject private var offlineStore: OfflineReportStore
    let selectedCount: Int
    let onCancel: () -> Void
    let onDownload: () -> Void

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Preparar trabajo offline",
                    subtitle: selectedCount == 0
                        ? "Marca uno o varios trabajos de la lista"
                        : "\(selectedCount) trabajo(s) seleccionado(s)"
                )
                if let progress = offlineStore.downloadProgress {
                    ProgressView(value: progress.fraction) {
                        Text("Descargando \(progress.completed) de \(progress.total)")
                    }
                    if !progress.failedTitles.isEmpty {
                        Text("No se pudieron descargar: \(progress.failedTitles.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(BrandColor.red)
                    }
                }
                if !offlineStore.lastDownloadFailedTitles.isEmpty {
                    Text("Pendiente de reintento: \(offlineStore.lastDownloadFailedTitles.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(BrandColor.red)
                }
                ActionButtonGrid {
                    Button("Cancelar", action: onCancel)
                        .buttonStyle(ActionTileButtonStyle())
                        .disabled(offlineStore.downloadProgress != nil)
                    Button(action: onDownload) {
                        Label("Descargar seleccionados", systemImage: "arrow.down.circle.fill")
                    }
                    .buttonStyle(ActionTileButtonStyle(prominent: true))
                    .disabled(selectedCount == 0 || !offlineStore.isNetworkAvailable || offlineStore.downloadProgress != nil)
                }
            }
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

    var isMissingServerResource: Bool {
        guard let apiError = self as? APIClient.APIError,
              case let .serverError(message) = apiError else {
            return false
        }
        let normalized = message.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale.current
        )
        return normalized.contains("no encontrada")
            || normalized.contains("not found")
            || normalized.contains("404")
    }
}
