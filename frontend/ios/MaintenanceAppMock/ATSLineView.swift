import Foundation
import SwiftUI

private struct ATSLineViewBox: Codable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var center: CGPoint {
        CGPoint(x: x + width / 2, y: y + height / 2)
    }
}

private struct ATSLineSegment: Codable, Identifiable, Equatable {
    let id: String
    let x1: Double
    let y1: Double
    let x2: Double
    let y2: Double
    let length: Double
    let track: String
    let lineSegment: String
    let startPK: Double
    let endPK: Double
    let previousIDs: [String]
    let nextIDs: [String]

    enum CodingKeys: String, CodingKey {
        case id, x1, y1, x2, y2, length, track
        case lineSegment = "line_segment"
        case startPK = "start_pk"
        case endPK = "end_pk"
        case previousIDs = "previous_ids"
        case nextIDs = "next_ids"
    }

    var midpoint: CGPoint {
        CGPoint(x: (x1 + x2) / 2, y: (y1 + y2) / 2)
    }
}

private struct ATSLineLinearObject: Codable, Identifiable, Equatable {
    let id: String
    let x1: Double
    let y1: Double
    let x2: Double
    let y2: Double
    let length: Double

    var midpoint: CGPoint {
        CGPoint(x: (x1 + x2) / 2, y: (y1 + y2) / 2)
    }
}

private struct ATSLinePlatform: Codable, Identifiable, Equatable {
    let id: String
    let x1: Double
    let y1: Double
    let x2: Double
    let y2: Double
    let length: Double
    let name: String
    let physicalLength: Double?
    let firstPK: Double?
    let secondPK: Double?

    enum CodingKeys: String, CodingKey {
        case id, x1, y1, x2, y2, length, name
        case physicalLength = "physical_length_m"
        case firstPK = "first_pk"
        case secondPK = "second_pk"
    }

    var midpoint: CGPoint {
        CGPoint(x: (x1 + x2) / 2, y: (y1 + y2) / 2)
    }
}

private struct ATSLinePointObject: Codable, Identifiable, Equatable {
    let id: String
    let x: Double
    let y: Double

    var point: CGPoint { CGPoint(x: x, y: y) }
}

private struct ATSLineStop: Codable, Identifiable, Equatable {
    let id: String
    let segmentID: String
    let x: Double
    let pk: Double?
    let track: String
    let atsID: Int?
    let atsType: String?
    let type: String

    enum CodingKeys: String, CodingKey {
        case id, x, pk, track, type
        case segmentID = "segment_id"
        case atsID = "ats_id"
        case atsType = "ats_type"
    }
}

private struct ATSLineTraversal: Codable, Equatable {
    let segmentID: String
    let xStart: Double
    let xEnd: Double
    let distance: Double?

    enum CodingKeys: String, CodingKey {
        case segmentID = "segment_id"
        case xStart = "x_start"
        case xEnd = "x_end"
        case distance
    }
}

private struct ATSLineCalibration: Codable, Identifiable, Equatable {
    let id: String
    let startBaliseID: String
    let endBaliseID: String
    let declaredDistance: Double?
    let calculatedDistance: Double?
    let traversed: [ATSLineTraversal]

    enum CodingKeys: String, CodingKey {
        case id, traversed
        case startBaliseID = "start_balise_id"
        case endBaliseID = "end_balise_id"
        case declaredDistance = "declared_distance"
        case calculatedDistance = "calculated_distance"
    }
}

private struct ATSLineTrack: Codable, Identifiable, Equatable {
    let id: String
    let area: String
    let type: String
    let controlName: String
    let startPK: Double?
    let endPK: Double?

    enum CodingKeys: String, CodingKey {
        case id, area, type
        case controlName = "control_name"
        case startPK = "start_pk"
        case endPK = "end_pk"
    }
}

private struct ATSLineObjectContext: Codable, Equatable {
    let category: String?
    let segmentID: String?
    let track: String?
    let x: Double?
    let pk: Double?

    enum CodingKeys: String, CodingKey {
        case category, track, x, pk
        case segmentID = "segment_id"
    }
}

private struct ATSLineData: Codable, Equatable {
    let source: String
    let mode: String
    let viewBox: ATSLineViewBox
    let segments: [ATSLineSegment]
    let tracks: [ATSLineLinearObject]
    let virtualBlocks: [ATSLineLinearObject]
    let tags: [ATSLinePointObject]
    let signals: [ATSLinePointObject]
    let platforms: [ATSLinePlatform]
    let bufferStops: [ATSLinePointObject]
    let switches: [ATSLinePointObject]
    let stoppingPoints: [ATSLineStop]
    let calibrationLinks: [ATSLineCalibration]
    let trackDefinitions: [ATSLineTrack]
    let objectContext: [String: ATSLineObjectContext]

    enum CodingKeys: String, CodingKey {
        case source, mode, segments, tracks, tags, signals, platforms, switches
        case viewBox = "view_box"
        case virtualBlocks = "virtual_blocks"
        case bufferStops = "buffer_stops"
        case stoppingPoints = "stopping_points"
        case calibrationLinks = "calibration_links"
        case trackDefinitions = "track_definitions"
        case objectContext = "object_context"
    }

    var segmentByID: [String: ATSLineSegment] {
        Dictionary(uniqueKeysWithValues: segments.map { ($0.id, $0) })
    }
}

private enum ATSLineJSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .boolean(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var displayValue: String {
        switch self {
        case .string(let value): value
        case .number(let value): value.formatted(.number.precision(.fractionLength(0...6)))
        case .boolean(let value): value ? "Sí" : "No"
        case .null: "—"
        }
    }
}

private struct ATSLineSourceField: Codable, Identifiable, Equatable {
    let column: Int
    let label: String
    let value: ATSLineJSONValue

    var id: Int { column }
}

private struct ATSLineObjectRecord: Codable, Identifiable, Equatable {
    let id: String
    let category: String
    let sourceSheet: String?
    let sourceRow: Int?
    let sourceFields: [ATSLineSourceField]

    enum CodingKeys: String, CodingKey {
        case id, category
        case sourceSheet = "source_sheet"
        case sourceRow = "source_row"
        case sourceFields = "source_fields"
    }
}

private struct ATSLineObjectResponse: Codable, Equatable {
    let id: String
    let items: [ATSLineObjectRecord]
}

private struct ATSLineDistanceRequest: Encodable {
    let originSegmentID: String
    let originX: Double
    let destinationSegmentID: String
    let destinationX: Double

    enum CodingKeys: String, CodingKey {
        case originSegmentID = "origin_segment_id"
        case originX = "origin_x"
        case destinationSegmentID = "destination_segment_id"
        case destinationX = "destination_x"
    }
}

private struct ATSLineDistanceResponse: Codable, Equatable {
    let possible: Bool
    let distance: Double?
    let direction: String?
    let traversed: [ATSLineTraversal]
    let reason: String?
}

private struct ATSLineService {
    let client: APIClient

    init(baseURL: String) {
        client = APIClient(baseURLString: baseURL)
    }

    func line(token: String) async throws -> ATSLineData {
        try await client.get("/api/v1/ats-line", bearerToken: token)
    }

    func object(id: String, token: String) async throws -> ATSLineObjectResponse {
        try await client.get(
            "/api/v1/ats-line/objects/\(id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id)",
            bearerToken: token
        )
    }

    func distance(
        from start: ATSLineMeasurePoint,
        to end: ATSLineMeasurePoint,
        token: String
    ) async throws -> ATSLineDistanceResponse {
        try await client.post(
            "/api/v1/ats-line/distance",
            body: ATSLineDistanceRequest(
                originSegmentID: start.segmentID,
                originX: start.x,
                destinationSegmentID: end.segmentID,
                destinationX: end.x
            ),
            bearerToken: token
        )
    }
}

private enum ATSLineScope: String, CaseIterable, Identifiable {
    case all = "Red completa"
    case main = "Vía principal"
    case yard = "Patio y enlaces"

    var id: String { rawValue }

    func includes(area: String) -> Bool {
        switch self {
        case .all: true
        case .main: area == "principal"
        case .yard: area != "principal"
        }
    }
}

private enum ATSLineLayer: String, CaseIterable, Identifiable {
    case segments = "Segmentos"
    case tags = "Balizas"
    case signals = "Señales"
    case platforms = "Plataformas"
    case switches = "Desvíos"
    case buffers = "Topes"
    case stops = "Paradas operacionales"
    case calibration = "Calibración"
    case labels = "Nombres"

    var id: String { rawValue }
}

private enum ATSLineSymbol: String, CaseIterable, Identifiable {
    case main = "Vía principal"
    case yard = "Patio"
    case links = "Enlaces"
    case tag = "Baliza"
    case signal = "Señal"
    case platform = "Plataforma"
    case turnout = "Desvío"
    case buffer = "Tope"
    case stop = "Parada operacional"
    case calibration = "Calibración"
    case selection = "Selección"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .main: Color(red: 0.08, green: 0.55, blue: 0.61)
        case .yard: Color(red: 0.23, green: 0.39, blue: 0.66)
        case .links: Color(red: 0.55, green: 0.34, blue: 0.66)
        case .tag: .cyan
        case .signal: Color(red: 0.87, green: 0.36, blue: 0.34)
        case .platform: BrandColor.green
        case .turnout: .indigo
        case .buffer: .brown
        case .stop, .calibration: BrandColor.amber
        case .selection: BrandColor.red
        }
    }

    func path(at center: CGPoint, scale: CGFloat) -> Path {
        func rect(_ halfWidth: CGFloat, _ halfHeight: CGFloat) -> CGRect {
            CGRect(x: center.x - halfWidth * scale, y: center.y - halfHeight * scale,
                   width: 2 * halfWidth * scale, height: 2 * halfHeight * scale)
        }
        switch self {
        case .tag: return Path(ellipseIn: rect(7, 7))
        case .stop: return Path(ellipseIn: rect(6, 6))
        case .signal:
            var path = Path()
            path.move(to: CGPoint(x: center.x, y: center.y - 9 * scale))
            path.addLine(to: CGPoint(x: center.x + 9 * scale, y: center.y + 7 * scale))
            path.addLine(to: CGPoint(x: center.x - 9 * scale, y: center.y + 7 * scale))
            path.closeSubpath()
            return path
        case .turnout: return Path(roundedRect: rect(7, 7), cornerRadius: 2 * scale)
        case .buffer: return Path(rect(9, 5))
        case .selection:
            return Path(ellipseIn: rect(12, 12)).strokedPath(StrokeStyle(lineWidth: 3 * scale))
        case .main, .yard, .links, .platform, .calibration:
            return Path(roundedRect: rect(11, 2.5), cornerRadius: 2.5 * scale)
        }
    }
}

private struct ATSLineSelection: Identifiable, Equatable {
    let id: String
    let kind: String
    let track: String?
    let segmentID: String?
    let x: Double?
    let pk: Double?
    let length: Double?
    let startPK: Double?
    let endPK: Double?
    let code: String?
    let extra: String?
    let point: CGPoint?
}

private struct ATSLineMeasurePoint: Equatable {
    let id: String
    let segmentID: String
    let x: Double
    let point: CGPoint
}

private struct ATSLineFocusRequest: Equatable {
    let serial: Int
    let point: CGPoint
}

private struct ATSLineCatalogItem: Identifiable, Equatable {
    let objectID: String
    let name: String
    let kind: String
    let track: String
    let location: String
    let selection: ATSLineSelection

    var id: String { "\(kind)-\(objectID)" }

    var searchText: String {
        "\(objectID) \(name) \(kind) \(track)".folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: .current
        )
    }
}

@MainActor
private final class ATSLineStore: ObservableObject {
    @Published private(set) var data: ATSLineData?
    @Published private(set) var isLoading = false
    @Published private(set) var isUsingCache = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var scope = ATSLineScope.all
    @Published var selectedKind = "Todos"
    @Published var layers: Set<ATSLineLayer> = [
        .segments, .tags, .signals, .platforms, .switches, .buffers, .stops,
    ]
    @Published var selection: ATSLineSelection?
    @Published private(set) var record: ATSLineObjectRecord?
    @Published private(set) var isLoadingRecord = false
    @Published var isMeasuring = false
    @Published private(set) var measureStart: ATSLineMeasurePoint?
    @Published private(set) var measureEnd: ATSLineMeasurePoint?
    @Published private(set) var distanceResult: ATSLineDistanceResponse?
    @Published private(set) var measurementError: String?
    @Published private(set) var catalogItems: [ATSLineCatalogItem] = []
    @Published var focusRequest: ATSLineFocusRequest?

    private var focusSerial = 0
    private var recordTask: Task<Void, Never>?
    private let cacheURL: URL

    init() {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        cacheURL = root.appendingPathComponent("ats-line/line.json")
    }

    var searchResults: [ATSLineCatalogItem] {
        let term = normalized(searchText)
        guard !term.isEmpty else { return [] }
        return Array(
            catalogItems
                .filter { $0.searchText.contains(term) }
                .sorted {
                    let firstExact = normalized($0.objectID) == term
                    let secondExact = normalized($1.objectID) == term
                    return firstExact != secondExact ? firstExact : $0.objectID < $1.objectID
                }
                .prefix(8)
        )
    }

    var filteredCatalogItems: [ATSLineCatalogItem] {
        let term = normalized(searchText)
        return catalogItems.filter { item in
            let kindMatches = selectedKind == "Todos" || item.kind == selectedKind
            let scopeMatches = trackAllowed(item.track)
            return kindMatches && scopeMatches
                && (term.isEmpty || item.searchText.contains(term))
        }
    }

    var availableKinds: [String] {
        ["Todos"] + Set(catalogItems.map(\.kind)).sorted()
    }

    func load(session: SessionStore) async {
        guard data == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await request(session: session) { service, token in
                try await service.line(token: token)
            }
            data = loaded
            catalogItems = buildCatalog(from: loaded)
            isUsingCache = false
            errorMessage = nil
            try? saveCache(loaded)
        } catch {
            if let cached = try? loadCache() {
                data = cached
                catalogItems = buildCatalog(from: cached)
                isUsingCache = true
                errorMessage = "Se muestran los últimos datos guardados en este iPad."
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func retry(session: SessionStore) async {
        data = nil
        await load(session: session)
    }

    func select(_ item: ATSLineSelection, session: SessionStore, focus: Bool = false) {
        selection = item
        record = nil
        if focus, let point = item.point {
            requestFocus(point)
        }
        if isMeasuring {
            registerMeasurement(item, session: session)
        }
        recordTask?.cancel()
        recordTask = Task { [weak self] in
            await self?.loadRecord(id: item.id, session: session)
        }
    }

    func locateFirstResult(session: SessionStore) {
        guard let item = searchResults.first else { return }
        select(item.selection, session: session, focus: true)
    }

    func toggleLayer(_ layer: ATSLineLayer) {
        if layers.contains(layer) {
            layers.remove(layer)
        } else {
            layers.insert(layer)
        }
    }

    func toggleMeasurement() {
        isMeasuring.toggle()
        clearMeasurement()
    }

    func clearMeasurement() {
        measureStart = nil
        measureEnd = nil
        distanceResult = nil
        measurementError = nil
    }

    func focusSelection() {
        guard let point = visibleSelection?.point else { return }
        requestFocus(point)
    }

    var visibleSelection: ATSLineSelection? {
        guard let selection else { return nil }
        if let track = selection.track ?? selection.segmentID.flatMap({ data?.segmentByID[$0]?.track }),
           !trackAllowed(track) { return nil }
        return selection
    }

    func trackAllowed(_ track: String) -> Bool {
        guard !track.isEmpty, track != "—" else { return true }
        return scope.includes(area: area(for: track))
    }

    func area(for track: String) -> String {
        data?.trackDefinitions.first(where: { $0.id == track })?.area
            ?? (track.hasPrefix("VIA") ? "principal" : track.hasPrefix("TK_") ? "patio" : "enlace")
    }

    func point(on segmentID: String, x: Double) -> CGPoint? {
        guard let segment = data?.segmentByID[segmentID] else { return nil }
        let ratio = segment.length > 0 ? min(1, max(0, x / segment.length)) : 0
        return CGPoint(
            x: segment.x1 + (segment.x2 - segment.x1) * ratio,
            y: segment.y1 + (segment.y2 - segment.y1) * ratio
        )
    }

    private func registerMeasurement(_ selection: ATSLineSelection, session: SessionStore) {
        guard let position = measurePoint(for: selection) else {
            measurementError = "El elemento no tiene una posición Xseg verificable."
            return
        }
        measurementError = nil
        if measureStart == nil || measureEnd != nil {
            measureStart = position
            measureEnd = nil
            distanceResult = nil
            return
        }
        guard let start = measureStart else { return }
        measureEnd = position
        Task {
            do {
                let result = try await request(session: session) { service, token in
                    try await service.distance(from: start, to: position, token: token)
                }
                distanceResult = result
                measurementError = result.possible ? nil : result.reason
            } catch {
                measurementError = error.localizedDescription
            }
        }
    }

    private func measurePoint(for selection: ATSLineSelection) -> ATSLineMeasurePoint? {
        guard let segmentID = selection.segmentID,
              let x = selection.x,
              let point = selection.point else { return nil }
        return ATSLineMeasurePoint(id: selection.id, segmentID: segmentID, x: x, point: point)
    }

    private func loadRecord(id: String, session: SessionStore) async {
        isLoadingRecord = true
        defer { isLoadingRecord = false }
        do {
            let response = try await request(session: session) { service, token in
                try await service.object(id: id, token: token)
            }
            guard !Task.isCancelled, selection?.id == id else { return }
            record = response.items.first
        } catch {
            guard !Task.isCancelled, selection?.id == id else { return }
            record = nil
        }
    }

    private func request<T>(
        session: SessionStore,
        operation: @escaping (ATSLineService, String) async throws -> T
    ) async throws -> T {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else {
            throw APIClient.APIError.invalidBaseURL
        }
        return try await session.withValidAccessToken { token in
            try await operation(ATSLineService(baseURL: baseURL), token)
        }
    }

    private func requestFocus(_ point: CGPoint) {
        focusSerial += 1
        focusRequest = ATSLineFocusRequest(serial: focusSerial, point: point)
    }

    private func buildCatalog(from data: ATSLineData) -> [ATSLineCatalogItem] {
        var items: [ATSLineCatalogItem] = []
        func context(_ id: String) -> ATSLineObjectContext? { data.objectContext[id] }
        func place(_ id: String) -> String {
            if let pk = context(id)?.pk { return "PK \(format(pk)) m" }
            if let x = context(id)?.x { return "X \(format(x)) m" }
            return "—"
        }
        func objectSelection(
            id: String,
            kind: String,
            point: CGPoint,
            length: Double? = nil,
            startPK: Double? = nil,
            endPK: Double? = nil,
            extra: String? = nil
        ) -> ATSLineSelection {
            let value = context(id)
            return ATSLineSelection(
                id: id,
                kind: kind,
                track: value?.track,
                segmentID: value?.segmentID,
                x: value?.x,
                pk: value?.pk,
                length: length,
                startPK: startPK,
                endPK: endPK,
                code: nil,
                extra: extra,
                point: point
            )
        }
        for segment in data.segments {
            let selection = segmentSelection(segment, fraction: 0.5)
            items.append(
                ATSLineCatalogItem(
                    objectID: segment.id,
                    name: segment.id,
                    kind: "Segmento",
                    track: segment.track,
                    location: "PK \(format(segment.startPK))–\(format(segment.endPK)) m",
                    selection: selection
                )
            )
        }
        for item in data.tags {
            let selection = objectSelection(id: item.id, kind: "Baliza", point: item.point)
            items.append(catalogItem(item.id, item.id, "Baliza", selection.track, place(item.id), selection))
        }
        for item in data.signals {
            let selection = objectSelection(id: item.id, kind: "Señal", point: item.point)
            items.append(catalogItem(item.id, item.id, "Señal", selection.track, place(item.id), selection))
        }
        for item in data.platforms {
            let selection = objectSelection(
                id: item.id,
                kind: "Plataforma",
                point: item.midpoint,
                length: item.physicalLength,
                startPK: item.firstPK,
                endPK: item.secondPK,
                extra: item.name
            )
            items.append(catalogItem(item.id, item.name, "Plataforma", selection.track, place(item.id), selection))
        }
        for item in data.stoppingPoints {
            guard let point = pointIn(data: data, segmentID: item.segmentID, x: item.x) else { continue }
            let selection = ATSLineSelection(
                id: item.id,
                kind: "Punto de parada",
                track: item.track,
                segmentID: item.segmentID,
                x: item.x,
                pk: item.pk,
                length: nil,
                startPK: nil,
                endPK: nil,
                code: item.atsID.map(String.init),
                extra: item.type,
                point: point
            )
            items.append(catalogItem(item.id, item.atsID.map { "ATS \($0)" } ?? item.id, "Punto de parada", item.track, item.pk.map { "PK \(format($0)) m" } ?? "X \(format(item.x)) m", selection))
        }
        for item in data.switches {
            let selection = objectSelection(id: item.id, kind: "Desvío", point: item.point)
            items.append(catalogItem(item.id, item.id, "Desvío", selection.track, place(item.id), selection))
        }
        for item in data.bufferStops {
            let selection = objectSelection(id: item.id, kind: "Tope", point: item.point)
            items.append(catalogItem(item.id, item.id, "Tope", selection.track, place(item.id), selection))
        }
        for item in data.trackDefinitions {
            let segments = data.segments.filter { $0.track == item.id }
            guard let first = segments.first else { continue }
            let selection = ATSLineSelection(
                id: item.id,
                kind: "Vía",
                track: item.id,
                segmentID: nil,
                x: nil,
                pk: nil,
                length: segments.reduce(0) { $0 + $1.length },
                startPK: item.startPK,
                endPK: item.endPK,
                code: item.controlName,
                extra: item.type,
                point: first.midpoint
            )
            items.append(catalogItem(item.id, item.id, "Vía", item.id, item.area, selection))
        }
        for item in data.calibrationLinks {
            guard let first = item.traversed.first,
                  let point = pointIn(
                    data: data,
                    segmentID: first.segmentID,
                    x: (first.xStart + first.xEnd) / 2
                  ) else { continue }
            let selection = ATSLineSelection(
                id: item.id,
                kind: "Base de calibración",
                track: nil,
                segmentID: nil,
                x: nil,
                pk: nil,
                length: item.calculatedDistance,
                startPK: nil,
                endPK: nil,
                code: item.declaredDistance.map(format),
                extra: "\(item.startBaliseID) → \(item.endBaliseID)",
                point: point
            )
            items.append(catalogItem(item.id, selection.extra ?? item.id, "Calibración", nil, item.calculatedDistance.map { "\(format($0)) m" } ?? "—", selection))
        }
        return items.sorted { $0.kind == $1.kind ? $0.objectID < $1.objectID : $0.kind < $1.kind }
    }

    private func segmentSelection(_ item: ATSLineSegment, fraction: Double) -> ATSLineSelection {
        let clamped = min(1, max(0, fraction))
        let x = item.length * clamped
        let pk = item.startPK + (item.endPK >= item.startPK ? x : -x)
        return ATSLineSelection(
            id: item.id,
            kind: "Segmento de vía",
            track: item.track,
            segmentID: item.id,
            x: x,
            pk: pk,
            length: item.length,
            startPK: item.startPK,
            endPK: item.endPK,
            code: item.lineSegment,
            extra: "Conecta con \((item.previousIDs + item.nextIDs).joined(separator: ", "))",
            point: CGPoint(
                x: item.x1 + (item.x2 - item.x1) * clamped,
                y: item.y1 + (item.y2 - item.y1) * clamped
            )
        )
    }

    private func catalogItem(
        _ id: String,
        _ name: String,
        _ kind: String,
        _ track: String?,
        _ location: String,
        _ selection: ATSLineSelection
    ) -> ATSLineCatalogItem {
        ATSLineCatalogItem(
            objectID: id,
            name: name,
            kind: kind,
            track: track ?? "—",
            location: location,
            selection: selection
        )
    }

    private func pointIn(data: ATSLineData, segmentID: String, x: Double) -> CGPoint? {
        guard let segment = data.segmentByID[segmentID] else { return nil }
        let ratio = segment.length > 0 ? min(1, max(0, x / segment.length)) : 0
        return CGPoint(
            x: segment.x1 + (segment.x2 - segment.x1) * ratio,
            y: segment.y1 + (segment.y2 - segment.y1) * ratio
        )
    }

    private func saveCache(_ data: ATSLineData) throws {
        try FileManager.default.createDirectory(
            at: cacheURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoded = try JSONEncoder().encode(data)
        try encoded.write(to: cacheURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private func loadCache() throws -> ATSLineData {
        try JSONDecoder().decode(ATSLineData.self, from: Data(contentsOf: cacheURL))
    }

    private func normalized(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

struct ATSLineView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var store = ATSLineStore()
    @State private var presentedSheet: ATSLineSheet?
    @State private var isWideLayout = true

    var body: some View {
        ZStack {
            MaintenanceScreenBackground()
            GeometryReader { proxy in
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    header
                    if let data = store.data {
                        controls
                        workspace(data: data, isWide: proxy.size.width >= 920)
                    } else if store.isLoading {
                        loadingState
                    } else {
                        errorState
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.sm)
            }
        }
        .navigationTitle("Línea ATS")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $store.searchText, prompt: "Segmento, baliza, señal, vía o ID ATS")
        .searchSuggestions {
            ForEach(store.searchResults) { item in
                Button {
                    choose(item.selection, focus: true)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                        Text("\(item.kind) · \(item.objectID)\(item.track == "—" ? "" : " · \(item.track)")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onSubmit(of: .search) {
            store.locateFirstResult(session: session)
            presentDetailIfNeeded()
        }
        .task { await store.load(session: session) }
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.size.width >= 920
        } action: { isWide in
            isWideLayout = isWide
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .detail:
                NavigationStack {
                    ATSLineInspector(store: store)
                        .navigationTitle("Detalle del elemento")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Cerrar") { presentedSheet = nil }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            case .catalog:
                ATSLineCatalogSheet(store: store) { item in
                    choose(item.selection, focus: true)
                    presentedSheet = isWideLayout ? nil : .detail
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Línea y patio")
                    .font(.largeTitle.bold())
                Text("Explora la topología ATS y consulta cada elemento de la red")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: AppSpacing.sm)
            if let data = store.data {
                Label("\(data.segments.count) segmentos · \(data.trackDefinitions.count) vías", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColor.graphite)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 8)
                    .background(BrandColor.railMist, in: Capsule())
            }
        }
        .padding(.top, AppSpacing.xs)
    }

    private var controls: some View {
        GlassPanel {
            VStack(spacing: AppSpacing.sm) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppSpacing.sm) {
                        scopePicker
                            .frame(width: 360)
                        actionRow
                    }
                    VStack(spacing: AppSpacing.xs) {
                        scopePicker
                        ViewThatFits(in: .horizontal) {
                            actionRow
                            ScrollView(.horizontal) { actionRow }
                                .scrollIndicators(.hidden)
                        }
                    }
                }
                if store.isUsingCache || store.errorMessage != nil {
                    Label(
                        store.errorMessage ?? "Datos guardados disponibles",
                        systemImage: store.isUsingCache ? "wifi.slash" : "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(store.isUsingCache ? BrandColor.amber : BrandColor.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var scopePicker: some View {
        Picker("Zona", selection: $store.scope) {
            ForEach(ATSLineScope.allCases) { scope in
                Text(scope.rawValue).tag(scope)
            }
        }
        .pickerStyle(.segmented)
    }

    private var actionRow: some View {
        HStack(spacing: AppSpacing.xs) {
            actionControls
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var actionControls: some View {
        Menu {
            ForEach(ATSLineLayer.allCases) { layer in
                Button {
                    store.toggleLayer(layer)
                } label: {
                    Label(layer.rawValue, systemImage: store.layers.contains(layer) ? "checkmark.circle.fill" : "circle")
                }
            }
        } label: {
            Label("Capas", systemImage: "square.3.layers.3d")
        }
        .buttonStyle(.bordered)

        Button {
            presentedSheet = .catalog
        } label: {
            Label("Catálogo", systemImage: "list.bullet.rectangle")
        }
        .buttonStyle(.bordered)

        Button {
            store.toggleMeasurement()
        } label: {
            Label(store.isMeasuring ? "Salir de medición" : "Medir", systemImage: "ruler")
        }
        .buttonStyle(.borderedProminent)
        .tint(store.isMeasuring ? BrandColor.red : BrandColor.graphite)
    }

    private func workspace(data: ATSLineData, isWide: Bool) -> some View {
        Group {
            if isWide {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    mapPanel(data: data)
                    ATSLineInspector(store: store)
                        .frame(width: 320)
                }
            } else {
                mapPanel(data: data)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func mapPanel(data: ATSLineData) -> some View {
        ContentGlassPanel {
            VStack(spacing: AppSpacing.xs) {
                ZStack(alignment: .topLeading) {
                    ATSLineCanvas(
                        data: data,
                        scope: store.scope,
                        layers: store.layers,
                        selection: store.visibleSelection,
                        measureStart: store.measureStart,
                        measureEnd: store.measureEnd,
                        distanceResult: store.distanceResult,
                        focusRequest: store.focusRequest,
                        areaForTrack: store.area(for:),
                        onSelect: { selection in choose(selection, focus: false) }
                    )
                    if store.isMeasuring {
                        measurementBanner
                            .padding(AppSpacing.sm)
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), alignment: .leading)], spacing: 6) {
                    ForEach(ATSLineSymbol.allCases) { symbol in
                        Label {
                            Text(symbol.rawValue)
                        } icon: {
                            symbol.path(at: CGPoint(x: 9, y: 9), scale: 0.7)
                                .fill(symbol.color)
                                .frame(width: 18, height: 18)
                                .accessibilityHidden(true)
                        }
                    }
                    if store.isMeasuring {
                        Label("Medición (A y B)", systemImage: "ruler")
                            .foregroundStyle(BrandColor.red)
                    }
                }
                HStack(spacing: AppSpacing.sm) {
                    Text("Plano esquemático · las medidas proceden de DC SYS")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if store.visibleSelection?.point != nil {
                        Button("Centrar selección", systemImage: "scope") {
                            store.focusSelection()
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .font(.caption)
            }
        }
    }

    private var measurementBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Medición sobre la vía")
                .font(.caption.bold())
            if let start = store.measureStart {
                Text("A · \(start.id) · X \(format(start.x)) m")
            } else {
                Text("Selecciona el punto de origen")
            }
            if let end = store.measureEnd {
                Text("B · \(end.id) · X \(format(end.x)) m")
            }
            if let result = store.distanceResult, let distance = result.distance {
                Text("\(format(distance)) m")
                    .font(.headline)
                    .foregroundStyle(BrandColor.red)
            } else if let error = store.measurementError {
                Text(error).foregroundStyle(BrandColor.red)
            }
        }
        .font(.caption)
        .padding(AppSpacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(BrandColor.red.opacity(0.22)) }
    }

    private var loadingState: some View {
        GlassPanel {
            VStack(spacing: AppSpacing.md) {
                ProgressView()
                Text("Cargando topología ATS…")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    private var errorState: some View {
        ContentUnavailableView {
            Label("No se pudo cargar la línea", systemImage: "point.3.connected.trianglepath.dotted")
        } description: {
            Text(store.errorMessage ?? "Verifica que el backend tenga disponible la base portable ATS.")
        } actions: {
            Button("Reintentar") {
                Task { await store.retry(session: session) }
            }
            .buttonStyle(.borderedProminent)
            .tint(BrandColor.red)
        }
        .frame(maxHeight: .infinity)
    }

    private func choose(_ selection: ATSLineSelection, focus: Bool) {
        store.select(selection, session: session, focus: focus)
        presentDetailIfNeeded()
    }

    private func presentDetailIfNeeded() {
        if !isWideLayout { presentedSheet = .detail }
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

private enum ATSLineSheet: String, Identifiable {
    case detail
    case catalog

    var id: String { rawValue }
}

private struct ATSLineInspector: View {
    @ObservedObject var store: ATSLineStore

    var body: some View {
        ContentGlassPanel {
            if let selection = store.selection {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(selection.kind.uppercased())
                                    .font(.caption2.bold())
                                    .foregroundStyle(BrandColor.red)
                                Text(selection.id)
                                    .font(.title3.bold())
                                    .textSelection(.enabled)
                            }
                            Spacer()
                            Image(systemName: symbol(for: selection.kind))
                                .font(.title2)
                                .foregroundStyle(BrandColor.red)
                                .frame(width: 44, height: 44)
                                .background(BrandColor.redSubtle, in: RoundedRectangle(cornerRadius: 8))
                        }

                        section(title: "Ubicación") {
                            value("Vía / TK", selection.track)
                            value("Segmento", selection.segmentID)
                            value("Posición Xseg", selection.x.map { "\(format($0)) m" })
                            value("PK", selection.pk.map { "\(format($0)) m" })
                        }

                        section(title: "Medidas e identificadores") {
                            value("Longitud", selection.length.map { "\(format($0)) m" })
                            value("PK inicial", selection.startPK.map { "\(format($0)) m" })
                            value("PK final", selection.endPK.map { "\(format($0)) m" })
                            value("Código", selection.code)
                            value("Información adicional", selection.extra)
                        }

                        Divider()
                        if store.isLoadingRecord {
                            HStack {
                                ProgressView().controlSize(.small)
                                Text("Consultando datos originales…")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        } else if let record = store.record {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                HStack {
                                    Text("Fuente original · DC SYS")
                                        .font(.headline)
                                    Spacer()
                                    Text([record.sourceSheet, record.sourceRow.map { "fila \($0)" }].compactMap { $0 }.joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                ForEach(record.sourceFields) { field in
                                    value(field.label, field.value.displayValue)
                                }
                            }
                        } else {
                            Text("Este elemento no tiene una fila vinculada en el catálogo importado.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Detalle del elemento",
                    systemImage: "scope",
                    description: Text("Selecciona una vía o elemento del plano para consultar su información.")
                )
            }
        }
    }

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            content()
        }
    }

    @ViewBuilder
    private func value(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 7)
            .overlay(alignment: .bottom) { Divider() }
        }
    }

    private func symbol(for kind: String) -> String {
        switch kind {
        case "Baliza": "dot.radiowaves.left.and.right"
        case "Señal": "lightspectrum.horizontal"
        case "Plataforma": "tram.fill"
        case "Punto de parada": "mappin.and.ellipse"
        case "Desvío": "arrow.triangle.branch"
        case "Calibración", "Base de calibración": "ruler"
        default: "point.3.connected.trianglepath.dotted"
        }
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

private struct ATSLineCatalogSheet: View {
    @ObservedObject var store: ATSLineStore
    let onSelect: (ATSLineCatalogItem) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(store.filteredCatalogItems) { item in
                Button {
                    onSelect(item)
                    dismiss()
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "scope")
                            .foregroundStyle(BrandColor.red)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("\(item.kind) · \(item.objectID)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(item.track)
                            Text(item.location)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Catálogo de línea")
            .searchable(text: $store.searchText, prompt: "Buscar elemento")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(store.availableKinds, id: \.self) { kind in
                            Button(kind) { store.selectedKind = kind }
                        }
                    } label: {
                        Label(store.selectedKind, systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}

private struct ATSLineMapTransform {
    let world: ATSLineViewBox
    let size: CGSize
    let zoom: CGFloat
    let pan: CGSize

    var baseScale: CGFloat {
        min(
            size.width / max(CGFloat(world.width), 1),
            size.height / max(CGFloat(world.height), 1)
        ) * 0.94
    }

    var scale: CGFloat { baseScale * zoom }

    // Use diagram units like the original SVG, with limits for iPad readability.
    func drawingSize(_ units: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        min(maximum, max(minimum, units * scale))
    }

    func screen(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: size.width / 2 + (point.x - world.center.x) * scale + pan.width,
            y: size.height / 2 + (point.y - world.center.y) * scale + pan.height
        )
    }
}

private struct ATSLineCanvas: View {
    let data: ATSLineData
    let scope: ATSLineScope
    let layers: Set<ATSLineLayer>
    let selection: ATSLineSelection?
    let measureStart: ATSLineMeasurePoint?
    let measureEnd: ATSLineMeasurePoint?
    let distanceResult: ATSLineDistanceResponse?
    let focusRequest: ATSLineFocusRequest?
    let areaForTrack: (String) -> String
    let onSelect: (ATSLineSelection) -> Void

    @State private var zoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @GestureState private var gestureZoom: CGFloat = 1
    @GestureState private var gesturePan: CGSize = .zero

    private var fittedWorld: ATSLineViewBox {
        if scope == .all { return data.viewBox }

        let segments = data.segments.filter(trackAllowed)
        let ids = Set(segments.map(\.id))
        var points = segments.flatMap {
            [CGPoint(x: $0.x1, y: $0.y1), CGPoint(x: $0.x2, y: $0.y2)]
        }
        for item in data.platforms where objectAllowed(item.id, visibleIDs: ids) {
            points.append(CGPoint(x: item.x1, y: item.y1))
            points.append(CGPoint(x: item.x2, y: item.y2))
        }
        for items in [data.tags, data.signals, data.switches, data.bufferStops] {
            points.append(contentsOf: items.lazy.filter { objectAllowed($0.id, visibleIDs: ids) }.map(\.point))
        }
        guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
              let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() else {
            return data.viewBox
        }
        let padding = max(60, max(maxX - minX, maxY - minY) * 0.035)
        return ATSLineViewBox(x: minX - padding, y: minY - padding,
                              width: maxX - minX + 2 * padding, height: maxY - minY + 2 * padding)
    }

    var body: some View {
        let world = fittedWorld
        GeometryReader { proxy in
            let effectiveZoom = min(24, max(1, zoom * gestureZoom))
            let effectivePan = CGSize(
                width: pan.width + gesturePan.width,
                height: pan.height + gesturePan.height
            )
            let transform = ATSLineMapTransform(
                world: world,
                size: proxy.size,
                zoom: effectiveZoom,
                pan: effectivePan
            )
            Canvas { context, size in
                draw(context: &context, size: size, transform: transform)
            }
            .background(Color(red: 0.976, green: 0.988, blue: 0.994))
            .contentShape(Rectangle())
            .clipShape(.rect(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(BrandColor.railMist, lineWidth: 1) }
            .gesture(
                DragGesture(minimumDistance: 8)
                    .updating($gesturePan) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        pan.width += value.translation.width
                        pan.height += value.translation.height
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .updating($gestureZoom) { value, state, _ in state = value.magnification }
                    .onEnded { value in zoom = min(24, max(1, zoom * value.magnification)) }
            )
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        if let selection = hitTest(at: value.location, transform: transform) {
                            onSelect(selection)
                        }
                    }
            )
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 4) {
                    mapButton("minus", label: "Alejar") { zoom = max(1, zoom / 1.45) }
                    mapButton("arrow.up.left.and.arrow.down.right", label: "Ajustar vista") {
                        resetViewport()
                    }
                    mapButton("plus", label: "Acercar") { zoom = min(24, zoom * 1.45) }
                }
                .padding(6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(AppSpacing.sm)
            }
            .onChange(of: world) { resetViewport() }
            .onChange(of: focusRequest) { _, request in
                guard let request else { return }
                let targetZoom: CGFloat = 6
                let scale = transform.baseScale * targetZoom
                zoom = targetZoom
                pan = CGSize(
                    width: (world.center.x - request.point.x) * scale,
                    height: (world.center.y - request.point.y) * scale
                )
            }
        }
        .frame(minHeight: 360)
    }

    private func resetViewport() {
        zoom = 1
        pan = .zero
    }

    private func mapButton(
        _ symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func draw(
        context: inout GraphicsContext,
        size: CGSize,
        transform: ATSLineMapTransform
    ) {
        let visibleSegments = data.segments.filter(trackAllowed)
        let visibleIDs = Set(visibleSegments.map(\.id))
        let strokeScale = transform.drawingSize(8, minimum: 0.8, maximum: 4)
        let symbolScale = transform.drawingSize(1, minimum: 0.09, maximum: 1)
        let bounds = CGRect(origin: .zero, size: size)
        var labelBounds: [CGRect] = []
        var labels: [(String, CGPoint)] = []
        if layers.contains(.segments) {
            for segment in visibleSegments {
                let path = linePath(
                    from: transform.screen(CGPoint(x: segment.x1, y: segment.y1)),
                    to: transform.screen(CGPoint(x: segment.x2, y: segment.y2))
                )
                context.stroke(
                    path,
                    with: .color(segmentColor(segment.track)),
                    style: StrokeStyle(lineWidth: selection?.id == segment.id ? max(3, strokeScale * 1.7) : strokeScale, lineCap: .round)
                )
                if layers.contains(.labels), transform.zoom >= 2.2 {
                    labels.append((segment.id, transform.screen(segment.midpoint)))
                }
            }
        }
        if let result = distanceResult, result.possible {
            for traversal in result.traversed where visibleIDs.contains(traversal.segmentID) {
                drawTraversal(traversal, color: BrandColor.red, width: 8, context: &context, transform: transform)
            }
        }
        if layers.contains(.platforms) {
            for item in data.platforms where objectAllowed(item.id, visibleIDs: visibleIDs) {
                stroke(item, context: &context, transform: transform, color: ATSLineSymbol.platform.color, width: selection?.id == item.id ? max(4, strokeScale * 2.5) : strokeScale * 2)
                if layers.contains(.labels), transform.zoom >= 1.8 {
                    labels.append((item.name, transform.screen(item.midpoint)))
                }
            }
        }
        if layers.contains(.calibration) {
            for item in data.calibrationLinks {
                for traversal in item.traversed where visibleIDs.contains(traversal.segmentID) {
                    drawTraversal(traversal, color: ATSLineSymbol.calibration.color, width: selection?.id == item.id ? max(4, strokeScale * 2.2) : strokeScale * 1.6, context: &context, transform: transform)
                }
            }
        }
        if layers.contains(.tags) {
            for item in data.tags where objectAllowed(item.id, visibleIDs: visibleIDs) {
                drawSymbol(.tag, id: item.id, at: transform.screen(item.point), scale: symbolScale, context: &context)
                if layers.contains(.labels), transform.zoom >= 2.8 { labels.append((item.id, transform.screen(item.point))) }
            }
        }
        if layers.contains(.signals) {
            for item in data.signals where objectAllowed(item.id, visibleIDs: visibleIDs) {
                let center = transform.screen(item.point)
                drawSymbol(.signal, id: item.id, at: center, scale: symbolScale, context: &context)
                if layers.contains(.labels), transform.zoom >= 2.8 { labels.append((item.id, center)) }
            }
        }
        if layers.contains(.switches) {
            for item in data.switches where objectAllowed(item.id, visibleIDs: visibleIDs) {
                drawSymbol(.turnout, id: item.id, at: transform.screen(item.point), scale: symbolScale, context: &context)
            }
        }
        if layers.contains(.buffers) {
            for item in data.bufferStops where objectAllowed(item.id, visibleIDs: visibleIDs) {
                drawSymbol(.buffer, id: item.id, at: transform.screen(item.point), scale: symbolScale, context: &context)
            }
        }
        if layers.contains(.stops) {
            for item in data.stoppingPoints where visibleIDs.contains(item.segmentID) {
                guard let point = point(on: item.segmentID, x: item.x) else { continue }
                let center = transform.screen(point)
                drawSymbol(.stop, id: item.id, at: center, scale: symbolScale, context: &context)
                if layers.contains(.labels), transform.zoom >= 2.3 { labels.append((item.id, center)) }
            }
        }
        for (label, point) in labels {
            drawLabel(label, at: point, in: bounds, occupied: &labelBounds, context: &context)
        }
        if let point = selection?.point {
            let symbol = ATSLineSymbol.selection
            context.fill(symbol.path(at: transform.screen(point), scale: 1), with: .color(symbol.color))
        }
        if let start = measureStart, visibleIDs.contains(start.segmentID) {
            drawMeasurePoint(start, label: "A", context: &context, transform: transform)
        }
        if let end = measureEnd, visibleIDs.contains(end.segmentID) {
            drawMeasurePoint(end, label: "B", context: &context, transform: transform)
        }
    }

    private func hitTest(
        at location: CGPoint,
        transform: ATSLineMapTransform
    ) -> ATSLineSelection? {
        let visibleSegments = data.segments.filter(trackAllowed)
        let visibleIDs = Set(visibleSegments.map(\.id))
        var pointCandidates: [(CGFloat, ATSLineSelection)] = []
        let pointTolerance = transform.drawingSize(18, minimum: 5, maximum: 16)

        func addPoint(_ id: String, kind: String, point: CGPoint) {
            guard objectAllowed(id, visibleIDs: visibleIDs) else { return }
            let distance = hypot(transform.screen(point).x - location.x, transform.screen(point).y - location.y)
            guard distance <= pointTolerance else { return }
            let context = data.objectContext[id]
            pointCandidates.append((distance, ATSLineSelection(
                id: id,
                kind: kind,
                track: context?.track,
                segmentID: context?.segmentID,
                x: context?.x,
                pk: context?.pk,
                length: nil,
                startPK: nil,
                endPK: nil,
                code: nil,
                extra: nil,
                point: point
            )))
        }

        if layers.contains(.tags) { data.tags.forEach { addPoint($0.id, kind: "Baliza", point: $0.point) } }
        if layers.contains(.signals) { data.signals.forEach { addPoint($0.id, kind: "Señal", point: $0.point) } }
        if layers.contains(.switches) { data.switches.forEach { addPoint($0.id, kind: "Desvío", point: $0.point) } }
        if layers.contains(.buffers) { data.bufferStops.forEach { addPoint($0.id, kind: "Tope", point: $0.point) } }
        if layers.contains(.stops) {
            for item in data.stoppingPoints where visibleIDs.contains(item.segmentID) {
                guard let point = point(on: item.segmentID, x: item.x) else { continue }
                let distance = hypot(transform.screen(point).x - location.x, transform.screen(point).y - location.y)
                guard distance <= pointTolerance else { continue }
                pointCandidates.append((distance, ATSLineSelection(
                    id: item.id,
                    kind: "Punto de parada",
                    track: item.track,
                    segmentID: item.segmentID,
                    x: item.x,
                    pk: item.pk,
                    length: nil,
                    startPK: nil,
                    endPK: nil,
                    code: item.atsID.map(String.init),
                    extra: item.type,
                    point: point
                )))
            }
        }
        if let nearest = pointCandidates.min(by: { $0.0 < $1.0 }) { return nearest.1 }

        if layers.contains(.platforms) {
            for item in data.platforms where objectAllowed(item.id, visibleIDs: visibleIDs) {
                let distance = distanceToLine(
                    location,
                    transform.screen(CGPoint(x: item.x1, y: item.y1)),
                    transform.screen(CGPoint(x: item.x2, y: item.y2))
                ).distance
                if distance <= 18 {
                    let context = data.objectContext[item.id]
                    return ATSLineSelection(
                        id: item.id,
                        kind: "Plataforma",
                        track: context?.track,
                        segmentID: context?.segmentID,
                        x: context?.x,
                        pk: context?.pk,
                        length: item.physicalLength,
                        startPK: item.firstPK,
                        endPK: item.secondPK,
                        code: nil,
                        extra: item.name,
                        point: item.midpoint
                    )
                }
            }
        }

        var segmentCandidates: [(CGFloat, ATSLineSegment, CGFloat)] = []
        if layers.contains(.segments) {
            for item in visibleSegments {
                let result = distanceToLine(
                    location,
                    transform.screen(CGPoint(x: item.x1, y: item.y1)),
                    transform.screen(CGPoint(x: item.x2, y: item.y2))
                )
                if result.distance <= 20 { segmentCandidates.append((result.distance, item, result.fraction)) }
            }
        }
        guard let nearest = segmentCandidates.min(by: { $0.0 < $1.0 }) else { return nil }
        let item = nearest.1
        let fraction = Double(nearest.2)
        let x = item.length * fraction
        let pk = item.startPK + (item.endPK >= item.startPK ? x : -x)
        return ATSLineSelection(
            id: item.id,
            kind: "Segmento de vía",
            track: item.track,
            segmentID: item.id,
            x: x,
            pk: pk,
            length: item.length,
            startPK: item.startPK,
            endPK: item.endPK,
            code: item.lineSegment,
            extra: "Conecta con \((item.previousIDs + item.nextIDs).joined(separator: ", "))",
            point: CGPoint(
                x: item.x1 + (item.x2 - item.x1) * fraction,
                y: item.y1 + (item.y2 - item.y1) * fraction
            )
        )
    }

    private func trackAllowed(_ segment: ATSLineSegment) -> Bool {
        scope.includes(area: areaForTrack(segment.track))
    }

    private func objectAllowed(_ id: String, visibleIDs: Set<String>) -> Bool {
        if scope == .all { return true }
        guard let context = data.objectContext[id] else { return false }
        if let track = context.track {
            return scope.includes(area: areaForTrack(track))
        }
        return context.segmentID.map(visibleIDs.contains) ?? false
    }

    private func point(on segmentID: String, x: Double) -> CGPoint? {
        guard let segment = data.segmentByID[segmentID] else { return nil }
        let ratio = segment.length > 0 ? min(1, max(0, x / segment.length)) : 0
        return CGPoint(
            x: segment.x1 + (segment.x2 - segment.x1) * ratio,
            y: segment.y1 + (segment.y2 - segment.y1) * ratio
        )
    }

    private func drawTraversal(
        _ item: ATSLineTraversal,
        color: Color,
        width: CGFloat,
        context: inout GraphicsContext,
        transform: ATSLineMapTransform
    ) {
        guard let start = point(on: item.segmentID, x: item.xStart),
              let end = point(on: item.segmentID, x: item.xEnd) else { return }
        context.stroke(
            linePath(from: transform.screen(start), to: transform.screen(end)),
            with: .color(color),
            style: StrokeStyle(lineWidth: width, lineCap: .round)
        )
    }

    private func stroke(
        _ item: ATSLinePlatform,
        context: inout GraphicsContext,
        transform: ATSLineMapTransform,
        color: Color,
        width: CGFloat
    ) {
        context.stroke(
            linePath(
                from: transform.screen(CGPoint(x: item.x1, y: item.y1)),
                to: transform.screen(CGPoint(x: item.x2, y: item.y2))
            ),
            with: .color(color),
            style: StrokeStyle(lineWidth: width, lineCap: .round)
        )
    }

    private func drawSymbol(
        _ symbol: ATSLineSymbol,
        id: String,
        at center: CGPoint,
        scale: CGFloat,
        context: inout GraphicsContext
    ) {
        context.fill(
            symbol.path(at: center, scale: scale),
            with: .color(selection?.id == id ? BrandColor.red : symbol.color)
        )
    }

    private func drawMeasurePoint(
        _ item: ATSLineMeasurePoint,
        label: String,
        context: inout GraphicsContext,
        transform: ATSLineMapTransform
    ) {
        let center = transform.screen(item.point)
        context.fill(Path(ellipseIn: CGRect(x: center.x - 8, y: center.y - 8, width: 16, height: 16)), with: .color(BrandColor.red))
        context.draw(Text(label).font(.caption.bold()).foregroundStyle(.white), at: center)
    }

    private func drawLabel(
        _ label: String,
        at point: CGPoint,
        in bounds: CGRect,
        occupied: inout [CGRect],
        context: inout GraphicsContext
    ) {
        guard bounds.contains(point) else { return }
        let resolved = context.resolve(
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(BrandColor.graphite)
        )
        let size = resolved.measure(in: bounds.size)
        let rect = CGRect(x: point.x + 8, y: point.y - 10 - size.height / 2, width: size.width, height: size.height)
        let padded = rect.insetBy(dx: -3, dy: -2)
        guard bounds.contains(padded), !occupied.contains(where: { $0.intersects(padded) }) else { return }
        occupied.append(padded)
        context.draw(resolved, at: rect.origin, anchor: .topLeading)
    }

    private func segmentColor(_ track: String) -> Color {
        switch areaForTrack(track) {
        case "principal": ATSLineSymbol.main.color
        case "patio": ATSLineSymbol.yard.color
        default: ATSLineSymbol.links.color
        }
    }

    private func linePath(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }

    private func distanceToLine(
        _ point: CGPoint,
        _ start: CGPoint,
        _ end: CGPoint
    ) -> (distance: CGFloat, fraction: CGFloat) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let denominator = dx * dx + dy * dy
        guard denominator > 0 else { return (hypot(point.x - start.x, point.y - start.y), 0) }
        let raw = ((point.x - start.x) * dx + (point.y - start.y) * dy) / denominator
        let fraction = min(1, max(0, raw))
        let projection = CGPoint(x: start.x + dx * fraction, y: start.y + dy * fraction)
        return (hypot(point.x - projection.x, point.y - projection.y), fraction)
    }
}

#Preview {
    NavigationStack {
        ATSLineView()
            .environmentObject(SessionStore())
    }
}
