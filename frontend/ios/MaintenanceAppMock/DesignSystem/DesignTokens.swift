import SwiftUI

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

struct StatusBadge: View {
    let status: MaintenanceStatus

    var body: some View {
        Label(status.label, systemImage: status.icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.foregroundColor)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 6)
            .background(status.backgroundColor)
            .clipShape(Capsule())
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
            .glassEffect(.regular.tint(BrandColor.red.opacity(0.04)).interactive(), in: .rect(cornerRadius: 18))
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

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .labelStyle(.titleAndIcon)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .center)
            .padding(.horizontal, AppSpacing.md)
            .foregroundStyle(prominent ? Color.white : BrandColor.red)
            .background(
                prominent ? BrandColor.red : BrandColor.red.opacity(configuration.isPressed ? 0.16 : 0.10),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

struct ParticipantsSignaturePanel: View {
    @Binding var participants: [ReportParticipantDraft]
    @Binding var signingParticipantID: UUID?
    @Binding var signatureStrokes: [UUID: [[CGPoint]]]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ForEach($participants) { $participant in
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Toggle(isOn: $participant.isSelected) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: participant.user.avatarSystemImage)
                                .font(.title3)
                                .foregroundStyle(BrandColor.red)
                            VStack(alignment: .leading) {
                                Text(participant.user.name)
                                    .font(.headline)
                                Text(participant.user.role.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if participant.isSelected {
                        HStack(alignment: .center, spacing: AppSpacing.md) {
                            Button {
                                signingParticipantID = participant.id
                            } label: {
                                Label(participant.hasSignature ? "Volver a firmar" : "Dibujar firma", systemImage: "pencil.and.scribble")
                            }
                            .buttonStyle(ActionTileButtonStyle(prominent: !participant.hasSignature))
                            .frame(maxWidth: 260)

                            SignaturePreview(
                                name: participant.user.name,
                                isSigned: participant.hasSignature,
                                strokes: signatureStrokes[participant.id] ?? []
                            )
                        }
                    }
                }
                .padding(AppSpacing.md)
                .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

struct ReportSignaturesPreview: View {
    let signatures: [ReportSignature]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ForEach(signatures) { signature in
                HStack(alignment: .center, spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(signature.user.name)
                            .font(.headline)
                        Text(signature.user.role.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 220, alignment: .leading)

                    SignaturePreview(
                        name: signature.user.name,
                        isSigned: !signature.strokes.isEmpty,
                        strokes: signature.strokes
                    )
                }
                .padding(AppSpacing.md)
                .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if signatures.isEmpty {
                Text("Aun no hay firmas capturadas para este reporte.")
                    .foregroundStyle(.secondary)
            }
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
                .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.04), lineWidth: 1)
        }
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

extension View {
    func maintenanceListChrome() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(MaintenanceScreenBackground())
    }
}
