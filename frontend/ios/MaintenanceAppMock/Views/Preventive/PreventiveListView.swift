import SwiftUI

struct PreventiveListView: View {
    @EnvironmentObject private var store: MockMaintenanceStore

    var body: some View {
        List {
            activitySection("Hoy", activities: store.activities.filter { $0.status == .scheduled || $0.status == .inProgress })
            activitySection("Completados", activities: store.activities(for: .completed))
            activitySection("Cerrados", activities: store.activities(for: .closed))
        }
        .navigationTitle("Preventivos")
    }

    @ViewBuilder
    private func activitySection(_ title: String, activities: [PreventiveActivity]) -> some View {
        if !activities.isEmpty {
            Section(title) {
                ForEach(activities) { activity in
                    NavigationLink {
                        PreventiveDetailView(activityID: activity.id)
                    } label: {
                        PreventiveActivityRow(activity: activity)
                    }
                }
            }
        }
    }
}

struct PreventiveActivityRow: View {
    let activity: PreventiveActivity

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .top) {
                Text(activity.name)
                    .font(.headline)
                Spacer()
                StatusBadge(status: activity.status)
            }

            Text(activity.assets.joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Label(activity.location, systemImage: "mappin.and.ellipse")
                Spacer()
                Text(activity.subsystem)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack {
        PreventiveListView()
            .environmentObject(MockMaintenanceStore())
    }
}

