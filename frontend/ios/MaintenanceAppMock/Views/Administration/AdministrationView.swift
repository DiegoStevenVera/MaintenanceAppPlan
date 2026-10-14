import SwiftUI

private struct AdministrationSnapshot: Decodable {
    let users: [ManagedUser]
    let workAreas: [ManagedWorkArea]
    let sites: [ManagedSite]
    let projects: [ManagedProject]
    let stages: [ManagedStage]
    let systems: [ManagedSystem]
    let subsystems: [ManagedSubsystem]
    let rolePermissions: [ManagedRolePermissions]

    enum CodingKeys: String, CodingKey {
        case users, sites, projects, stages, systems, subsystems
        case workAreas = "work_areas"
        case rolePermissions = "role_permissions"
    }

    static let empty = AdministrationSnapshot(
        users: [], workAreas: [], sites: [], projects: [], stages: [], systems: [], subsystems: [], rolePermissions: []
    )
}

private struct ManagedRolePermissions: Decodable, Identifiable {
    let role: String
    let roleLabel: String
    let isLocked: Bool
    let permissions: [ManagedModulePermission]

    var id: String { role }

    enum CodingKeys: String, CodingKey {
        case role, permissions
        case roleLabel = "role_label"
        case isLocked = "is_locked"
    }
}

private struct ManagedModulePermission: Decodable, Identifiable {
    let module: String
    let label: String
    let permissionLevel: String

    var id: String { module }

    enum CodingKeys: String, CodingKey {
        case module, label
        case permissionLevel = "permission_level"
    }
}

private struct RolePermissionsPayload: Encodable {
    let permissions: [String: String]
}

private struct ManagedUser: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let email: String
    let role: String
    let jobTitle: String
    let workAreaID: String?
    let workAreaName: String?
    let supervisedWorkAreaIDs: [String]
    let appearsInSchedule: Bool
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, email, role
        case jobTitle = "job_title"
        case workAreaID = "work_area_id"
        case workAreaName = "work_area_name"
        case supervisedWorkAreaIDs = "supervised_work_area_ids"
        case appearsInSchedule = "appears_in_schedule"
        case isActive = "is_active"
    }
}

private struct ManagedWorkArea: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case isActive = "is_active"
    }
}

private struct ManagedSite: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case isActive = "is_active"
    }
}

private struct ManagedProject: Codable, Identifiable, Hashable {
    let id: String
    let siteID: String
    let siteName: String
    let name: String
    let description: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case siteID = "site_id"
        case siteName = "site_name"
        case isActive = "is_active"
    }
}

private struct ManagedStage: Codable, Identifiable, Hashable {
    let id: String
    let projectID: String
    let name: String
    let operationalStatus: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, name
        case projectID = "project_id"
        case operationalStatus = "operational_status"
        case isActive = "is_active"
    }
}

private struct ManagedSystem: Codable, Identifiable, Hashable {
    let id: String
    let projectID: String
    let name: String
    let description: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case projectID = "project_id"
        case isActive = "is_active"
    }
}

private struct ManagedSubsystem: Codable, Identifiable, Hashable {
    let id: String
    let systemID: String
    let code: String
    let name: String
    let description: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, code, name, description
        case systemID = "system_id"
        case isActive = "is_active"
    }
}

private struct ManagedUserPayload: Encodable {
    let name: String
    let email: String
    let role: String
    let jobTitle: String
    let workAreaID: String?
    let supervisedWorkAreaIDs: [String]
    let appearsInSchedule: Bool
    let isActive: Bool
    let password: String?

    enum CodingKeys: String, CodingKey {
        case name, email, role, password
        case jobTitle = "job_title"
        case workAreaID = "work_area_id"
        case supervisedWorkAreaIDs = "supervised_work_area_ids"
        case appearsInSchedule = "appears_in_schedule"
        case isActive = "is_active"
    }
}

private struct WorkAreaPayload: Encodable {
    let name: String
    let description: String?
    let isActive: Bool
    enum CodingKeys: String, CodingKey { case name, description; case isActive = "is_active" }
}

private struct SitePayload: Encodable {
    let name: String
    let description: String?
    let isActive: Bool
    enum CodingKeys: String, CodingKey { case name, description; case isActive = "is_active" }
}

private struct ProjectPayload: Encodable {
    let siteID: String
    let name: String
    let description: String?
    let isActive: Bool
    enum CodingKeys: String, CodingKey { case name, description; case siteID = "site_id"; case isActive = "is_active" }
}

private struct StagePayload: Encodable {
    let projectID: String
    let name: String
    let operationalStatus: String?
    let isActive: Bool
    enum CodingKeys: String, CodingKey { case name; case projectID = "project_id"; case operationalStatus = "operational_status"; case isActive = "is_active" }
}

private struct SystemPayload: Encodable {
    let projectID: String
    let name: String
    let description: String?
    let isActive: Bool
    enum CodingKeys: String, CodingKey { case name, description; case projectID = "project_id"; case isActive = "is_active" }
}

private struct SubsystemPayload: Encodable {
    let systemID: String
    let code: String
    let name: String
    let description: String?
    let isActive: Bool
    enum CodingKeys: String, CodingKey { case code, name, description; case systemID = "system_id"; case isActive = "is_active" }
}

private struct AdministrationService {
    let client: APIClient

    init(baseURL: String) { client = APIClient(baseURLString: baseURL) }

    func bootstrap(token: String) async throws -> AdministrationSnapshot {
        try await client.get("api/v1/administration/bootstrap", bearerToken: token)
    }

    func saveUser(id: String?, payload: ManagedUserPayload, token: String) async throws {
        let response: ManagedUser
        if let id {
            response = try await client.put("api/v1/administration/users/\(id)", body: payload, bearerToken: token)
        } else {
            response = try await client.post("api/v1/administration/users", body: payload, bearerToken: token)
        }
        _ = response
    }

    func saveWorkArea(id: String?, payload: WorkAreaPayload, token: String) async throws {
        let _: ManagedWorkArea = if let id {
            try await client.put("api/v1/administration/work-areas/\(id)", body: payload, bearerToken: token)
        } else {
            try await client.post("api/v1/administration/work-areas", body: payload, bearerToken: token)
        }
    }

    func saveSite(id: String?, payload: SitePayload, token: String) async throws {
        let _: ManagedSite = if let id {
            try await client.put("api/v1/administration/sites/\(id)", body: payload, bearerToken: token)
        } else {
            try await client.post("api/v1/administration/sites", body: payload, bearerToken: token)
        }
    }

    func saveProject(id: String?, payload: ProjectPayload, token: String) async throws {
        let _: ManagedProject = if let id {
            try await client.put("api/v1/administration/projects/\(id)", body: payload, bearerToken: token)
        } else {
            try await client.post("api/v1/administration/projects", body: payload, bearerToken: token)
        }
    }

    func saveStage(id: String?, payload: StagePayload, token: String) async throws {
        let _: ManagedStage = if let id {
            try await client.put("api/v1/administration/stages/\(id)", body: payload, bearerToken: token)
        } else {
            try await client.post("api/v1/administration/stages", body: payload, bearerToken: token)
        }
    }

    func saveSystem(id: String?, payload: SystemPayload, token: String) async throws {
        let _: ManagedSystem = if let id {
            try await client.put("api/v1/administration/systems/\(id)", body: payload, bearerToken: token)
        } else {
            try await client.post("api/v1/administration/systems", body: payload, bearerToken: token)
        }
    }

    func saveSubsystem(id: String?, payload: SubsystemPayload, token: String) async throws {
        let _: ManagedSubsystem = if let id {
            try await client.put("api/v1/administration/subsystems/\(id)", body: payload, bearerToken: token)
        } else {
            try await client.post("api/v1/administration/subsystems", body: payload, bearerToken: token)
        }
    }

    func savePermissions(role: String, permissions: [String: String], token: String) async throws {
        let _: ManagedRolePermissions = try await client.put(
            "api/v1/administration/permissions/\(role)",
            body: RolePermissionsPayload(permissions: permissions),
            bearerToken: token
        )
    }
}

private enum AdministrationSection: String, CaseIterable, Identifiable {
    case people = "Usuarios y personal"
    case organization = "Estructura organizacional"
    case permissions = "Permisos por perfil"
    case operations = "Configuracion operativa"
    var id: String { rawValue }
}

private enum StructureKind: String, CaseIterable, Identifiable {
    case workArea = "Areas"
    case site = "Sedes"
    case project = "Proyectos"
    case stage = "Etapas"
    case system = "Sistemas"
    case subsystem = "Subsistemas"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .workArea: "person.3.fill"
        case .site: "mappin.and.ellipse"
        case .project: "building.2.fill"
        case .stage: "flag.checkered"
        case .system: "square.stack.3d.up.fill"
        case .subsystem: "square.3.layers.3d"
        }
    }
}

private enum AdministrationSheet: Identifiable {
    case user(ManagedUser?)
    case structure(StructureKind, String?)

    var id: String {
        switch self {
        case .user(let user): "user-\(user?.id ?? "new")"
        case .structure(let kind, let id): "\(kind.id)-\(id ?? "new")"
        }
    }
}

struct AdministrationView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var section = AdministrationSection.people
    @State private var structureKind = StructureKind.workArea
    @State private var snapshot = AdministrationSnapshot.empty
    @State private var query = ""
    @State private var showInactive = false
    @State private var sheet: AdministrationSheet?
    @State private var isShowingOfflineWork = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedPermissionRole = "MAINTENANCE_ENGINEER"
    @State private var permissionDrafts: [String: [String: String]] = [:]
    @State private var isSavingPermissions = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    header
                    administrationSectionPicker(isWide: geometry.size.width >= 900)

                    switch section {
                    case .people:
                        peopleContent(isWide: geometry.size.width >= 900)
                    case .organization:
                        organizationContent(isWide: geometry.size.width >= 900)
                    case .permissions:
                        permissionsContent(isWide: geometry.size.width >= 900)
                    case .operations:
                        operationsContent(isWide: geometry.size.width >= 900)
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(BrandColor.red)
                            .padding(AppSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(BrandColor.redSubtle, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: 1280)
                .frame(maxWidth: .infinity)
            }
            .refreshable { await load() }
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Administracion")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(item: $sheet) { item in
            switch item {
            case .user(let user):
                UserAdministrationForm(user: user, workAreas: snapshot.workAreas) { payload in
                    try await saveUser(id: user?.id, payload: payload)
                }
            case .structure(let kind, let id):
                StructureAdministrationForm(kind: kind, recordID: id, snapshot: snapshot) { save in
                    try await saveStructure(save)
                }
            }
        }
        .sheet(isPresented: $isShowingOfflineWork) {
            OfflineWorkCenterView()
        }
        .overlay {
            if isLoading && snapshot.users.isEmpty {
                ProgressView("Cargando administracion...")
                    .padding(AppSpacing.lg)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom) {
                headerTitle
                Spacer()
                if section == .people || section == .organization { createButton }
            }
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                headerTitle
                if section == .people || section == .organization { createButton }
            }
        }
    }

    private var headerTitle: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text("Administracion")
                    .font(.largeTitle.bold())
                Text("Gestiona personas, permisos y la estructura maestra de la operacion")
                    .foregroundStyle(.secondary)
            }
    }

    private var createButton: some View {
            Button {
                sheet = section == .people ? .user(nil) : .structure(structureKind, nil)
            } label: {
                Label(section == .people ? "Nuevo usuario" : "Nuevo registro", systemImage: "plus")
            }
            .buttonStyle(ActionTileButtonStyle(prominent: true))
    }

    @ViewBuilder
    private func administrationSectionPicker(isWide: Bool) -> some View {
        if isWide {
            Picker("Modulo", selection: $section) {
                ForEach(AdministrationSection.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
        } else {
            HStack(spacing: AppSpacing.md) {
                Text("Modulo")
                    .font(.headline)
                Spacer()
                Picker("Modulo", selection: $section) {
                    ForEach(AdministrationSection.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(minHeight: 52)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func permissionsContent(isWide: Bool) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SectionHeaderText(
                    title: "Permisos por perfil",
                    subtitle: "Define qué módulos puede ver cada perfil y si puede modificarlos. Administración permanece reservada para administradores."
                )

                if isWide {
                    HStack(alignment: .top, spacing: AppSpacing.lg) {
                        permissionRoleList.frame(width: 260)
                        permissionEditor
                    }
                } else {
                    Picker("Perfil", selection: $selectedPermissionRole) {
                        ForEach(snapshot.rolePermissions) { group in
                            Text(group.roleLabel).tag(group.role)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, AppSpacing.md)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                    permissionEditor
                }
            }
        }
    }

    private var permissionRoleList: some View {
        VStack(spacing: AppSpacing.xs) {
            ForEach(snapshot.rolePermissions) { group in
                Button {
                    selectedPermissionRole = group.role
                } label: {
                    HStack {
                        Image(systemName: group.isLocked ? "lock.fill" : "person.crop.circle")
                        Text(group.roleLabel)
                            .fontWeight(selectedPermissionRole == group.role ? .semibold : .regular)
                        Spacer()
                        if selectedPermissionRole == group.role {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .foregroundStyle(selectedPermissionRole == group.role ? BrandColor.red : .primary)
                    .padding(AppSpacing.md)
                    .background(
                        selectedPermissionRole == group.role ? BrandColor.redSubtle : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var permissionEditor: some View {
        if let group = snapshot.rolePermissions.first(where: { $0.role == selectedPermissionRole }) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.roleLabel).font(.title3.bold())
                        Text(group.isLocked ? "Acceso total protegido" : "Selecciona el nivel de acceso por módulo")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !group.isLocked {
                        Button {
                            Task { await savePermissions(for: group.role) }
                        } label: {
                            if isSavingPermissions {
                                ProgressView().tint(.white)
                            } else {
                                Label("Guardar permisos", systemImage: "checkmark.circle.fill")
                            }
                        }
                        .buttonStyle(ActionTileButtonStyle(prominent: true))
                        .disabled(isSavingPermissions)
                    }
                }

                ForEach(group.permissions) { permission in
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: AppSpacing.md) {
                            permissionModuleLabel(permission)
                            Spacer()
                            permissionLevelPicker(group: group, permission: permission)
                                .frame(width: 430)
                        }
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            permissionModuleLabel(permission)
                            permissionLevelPicker(group: group, permission: permission)
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                }

                Label(
                    "Los cambios se aplican al volver a iniciar sesión o al renovar la sesión.",
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        } else {
            ContentUnavailableView(
                "Sin perfiles",
                systemImage: "person.crop.circle.badge.questionmark"
            )
        }
    }

    private func permissionModuleLabel(_ permission: ManagedModulePermission) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(permission.label).font(.headline)
            Text(permissionDescription(permission.module))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func permissionLevelPicker(
        group: ManagedRolePermissions,
        permission: ManagedModulePermission
    ) -> some View {
        Picker(
            permission.label,
            selection: permissionBinding(role: group.role, module: permission.module)
        ) {
            Text("Sin acceso").tag("NONE")
            Text("Solo lectura").tag("READ")
            Text("Puede modificar").tag("WRITE")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .disabled(group.isLocked)
    }

    private func permissionBinding(role: String, module: String) -> Binding<String> {
        Binding(
            get: { permissionDrafts[role]?[module] ?? "NONE" },
            set: { permissionDrafts[role, default: [:]][module] = $0 }
        )
    }

    private func permissionDescription(_ module: String) -> String {
        switch module {
        case "HOME": "Panel principal y resumen operativo"
        case "PREVENTIVE": "Mantenimientos y reportes preventivos"
        case "CORRECTIVE": "Eventos y reportes correctivos"
        case "PCON": "Planificación anual, mensual y semanal"
        case "EQUIPMENT": "Inventario y detalle de equipos"
        case "SCHEDULE": "Horario del equipo de trabajo"
        case "STOCK": "Existencias y movimientos de almacén"
        case "TOOLS": "Herramientas y asignaciones"
        case "PROFILE": "Perfil personal y credenciales"
        default: "Módulo de la aplicación"
        }
    }

    private func operationsContent(isWide: Bool) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Configuracion operativa",
                    subtitle: "Administra plantillas y recursos locales de la aplicacion"
                )
                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(minimum: isWide ? 360 : 280),
                            spacing: AppSpacing.md
                        )
                    ],
                    spacing: AppSpacing.md
                ) {
                    NavigationLink {
                        PreventiveTemplateListView()
                    } label: {
                        administrationActionCard(
                            title: "Checklists preventivos",
                            subtitle: "Crea y edita las plantillas usadas en los reportes preventivos.",
                            systemImage: "checklist"
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        isShowingOfflineWork = true
                    } label: {
                        administrationActionCard(
                            title: "Trabajo offline",
                            subtitle: "Gestiona catalogos, trabajos descargados y sincronizacion local.",
                            systemImage: "ipad.and.arrow.forward"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func administrationActionCard(
        title: String,
        subtitle: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(BrandColor.red)
                .frame(width: 48, height: 48)
                .background(BrandColor.redSubtle, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func peopleContent(isWide: Bool) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                filterBar(placeholder: "Buscar por nombre, correo o cargo")
                let users = filteredUsers
                if users.isEmpty {
                    ContentUnavailableView("Sin usuarios", systemImage: "person.3", description: Text("No hay resultados para los filtros seleccionados."))
                        .frame(minHeight: 260)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: isWide ? 440 : 300), spacing: AppSpacing.sm)], spacing: AppSpacing.sm) {
                        ForEach(users) { user in
                            userCard(user)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func organizationContent(isWide: Bool) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if isWide {
                    Picker("Catalogo", selection: $structureKind) {
                        ForEach(StructureKind.allCases) { kind in
                            Label(kind.rawValue, systemImage: kind.icon).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                } else {
                    Picker("Catalogo", selection: $structureKind) {
                        ForEach(StructureKind.allCases) { kind in
                            Label(kind.rawValue, systemImage: kind.icon).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                }
                filterBar(placeholder: "Buscar en \(structureKind.rawValue.lowercased())")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: isWide ? 360 : 280), spacing: AppSpacing.sm)], spacing: AppSpacing.sm) {
                    ForEach(structureRows) { row in
                        structureCard(row)
                    }
                }
            }
        }
    }

    private func filterBar(placeholder: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.md) { searchField(placeholder); inactiveToggle }
            VStack(alignment: .leading, spacing: AppSpacing.sm) { searchField(placeholder); inactiveToggle }
        }
    }

    private func searchField(_ placeholder: String) -> some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(placeholder, text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(height: 48)
        .background(.background.opacity(0.76), in: RoundedRectangle(cornerRadius: 8))
    }

    private var inactiveToggle: some View {
        Toggle("Mostrar inactivos", isOn: $showInactive)
            .toggleStyle(.switch)
            .fixedSize()
    }

    private var filteredUsers: [ManagedUser] {
        snapshot.users.filter { user in
            (showInactive || user.isActive) && (query.isEmpty || [user.name, user.email, user.jobTitle, user.workAreaName ?? ""].contains { $0.localizedCaseInsensitiveContains(query) })
        }
    }

    private func userCard(_ user: ManagedUser) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: user.isActive ? "person.crop.circle.fill" : "person.crop.circle.badge.xmark")
                .font(.title2)
                .foregroundStyle(user.isActive ? BrandColor.red : .secondary)
                .frame(width: 44, height: 44)
                .background(BrandColor.redSubtle, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(user.name).font(.headline)
                    statusBadge(active: user.isActive)
                }
                Text(user.jobTitle).font(.subheadline).foregroundStyle(.secondary)
                Text([user.workAreaName, user.appearsInSchedule ? "Visible en Horarios" : nil].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
                if user.role == "BOSS", !user.supervisedWorkAreaIDs.isEmpty {
                    Text("Supervisa \(user.supervisedWorkAreaIDs.count) area(s)")
                        .font(.caption.weight(.semibold)).foregroundStyle(BrandColor.red)
                }
            }
            Spacer()
            Button { sheet = .user(user) } label: {
                Label("Editar", systemImage: "pencil")
            }
            .buttonStyle(.bordered)
        }
        .padding(AppSpacing.md)
        .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
    }

    private struct StructureRow: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let active: Bool
    }

    private var structureRows: [StructureRow] {
        let rows: [StructureRow]
        switch structureKind {
        case .workArea:
            rows = snapshot.workAreas.map { .init(id: $0.id, title: $0.name, subtitle: $0.description ?? "Area de trabajo", active: $0.isActive) }
        case .site:
            rows = snapshot.sites.map { .init(id: $0.id, title: $0.name, subtitle: $0.description ?? "Sede", active: $0.isActive) }
        case .project:
            rows = snapshot.projects.map { .init(id: $0.id, title: $0.name, subtitle: $0.siteName, active: $0.isActive) }
        case .stage:
            rows = snapshot.stages.map { item in .init(id: item.id, title: item.name, subtitle: projectName(item.projectID), active: item.isActive) }
        case .system:
            rows = snapshot.systems.map { item in .init(id: item.id, title: item.name, subtitle: projectName(item.projectID), active: item.isActive) }
        case .subsystem:
            rows = snapshot.subsystems.map { item in .init(id: item.id, title: "\(item.code) · \(item.name)", subtitle: systemName(item.systemID), active: item.isActive) }
        }
        return rows.filter { (showInactive || $0.active) && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.subtitle.localizedCaseInsensitiveContains(query)) }
    }

    private func structureCard(_ row: StructureRow) -> some View {
        Button { sheet = .structure(structureKind, row.id) } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: structureKind.icon)
                    .font(.title3)
                    .foregroundStyle(BrandColor.red)
                    .frame(width: 42, height: 42)
                    .background(BrandColor.redSubtle, in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title).font(.headline).foregroundStyle(.primary)
                    Text(row.subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                statusBadge(active: row.active)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(AppSpacing.md)
            .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func statusBadge(active: Bool) -> some View {
        Text(active ? "Activo" : "Inactivo")
            .font(.caption.weight(.bold))
            .foregroundStyle(active ? BrandColor.green : .secondary)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background((active ? BrandColor.green : Color.secondary).opacity(0.1), in: Capsule())
    }

    private func projectName(_ id: String) -> String { snapshot.projects.first { $0.id == id }?.name ?? "Proyecto no disponible" }
    private func systemName(_ id: String) -> String { snapshot.systems.first { $0.id == id }?.name ?? "Sistema no disponible" }

    private func load() async {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            snapshot = try await session.withValidAccessToken { token in
                try await AdministrationService(baseURL: baseURL).bootstrap(token: token)
            }
            permissionDrafts = Dictionary(
                uniqueKeysWithValues: snapshot.rolePermissions.map { group in
                    (
                        group.role,
                        Dictionary(
                            uniqueKeysWithValues: group.permissions.map {
                                ($0.module, $0.permissionLevel)
                            }
                        )
                    )
                }
            )
            if !snapshot.rolePermissions.contains(where: { $0.role == selectedPermissionRole }) {
                selectedPermissionRole = snapshot.rolePermissions.first?.role ?? ""
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func savePermissions(for role: String) async {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL"),
              let values = permissionDrafts[role] else { return }
        isSavingPermissions = true
        errorMessage = nil
        defer { isSavingPermissions = false }
        do {
            try await session.withValidAccessToken { token in
                try await AdministrationService(baseURL: baseURL).savePermissions(
                    role: role,
                    permissions: values,
                    token: token
                )
            }
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveUser(id: String?, payload: ManagedUserPayload) async throws {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else { throw APIClient.APIError.invalidBaseURL }
        try await session.withValidAccessToken { token in
            try await AdministrationService(baseURL: baseURL).saveUser(id: id, payload: payload, token: token)
        }
        await load()
    }

    private func saveStructure(_ save: StructureSave) async throws {
        guard let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else { throw APIClient.APIError.invalidBaseURL }
        try await session.withValidAccessToken { token in
            let service = AdministrationService(baseURL: baseURL)
            switch save {
            case .workArea(let id, let payload): try await service.saveWorkArea(id: id, payload: payload, token: token)
            case .site(let id, let payload): try await service.saveSite(id: id, payload: payload, token: token)
            case .project(let id, let payload): try await service.saveProject(id: id, payload: payload, token: token)
            case .stage(let id, let payload): try await service.saveStage(id: id, payload: payload, token: token)
            case .system(let id, let payload): try await service.saveSystem(id: id, payload: payload, token: token)
            case .subsystem(let id, let payload): try await service.saveSubsystem(id: id, payload: payload, token: token)
            }
        }
        await load()
    }
}

private struct UserAdministrationForm: View {
    @Environment(\.dismiss) private var dismiss
    let user: ManagedUser?
    let workAreas: [ManagedWorkArea]
    let onSave: (ManagedUserPayload) async throws -> Void

    @State private var name: String
    @State private var email: String
    @State private var role: String
    @State private var jobTitle: String
    @State private var workAreaID: String
    @State private var supervisedAreaIDs: Set<String>
    @State private var appearsInSchedule: Bool
    @State private var isActive: Bool
    @State private var password = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(user: ManagedUser?, workAreas: [ManagedWorkArea], onSave: @escaping (ManagedUserPayload) async throws -> Void) {
        self.user = user
        self.workAreas = workAreas
        self.onSave = onSave
        _name = State(initialValue: user?.name ?? "")
        _email = State(initialValue: user?.email ?? "")
        _role = State(initialValue: user?.role ?? "MAINTENANCE_ENGINEER")
        _jobTitle = State(initialValue: user?.jobTitle ?? "")
        _workAreaID = State(initialValue: user?.workAreaID ?? "")
        _supervisedAreaIDs = State(initialValue: Set(user?.supervisedWorkAreaIDs ?? []))
        _appearsInSchedule = State(initialValue: user?.appearsInSchedule ?? true)
        _isActive = State(initialValue: user?.isActive ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identidad") {
                    TextField("Nombre completo", text: $name)
                    TextField("Correo", text: $email)
                        .textInputAutocapitalization(.never).keyboardType(.emailAddress)
                    SecureField(user == nil ? "Contrasena inicial" : "Nueva contrasena (opcional)", text: $password)
                    TextField("Cargo", text: $jobTitle)
                }
                Section("Asignacion") {
                    Picker("Rol", selection: $role) {
                        Text("Ingeniero de mantenimiento").tag("MAINTENANCE_ENGINEER")
                        Text("Coordinador").tag("COORDINATOR")
                        Text("Jefe").tag("BOSS")
                        Text("Administrador").tag("ADMINISTRATOR")
                    }
                    Picker("Area de trabajo", selection: $workAreaID) {
                        Text("Sin area").tag("")
                        ForEach(workAreas.filter(\.isActive)) { area in Text(area.name).tag(area.id) }
                    }
                    if role != "BOSS" {
                        Toggle("Aparece en Horarios", isOn: $appearsInSchedule)
                    }
                    Toggle("Usuario activo", isOn: $isActive)
                }
                if role == "BOSS" {
                    Section("Areas que puede supervisar") {
                        ForEach(workAreas.filter(\.isActive)) { area in
                            Toggle(area.name, isOn: areaBinding(area.id))
                        }
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(BrandColor.red) }
                }
            }
            .navigationTitle(user == nil ? "Nuevo usuario" : "Editar usuario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }
                        .disabled(!isValid || isSaving)
                }
            }
            .onChange(of: role) {
                if role == "BOSS" { appearsInSchedule = false } else { supervisedAreaIDs = [] }
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && email.contains("@")
            && !jobTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (user != nil || password.count >= 8)
            && (!appearsInSchedule || !workAreaID.isEmpty)
    }

    private func areaBinding(_ id: String) -> Binding<Bool> {
        Binding(get: { supervisedAreaIDs.contains(id) }, set: { selected in
            if selected { supervisedAreaIDs.insert(id) } else { supervisedAreaIDs.remove(id) }
        })
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            try await onSave(ManagedUserPayload(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                role: role,
                jobTitle: jobTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                workAreaID: workAreaID.isEmpty ? nil : workAreaID,
                supervisedWorkAreaIDs: role == "BOSS" ? supervisedAreaIDs.sorted() : [],
                appearsInSchedule: role == "BOSS" ? false : appearsInSchedule,
                isActive: isActive,
                password: password.isEmpty ? nil : password
            ))
            dismiss()
        } catch { errorMessage = error.localizedDescription }
        isSaving = false
    }
}

private enum StructureSave {
    case workArea(String?, WorkAreaPayload)
    case site(String?, SitePayload)
    case project(String?, ProjectPayload)
    case stage(String?, StagePayload)
    case system(String?, SystemPayload)
    case subsystem(String?, SubsystemPayload)
}

private struct StructureAdministrationForm: View {
    @Environment(\.dismiss) private var dismiss
    let kind: StructureKind
    let recordID: String?
    let snapshot: AdministrationSnapshot
    let onSave: (StructureSave) async throws -> Void

    @State private var name = ""
    @State private var code = ""
    @State private var description = ""
    @State private var parentID = ""
    @State private var status = ""
    @State private var isActive = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Informacion") {
                    if kind == .subsystem {
                        TextField("Codigo", text: $code).textInputAutocapitalization(.characters)
                    }
                    TextField("Nombre", text: $name)
                    if kind == .stage {
                        TextField("Estado operativo (opcional)", text: $status)
                    } else {
                        TextField("Descripcion (opcional)", text: $description, axis: .vertical)
                    }
                }
                if kind != .workArea && kind != .site {
                    Section("Relacion") { parentPicker }
                }
                Section("Disponibilidad") {
                    Toggle("Registro activo", isOn: $isActive)
                    Text("Los registros inactivos se conservan para no perder el historial relacionado.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let errorMessage { Section { Text(errorMessage).foregroundStyle(BrandColor.red) } }
            }
            .navigationTitle(recordID == nil ? "Nuevo \(kind.rawValue.lowercased())" : "Editar \(kind.rawValue.lowercased())")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }.disabled(!isValid || isSaving)
                }
            }
            .onAppear { populate() }
        }
    }

    @ViewBuilder private var parentPicker: some View {
        switch kind {
        case .workArea, .site: EmptyView()
        case .project:
            Picker("Sede", selection: $parentID) { ForEach(snapshot.sites.filter(\.isActive)) { Text($0.name).tag($0.id) } }
        case .stage, .system:
            Picker("Proyecto", selection: $parentID) { ForEach(snapshot.projects.filter(\.isActive)) { Text($0.name).tag($0.id) } }
        case .subsystem:
            Picker("Sistema", selection: $parentID) { ForEach(snapshot.systems.filter(\.isActive)) { Text($0.name).tag($0.id) } }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (kind == .workArea || kind == .site || !parentID.isEmpty)
            && (kind != .subsystem || !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func populate() {
        guard let recordID else {
            switch kind {
            case .project: parentID = snapshot.sites.first(where: \.isActive)?.id ?? ""
            case .stage, .system: parentID = snapshot.projects.first(where: \.isActive)?.id ?? ""
            case .subsystem: parentID = snapshot.systems.first(where: \.isActive)?.id ?? ""
            case .workArea, .site: break
            }
            return
        }
        switch kind {
        case .workArea:
            guard let item = snapshot.workAreas.first(where: { $0.id == recordID }) else { return }
            name = item.name; description = item.description ?? ""; isActive = item.isActive
        case .site:
            guard let item = snapshot.sites.first(where: { $0.id == recordID }) else { return }
            name = item.name; description = item.description ?? ""; isActive = item.isActive
        case .project:
            guard let item = snapshot.projects.first(where: { $0.id == recordID }) else { return }
            name = item.name; description = item.description ?? ""; parentID = item.siteID; isActive = item.isActive
        case .stage:
            guard let item = snapshot.stages.first(where: { $0.id == recordID }) else { return }
            name = item.name; status = item.operationalStatus ?? ""; parentID = item.projectID; isActive = item.isActive
        case .system:
            guard let item = snapshot.systems.first(where: { $0.id == recordID }) else { return }
            name = item.name; description = item.description ?? ""; parentID = item.projectID; isActive = item.isActive
        case .subsystem:
            guard let item = snapshot.subsystems.first(where: { $0.id == recordID }) else { return }
            name = item.name; code = item.code; description = item.description ?? ""; parentID = item.systemID; isActive = item.isActive
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            switch kind {
            case .workArea:
                try await onSave(.workArea(recordID, .init(name: cleanName, description: cleanDescription.isEmpty ? nil : cleanDescription, isActive: isActive)))
            case .site:
                try await onSave(.site(recordID, .init(name: cleanName, description: cleanDescription.isEmpty ? nil : cleanDescription, isActive: isActive)))
            case .project:
                try await onSave(.project(recordID, .init(siteID: parentID, name: cleanName, description: cleanDescription.isEmpty ? nil : cleanDescription, isActive: isActive)))
            case .stage:
                let cleanStatus = status.trimmingCharacters(in: .whitespacesAndNewlines)
                try await onSave(.stage(recordID, .init(projectID: parentID, name: cleanName, operationalStatus: cleanStatus.isEmpty ? nil : cleanStatus, isActive: isActive)))
            case .system:
                try await onSave(.system(recordID, .init(projectID: parentID, name: cleanName, description: cleanDescription.isEmpty ? nil : cleanDescription, isActive: isActive)))
            case .subsystem:
                try await onSave(.subsystem(recordID, .init(systemID: parentID, code: code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), name: cleanName, description: cleanDescription.isEmpty ? nil : cleanDescription, isActive: isActive)))
            }
            dismiss()
        } catch { errorMessage = error.localizedDescription }
        isSaving = false
    }
}
