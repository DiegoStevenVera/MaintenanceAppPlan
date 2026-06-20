import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: MockMaintenanceStore

    var todayActivities: [PreventiveActivity] {
        store.activities.filter { $0.status != .closed }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Hola, \(store.currentUser.name)")
                        .font(.largeTitle.weight(.bold))
                    Text(store.currentUser.role.label)
                        .font(.headline)
                        .foregroundStyle(BrandColor.graphite)
                }
                .padding(.vertical, AppSpacing.sm)
            }

            Section("Resumen") {
                SummaryRow(title: "Preventivos de hoy", value: "\(todayActivities.count)", icon: "calendar.badge.clock")
                SummaryRow(title: "Correctivos activos", value: "\(store.activeCorrectiveCount)", icon: "exclamationmark.triangle")
                SummaryRow(title: "Pendientes de cierre", value: "\(store.pendingClosureCount)", icon: "lock.open")
            }

            Section("Preventivos cercanos") {
                ForEach(todayActivities.prefix(3)) { activity in
                    NavigationLink {
                        PreventiveDetailView(activityID: activity.id)
                    } label: {
                        PreventiveActivityRow(activity: activity)
                    }
                }
            }
        }
        .navigationTitle("Inicio")
    }
}

struct SummaryRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .foregroundStyle(BrandColor.red)
                .frame(width: 28)

            Text(title)
            Spacer()
            Text(value)
                .font(.title3.weight(.bold))
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(MockMaintenanceStore())
    }
}

