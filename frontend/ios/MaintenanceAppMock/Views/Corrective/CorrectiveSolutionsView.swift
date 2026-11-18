import CryptoKit
import SwiftUI

struct SolutionAsset: Codable, Identifiable {
    let id: String
    let name: String
    let code: String
    let type_key: String
    let part_number: String?
}

struct SolutionAction: Codable, Identifiable {
    let id: String
    let name: String?
    let description: String?
    let started_at: String?
    let ended_at: String?
    let replacement: SolutionReplacement?
    let notes: String?
}

struct SolutionReplacement: Codable, Identifiable {
    let record_id: String?
    let removed_asset_id: String?
    let installed_asset_id: String?
    let source_description: String?
    let destination_description: String?
    let reason: String?
    var id: String { record_id ?? [removed_asset_id, installed_asset_id, reason].compactMap { $0 }.joined(separator: "|") }
}

struct SolutionEvidence: Codable, Identifiable {
    let id: String
    let title: String
    let url: String
    let media_type: String?
    let size_bytes: Int?
}

struct SolutionSource: Codable, Identifiable {
    let id: String
    let report_id: String
    let report_number: Int
    let version: Int
    let shift: String?
    let date: String
    let finalized: Bool
    let principal: Bool
    let searchable: Bool
    let symptom: String?
    let description: String?
    let analysis: String?
    let impact: String?
    let actions: [SolutionAction]
    let tests: String?
    let validation: String?
    let service_released: Bool
    let technical_status: String?
    let conclusion: String?
    let additional_comments: String?
    let evidence: [SolutionEvidence]
    let replacements: [SolutionReplacement]
}

struct SolutionComment: Codable, Identifiable {
    let id: String
    let text: String
    let date: String
    let provisional: Bool
}

struct SolutionCase: Codable, Identifiable {
    let id: String
    let activity_id: String?
    let code: String
    let sap_code: String
    let title: String
    let status: String
    let subsystem: String
    let date: String
    let location: String?
    let impact: String?
    var problem: String
    var actions_summary: String
    var tests_summary: String?
    var conclusion: String?
    let outcome: String
    let assets: [SolutionAsset]
    let asset_ids: [String]
    let type_keys: [String]
    var sources: [SolutionSource]
    var comments: [SolutionComment]
    let reasons: [String]
    var has_provisional: Bool
    var search_text: String

    func finalizedOnly() -> Self? {
        let final = sources.filter(\.finalized)
        guard !final.isEmpty else { return nil }
        var result = self
        result.sources = final
        result.comments = []
        result.has_provisional = false
        let principal = final.filter(\.principal)
        result.problem = principal.compactMap { $0.symptom ?? $0.description }.joined(separator: "\n")
        if result.problem.isEmpty { result.problem = "No documentado" }
        result.actions_summary = principal.flatMap(\.actions).compactMap { $0.description ?? $0.name }.joined(separator: "\n")
        result.tests_summary = principal.last?.tests
        result.conclusion = principal.last?.conclusion
        result.search_text = "\(title) \(code) \(sap_code) " + (String(data: (try? JSONEncoder().encode(principal)) ?? Data(), encoding: .utf8) ?? "")
        return result
    }

    var outcomeLabel: String {
        switch outcome {
        case "VALIDATED": "Liberación con validación documentada"
        case "PENDING": "Pendiente / evento activo"
        case "UNVALIDATED": "Sin validación suficiente documentada"
        default: "Sin reporte finalizado documentado"
        }
    }
}

struct SolutionSearchResponse: Decodable {
    let items: [SolutionCase]
    let total: Int
    let query: String
    let context_only: Bool
    let updated_at: String
    let subsystems: [String]
    let assets: [SolutionAsset]
    let suggestions: [String]?
    let revision: String?
}

struct SavedSolutionPackage: Codable, Identifiable {
    let id: String
    let label: String
    let savedAt: Date
    let cases: [SolutionCase]
}

@MainActor
final class SolutionLibrary: ObservableObject {
    @Published private(set) var packages: [SavedSolutionPackage] = []
    private(set) var scope = ""
    private var directory: URL?

    func clearVisible() {
        packages = []
        scope = ""
        directory = nil
    }

    var cases: [SolutionCase] {
        var byID: [String: SolutionCase] = [:]
        for package in packages.sorted(by: { $0.savedAt < $1.savedAt }) {
            for item in package.cases { byID[item.id] = item }
        }
        return byID.values.sorted { $0.date > $1.date }
    }

    func activate(_ value: String) throws {
        guard scope != value else { return }
        packages = []
        scope = value
        directory = nil
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let digest = SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
        var path = root.appendingPathComponent("CorrectiveSolutionLibrary").appendingPathComponent(digest)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try path.setResourceValues(values)
        directory = path
        let file = path.appendingPathComponent("packages.json")
        if FileManager.default.fileExists(atPath: file.path) {
            packages = try JSONDecoder().decode([SavedSolutionPackage].self, from: Data(contentsOf: file))
        }
    }

    func save(id: String, label: String, cases: [SolutionCase], expectedScope: String) throws {
        guard expectedScope == scope, let directory else { throw APIClient.APIError.unauthorized }
        var updated = packages.filter { $0.id != id }
        updated.append(SavedSolutionPackage(id: id, label: label, savedAt: Date(), cases: cases))
        try JSONEncoder().encode(updated).write(to: directory.appendingPathComponent("packages.json"),
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        packages = updated
    }

    func evidence(_ id: String) -> Data? {
        guard let directory else { return nil }
        return try? Data(contentsOf: directory.appendingPathComponent(evidenceKey(id)))
    }

    func saveEvidence(_ id: String, data: Data, expectedScope: String) throws {
        guard expectedScope == scope, let directory else { throw APIClient.APIError.unauthorized }
        guard data.count <= 20_000_000 else { throw APIClient.APIError.serverError("La evidencia supera 20 MB.") }
        try data.write(to: directory.appendingPathComponent(evidenceKey(id)),
                       options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func removeDownloads() throws {
        if let directory { try FileManager.default.removeItem(at: directory) }
        let previous = scope
        scope = ""
        try activate(previous)
    }

    private func evidenceKey(_ id: String) -> String {
        SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined() + ".evidence"
    }
}

struct CorrectiveSolutionsView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var offlineStore: OfflineReportStore
    @StateObject private var library = SolutionLibrary()
    let referenceID: String?
    @State private var query = ""
    @State private var subsystem = ""
    @State private var assetID = ""
    @State private var includeProvisional = true
    @State private var localOnly = false
    @State private var response: SolutionSearchResponse?
    @State private var page = 0
    @State private var loading = false
    @State private var downloading = false
    @State private var error: String?
    @State private var downloadMessage: String?
    @State private var selectedCase: SolutionCase?
    @State private var deleteDownloads = false

    init(referenceID: String? = nil, subsystem: String = "", assetID: String = "", initialQuery: String = "") {
        self.referenceID = referenceID
        _subsystem = State(initialValue: subsystem)
        _assetID = State(initialValue: assetID)
        _query = State(initialValue: String(initialQuery.prefix(1000)))
    }

    private var baseURL: String { UserDefaults.standard.string(forKey: "apiBaseURL") ?? "" }
    private var scope: String {
        let permissions = session.permissions.map { "\($0.key.rawValue):\($0.value.rawValue)" }.sorted().joined(separator: ",")
        return "\(session.currentUser?.id ?? "")|\(session.currentUser?.role.rawValue ?? "")|\(AppEnvironment.name)|\(baseURL)|\(permissions)"
    }
    private var isLocal: Bool { localOnly || !offlineStore.isNetworkAvailable }
    private var results: [SolutionCase] { isLocal ? localResults : response?.items ?? [] }
    private var total: Int { isLocal ? localResults.count : response?.total ?? 0 }
    private var availableAssets: [SolutionAsset] {
        if !isLocal { return response?.assets ?? [] }
        return Dictionary(library.cases.flatMap(\.assets).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            .values.sorted { $0.name < $1.name }
    }
    private var availableSubsystems: [String] {
        isLocal ? Array(Set(library.cases.map(\.subsystem))).sorted() : response?.subsystems ?? []
    }
    private var taskKey: String { "\(scope)|\(query)|\(subsystem)|\(assetID)|\(includeProvisional)|\(isLocal)|\(page)" }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Consulta de soluciones").font(.system(.largeTitle, design: .rounded).weight(.black))
                Text("Antecedentes documentales · búsqueda textual y contextual").font(.caption).foregroundStyle(.secondary)
                GlassPanel {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        TextField("Síntoma, alarma, código o acción realizada", text: $query)
                            .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        ViewThatFits(in: .horizontal) {
                            HStack { filters }
                            VStack(alignment: .leading) { filters }
                        }
                        Toggle("Incluir información provisional", isOn: $includeProvisional)
                        if let suggestions = response?.suggestions, !isLocal, !suggestions.isEmpty {
                            Text("Síntomas documentados").font(.caption).foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(suggestions, id: \.self) { suggestion in
                                        Button(suggestion) { query = suggestion }.buttonStyle(.bordered)
                                    }
                                }
                            }
                        }
                        Toggle("Solo antecedentes descargados", isOn: $localOnly)
                            .disabled(!offlineStore.isNetworkAvailable)
                        if referenceID != nil {
                            Button("Ampliar a otros equipos del subsistema", systemImage: "arrow.up.left.and.arrow.down.right") {
                                assetID = ""
                            }.buttonStyle(.bordered)
                        }
                    }
                }
                if isLocal {
                    Label("Consulta local: \(library.cases.count) fichas descargadas", systemImage: "wifi.slash")
                    DisclosureGroup("Cobertura descargada (\(library.packages.count) paquetes)") {
                        ForEach(library.packages) { package in
                            Text("\(package.label) · descargado \(package.savedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } else if response?.context_only == true {
                    Text("Antecedentes disponibles por contexto. No determinan la falla actual.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else if referenceID != nil && query.isEmpty, let effective = response?.query {
                    Text("Síntoma del evento: \(effective)").font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                }
                if let downloadMessage { Text(downloadMessage).font(.subheadline).foregroundStyle(.secondary) }
                if let error {
                    Text(error).foregroundStyle(BrandColor.red)
                    Button("Reintentar") { Task { await search() } }
                }
                if loading { ProgressView("Consultando antecedentes") }
                Text("\(total) antecedentes").font(.headline)
                if !loading && results.isEmpty {
                    ContentUnavailableView("Sin antecedentes relevantes", systemImage: "doc.text.magnifyingglass",
                        description: Text(isLocal ? "Solo se consulta la cobertura descargada en este iPad."
                            : "Cambia el síntoma o amplía los filtros. No hay una solución comprobada para esta consulta."))
                }
                ForEach(results) { item in
                    Button { selectedCase = item } label: { SolutionSummaryCard(item: item) }
                        .buttonStyle(.plain)
                }
                if !isLocal {
                    PaginationBar(currentPage: page, pageCount: max(1, (total + 19) / 20)) { page = $0 }
                }
            }
            .padding(AppSpacing.lg).frame(maxWidth: 1100).frame(maxWidth: .infinity)
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Consulta de soluciones").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button { Task { await download() } } label: {
                Label(downloading ? "Descargando" : "Descargar antecedentes", systemImage: "arrow.down.circle")
            }.disabled(downloading || isLocal || (subsystem.isEmpty && assetID.isEmpty))
            Menu {
                Button("Eliminar descargas", role: .destructive) { deleteDownloads = true }
            } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("Opciones de antecedentes")
        }
        .confirmationDialog("¿Eliminar antecedentes descargados de esta cuenta?", isPresented: $deleteDownloads) {
            Button("Eliminar descargas", role: .destructive) {
                do { try library.removeDownloads() } catch { self.error = error.localizedDescription }
            }
        }
        .task(id: taskKey) {
            if !query.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
            guard !Task.isCancelled else { return }
            await search()
        }
        .onChange(of: query) { page = 0 }
        .onChange(of: subsystem) { page = 0 }
        .onChange(of: assetID) { page = 0 }
        .onChange(of: includeProvisional) { page = 0 }
        .onChange(of: scope) { _, _ in
            library.clearVisible()
            response = nil
            selectedCase = nil
            error = nil
            downloadMessage = nil
        }
        .navigationDestination(item: $selectedCase) { item in
            SolutionCaseView(item: item, library: library, scope: scope)
        }
    }

    @ViewBuilder private var filters: some View {
        Picker("Subsistema", selection: $subsystem) {
            Text("Todos los subsistemas").tag("")
            ForEach(Array(Set(availableSubsystems + (subsystem.isEmpty ? [] : [subsystem]))).sorted(), id: \.self) { Text($0).tag($0) }
        }.pickerStyle(.menu)
        Picker("Equipo o componente", selection: $assetID) {
            Text("Todos los equipos y componentes").tag("")
            if !assetID.isEmpty && !availableAssets.contains(where: { $0.id == assetID }) {
                Text("Equipo del correctivo").tag(assetID)
            }
            ForEach(availableAssets) { Text("\($0.name) · \($0.code)").tag($0.id) }
        }.pickerStyle(.menu)
    }

    private func search() async {
        guard session.isAuthenticated && session.canView(.corrective) else {
            library.clearVisible()
            response = nil
            return
        }
        let currentScope = scope
        do { try library.activate(currentScope) } catch { self.error = error.localizedDescription; return }
        guard !isLocal else { error = nil; return }
        loading = true
        error = nil
        defer { loading = false }
        var parameters = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "subsystem", value: subsystem.isEmpty ? nil : subsystem),
            URLQueryItem(name: "asset_id", value: assetID.isEmpty ? nil : assetID),
            URLQueryItem(name: "include_provisional", value: String(includeProvisional)),
            URLQueryItem(name: "offset", value: String(page * 20))]
        if let referenceID { parameters.append(URLQueryItem(name: "similar_to", value: referenceID)) }
        parameters.removeAll { $0.value == nil }
        do {
            let result: SolutionSearchResponse = try await session.withValidAccessToken { token in
                try await APIClient(baseURLString: baseURL).get("api/v1/corrective-solutions/search",
                    bearerToken: token, queryItems: parameters)
            }
            guard !Task.isCancelled && currentScope == scope else { return }
            response = result
        } catch {
            guard !Task.isCancelled && currentScope == scope else { return }
            response = nil
            self.error = error.localizedDescription
        }
    }

    private func download() async {
        guard !downloading && session.canView(.corrective) && (!assetID.isEmpty || !subsystem.isEmpty) else { return }
        let expectedScope = scope
        let selectedAsset = assetID, selectedSubsystem = subsystem
        downloading = true
        defer { downloading = false }
        do {
            try library.activate(expectedScope)
            var items: [SolutionCase] = []
            var revision: String?
            while true {
                guard scope == expectedScope else { return }
                var parameters = [URLQueryItem(name: "offset", value: String(items.count)), URLQueryItem(name: "limit", value: "100")]
                if !selectedAsset.isEmpty { parameters.append(URLQueryItem(name: "asset_id", value: selectedAsset)) }
                if !selectedSubsystem.isEmpty { parameters.append(URLQueryItem(name: "subsystem", value: selectedSubsystem)) }
                if let revision { parameters.append(URLQueryItem(name: "revision", value: revision)) }
                let result: SolutionSearchResponse = try await session.withValidAccessToken { token in
                    try await APIClient(baseURLString: baseURL).get("api/v1/corrective-solutions/bundle", bearerToken: token, queryItems: parameters)
                }
                guard scope == expectedScope else { return }
                revision = result.revision
                items.append(contentsOf: result.items)
                if items.count >= result.total || result.items.isEmpty { break }
            }
            let label = availableAssets.first { $0.id == selectedAsset }?.name ?? selectedSubsystem
            try library.save(id: "\(selectedSubsystem)|\(selectedAsset)", label: label, cases: items, expectedScope: expectedScope)
            downloadMessage = "\(items.count) fichas descargadas. Las evidencias se guardan individualmente desde su vista."
        } catch { self.error = error.localizedDescription }
    }

    private var localResults: [SolutionCase] {
        guard library.scope == scope && session.canView(.corrective) else { return [] }
        let words = solutionLocalWords(query)
        return library.cases.compactMap { includeProvisional ? $0 : $0.finalizedOnly() }.filter { item in
            (referenceID == nil || (item.id != referenceID && item.activity_id != referenceID))
                && (subsystem.isEmpty || item.subsystem == subsystem)
                && (assetID.isEmpty || item.asset_ids.contains(assetID))
                && !solutionPolarityMismatch(query, item.problem)
                && (words.isEmpty || !words.isDisjoint(with: solutionLocalWords(item.search_text)))
        }.sorted { a, b in
            let ac = words.intersection(solutionLocalWords(a.search_text)).count
            let bc = words.intersection(solutionLocalWords(b.search_text)).count
            return ac == bc ? a.date > b.date : ac > bc
        }
    }
}

extension SolutionCase: Hashable {
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

private func solutionLocalWords(_ value: String) -> Set<String> {
    let text = solutionCanonical(value)
    let stop = Set(["de", "del", "el", "la", "los", "las", "un", "una", "en", "por", "para", "con", "que", "se", "al", "y", "o", "es"])
    return Set(text.components(separatedBy: .alphanumerics.inverted).filter { !$0.isEmpty && !stop.contains($0) })
}

private func solutionCanonical(_ value: String) -> String {
    var text = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
    for (phrase, canonical) in [("por ratos", "intermitencia"), ("a veces", "intermitencia"),
        ("intermitente", "intermitencia"), ("enlace", "comunicacion"), ("conexion", "comunicacion"),
        ("energia", "alimentacion")] {
        text = text.replacingOccurrences(of: "\\b" + phrase + "\\b", with: canonical, options: .regularExpression)
    }
    return text
}

private func solutionPolarityMismatch(_ query: String, _ problem: String) -> Bool {
    let q = solutionCanonical(query), p = solutionCanonical(problem)
    for topic in ["alimentacion", "comunicacion", "tension", "senal"] {
        let negative = "(?:sin|no hay|ausencia de|falta de)\\s+" + topic
        let positive = topic + "\\s+(?:correcta|correcto|normal|presente|estable)"
        let qn = q.range(of: negative, options: .regularExpression) != nil
        let pn = p.range(of: negative, options: .regularExpression) != nil
        let qp = q.range(of: positive, options: .regularExpression) != nil
        let pp = p.range(of: positive, options: .regularExpression) != nil
        if (qn && pp && !pn) || (qp && pn && !pp) { return true }
    }
    return false
}

private struct SolutionSummaryCard: View {
    let item: SolutionCase
    var body: some View {
        ContentGlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(item.title).font(.headline)
                Text("\(item.code) · \(item.subsystem) · \(item.date)").font(.caption).foregroundStyle(.secondary)
                if let location = item.location { Text(location).font(.caption).foregroundStyle(.secondary) }
                Text(item.outcomeLabel).font(.subheadline.weight(.semibold))
                    .foregroundStyle(item.outcome == "VALIDATED" ? .green : .secondary)
                if item.has_provisional { Label("Incluye información provisional", systemImage: "clock").font(.caption) }
                summary("Problema", item.problem)
                summary("Acciones documentadas", item.actions_summary)
                summary("Comprobación", item.tests_summary)
                Text(item.reasons.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                Label("Ver ficha y fuentes", systemImage: "chevron.right").font(.subheadline).foregroundStyle(BrandColor.red)
            }
        }
    }
    private func summary(_ title: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(value.flatMap { $0.isEmpty ? nil : $0 } ?? "No documentado").font(.subheadline).lineLimit(3)
        }
    }
}

private struct SolutionCaseView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var offlineStore: OfflineReportStore
    let item: SolutionCase
    @ObservedObject var library: SolutionLibrary
    let scope: String
    @State private var showPrevious = false
    @State private var error: String?
    @State private var message: String?
    @State private var selectedEvidence: SolutionEvidence?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SolutionSummaryCard(item: item)
                Text("Antecedente documental, no procedimiento revisado para reutilización.")
                    .font(.caption).foregroundStyle(.secondary)
                if let error { Text(error).foregroundStyle(BrandColor.red) }
                if let message { Text(message).foregroundStyle(.secondary) }
                if offlineStore.isNetworkAvailable, let activityID = item.activity_id {
                    NavigationLink("Abrir evento de origen") { CorrectiveDetailView(eventID: activityID) }
                }
                Toggle("Mostrar versiones anteriores", isOn: $showPrevious)
                ForEach(item.sources.filter { showPrevious || $0.searchable }) { source in
                    ContentGlassPanel {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("Reporte \(source.report_number) · Versión \(source.version)").font(.title3.bold())
                            Text(sourceLabel(source))
                                .font(.caption).foregroundStyle(.secondary)
                            if offlineStore.isNetworkAvailable {
                                NavigationLink {
                                    PDFPreviewView(versionID: source.id)
                                } label: {
                                    Label("Abrir versión de origen", systemImage: "doc.text.magnifyingglass")
                                }
                            }
                            field("Problema", source.symptom)
                            field("Descripción técnica", source.description)
                            field("Impacto operativo", source.impact)
                            field("Análisis registrado", source.analysis)
                            Text("Acciones documentadas").font(.headline)
                            if source.actions.isEmpty { Text("No documentado").foregroundStyle(.secondary) }
                            ForEach(Array(source.actions.enumerated()), id: \.element.id) { index, action in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(index + 1). \(action.name ?? "Acción")").font(.subheadline.bold())
                                    Text(action.description ?? "No documentado").font(.subheadline)
                                    if let notes = action.notes { Text(notes).font(.subheadline) }
                                    if let date = action.started_at { Text(date).font(.caption).foregroundStyle(.secondary) }
                                    if let replacement = action.replacement { replacementView(replacement) }
                                }
                            }
                            ForEach(source.replacements) { replacement in replacementView(replacement) }
                            field("Pruebas realizadas", source.tests)
                            field("Resultado de validación", source.validation)
                            field("Estado técnico", source.technical_status)
                            field("Conclusión documentada", source.conclusion)
                            field("Comentarios del reporte", source.additional_comments)
                            ForEach(source.evidence) { evidence in
                                Button(evidence.title, systemImage: "photo") { selectedEvidence = evidence }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                if !item.comments.isEmpty {
                    ContentGlassPanel {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Comentarios del evento · información provisional").font(.headline)
                            ForEach(item.comments) { comment in
                                Text(comment.text)
                                Text(comment.date).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }.padding(AppSpacing.lg).frame(maxWidth: 1100).frame(maxWidth: .infinity)
        }
        .background(MaintenanceScreenBackground()).navigationTitle("Ficha del antecedente")
        .toolbar {
            Button("Guardar ficha offline", systemImage: "arrow.down.circle") {
                do {
                    try library.save(id: "case:\(item.id)", label: item.code, cases: [item], expectedScope: scope)
                    message = "Ficha guardada en este iPad."
                } catch { self.error = error.localizedDescription }
            }
        }
        .sheet(item: $selectedEvidence) { evidence in
            SolutionEvidenceView(evidence: evidence, library: library, scope: scope)
        }
    }

    private func field(_ label: String, _ text: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.headline)
            Text(text.flatMap { $0.isEmpty ? nil : $0 } ?? "No documentado").textSelection(.enabled)
        }
    }
    private func sourceLabel(_ source: SolutionSource) -> String {
        var parts = [source.date, source.finalized ? "Finalizado" : "Provisional"]
        if let shift = source.shift { parts.insert(shift, at: 0) }
        parts.append(source.principal ? "Referencia principal" : source.searchable ? "Borrador reciente" : "Versión anterior")
        return parts.joined(separator: " · ")
    }
    private func replacementView(_ replacement: SolutionReplacement) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Reemplazo registrado").font(.subheadline.bold())
            Text("\(replacement.source_description ?? replacement.removed_asset_id ?? "No documentado") → \(replacement.destination_description ?? replacement.installed_asset_id ?? "No documentado")")
            Text(replacement.reason ?? "Motivo no documentado").font(.caption)
        }
    }
}

private struct SolutionEvidenceView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var offlineStore: OfflineReportStore
    @Environment(\.dismiss) private var dismiss
    let evidence: SolutionEvidence
    @ObservedObject var library: SolutionLibrary
    let scope: String
    @State private var data: Data?
    @State private var message: String?
    @State private var loading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                if let data, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity)
                } else if loading { ProgressView("Cargando evidencia") }
                if let message { Text(message).padding() }
            }
            .navigationTitle(evidence.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Guardar offline", systemImage: "arrow.down.circle") {
                        do {
                            if let data { try library.saveEvidence(evidence.id, data: data, expectedScope: scope) }
                            message = "Evidencia guardada en este iPad."
                        } catch { message = error.localizedDescription }
                    }.disabled(data == nil)
                }
            }
            .task {
                defer { loading = false }
                if let cached = library.evidence(evidence.id) { data = cached; return }
                guard offlineStore.isNetworkAvailable else { message = "Esta evidencia no fue descargada."; return }
                guard evidence.media_type?.hasPrefix("image/") == true else { message = "Consulta este adjunto en el reporte de origen."; return }
                guard (evidence.size_bytes ?? 0) <= 20_000_000 else { message = "La evidencia supera 20 MB."; return }
                do {
                    let result = try await session.withValidAccessToken { token in
                        try await APIClient(baseURLString: UserDefaults.standard.string(forKey: "apiBaseURL") ?? "")
                            .getData(evidence.url, bearerToken: token)
                    }
                    guard library.scope == scope && !Task.isCancelled else { return }
                    data = result
                } catch { message = error.localizedDescription }
            }
        }
    }
}
