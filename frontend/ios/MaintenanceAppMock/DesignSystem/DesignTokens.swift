import SwiftUI

enum BrandColor {
    static let red = Color(red: 0.902, green: 0.0, blue: 0.071)
    static let redPressed = Color(red: 0.722, green: 0.0, blue: 0.055)
    static let redSubtle = Color(red: 0.992, green: 0.922, blue: 0.925)
    static let graphite = Color(red: 0.290, green: 0.290, blue: 0.290)
    static let backgroundSecondary = Color(red: 0.965, green: 0.965, blue: 0.965)
}

enum AppSpacing {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
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

