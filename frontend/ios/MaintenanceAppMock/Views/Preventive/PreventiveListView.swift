import SwiftUI

struct PreventiveListView: View {
    @EnvironmentObject private var store: MockMaintenanceStore
    @State private var selectedFilter: MaintenanceDateFilter = .today
    @State private var searchText = ""
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var selectedYear = Calendar.current.component(.year, from: Date())

    private var filteredActivities: [PreventiveActivity] {
        store.activities
            .filter { matches($0.scheduledDate, filter: selectedFilter) }
            .filter { activity in
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !query.isEmpty else { return true }
                return activity.name.localizedCaseInsensitiveContains(query) ||
                    activity.templateName.localizedCaseInsensitiveContains(query) ||
                    activity.assets.joined(separator: " ").localizedCaseInsensitiveContains(query)
            }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                PreventiveSummaryStrip(
                    scheduled: store.activities.filter { $0.status == .scheduled }.count,
                    inProgress: store.activities.filter { $0.status == .inProgress }.count,
                    completed: store.activities(for: .completed).count
                )

                historyFilterBar

                activitySection("Programados y en progreso", subtitle: filterSubtitle, activities: filteredActivities.filter { $0.status == .scheduled || $0.status == .inProgress })
                activitySection("Completados", subtitle: "Listos para revision o cierre", activities: filteredActivities.filter { $0.status == .completed })
                activitySection("Cerrados", subtitle: "Historico sin edicion activa", activities: filteredActivities.filter { $0.status == .closed })

                if filteredActivities.isEmpty {
                    GlassPanel {
                        Text("No hay preventivos para este filtro.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(MaintenanceScreenBackground())
        .navigationTitle("Preventivos")
    }

    private var historyFilterBar: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: "Filtros", subtitle: "Segun fecha de programacion")
                ActionButtonGrid {
                    ForEach(MaintenanceDateFilter.allCases) { filter in
                        Button {
                            selectedFilter = filter
                        } label: {
                            Label(filter.label, systemImage: filter == selectedFilter ? "line.3.horizontal.decrease.circle.fill" : filter.icon)
                        }
                        .buttonStyle(ActionTileButtonStyle(prominent: filter == selectedFilter))
                    }
                }

                if selectedFilter == .specificMonth {
                    HStack(spacing: AppSpacing.md) {
                        Picker("Mes", selection: $selectedMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text(Self.monthName(month)).tag(month)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Anio", selection: $selectedYear) {
                            ForEach((selectedYear - 2)...(selectedYear + 1), id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(AppSpacing.md)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Buscar por nombre de mantenimiento", text: $searchText)
                        .textInputAutocapitalization(.never)
                }
                .padding(AppSpacing.md)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func activitySection(_ title: String, subtitle: String, activities: [PreventiveActivity]) -> some View {
        if !activities.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeaderText(title: title, subtitle: subtitle)
                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(activities) { activity in
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
    }

    private var filterSubtitle: String {
        if selectedFilter == .specificMonth {
            return "\(Self.monthName(selectedMonth)) \(selectedYear)"
        }
        return selectedFilter.label
    }

    private func matches(_ date: Date, filter: MaintenanceDateFilter) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        switch filter {
        case .today:
            return calendar.isDate(date, inSameDayAs: now)
        case .thisWeek:
            return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .thisMonth:
            return calendar.isDate(date, equalTo: now, toGranularity: .month)
        case .specificMonth:
            return calendar.component(.month, from: date) == selectedMonth &&
                calendar.component(.year, from: date) == selectedYear
        }
    }

    private static func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        return formatter.monthSymbols[max(0, min(month - 1, 11))].capitalized
    }
}

private struct HistoricalPreventiveCard: View {
    let report: HistoricalMaintenanceReport

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(report.activityName)
                    .font(.title3.weight(.bold))
                Label(report.equipmentName, systemImage: "wrench.and.screwdriver")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Ingeniero de Mantenimiento: \(report.technicianName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                Text(Self.dateFormatter.string(from: report.performedAt))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(report.result)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandColor.red)
            }
        }
        .padding(AppSpacing.lg)
        .background(.background.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BrandColor.red.opacity(0.08), lineWidth: 1)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}


private struct PreventiveSummaryStrip: View {
    let scheduled: Int
    let inProgress: Int
    let completed: Int

    var body: some View {
        GlassPanel {
            HStack(spacing: AppSpacing.md) {
                compactMetric("Programados", scheduled, "calendar", BrandColor.graphite)
                Divider()
                compactMetric("En progreso", inProgress, "arrow.triangle.2.circlepath", BrandColor.amber)
                Divider()
                compactMetric("Completados", completed, "checkmark.circle.fill", BrandColor.green)
            }
        }
    }

    private func compactMetric(_ title: String, _ value: Int, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

struct PreventiveActivityRow: View {
    let activity: PreventiveActivity

    var body: some View {
        PreventiveActivityCard(activity: activity)
    }
}

struct PreventiveListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PreventiveListView()
                .environmentObject(MockMaintenanceStore())
        }
    }
}
