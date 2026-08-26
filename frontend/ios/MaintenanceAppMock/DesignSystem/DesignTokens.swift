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
            .glassEffect(.regular.tint(BrandColor.red.opacity(0.04)).interactive(), in: .rect(cornerRadius: 18))
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
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

struct MaintenanceLifecycleActionPanel: View {
    let status: String
    let role: UserRole
    let isWorking: Bool
    let errorMessage: String?
    let onClearError: () -> Void
    let onPerform: (MaintenanceLifecycleCommand, String?) -> Void

    @State private var confirmationCommand: MaintenanceLifecycleCommand?
    @State private var isShowingReopenSheet = false
    @State private var reopenReason = ""

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(
                    title: "Acciones",
                    subtitle: "Cambios de estado registrados con tu usuario"
                )

                ActionButtonGrid {
                    ForEach(Self.commands(status: status, role: role)) { command in
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
                        .buttonStyle(
                            ActionTileButtonStyle(
                                prominent: command == .start || command == .complete,
                                prominentColor: command == .start
                                    ? BrandColor.green
                                    : BrandColor.red
                            )
                        )
                        .disabled(isWorking)
                        .opacity(isWorking ? 0.55 : 1)
                        .accessibilityHint(command.accessibilityHint)
                    }
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

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: icon)
                .font(.system(size: 76, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.055))
                .padding(.trailing, 10)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                HStack(spacing: AppSpacing.xs) {
                    Circle()
                        .fill(tint)
                        .frame(width: 10, height: 10)
                    Text(statusText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.lg)
        }
        .frame(minHeight: 132)
        .background(colorScheme == .dark ? Color(.secondarySystemBackground) : Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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

                TextField("Escribir comentario", text: $message, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .textFieldStyle(.roundedBorder)

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
