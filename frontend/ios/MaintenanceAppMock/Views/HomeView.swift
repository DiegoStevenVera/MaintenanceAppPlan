import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var activityStore: MaintenanceActivityStore
    @State private var selectedMetric: DashboardMetric?

    private enum DashboardMetric: String {
        case preventiveToday
        case activeCorrectives
        case pendingClosure
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
                            Text("Hola, \(session.currentUser?.name ?? "Usuario")")
                                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            Text("Turno activo como \(session.currentUser?.role.label ?? "Sin rol")")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: session.currentUser?.avatarSystemImage ?? "person.crop.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(BrandColor.red)
                            .frame(width: 78, height: 78)
                            .background(BrandColor.red.opacity(0.12), in: Circle())
                    }
                }

                LazyVGrid(columns: metricColumns, spacing: AppSpacing.md) {
                    metricButton(
                        metric: .preventiveToday,
                        title: "Preventivos de hoy",
                        value: activityStore.dashboard?.preventiveTodayCount ?? 0,
                        icon: "calendar.badge.clock",
                        tint: BrandColor.red,
                        statusText: "Listos para revisar"
                    )
                    metricButton(
                        metric: .activeCorrectives,
                        title: "Correctivos activos",
                        value: activityStore.dashboard?.activeCorrectiveCount ?? 0,
                        icon: "exclamationmark.triangle",
                        tint: BrandColor.amber,
                        statusText: "Accion requerida"
                    )
                    metricButton(
                        metric: .pendingClosure,
                        title: "Pendientes de cierre",
                        value: activityStore.dashboard?.pendingClosureCount ?? 0,
                        icon: "lock.open",
                        tint: BrandColor.green,
                        statusText: "Listos para cierre"
                    )
                }

                if selectedMetric == nil || selectedMetric == .preventiveToday {
                    dashboardSection(
                        title: "Preventivos de hoy",
                        subtitle: "Actividades con fecha especifica para el turno",
                        activities: activityStore.dashboard?.preventiveToday ?? [],
                        emptyMessage: "No hay preventivos con fecha especifica para hoy."
                    )
                }

                if selectedMetric == nil || selectedMetric == .activeCorrectives {
                    dashboardSection(
                        title: "Correctivos",
                        subtitle: "Actividades programadas y en progreso",
                        activities: activityStore.dashboard?.activeCorrectives ?? [],
                        emptyMessage: "No hay correctivos activos."
                    )
                }

                if selectedMetric == .pendingClosure {
                    dashboardSection(
                        title: "Pendientes de cierre",
                        subtitle: "Actividades completadas que esperan cierre",
                        activities: activityStore.dashboard?.pendingClosure ?? [],
                        emptyMessage: "No hay mantenimientos pendientes de cierre."
                    )
                }

                if let error = activityStore.dashboardError {
                    ContentUnavailableView {
                        Label("No se pudo cargar Inicio", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Reintentar") { Task { await loadDashboard() } }
                    }
                } else if activityStore.isLoadingDashboard && activityStore.dashboard == nil {
                    ProgressView("Cargando indicadores")
                        .frame(maxWidth: .infinity)
                        .padding(AppSpacing.xl)
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Inicio")
        .refreshable { await loadDashboard() }
        .task { await loadDashboard() }
    }

    private func loadDashboard() async {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }
        await activityStore.loadDashboard(dayFrom: start, dayTo: end, session: session)
    }

    private func metricButton(
        metric: DashboardMetric,
        title: String,
        value: Int,
        icon: String,
        tint: Color,
        statusText: String
    ) -> some View {
        Button {
            withAnimation(.snappy) {
                selectedMetric = selectedMetric == metric ? nil : metric
            }
        } label: {
            MetricGlassCard(
                title: title,
                value: "\(value)",
                icon: icon,
                tint: tint,
                statusText: statusText,
                isSelected: selectedMetric == metric
            )
        }
        .buttonStyle(.plain)
        .accessibilityValue(selectedMetric == metric ? "Filtro aplicado" : "Sin seleccionar")
        .accessibilityHint(selectedMetric == metric ? "Toca para limpiar el filtro" : "Toca para filtrar")
    }

    @ViewBuilder
    private func dashboardSection(
        title: String,
        subtitle: String,
        activities: [APIActivity],
        emptyMessage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeaderText(title: title, subtitle: subtitle)
            if activities.isEmpty {
                GlassPanel {
                    Text(emptyMessage)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(activities) { activity in
                        NavigationLink {
                            if activity.activityType == "CORRECTIVE" {
                                CorrectiveDetailView(eventID: activity.id)
                            } else {
                                PreventiveDetailView(activityID: activity.id)
                            }
                        } label: {
                            APIActivityCard(activity: activity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HomeView()
                .environmentObject(SessionStore())
                .environmentObject(MaintenanceActivityStore())
        }
    }
}
