import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: MockMaintenanceStore

    private var todayActivities: [PreventiveActivity] {
        store.activities.filter { $0.status != .closed }
    }

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 190), spacing: AppSpacing.md)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                GlassPanel {
                    HStack(alignment: .center, spacing: AppSpacing.lg) {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Linea 2 · Senalizacion")
                                .font(.caption.weight(.bold))
                                .textCase(.uppercase)
                                .foregroundStyle(BrandColor.red)
                            Text("Hola, \(store.currentUser.name)")
                                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            Text("Turno activo como \(store.currentUser.role.label)")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: store.currentUser.avatarSystemImage)
                            .font(.system(size: 52))
                            .foregroundStyle(BrandColor.red)
                            .frame(width: 78, height: 78)
                            .background(BrandColor.red.opacity(0.12), in: Circle())
                    }
                }

                LazyVGrid(columns: metricColumns, spacing: AppSpacing.md) {
                    MetricGlassCard(title: "Preventivos de hoy", value: "\(todayActivities.count)", icon: "calendar.badge.clock", statusText: "Listos para revisar")
                    MetricGlassCard(title: "Correctivos activos", value: "\(store.activeCorrectiveCount)", icon: "exclamationmark.triangle", tint: BrandColor.amber, statusText: "Accion requerida")
                    MetricGlassCard(title: "Pendientes de cierre", value: "\(store.pendingClosureCount)", icon: "lock.open", tint: BrandColor.green, statusText: "Listos para cierre")
                }

                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    SectionHeaderText(title: "Preventivos cercanos", subtitle: "Actividades que necesitan atencion del turno")

                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(todayActivities.prefix(4)) { activity in
                            NavigationLink {
                                PreventiveDetailView(activityID: activity.id)
                            } label: {
                                PreventiveActivityCard(activity: activity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Inicio")
    }
}

struct PreventiveActivityCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let activity: PreventiveActivity

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color.white)
                .shadow(color: BrandColor.signalInk.opacity(colorScheme == .dark ? 0.0 : 0.06), radius: 16, x: 0, y: 8)

            if activity.status == .inProgress || activity.status == .scheduled {
                UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18)
                    .fill(BrandColor.red)
                    .frame(width: 6)
            }

            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(activity.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Label(activity.locationPath, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: AppSpacing.md)
                    StatusBadge(status: activity.status)
                }

                HStack(alignment: .bottom) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(BrandColor.red)
                    Text(activity.subsystem)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BrandColor.red)
                    Spacer()
                    Text(scheduleLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, AppSpacing.lg)
            .padding(.vertical, AppSpacing.lg)
            .padding(.trailing, AppSpacing.lg)
        }
        .frame(minHeight: 148)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BrandColor.red.opacity(activity.status == .scheduled ? 0.10 : 0.0), lineWidth: 1)
        }
        .glassEffect(.regular.tint(BrandColor.red.opacity(0.02)).interactive(), in: .rect(cornerRadius: 18))
    }

    private var scheduleLabel: String {
        switch activity.status {
        case .scheduled:
            return "PROGRAMADO \(Self.timeFormatter.string(from: activity.scheduledDate))"
        case .inProgress:
            return "INICIADO \(Self.timeFormatter.string(from: activity.startedAt ?? activity.scheduledDate))"
        case .completed:
            return "COMPLETADO \(Self.timeFormatter.string(from: activity.endedAt ?? activity.scheduledDate))"
        case .closed:
            return "CERRADO"
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

struct EquipmentPhotoPanel: View {
    let activity: PreventiveActivity

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if usesATSCabinetPhoto {
                Image("ats-cabinet-reference")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .overlay {
                        LinearGradient(
                            colors: [Color.black.opacity(0.05), Color.black.opacity(0.20)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [BrandColor.red.opacity(0.14), BrandColor.graphite.opacity(0.18), BrandColor.red.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                SignalMapLines()
                    .stroke(Color.white.opacity(0.18), lineWidth: 2)
                    .padding(AppSpacing.lg)

                Image(systemName: equipmentSymbol)
                    .font(.system(size: 118, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.86))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "plus.magnifyingglass")
                Image(systemName: "camera")
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(BrandColor.signalInk)
            .padding(AppSpacing.sm)
            .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(AppSpacing.md)
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        }
        .accessibilityLabel("Imagen referencial del equipo \(activity.assets.first ?? "")")
    }

    private var equipmentSymbol: String {
        let joined = activity.assets.joined(separator: " ").lowercased()
        if joined.contains("tren") {
            return "tram.fill"
        }
        if joined.contains("lim") || joined.contains("software") {
            return "server.rack"
        }
        if joined.contains("crk") || joined.contains("frontam") {
            return "shippingbox.fill"
        }
        return "square.stack.3d.up.fill"
    }

    private var usesATSCabinetPhoto: Bool {
        let joined = "\(activity.name) \(activity.templateName) \(activity.assets.joined(separator: " ")) \(activity.subsystem)"
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        return joined.contains("ats")
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HomeView()
                .environmentObject(MockMaintenanceStore())
        }
    }
}
