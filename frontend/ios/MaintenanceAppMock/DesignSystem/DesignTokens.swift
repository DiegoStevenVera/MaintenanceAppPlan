import SwiftUI
import UIKit

func maintenanceBundleImage(_ name: String) -> Image {
    guard let image = UIImage(named: name, in: .main, compatibleWith: nil) else {
        return Image(systemName: "photo")
    }
    return Image(uiImage: image)
}

enum BrandColor {
    static let red = Color(red: 0.902, green: 0.0, blue: 0.071)
    static let redPressed = Color(red: 0.722, green: 0.0, blue: 0.055)
    static let redSubtle = Color(red: 0.992, green: 0.922, blue: 0.925)
    static let graphite = Color(red: 0.290, green: 0.290, blue: 0.290)
    static let backgroundSecondary = Color(red: 0.965, green: 0.965, blue: 0.965)
    static let signalInk = Color(red: 0.075, green: 0.089, blue: 0.110)
    static let railMist = Color(red: 0.922, green: 0.941, blue: 0.953)
    static let glassStroke = Color.white.opacity(0.42)
    static let amber = Color(red: 0.780, green: 0.471, blue: 0.0)
    static let green = Color(red: 0.122, green: 0.541, blue: 0.298)
}

enum AppSpacing {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

struct PaginationBar: View {
    let currentPage: Int
    let pageCount: Int
    var hasMore = false
    var isLoading = false
    let onSelectPage: (Int) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            pagination(maximumPageButtons: 7)
            pagination(maximumPageButtons: 5)
            pagination(maximumPageButtons: 3)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func pagination(maximumPageButtons: Int) -> some View {
        HStack(spacing: 4) {
            navigationButton(
                systemImage: "chevron.left",
                accessibilityLabel: "Pagina anterior",
                isDisabled: currentPage <= 0
            ) {
                onSelectPage(max(0, currentPage - 1))
            }

            ForEach(items(maximumPageButtons: maximumPageButtons)) { item in
                switch item.kind {
                case let .page(page):
                    Button {
                        onSelectPage(page)
                    } label: {
                        Text(String(page + 1))
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .frame(width: 34, height: 34)
                            .foregroundStyle(page == currentPage ? Color.white : Color.primary)
                            .background(
                                page == currentPage ? BrandColor.red : Color.clear,
                                in: Circle()
                            )
                            .overlay {
                                if page == currentPage {
                                    Circle().stroke(Color.white.opacity(0.45), lineWidth: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                    .accessibilityLabel("Pagina \(page + 1)")
                    .accessibilityAddTraits(page == currentPage ? .isSelected : [])

                case .ellipsis:
                    Text("...")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 34)
                        .accessibilityHidden(true)
                }
            }

            if hasMore {
                Text("...")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 34)
                    .accessibilityLabel("Hay mas paginas disponibles")
            }

            navigationButton(
                systemImage: "chevron.right",
                accessibilityLabel: "Pagina siguiente",
                isDisabled: currentPage >= normalizedPageCount - 1 && !hasMore
            ) {
                onSelectPage(currentPage + 1)
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
        .overlay { Capsule().stroke(BrandColor.glassStroke, lineWidth: 1) }
        .glassEffect(.regular.tint(BrandColor.red.opacity(0.035)), in: .capsule)
        .fixedSize(horizontal: true, vertical: false)
        .opacity(isLoading ? 0.72 : 1)
        .animation(.snappy, value: currentPage)
    }

    private func navigationButton(
        systemImage: String,
        accessibilityLabel: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if isLoading, systemImage == "chevron.right" {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: systemImage)
                        .font(.caption.bold())
                }
            }
            .frame(width: 34, height: 34)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(accessibilityLabel)
    }

    private var normalizedPageCount: Int {
        max(1, pageCount)
    }

    private func items(maximumPageButtons: Int) -> [PaginationItem] {
        let count = normalizedPageCount
        guard count > maximumPageButtons else {
            return (0..<count).map { PaginationItem(kind: .page($0)) }
        }

        let lastPage = count - 1
        let interiorCount = max(1, maximumPageButtons - 2)

        if currentPage <= interiorCount {
            let pages = (0...interiorCount).map { PaginationItem(kind: .page($0)) }
            return pages + [PaginationItem(kind: .ellipsis(1)), PaginationItem(kind: .page(lastPage))]
        }

        if currentPage >= lastPage - interiorCount {
            let firstVisible = lastPage - interiorCount
            let pages = (firstVisible...lastPage).map { PaginationItem(kind: .page($0)) }
            return [PaginationItem(kind: .page(0)), PaginationItem(kind: .ellipsis(0))] + pages
        }

        let halfWindow = interiorCount / 2
        let start = currentPage - halfWindow
        let end = start + interiorCount - 1
        let middle = (start...end).map { PaginationItem(kind: .page($0)) }
        return [PaginationItem(kind: .page(0)), PaginationItem(kind: .ellipsis(0))]
            + middle
            + [PaginationItem(kind: .ellipsis(1)), PaginationItem(kind: .page(lastPage))]
    }
}

private struct PaginationItem: Identifiable {
    enum Kind: Hashable {
        case page(Int)
        case ellipsis(Int)
    }

    let kind: Kind

    var id: Kind { kind }
}

extension String {
    /// Keeps activity summaries scannable without changing the full location
    /// retained in the database or shown in detailed report views.
    var activityLocationSummary: String {
        let levels = split(separator: "/")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return levels.prefix(2).joined(separator: " / ")
    }
}

struct MaintenanceScreenBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white)
            SignalMapLines()
                .stroke(BrandColor.red.opacity(colorScheme == .dark ? 0.18 : 0.10), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                .padding(.horizontal, 28)
                .padding(.vertical, 56)
        }
        .ignoresSafeArea()
    }
}

struct SignalMapLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let y1 = rect.minY + rect.height * 0.18
        let y2 = rect.minY + rect.height * 0.44
        let y3 = rect.minY + rect.height * 0.72
        let xStart = rect.minX + rect.width * 0.04
        let xEnd = rect.maxX - rect.width * 0.06

        path.move(to: CGPoint(x: xStart, y: y1))
        path.addLine(to: CGPoint(x: rect.midX * 0.82, y: y1))
        path.addCurve(
            to: CGPoint(x: rect.midX * 1.10, y: y2),
            control1: CGPoint(x: rect.midX * 0.98, y: y1),
            control2: CGPoint(x: rect.midX * 0.92, y: y2)
        )
        path.addLine(to: CGPoint(x: xEnd, y: y2))

        path.move(to: CGPoint(x: xStart, y: y3))
        path.addLine(to: CGPoint(x: rect.midX * 0.60, y: y3))
        path.addLine(to: CGPoint(x: rect.midX * 0.92, y: y2))
        path.addLine(to: CGPoint(x: xEnd, y: y1 + rect.height * 0.04))

        for xRatio in [0.18, 0.38, 0.58, 0.78] {
            let x = rect.minX + rect.width * xRatio
            path.move(to: CGPoint(x: x, y: y2 - 5))
            path.addLine(to: CGPoint(x: x, y: y2 + 5))
        }

        return path
    }
}

struct GlassPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.md)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(BrandColor.glassStroke, lineWidth: 1)
            }
            // Large report sections are passive surfaces. Keeping the glass
            // non-interactive here avoids making the whole scrolling region a
            // live Liquid Glass sample; buttons keep the interactive effect.
            .glassEffect(.regular.tint(BrandColor.red.opacity(0.04)), in: .rect(cornerRadius: 18))
            .shadow(color: BrandColor.signalInk.opacity(0.08), radius: 18, x: 0, y: 10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Liquid Glass surface for paginated, scrollable content.
///
/// The outer surface keeps the original material and tint, but leaves touch
/// interaction to the individual rows so a tall panel does not become one
/// giant interactive texture while scrolling.
struct ContentGlassPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.md)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(BrandColor.glassStroke, lineWidth: 1)
            }
            .glassEffect(
                .regular.tint(BrandColor.red.opacity(0.04)),
                in: .rect(cornerRadius: 18)
            )
            .shadow(color: BrandColor.signalInk.opacity(0.08), radius: 18, x: 0, y: 10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DetailTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct ActionButtonGrid<Content: View>: View {
    let content: Content

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 190), spacing: AppSpacing.md)]
    }

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: AppSpacing.md) {
            content
        }
        .frame(maxWidth: .infinity)
    }
}

struct ActionTileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var prominent = false
    var prominentColor = BrandColor.red

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .labelStyle(.titleAndIcon)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .center)
            .padding(.horizontal, AppSpacing.md)
            .foregroundStyle(prominent ? Color.white : BrandColor.red)
            .background(
                prominent ? prominentColor : BrandColor.red.opacity(configuration.isPressed ? 0.16 : 0.10),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .glassEffect(
                .regular.tint((prominent ? prominentColor : BrandColor.red).opacity(0.10)).interactive(),
                in: .rect(cornerRadius: 18)
            )
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1.0 : 0.98)
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: configuration.isPressed)
    }
}

struct CompactActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var prominent = false
    var prominentColor = BrandColor.red

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, AppSpacing.md)
            .frame(minHeight: 42)
            .foregroundStyle(prominent ? Color.white : BrandColor.red)
            .background(
                prominent
                    ? prominentColor.opacity(configuration.isPressed ? 0.82 : 1)
                    : BrandColor.red.opacity(configuration.isPressed ? 0.16 : 0.09),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .glassEffect(
                .regular.tint((prominent ? prominentColor : BrandColor.red).opacity(0.10)).interactive(),
                in: .rect(cornerRadius: 12)
            )
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.98)
            .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: configuration.isPressed)
    }
}

/// Shared form-field surfaces. They intentionally keep the report bindings and
/// persistence flow untouched while giving the operational forms a consistent,
/// accessible label and focus treatment.
private struct MaintenanceInputSurface: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.md)
            .background(
                isFocused ? BrandColor.red.opacity(0.075) : Color.primary.opacity(0.035),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isFocused ? BrandColor.red.opacity(0.80) : Color.primary.opacity(0.10),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            }
            .animation(.easeOut(duration: 0.16), value: isFocused)
    }
}

private extension View {
    func maintenanceInputSurface(isFocused: Bool = false) -> some View {
        modifier(MaintenanceInputSurface(isFocused: isFocused))
    }
}

struct MaintenanceTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var systemImage: String? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var disablesAutocorrection = false

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            MaintenanceFieldLabel(title: title, systemImage: systemImage)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(disablesAutocorrection)
                .focused($isFocused)
                .accessibilityLabel(title)
        }
        .maintenanceInputSurface(isFocused: isFocused)
    }
}

struct MaintenanceTextArea: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var systemImage: String? = nil
    var minimumLines = 2
    var maximumLines = 4

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            MaintenanceFieldLabel(title: title, systemImage: systemImage)
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(maximumLines, reservesSpace: true)
                .frame(minHeight: CGFloat(minimumLines) * 22)
                .focused($isFocused)
                .accessibilityLabel(title)
        }
        .maintenanceInputSurface(isFocused: isFocused)
    }
}

struct MaintenanceChoiceField<Selection: Hashable, Content: View>: View {
    let title: String
    let systemImage: String?
    @Binding var selection: Selection
    @ViewBuilder let content: () -> Content

    init(
        _ title: String,
        systemImage: String? = nil,
        selection: Binding<Selection>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        _selection = selection
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            MaintenanceFieldLabel(title: title, systemImage: systemImage)
            Picker(title, selection: $selection, content: content)
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(title)
        }
        .maintenanceInputSurface()
    }
}

struct MaintenanceSegmentedChoiceField<Selection: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: Selection
    @ViewBuilder let content: () -> Content

    init(
        _ title: String,
        selection: Binding<Selection>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        _selection = selection
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            MaintenanceFieldLabel(title: title)
            Picker(title, selection: $selection, content: content)
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel(title)
        }
        .maintenanceInputSurface()
    }
}

struct MaintenanceDateTimeField: View {
    let title: String
    @Binding var selection: Date
    var displayedComponents: DatePickerComponents = [.date, .hourAndMinute]

    var body: some View {
        DatePicker(title, selection: $selection, displayedComponents: displayedComponents)
            .datePickerStyle(.compact)
            .font(.body.weight(.medium))
            .maintenanceInputSurface()
            .accessibilityLabel(title)
    }
}

struct MaintenanceToggleField: View {
    let title: String
    let systemImage: String?
    @Binding var isOn: Bool

    init(_ title: String, systemImage: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.systemImage = systemImage
        _isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            MaintenanceFieldLabel(title: title, systemImage: systemImage)
        }
        .toggleStyle(.switch)
        .maintenanceInputSurface()
    }
}

struct MaintenanceFieldGrid<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 280), spacing: AppSpacing.md)],
            alignment: .leading,
            spacing: AppSpacing.md
        ) {
            content
        }
    }
}

private struct MaintenanceFieldLabel: View {
    let title: String
    let systemImage: String?

    init(title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label {
            Text(title)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
        } icon: {
            if let systemImage {
                Image(systemName: systemImage)
            }
        }
        .foregroundStyle(.secondary)
    }
}

struct MaintenanceLifecycleActionPanel: View {
    enum Presentation {
        case panel
        case compact
    }

    let status: String
    let role: UserRole
    var completionAllowed = true
    let isWorking: Bool
    let errorMessage: String?
    let onClearError: () -> Void
    let onPerform: (MaintenanceLifecycleCommand, String?) -> Void
    var presentation: Presentation = .panel

    @State private var confirmationCommand: MaintenanceLifecycleCommand?
    @State private var isShowingReopenSheet = false
    @State private var reopenReason = ""

    var body: some View {
        Group {
            if presentation == .panel {
                GlassPanel {
                    actionContent(showsHeader: true)
                }
            } else {
                actionContent(showsHeader: false)
            }
        }
        .alert(
            confirmationCommand?.confirmationTitle ?? "Confirmar accion",
            isPresented: confirmationBinding,
            presenting: confirmationCommand
        ) { command in
            if command == .close {
                Button(command.label, role: .destructive) {
                    onPerform(command, nil)
                }
            } else {
                Button(command.label) {
                    onPerform(command, nil)
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: { command in
            Text(command.confirmationMessage)
        }
        .sheet(isPresented: $isShowingReopenSheet) {
            NavigationStack {
                Form {
                    Section("Motivo de reapertura") {
                        TextEditor(text: $reopenReason)
                            .frame(minHeight: 120)
                        Text("El motivo quedara registrado en el historial del mantenimiento.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Reabrir mantenimiento")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") {
                            isShowingReopenSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Reabrir") {
                            let reason = reopenReason.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                            isShowingReopenSheet = false
                            onPerform(.reopen, reason)
                        }
                        .disabled(
                            reopenReason.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).count < 3
                        )
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func actionContent(showsHeader: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if showsHeader {
                SectionHeaderText(
                    title: "Acciones",
                    subtitle: "Cambios de estado registrados con tu usuario"
                )
            }

            if presentation == .compact {
                HStack(spacing: AppSpacing.sm) {
                    lifecycleButtons(isCompact: true)
                }
            } else {
                ActionButtonGrid {
                    lifecycleButtons(isCompact: false)
                }
            }

            if presentation == .panel,
               Self.commands(status: status, role: role).contains(.complete),
               !completionAllowed {
                Label(
                    "Finaliza al menos una versión del reporte antes de completar el mantenimiento.",
                    systemImage: "doc.badge.exclamationmark"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            if isWorking {
                HStack(spacing: AppSpacing.sm) {
                    ProgressView()
                    Text("Actualizando el mantenimiento...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            if let errorMessage {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(BrandColor.red)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Button("Cerrar", action: onClearError)
                        .font(.subheadline.weight(.semibold))
                }
                .padding(AppSpacing.md)
                .background(
                    BrandColor.red.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            }
        }
    }

    @ViewBuilder
    private func lifecycleButtons(isCompact: Bool) -> some View {
        ForEach(Self.commands(status: status, role: role)) { command in
            if isCompact {
                lifecycleButton(command)
                    .buttonStyle(
                        CompactActionButtonStyle(
                            prominent: command == .start || command == .complete,
                            prominentColor: command == .start ? BrandColor.green : BrandColor.red
                        )
                    )
            } else {
                lifecycleButton(command)
                    .buttonStyle(
                        ActionTileButtonStyle(
                            prominent: command == .start || command == .complete,
                            prominentColor: command == .start ? BrandColor.green : BrandColor.red
                        )
                    )
            }
        }
    }

    private func lifecycleButton(_ command: MaintenanceLifecycleCommand) -> some View {
        Button {
            if command == .reopen {
                reopenReason = ""
                isShowingReopenSheet = true
            } else {
                confirmationCommand = command
            }
        } label: {
            Label(command.label, systemImage: command.icon)
        }
        .disabled(isWorking || (command == .complete && !completionAllowed))
        .opacity(isWorking || (command == .complete && !completionAllowed) ? 0.55 : 1)
        .accessibilityHint(command.accessibilityHint)
    }

    static func hasActions(status: String, role: UserRole) -> Bool {
        !commands(status: status, role: role).isEmpty
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { confirmationCommand != nil },
            set: { isPresented in
                if !isPresented {
                    confirmationCommand = nil
                }
            }
        )
    }

    private static func commands(
        status: String,
        role: UserRole
    ) -> [MaintenanceLifecycleCommand] {
        guard role != .boss else { return [] }
        switch status {
        case "SCHEDULED":
            return [.start]
        case "IN_PROGRESS":
            return [.complete]
        case "COMPLETED":
            return role.canCloseMaintenance ? [.reopen, .close] : [.reopen]
        case "CLOSED":
            return role.canCloseMaintenance ? [.reopen] : []
        default:
            return []
        }
    }
}

private extension MaintenanceLifecycleCommand {
    var confirmationTitle: String {
        switch self {
        case .start: return "¿Iniciar mantenimiento?"
        case .complete: return "¿Completar mantenimiento?"
        case .close: return "¿Cerrar mantenimiento?"
        case .reopen: return "Reabrir mantenimiento"
        }
    }

    var confirmationMessage: String {
        switch self {
        case .start:
            return "La hora actual quedara registrada como inicio real."
        case .complete:
            return "La hora actual y tu usuario quedaran registrados como finalizacion."
        case .close:
            return "Una vez cerrado, solo un Coordinador o Administrador podra reabrirlo."
        case .reopen:
            return "El mantenimiento volvera al estado En progreso."
        }
    }

    var accessibilityHint: String {
        switch self {
        case .start: return "Cambia el mantenimiento programado a En progreso."
        case .complete: return "Marca el mantenimiento en progreso como Completado."
        case .close: return "Cierra el mantenimiento completado."
        case .reopen: return "Solicita un motivo y devuelve el mantenimiento a En progreso."
        }
    }
}

struct SignaturePreview: View {
    let name: String
    let isSigned: Bool
    let strokes: [[CGPoint]]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .foregroundStyle(isSigned ? BrandColor.red : .secondary)

            if isSigned {
                SignatureCanvas(strokes: strokes, currentStroke: [], scalesToFit: true)
                    .padding(AppSpacing.sm)
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(AppSpacing.sm)
            } else {
                Text("Sin firma")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .accessibilityLabel(isSigned ? "Firma capturada de \(name)" : "Firma pendiente de \(name)")
    }
}

struct ReportParticipantsPanel: View {
    @Binding var participants: [ReportFormParticipant]
    let onSign: (String) -> Void
    @State private var showsUnselected = false

    private var selectedIndices: [Int] {
        participants.indices.filter { participants[$0].isSelected }
    }

    private var unselectedIndices: [Int] {
        participants.indices.filter { !participants[$0].isSelected }
    }

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Participantes y firmas",
                    subtitle: "\(selectedIndices.count) seleccionado(s)"
                )

                if !unselectedIndices.isEmpty {
                    DisclosureGroup(
                        isExpanded: $showsUnselected
                    ) {
                        VStack(spacing: AppSpacing.xs) {
                            ForEach(unselectedIndices, id: \.self) { index in
                                Toggle(
                                    isOn: $participants[index].isSelected
                                ) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(participants[index].name)
                                            .font(.subheadline.weight(.semibold))
                                        Text(participants[index].role)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, AppSpacing.xs)
                            }
                        }
                        .padding(.top, AppSpacing.sm)
                    } label: {
                        Label(
                            "No seleccionados (\(unselectedIndices.count))",
                            systemImage: "person.2.slash"
                        )
                        .font(.subheadline.weight(.semibold))
                    }
                    .padding(AppSpacing.md)
                    .background(
                        .background.opacity(0.58),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                }

                if selectedIndices.isEmpty {
                    Label(
                        "Seleccione al menos un participante",
                        systemImage: "person.crop.circle.badge.exclamationmark"
                    )
                    .foregroundStyle(.secondary)
                    .padding(.vertical, AppSpacing.sm)
                }

                ForEach(selectedIndices, id: \.self) { index in
                    selectedParticipant(participant: $participants[index])
                }
            }
        }
    }

    private func selectedParticipant(
        participant: Binding<ReportFormParticipant>
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Toggle(isOn: participant.isSelected) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(participant.wrappedValue.name).font(.headline)
                    Text(participant.wrappedValue.role)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: AppSpacing.md) {
                Button {
                    onSign(participant.wrappedValue.id)
                } label: {
                    Label(
                        participant.wrappedValue.strokes.isEmpty
                            ? "Dibujar firma"
                            : "Volver a firmar",
                        systemImage: "pencil.and.scribble"
                    )
                }
                .buttonStyle(
                    ActionTileButtonStyle(
                        prominent: participant.wrappedValue.strokes.isEmpty
                    )
                )
                .frame(maxWidth: 250)

                SignaturePreview(
                    name: participant.wrappedValue.name,
                    isSigned: !participant.wrappedValue.strokes.isEmpty,
                    strokes: participant.wrappedValue.strokes
                )
            }
        }
        .padding(AppSpacing.md)
        .background(
            .background.opacity(0.72),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }
}

struct SignatureCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    let participantName: String
    @Binding var strokes: [[CGPoint]]
    let onConfirm: () -> Void
    @State private var currentStroke: [CGPoint] = []

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SectionHeaderText(title: "Dibujar firma", subtitle: participantName)

                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white)
                    SignatureCanvas(strokes: strokes, currentStroke: currentStroke, scalesToFit: false)
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(Color.black.opacity(0.22))
                            .frame(height: 1)
                            .padding(.horizontal, AppSpacing.xl)
                            .padding(.bottom, AppSpacing.lg)
                    }
                }
                .frame(minHeight: 300)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(BrandColor.red.opacity(0.25), lineWidth: 1)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            currentStroke.append(value.location)
                        }
                        .onEnded { _ in
                            if !currentStroke.isEmpty {
                                strokes.append(currentStroke)
                                currentStroke = []
                            }
                        }
                )

                ActionButtonGrid {
                    Button {
                        strokes = []
                        currentStroke = []
                    } label: {
                        Label("Limpiar", systemImage: "eraser")
                    }
                    .buttonStyle(ActionTileButtonStyle())

                    Button {
                        onConfirm()
                    } label: {
                        Label("Guardar firma", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(ActionTileButtonStyle(prominent: true))
                }
            }
            .padding(AppSpacing.lg)
            .background(MaintenanceScreenBackground())
            .navigationTitle("Firma")
            .toolbar {
                Button("Cerrar") {
                    dismiss()
                }
            }
        }
    }
}

struct SignatureCanvas: View {
    let strokes: [[CGPoint]]
    let currentStroke: [CGPoint]
    var scalesToFit = false

    var body: some View {
        Canvas { context, size in
            let allStrokes = strokes + [currentStroke]
            let transform = scalesToFit ? Self.fitTransform(for: allStrokes, in: size) : .identity

            for stroke in allStrokes {
                guard let first = stroke.first else { continue }
                var path = Path()
                path.move(to: first.applying(transform))
                for point in stroke.dropFirst() {
                    path.addLine(to: point.applying(transform))
                }
                context.stroke(path, with: .color(BrandColor.red), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private static func fitTransform(for strokes: [[CGPoint]], in size: CGSize) -> CGAffineTransform {
        let points = strokes.flatMap { $0 }
        guard let first = points.first, size.width > 0, size.height > 0 else { return .identity }

        let bounds = points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { partial, point in
            partial.union(CGRect(origin: point, size: .zero))
        }

        guard bounds.width > 0, bounds.height > 0 else {
            return CGAffineTransform(translationX: size.width * 0.5 - first.x, y: size.height * 0.5 - first.y)
        }

        let padding: CGFloat = 18
        let scale = min((size.width - padding * 2) / bounds.width, (size.height - padding * 2) / bounds.height)
        let fittedWidth = bounds.width * scale
        let fittedHeight = bounds.height * scale
        let offsetX = (size.width - fittedWidth) * 0.5 - bounds.minX * scale
        let offsetY = (size.height - fittedHeight) * 0.5 - bounds.minY * scale

        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: offsetX, ty: offsetY)
    }
}

struct MetricGlassCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let value: String
    let icon: String
    var tint: Color = BrandColor.red
    var statusText: String = "Accion requerida"
    var isSelected = false
    var isCompact = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: icon)
                .font(.system(size: isCompact ? 48 : 76, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.055))
                .padding(.trailing, isCompact ? 6 : 10)
                .padding(.top, isCompact ? 6 : 8)

            VStack(alignment: .leading, spacing: isCompact ? AppSpacing.xs : AppSpacing.sm) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: isCompact ? 30 : 40, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                HStack(spacing: AppSpacing.xs) {
                    Circle()
                        .fill(tint)
                        .frame(width: 10, height: 10)
                    Text(statusText)
                        .font(isCompact ? .caption.weight(.medium) : .subheadline.weight(.medium))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(isCompact ? AppSpacing.md : AppSpacing.lg)
        }
        .frame(minHeight: isCompact ? 100 : 132)
        .background(
            isSelected ? tint.opacity(0.14) : Color.clear,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .background(
            colorScheme == .dark ? Color(.secondarySystemBackground) : Color.white,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isSelected
                        ? tint.opacity(0.85)
                        : colorScheme == .dark
                            ? Color.white.opacity(0.10)
                            : Color.black.opacity(0.04),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .scaleEffect(isSelected ? 1.015 : 1)
        .shadow(color: BrandColor.signalInk.opacity(colorScheme == .dark ? 0.0 : 0.06), radius: 16, x: 0, y: 8)
        .glassEffect(.regular.tint(tint.opacity(0.025)).interactive(), in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}

struct SectionHeaderText: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct MaintenanceCommentsPanel: View {
    let comments: [APIMaintenanceComment]
    @Binding var message: String
    let isSending: Bool
    let errorMessage: String?
    let title: String
    let subtitle: String
    let onSend: () -> Void

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: title, subtitle: subtitle)

                if comments.isEmpty {
                    Label("Aún no hay comentarios para este mantenimiento.", systemImage: "bubble.left")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, AppSpacing.xs)
                } else {
                    ForEach(comments) { comment in
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            HStack(alignment: .top, spacing: AppSpacing.sm) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(BrandColor.red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(comment.authorName)
                                        .font(.headline)
                                    Text(comment.authorRole)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(comment.createdAt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(comment.message)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(AppSpacing.md)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                MaintenanceTextArea(
                    title: "Nuevo comentario",
                    placeholder: "Escribir comentario",
                    text: $message,
                    systemImage: "bubble.left.and.bubble.right",
                    minimumLines: 2,
                    maximumLines: 4
                )

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(BrandColor.red)
                }

                Button(action: onSend) {
                    Label(
                        isSending ? "Guardando comentario..." : "Guardar comentario",
                        systemImage: "paperplane.fill"
                    )
                }
                .buttonStyle(ActionTileButtonStyle())
                .disabled(isSending || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

extension View {
    func maintenanceListChrome() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(MaintenanceScreenBackground())
    }
}
