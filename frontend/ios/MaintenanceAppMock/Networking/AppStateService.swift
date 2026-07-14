import Foundation

struct AppStateService {
    private let client: APIClient

    init(baseURLString: String) {
        self.client = APIClient(baseURLString: baseURLString)
    }

    func fetchCurrentState() async throws -> RemoteAppState {
        try await client.get("api/v1/app-state/current")
    }

    func replaceCurrentState(_ state: RemoteAppState) async throws {
        let _: SaveStateResponse = try await client.put("api/v1/app-state/current", body: state)
    }
}

private struct SaveStateResponse: Decodable {
    let status: String
}

struct RemoteAppState: Codable {
    var loginUsers: [MockUser]
    var activeMaintainers: [MockUser]
    var activities: [PreventiveActivity]
    var correctiveEvents: [CorrectiveEvent]
    var assets: [MaintenanceAsset]
    var stockAssets: [StockAsset]
    var maintenanceComments: [MaintenanceComment]
    var correctiveComments: [CorrectiveComment]
    var historicalReports: [HistoricalMaintenanceReport]
    var preventiveReportSignatures: [String: [ReportSignature]]
    var correctiveReportSignatures: [String: [ReportSignature]]
}
