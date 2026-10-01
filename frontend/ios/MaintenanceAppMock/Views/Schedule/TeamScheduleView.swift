import SwiftUI

private struct ScheduleWorkArea: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let canEdit: Bool

    enum CodingKeys: String, CodingKey {
        case id, name
        case canEdit = "can_edit"
    }
}

private struct ScheduleShiftType: Identifiable, Decodable, Hashable {
    let code: String
    let name: String
    let description: String
    let startsAt: String?
    let endsAt: String?
    let colorHex: String
    let appliesToFullWeek: Bool

    var id: String { code }

    enum CodingKeys: String, CodingKey {
        case code, name, description
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case colorHex = "color_hex"
        case appliesToFullWeek = "applies_to_full_week"
    }
}

private struct ScheduleMember: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let role: String
    let roleLabel: String

    enum CodingKeys: String, CodingKey {
        case id, name, role
        case roleLabel = "role_label"
    }
}

private struct ScheduleEntry: Identifiable, Decodable, Hashable {
    let id: String
    let userID: String
    let workDate: String
    let shiftCode: String

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case workDate = "work_date"
        case shiftCode = "shift_code"
    }
}

private struct WeeklySchedule: Decodable {
    let workArea: ScheduleWorkArea
    let weekStart: String
    let weekEnd: String
    let canEdit: Bool
    let members: [ScheduleMember]
    let shiftTypes: [ScheduleShiftType]
    let entries: [ScheduleEntry]

    enum CodingKeys: String, CodingKey {
        case members, entries
        case workArea = "work_area"
        case weekStart = "week_start"
        case weekEnd = "week_end"
        case canEdit = "can_edit"
        case shiftTypes = "shift_types"
    }
}

private struct ScheduleEntryUpdate: Encodable {
    let shiftCode: String?
    let applyScope: String
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case reason
        case shiftCode = "shift_code"
        case applyScope = "apply_scope"
    }
}

private struct CopyScheduleWeekRequest: Encodable {
    let workAreaID: String
    let sourceWeekStart: String
    let targetWeekStart: String
    let overwrite: Bool
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case overwrite, reason
        case workAreaID = "work_area_id"
        case sourceWeekStart = "source_week_start"
        case targetWeekStart = "target_week_start"
    }
}

private struct ScheduleBulkTarget: Hashable {
    let memberID: String
    let date: Date
}

private struct ScheduleBulkChange: Encodable {
    let userID: String
    let workDate: String
    let shiftCode: String?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case workDate = "work_date"
        case shiftCode = "shift_code"
    }
}

private struct ScheduleBulkUpdate: Encodable {
    let workAreaID: String
    let changes: [ScheduleBulkChange]

    enum CodingKeys: String, CodingKey {
        case changes
        case workAreaID = "work_area_id"
    }
}

private struct ScheduleService {
    let client: APIClient

    init(baseURLString: String) {
        client = APIClient(baseURLString: baseURLString)
    }

    func workAreas(accessToken: String) async throws -> [ScheduleWorkArea] {
        try await client.get("api/v1/schedules/work-areas", bearerToken: accessToken)
    }

    func week(
        starting weekStart: String,
        workAreaID: String?,
        accessToken: String
    ) async throws -> WeeklySchedule {
        var query = [URLQueryItem(name: "week_start", value: weekStart)]
        if let workAreaID {
            query.append(URLQueryItem(name: "work_area_id", value: workAreaID))
        }
        return try await client.get(
            "api/v1/schedules/week",
            bearerToken: accessToken,
            queryItems: query
        )
    }

    func update(
        memberID: String,
        date: String,
        shiftCode: String?,
        scope: String,
        reason: String?,
        accessToken: String
    ) async throws -> WeeklySchedule {
        try await client.put(
            "api/v1/schedules/entries/\(memberID)/\(date)",
            body: ScheduleEntryUpdate(
                shiftCode: shiftCode,
                applyScope: scope,
                reason: reason
            ),
            bearerToken: accessToken
        )
    }

    func copyPreviousWeek(
        workAreaID: String,
        sourceWeekStart: String,
        targetWeekStart: String,
        reason: String?,
        accessToken: String
    ) async throws -> WeeklySchedule {
        try await client.post(
            "api/v1/schedules/copy-week",
            body: CopyScheduleWeekRequest(
                workAreaID: workAreaID,
                sourceWeekStart: sourceWeekStart,
                targetWeekStart: targetWeekStart,
                overwrite: true,
                reason: reason
            ),
            bearerToken: accessToken
        )
    }

    func fill(
        workAreaID: String,
        targets: [ScheduleBulkTarget],
        shiftCode: String?,
        accessToken: String
    ) async throws -> WeeklySchedule {
        try await client.post(
            "api/v1/schedules/entries/bulk",
            body: ScheduleBulkUpdate(
                workAreaID: workAreaID,
                changes: targets.map {
                    ScheduleBulkChange(
                        userID: $0.memberID,
                        workDate: ScheduleDate.api.string(from: $0.date),
                        shiftCode: shiftCode
                    )
                }
            ),
            bearerToken: accessToken
        )
    }
}

@MainActor
private final class TeamScheduleStore: ObservableObject {
    @Published private(set) var workAreas: [ScheduleWorkArea] = []
    @Published private(set) var schedule: WeeklySchedule?
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    func load(
        weekStart: Date,
        selectedAreaID: String?,
        session: SessionStore
    ) async {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else {
            errorMessage = "No se encontro la URL de la API."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let service = ScheduleService(baseURLString: baseURL)
            let result = try await session.withValidAccessToken { token in
                let areas = try await service.workAreas(accessToken: token)
                let resolvedAreaID = selectedAreaID ?? areas.first?.id
                let schedule = try await service.week(
                    starting: ScheduleDate.api.string(from: weekStart),
                    workAreaID: resolvedAreaID,
                    accessToken: token
                )
                return (areas, schedule)
            }
            workAreas = result.0
            schedule = result.1
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func update(
        memberID: String,
        date: Date,
        shiftCode: String?,
        scope: String,
        reason: String?,
        session: SessionStore
    ) async {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else { return }
        isSaving = true
        errorMessage = nil
        do {
            schedule = try await session.withValidAccessToken { token in
                try await ScheduleService(baseURLString: baseURL).update(
                    memberID: memberID,
                    date: ScheduleDate.api.string(from: date),
                    shiftCode: shiftCode,
                    scope: scope,
                    reason: reason,
                    accessToken: token
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    func copyPreviousWeek(
        weekStart: Date,
        reason: String?,
        session: SessionStore
    ) async {
        guard let areaID = schedule?.workArea.id,
              let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL"),
              let source = Calendar.schedule.date(byAdding: .day, value: -7, to: weekStart)
        else { return }
        isSaving = true
        errorMessage = nil
        do {
            schedule = try await session.withValidAccessToken { token in
                try await ScheduleService(baseURLString: baseURL).copyPreviousWeek(
                    workAreaID: areaID,
                    sourceWeekStart: ScheduleDate.api.string(from: source),
                    targetWeekStart: ScheduleDate.api.string(from: weekStart),
                    reason: reason,
                    accessToken: token
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    func fill(
        targets: [ScheduleBulkTarget],
        shiftCode: String?,
        session: SessionStore
    ) async {
        guard !targets.isEmpty,
              let workAreaID = schedule?.workArea.id,
              let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL")
        else { return }
        isSaving = true
        errorMessage = nil
        do {
            schedule = try await session.withValidAccessToken { token in
                try await ScheduleService(baseURLString: baseURL).fill(
                    workAreaID: workAreaID,
                    targets: targets,
                    shiftCode: shiftCode,
                    accessToken: token
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    func shiftCode(memberID: String, date: Date) -> String? {
        let value = ScheduleDate.api.string(from: date)
        return schedule?.entries.first {
            $0.userID == memberID && $0.workDate == value
        }?.shiftCode
    }
}

struct TeamScheduleView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var store = TeamScheduleStore()
    @State private var weekStart = Calendar.schedule.startOfWeek(containing: Date())
    @State private var selectedAreaID: String?
    @State private var scopePrompt: PendingScheduleChange?
    @State private var showCopyConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                pageHeader
                legend
                scheduleContent
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 1500)
            .frame(maxWidth: .infinity)
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Horario")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .refreshable { await reload() }
        .onChange(of: weekStart) { Task { await reload() } }
        .onChange(of: selectedAreaID) { Task { await reload() } }
        .confirmationDialog(
            "¿Como deseas aplicar el cambio?",
            isPresented: Binding(
                get: { scopePrompt != nil },
                set: { if !$0 { scopePrompt = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Solo este dia") { resolveScope("DAY") }
            Button("Toda la semana") { resolveScope("WEEK") }
            Button("Cancelar", role: .cancel) { scopePrompt = nil }
        } message: {
            Text("El trabajador tiene CBTC semanal. Elige el alcance de esta modificacion.")
        }
        .confirmationDialog(
            "Copiar semana anterior",
            isPresented: $showCopyConfirmation,
            titleVisibility: .visible
        ) {
            Button("Copiar y reemplazar") { prepareWeekCopy() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Se reemplazaran los turnos existentes de la semana visible.")
        }
        .alert(
            "No se pudo actualizar el horario",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("Aceptar") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "Ocurrio un error inesperado.")
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Horario")
                        .font(.largeTitle.bold())
                    Text("Gestion de turnos del equipo por area de trabajo")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if store.isSaving {
                    ProgressView("Guardando")
                        .font(.caption)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppSpacing.sm) { headerControls }
                VStack(alignment: .leading, spacing: AppSpacing.sm) { headerControls }
            }
        }
    }

    @ViewBuilder
    private var headerControls: some View {
        if store.workAreas.count > 1 {
            Menu {
                ForEach(store.workAreas) { area in
                    Button(area.name) { selectedAreaID = area.id }
                }
            } label: {
                Label(store.schedule?.workArea.name ?? "Seleccionar area", systemImage: "person.3.fill")
                    .frame(minWidth: 180)
            }
            .buttonStyle(.bordered)
        } else if let areaName = store.schedule?.workArea.name {
            Label(areaName, systemImage: "person.3.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, AppSpacing.md)
                .frame(minHeight: 42)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }

        HStack(spacing: 4) {
            Button { moveWeek(by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Semana anterior")

            Label(weekLabel, systemImage: "calendar")
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 210)

            Button { moveWeek(by: 1) } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("Semana siguiente")
        }
        .buttonStyle(.bordered)

        if store.schedule?.canEdit == true {
            Button {
                showCopyConfirmation = true
            } label: {
                Label("Copiar semana anterior", systemImage: "doc.on.doc")
            }
            .buttonStyle(.borderedProminent)
            .tint(BrandColor.red)
            .disabled(store.isSaving || !canApplyToWholeWeek)
        }
    }

    private var legend: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Leyenda de turnos")
                    .font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.lg) {
                        ForEach(store.schedule?.shiftTypes ?? []) { shift in
                            ScheduleLegendItem(shift: shift)
                        }
                        ScheduleLegendItem(shift: nil)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var scheduleContent: some View {
        if store.isLoading && store.schedule == nil {
            ProgressView("Cargando horario")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 80)
        } else if let schedule = store.schedule {
            ContentGlassPanel {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Equipo de \(schedule.workArea.name) (\(schedule.members.count))")
                                .font(.title2.bold())
                            Text(schedule.canEdit ? "Selecciona un turno o manten pulsado y arrastra para copiarlo." : "Horario en modo consulta.")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if schedule.canEdit {
                            Label("Guardado automatico", systemImage: "checkmark.icloud")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    ScheduleGrid(
                        schedule: schedule,
                        dates: weekDates,
                        canEditDate: canEdit,
                        shiftCode: store.shiftCode,
                        onSelect: beginChange,
                        onFill: fill
                    )
                }
            }
        } else {
            ContentUnavailableView(
                "Horario no disponible",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("Asigna al usuario un area de trabajo para consultar su horario.")
            )
            .padding(.vertical, 80)
        }
    }

    private var weekDates: [Date] {
        (0..<7).compactMap { Calendar.schedule.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var weekLabel: String {
        guard let end = weekDates.last else { return "Semana" }
        return "\(ScheduleDate.short.string(from: weekStart)) - \(ScheduleDate.long.string(from: end))"
    }

    private func canEdit(_ date: Date) -> Bool {
        guard store.schedule?.canEdit == true else { return false }
        if session.currentUser?.role == .administrator { return true }
        return Calendar.schedule.startOfDay(for: date) >= Calendar.schedule.startOfDay(for: Date())
    }

    private var canApplyToWholeWeek: Bool {
        canEdit(weekStart)
    }

    private func beginChange(member: ScheduleMember, date: Date, shiftCode: String?) {
        let existing = store.shiftCode(memberID: member.id, date: date)
        let appliesAutomatically = shiftCode == "CBTC" || shiftCode == "COO"
        var change = PendingScheduleChange(
            memberID: member.id,
            date: date,
            shiftCode: shiftCode,
            scope: appliesAutomatically ? "WEEK" : "DAY"
        )
        if existing == "CBTC", !appliesAutomatically {
            scopePrompt = change
        } else {
            change.scope = appliesAutomatically ? "WEEK" : "DAY"
            prepare(change)
        }
    }

    private func resolveScope(_ scope: String) {
        guard var change = scopePrompt else { return }
        scopePrompt = nil
        change.scope = scope
        prepare(change)
    }

    private func prepare(_ change: PendingScheduleChange) {
        submit(change)
    }

    private func submit(_ change: PendingScheduleChange) {
        Task {
            await store.update(
                memberID: change.memberID,
                date: change.date,
                shiftCode: change.shiftCode,
                scope: change.scope,
                reason: nil,
                session: session
            )
        }
    }

    private func prepareWeekCopy() {
        copyPreviousWeek()
    }

    private func copyPreviousWeek() {
        Task { await store.copyPreviousWeek(weekStart: weekStart, reason: nil, session: session) }
    }

    private func fill(targets: [ScheduleBulkTarget], shiftCode: String?) {
        Task { await store.fill(targets: targets, shiftCode: shiftCode, session: session) }
    }

    private func moveWeek(by amount: Int) {
        if let value = Calendar.schedule.date(byAdding: .day, value: amount * 7, to: weekStart) {
            weekStart = value
        }
    }

    private func reload() async {
        await store.load(
            weekStart: weekStart,
            selectedAreaID: selectedAreaID,
            session: session
        )
        if selectedAreaID == nil {
            selectedAreaID = store.schedule?.workArea.id
        }
    }
}

private struct ScheduleGrid: View {
    let schedule: WeeklySchedule
    let dates: [Date]
    let canEditDate: (Date) -> Bool
    let shiftCode: (String, Date) -> String?
    let onSelect: (ScheduleMember, Date, String?) -> Void
    let onFill: ([ScheduleBulkTarget], String?) -> Void

    @State private var fillSelection: ScheduleFillSelection?
    @State private var shiftPickerSelection: ScheduleShiftPickerSelection?

    private let workerWidth: CGFloat = 210
    private let dayWidth: CGFloat = 128
    private let rowHeight: CGFloat = 64

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                Text("Trabajador")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.sm)
                    .frame(height: rowHeight)
                    .background(.background.opacity(0.86))
                ForEach(schedule.members) { member in
                    ScheduleMemberCell(member: member)
                        .frame(width: workerWidth, height: rowHeight)
                }
            }
            .frame(width: workerWidth)
            .zIndex(1)

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(dates, id: \.self) { date in
                            ScheduleDayHeader(date: date)
                                .frame(width: dayWidth, height: rowHeight)
                        }
                    }
                    ForEach(Array(schedule.members.enumerated()), id: \.element.id) { row, member in
                        HStack(spacing: 0) {
                            ForEach(Array(dates.enumerated()), id: \.element) { day, date in
                                ScheduleShiftCell(
                                    shiftCode: shiftCode(member.id, date),
                                    shifts: schedule.shiftTypes,
                                    isEditable: canEditDate(date),
                                    isFillSelected: fillSelection?.contains(row: row, day: day) == true,
                                    onOpenPicker: {
                                        shiftPickerSelection = ScheduleShiftPickerSelection(
                                            member: member,
                                            date: date
                                        )
                                    },
                                    onFillBegan: { beginFill(row: row, day: day) },
                                    onFillChanged: updateFill,
                                    onFillEnded: finishFill
                                )
                                .frame(width: dayWidth, height: rowHeight)
                            }
                        }
                    }
                }
                .coordinateSpace(.named("scheduleDays"))
            }
        }
        .clipShape(.rect(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(.quaternary) }
        .confirmationDialog(
            "Seleccionar turno",
            isPresented: Binding(
                get: { shiftPickerSelection != nil },
                set: { if !$0 { shiftPickerSelection = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Descanso") { selectShift(nil) }
            ForEach(schedule.shiftTypes) { shift in
                Button("\(shift.code) · \(shift.name)") { selectShift(shift.code) }
                    .disabled(
                        (shift.appliesToFullWeek || shift.code == "COO")
                            && !(dates.first.map(canEditDate) ?? false)
                    )
            }
            Button("Cancelar", role: .cancel) { shiftPickerSelection = nil }
        } message: {
            if let selection = shiftPickerSelection {
                Text("\(selection.member.name) · \(ScheduleDate.long.string(from: selection.date))")
            }
        }
    }

    private func selectShift(_ shiftCode: String?) {
        guard let selection = shiftPickerSelection else { return }
        shiftPickerSelection = nil
        onSelect(selection.member, selection.date, shiftCode)
    }

    private func beginFill(row: Int, day: Int) {
        guard fillSelection == nil, canEditDate(dates[day]) else { return }
        fillSelection = ScheduleFillSelection(
            sourceRow: row,
            sourceDay: day,
            targetRow: row,
            targetDay: day,
            shiftCode: shiftCode(schedule.members[row].id, dates[day])
        )
    }

    private func updateFill(_ location: CGPoint) {
        guard var selection = fillSelection else { return }
        let day = min(max(Int(location.x / dayWidth), 0), dates.count - 1)
        let row = min(
            max(Int((location.y - rowHeight) / rowHeight), 0),
            schedule.members.count - 1
        )
        selection.targetDay = day
        selection.targetRow = row
        fillSelection = selection
    }

    private func finishFill() {
        guard let selection = fillSelection else { return }
        fillSelection = nil
        guard selection.sourceRow != selection.targetRow
                || selection.sourceDay != selection.targetDay
        else { return }
        let rows = min(selection.sourceRow, selection.targetRow)...max(selection.sourceRow, selection.targetRow)
        let days = min(selection.sourceDay, selection.targetDay)...max(selection.sourceDay, selection.targetDay)
        let targets = rows.flatMap { row in
            days.compactMap { day -> ScheduleBulkTarget? in
                guard canEditDate(dates[day]) else { return nil }
                return ScheduleBulkTarget(
                    memberID: schedule.members[row].id,
                    date: dates[day]
                )
            }
        }
        if !targets.isEmpty {
            onFill(targets, selection.shiftCode)
        }
    }
}

private struct ScheduleMemberCell: View {
    let member: ScheduleMember

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(member.initials)
                .font(.caption.bold())
                .frame(width: 34, height: 34)
                .background(BrandColor.backgroundSecondary, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(member.shortRole)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.sm)
        .background(Color.clear)
    }
}

private struct ScheduleDayHeader: View {
    let date: Date

    var body: some View {
        VStack(spacing: 3) {
            Text(ScheduleDate.dayMonth.string(from: date))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(ScheduleDate.weekday.string(from: date).capitalized)
                .font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Calendar.schedule.isDateInToday(date)
                ? BrandColor.redSubtle
                : Color(uiColor: .systemBackground).opacity(0.86)
        )
        .overlay(alignment: .trailing) { Divider() }
    }
}

private struct ScheduleShiftCell: View {
    let shiftCode: String?
    let shifts: [ScheduleShiftType]
    let isEditable: Bool
    let isFillSelected: Bool
    let onOpenPicker: () -> Void
    let onFillBegan: () -> Void
    let onFillChanged: (CGPoint) -> Void
    let onFillEnded: () -> Void

    @State private var suppressShiftPicker = false
    @GestureState private var isFillGestureTracking = false

    var shift: ScheduleShiftType? {
        shifts.first { $0.code == shiftCode }
    }

    var body: some View {
        Group {
            if isEditable {
                Button {
                    guard !suppressShiftPicker else { return }
                    onOpenPicker()
                } label: {
                    cellLabel
                }
                .buttonStyle(.plain)
            } else {
                cellLabel
            }
        }
        .padding(5)
        .contentShape(Rectangle())
        .simultaneousGesture(fillGesture, including: isEditable ? .all : .none)
        .onChange(of: isFillGestureTracking) { wasTracking, isTracking in
            guard wasTracking, !isTracking else { return }
            onFillEnded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                suppressShiftPicker = false
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(shift.map { "Turno \($0.code), \($0.name)" } ?? "Descanso")
        .accessibilityAddTraits(isEditable ? .isButton : [])
        .accessibilityAction {
            guard isEditable else { return }
            onOpenPicker()
        }
    }

    private var cellLabel: some View {
        HStack(spacing: 5) {
            Text(shift?.code ?? "—")
                .font(.subheadline.weight(.semibold))
            if isEditable {
                Image(systemName: "chevron.down")
                    .font(.caption2.bold())
            }
        }
        .foregroundStyle(BrandColor.signalInk)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            shift.map { Color.scheduleHex($0.colorHex).opacity(0.72) } ?? Color.clear,
            in: RoundedRectangle(cornerRadius: 7)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(
                    isFillSelected
                        ? BrandColor.red
                        : (shift == nil ? Color.secondary.opacity(0.20) : Color.clear),
                    lineWidth: isFillSelected ? 2 : 1
                )
        }
    }

    private var fillGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(
                before: DragGesture(
                    minimumDistance: 2,
                    coordinateSpace: .named("scheduleDays")
                )
            )
            .updating($isFillGestureTracking) { value, isTracking, _ in
                switch value {
                case .first(true), .second(true, _):
                    isTracking = true
                default:
                    break
                }
            }
            .onChanged { value in
                switch value {
                case .first(true):
                    suppressShiftPicker = true
                    onFillBegan()
                case .second(true, let drag?):
                    suppressShiftPicker = true
                    onFillBegan()
                    onFillChanged(drag.location)
                default:
                    break
                }
            }
    }

}

private struct ScheduleShiftPickerSelection {
    let member: ScheduleMember
    let date: Date
}

private struct ScheduleFillSelection {
    let sourceRow: Int
    let sourceDay: Int
    var targetRow: Int
    var targetDay: Int
    let shiftCode: String?

    func contains(row: Int, day: Int) -> Bool {
        (min(sourceRow, targetRow)...max(sourceRow, targetRow)).contains(row)
            && (min(sourceDay, targetDay)...max(sourceDay, targetDay)).contains(day)
    }
}

private struct ScheduleLegendItem: View {
    let shift: ScheduleShiftType?

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            RoundedRectangle(cornerRadius: 6)
                .fill(shift.map { Color.scheduleHex($0.colorHex) } ?? Color.clear)
                .overlay { RoundedRectangle(cornerRadius: 6).stroke(.quaternary) }
                .frame(width: 42, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(shift?.code ?? "Descanso")
                    .font(.subheadline.bold())
                Text(shift?.description ?? "Sin turno")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct PendingScheduleChange: Identifiable {
    let id = UUID()
    let memberID: String
    let date: Date
    let shiftCode: String?
    var scope: String
}

private enum ScheduleDate {
    static let api = formatter("yyyy-MM-dd")
    static let short = formatter("d MMM")
    static let long = formatter("d MMM yyyy")
    static let dayMonth = formatter("d MMM")
    static let weekday = formatter("EEEE")

    private static func formatter(_ pattern: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.calendar = Calendar.schedule
        formatter.timeZone = TimeZone(identifier: "America/Lima")
        formatter.dateFormat = pattern
        return formatter
    }
}

private extension Calendar {
    static var schedule: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "es_PE")
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        calendar.firstWeekday = 2
        return calendar
    }

    func startOfWeek(containing date: Date) -> Date {
        let start = startOfDay(for: date)
        let weekday = component(.weekday, from: start)
        let daysFromMonday = (weekday + 5) % 7
        return self.date(byAdding: .day, value: -daysFromMonday, to: start) ?? start
    }
}

private extension ScheduleMember {
    var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }

    var shortRole: String {
        switch role {
        case "COORDINATOR": return "Coordinador"
        case "ADMINISTRATOR": return "Administrador"
        default: return "Ingeniero"
        }
    }
}

private extension Color {
    static func scheduleHex(_ value: String) -> Color {
        let hex = value.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard hex.count == 6, let number = Int(hex, radix: 16) else {
            return BrandColor.backgroundSecondary
        }
        return Color(
            red: Double((number >> 16) & 0xFF) / 255,
            green: Double((number >> 8) & 0xFF) / 255,
            blue: Double(number & 0xFF) / 255
        )
    }
}

#Preview {
    NavigationStack { TeamScheduleView() }
        .environmentObject(SessionStore())
}
