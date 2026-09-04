import Foundation
import CoreGraphics

struct ReportFormParticipant: Identifiable {
    let id: String
    let name: String
    let role: String
    var isSelected: Bool
    var strokes: [[CGPoint]]

    var apiWrite: APIReportParticipantWrite {
        APIReportParticipantWrite(
            userID: id,
            selected: isSelected,
            signatureStrokes: strokes.map(\.apiPoints),
            signatureImageBase64: nil
        )
    }
}

struct APISignaturePoint: Codable, Equatable {
    let x: Double
    let y: Double
}

struct APIReportParticipantWrite: Codable, Equatable, Identifiable {
    var id: String { userID }
    let userID: String
    var selected: Bool
    var signatureStrokes: [[APISignaturePoint]]
    var signatureImageBase64: String?

    enum CodingKeys: String, CodingKey {
        case selected
        case userID = "user_id"
        case signatureStrokes = "signature_strokes"
        case signatureImageBase64 = "signature_image_base64"
    }
}

struct APIReportEvidenceWrite: Codable, Equatable, Identifiable {
    var id: String { clientID }
    let clientID: String
    var attachmentID: String?
    var originalFileName: String
    var mediaType: String
    var title: String?
    var description: String?
    var capturedAt: Date
    var contentBase64: String?
    var preventiveStepID: String?
    var correctiveActivityClientID: String?

    enum CodingKeys: String, CodingKey {
        case title, description
        case clientID = "client_id"
        case attachmentID = "attachment_id"
        case originalFileName = "original_file_name"
        case mediaType = "media_type"
        case capturedAt = "captured_at"
        case contentBase64 = "content_base64"
        case preventiveStepID = "preventive_step_id"
        case correctiveActivityClientID = "corrective_activity_client_id"
    }
}

struct APIPreventiveTestWrite: Codable, Equatable, Identifiable {
    var id: String { templateTestID }
    let templateTestID: String
    var name: String
    var selectedResult: String
    var numericValue: String?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case name, notes
        case templateTestID = "template_test_id"
        case selectedResult = "selected_result"
        case numericValue = "numeric_value"
    }
}

struct APIPreventiveStepWrite: Codable, Equatable, Identifiable {
    var id: String { templateStepID }
    let templateStepID: String
    var title: String
    var manualPage: Int?
    var sequence: Int
    var isCompleted: Bool
    var comment: String?
    var tests: [APIPreventiveTestWrite]

    enum CodingKeys: String, CodingKey {
        case title, sequence, comment, tests
        case templateStepID = "template_step_id"
        case manualPage = "manual_page"
        case isCompleted = "is_completed"
    }
}

struct APIPreventiveReportWrite: Codable, Equatable {
    var sapOrder: String?
    var activityEndedAt: Date?
    var finalResult: String?
    var additionalComments: String?
    var steps: [APIPreventiveStepWrite]
    var participants: [APIReportParticipantWrite]
    var evidence: [APIReportEvidenceWrite]
    var tools: [APIReportToolUsageWrite]

    enum CodingKeys: String, CodingKey {
        case steps, participants, evidence, tools
        case sapOrder = "sap_order"
        case activityEndedAt = "activity_ended_at"
        case finalResult = "final_result"
        case additionalComments = "additional_comments"
    }
}

struct APIReportToolUsageWrite: Codable, Equatable, Identifiable {
    var id: String { toolID }
    let toolID: String

    enum CodingKeys: String, CodingKey {
        case toolID = "tool_id"
    }
}

struct APIEditorTool: Codable, Identifiable {
    let id: String
    let name: String
    let serialNumber: String
    let availabilityStatus: String
    let certificationNumber: String?
    // The API serializes a database DATE as YYYY-MM-DD, not an ISO-8601 instant.
    // Keeping it as text avoids making the whole report editor fail to decode.
    let certificationValidUntil: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case serialNumber = "serial_number"
        case availabilityStatus = "availability_status"
        case certificationNumber = "certification_number"
        case certificationValidUntil = "certification_valid_until"
    }
}

struct APICalibrationReceiverWrite: Codable, Equatable, Identifiable {
    var id: Int { sequence }
    var sequence: Int
    var jumpers: String
    var tca9: String
    var railCurrent: String

    enum CodingKeys: String, CodingKey {
        case sequence, jumpers, tca9
        case railCurrent = "rail_current"
    }
}

struct APICalibrationReportWrite: Codable, Equatable {
    var frequency: String
    var transmitterJumpers: String
    var receivers: [APICalibrationReceiverWrite]

    enum CodingKeys: String, CodingKey {
        case frequency, receivers
        case transmitterJumpers = "transmitter_jumpers"
    }
}

struct APICalibrationReceiver: Decodable, Identifiable {
    var id: Int { sequence }
    let sequence: Int
    let jumpers: String?
    let tca9: String?
    let railCurrent: String?

    enum CodingKeys: String, CodingKey {
        case sequence, jumpers, tca9
        case railCurrent = "rail_current"
    }
}

struct APICalibrationReport: Decodable {
    let trackCircuitAssetID: String
    let trackCircuitName: String
    let frequency: String?
    let calibrationDate: String
    let location: String
    let transmitterJumpers: String?
    let receivers: [APICalibrationReceiver]

    enum CodingKeys: String, CodingKey {
        case frequency, location, receivers
        case trackCircuitAssetID = "track_circuit_asset_id"
        case trackCircuitName = "track_circuit_name"
        case calibrationDate = "calibration_date"
        case transmitterJumpers = "transmitter_jumpers"
    }
}

struct APIComponentReplacementWrite: Codable, Equatable {
    var sourceKind: String? = "WAREHOUSE"
    var donorParentAssetID: String?
    var parentAssetID: String
    var removedAssetID: String
    var installedAssetID: String
    var removedPartNumber: String?
    var removedSerialNumber: String?
    var removedModel: String?
    var removedManufacturer: String?
    var installedPartNumber: String?
    var installedSerialNumber: String?
    var installedModel: String?
    var installedManufacturer: String?
    var sourceDescription: String
    var destinationDescription: String
    var removedCondition: String?
    var installedCondition: String?
    var removedNotes: String?
    var installedNotes: String?
    var reason: String

    enum CodingKeys: String, CodingKey {
        case reason
        case sourceKind = "source_kind"
        case donorParentAssetID = "donor_parent_asset_id"
        case parentAssetID = "parent_asset_id"
        case removedAssetID = "removed_asset_id"
        case installedAssetID = "installed_asset_id"
        case removedPartNumber = "removed_part_number"
        case removedSerialNumber = "removed_serial_number"
        case removedModel = "removed_model"
        case removedManufacturer = "removed_manufacturer"
        case installedPartNumber = "installed_part_number"
        case installedSerialNumber = "installed_serial_number"
        case installedModel = "installed_model"
        case installedManufacturer = "installed_manufacturer"
        case sourceDescription = "source_description"
        case destinationDescription = "destination_description"
        case removedCondition = "removed_condition"
        case installedCondition = "installed_condition"
        case removedNotes = "removed_notes"
        case installedNotes = "installed_notes"
    }
}

struct APICorrectiveActivityWrite: Codable, Equatable, Identifiable {
    var id: String { clientID }
    let clientID: String
    var actionTypeCode: String
    var name: String
    var description: String
    var startedAt: Date
    var endedAt: Date?
    var replacement: APIComponentReplacementWrite?

    enum CodingKeys: String, CodingKey {
        case name, description, replacement
        case clientID = "client_id"
        case actionTypeCode = "action_type_code"
        case startedAt = "started_at"
        case endedAt = "ended_at"
    }
}

struct APICorrectiveReportWrite: Codable, Equatable {
    var symptom: String?
    var technicalDescription: String?
    var operationalImpact: String?
    var failureAnalysisType: String?
    var functionalTests: String?
    var validationResult: String?
    var serviceReleased: Bool
    var serviceReleasedAt: Date?
    var validationResponsible: String?
    var technicalStatus: String?
    var conclusion: String?
    var additionalComments: String?
    var correctiveEndedAt: Date?
    var stopAfterBlockOrder: Int?
    var activities: [APICorrectiveActivityWrite]
    var participants: [APIReportParticipantWrite]
    var evidence: [APIReportEvidenceWrite]

    enum CodingKeys: String, CodingKey {
        case symptom, conclusion, activities, participants, evidence
        case technicalDescription = "technical_description"
        case operationalImpact = "operational_impact"
        case failureAnalysisType = "failure_analysis_type"
        case functionalTests = "functional_tests"
        case validationResult = "validation_result"
        case serviceReleased = "service_released"
        case serviceReleasedAt = "service_released_at"
        case validationResponsible = "validation_responsible"
        case technicalStatus = "technical_status"
        case additionalComments = "additional_comments"
        case correctiveEndedAt = "corrective_ended_at"
        case stopAfterBlockOrder = "stop_after_block_order"
    }
}

struct APIReportDraftWrite: Codable, Equatable {
    var baseReportVersionID: String?
    var enforceBaseVersion: Bool
    var preventive: APIPreventiveReportWrite?
    var corrective: APICorrectiveReportWrite?
    var calibration: APICalibrationReportWrite?

    enum CodingKeys: String, CodingKey {
        case preventive, corrective, calibration
        case baseReportVersionID = "base_report_version_id"
        case enforceBaseVersion = "enforce_base_version"
    }
}

struct APITemplateTest: Codable, Identifiable {
    let id: String
    let name: String
    let resultOptions: [String]
    let defaultResult: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case resultOptions = "result_options"
        case defaultResult = "default_result"
    }
}

struct APITemplateStep: Codable, Identifiable {
    let id: String
    let title: String
    let manualPage: Int?
    let sequence: Int
    let defaultComment: String?
    let tests: [APITemplateTest]

    enum CodingKeys: String, CodingKey {
        case id, title, sequence, tests
        case manualPage = "manual_page"
        case defaultComment = "default_comment"
    }
}

struct APIPreventiveHistoryReport: Decodable, Identifiable {
    var id: String { versionID }
    let activityID: String
    let versionID: String
    let title: String
    let internalCode: String
    let equipmentNames: [String]
    let performedAt: Date
    let finalResult: String?
    let versionNumber: Int
    let documentStatus: String

    enum CodingKeys: String, CodingKey {
        case title
        case activityID = "activity_id"
        case versionID = "version_id"
        case internalCode = "internal_code"
        case equipmentNames = "equipment_names"
        case performedAt = "performed_at"
        case finalResult = "final_result"
        case versionNumber = "version_number"
        case documentStatus = "document_status"
    }
}

struct APIPreventiveGuide: Decodable {
    let activityID: String
    let templateName: String?
    let templateSteps: [APITemplateStep]
    let previousReports: [APIPreventiveHistoryReport]
    let previousReportsHasMore: Bool
    let previousReportsOffset: Int

    enum CodingKeys: String, CodingKey {
        case activityID = "activity_id"
        case templateName = "template_name"
        case templateSteps = "template_steps"
        case previousReports = "previous_reports"
        case previousReportsHasMore = "previous_reports_has_more"
        case previousReportsOffset = "previous_reports_offset"
    }
}

struct APIEditorUser: Codable, Identifiable {
    let id: String
    let name: String
    let role: String
}

struct APIEditorActionType: Codable, Identifiable {
    var id: String { code }
    let code: String
    let name: String
}

struct APIEditorAsset: Codable, Identifiable {
    let id: String
    let name: String
    let path: String
    let parentID: String?
    let partNumber: String?
    let serialNumber: String?
    let model: String?
    let manufacturer: String?
    let status: String
    let nodeKind: String
    let selectable: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, path, model, manufacturer, status
        case parentID = "parent_id"
        case partNumber = "part_number"
        case serialNumber = "serial_number"
        case nodeKind = "node_kind"
        case selectable
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        parentID = try container.decodeIfPresent(String.self, forKey: .parentID)
        partNumber = try container.decodeIfPresent(String.self, forKey: .partNumber)
        serialNumber = try container.decodeIfPresent(String.self, forKey: .serialNumber)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        manufacturer = try container.decodeIfPresent(String.self, forKey: .manufacturer)
        status = try container.decode(String.self, forKey: .status)
        nodeKind = try container.decodeIfPresent(String.self, forKey: .nodeKind) ?? "ASSET"
        selectable = try container.decodeIfPresent(Bool.self, forKey: .selectable) ?? true
    }
}

struct APIStoredParticipant: Codable, Identifiable {
    let id: String
    let userID: String
    let name: String
    let role: String
    let selected: Bool
    let signedAt: Date?
    let signatureStrokes: [[APISignaturePoint]]

    enum CodingKeys: String, CodingKey {
        case id, name, role, selected
        case userID = "user_id"
        case signedAt = "signed_at"
        case signatureStrokes = "signature_strokes"
    }
}

struct APIStoredEvidence: Codable, Identifiable {
    let id: String
    let originalFileName: String?
    let mediaType: String?
    let title: String?
    let description: String?
    let capturedAt: Date
    let contentPath: String

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case originalFileName = "original_file_name"
        case mediaType = "media_type"
        case capturedAt = "captured_at"
        case contentPath = "content_path"
    }
}

struct APIGeneratedReport: Decodable {
    let id: String
    let reportVersionID: String
    let fileName: String
    let fileFormat: String
    let fileSizeBytes: Int?
    let generatedAt: Date
    let downloadPath: String

    enum CodingKeys: String, CodingKey {
        case id
        case reportVersionID = "report_version_id"
        case fileName = "file_name"
        case fileFormat = "file_format"
        case fileSizeBytes = "file_size_bytes"
        case generatedAt = "generated_at"
        case downloadPath = "download_path"
    }
}

struct APIReportVersionDetail: Decodable {
    let id: String
    let reportKind: String
    let reportNumber: Int
    let versionNumber: Int
    let documentStatus: String
    let summary: String?
    let createdAt: Date
    let finalizedAt: Date?
    let activity: APIActivity
    let preventiveReport: APIPreventiveReport?
    let correctiveReport: APICorrectiveReport?
    let calibrationReport: APICalibrationReport?
    let participants: [APIStoredParticipant]
    let evidence: [APIStoredEvidence]
    let generatedReport: APIGeneratedReport?

    enum CodingKeys: String, CodingKey {
        case id, summary, activity, participants, evidence
        case reportKind = "report_kind"
        case reportNumber = "report_number"
        case versionNumber = "version_number"
        case documentStatus = "document_status"
        case createdAt = "created_at"
        case finalizedAt = "finalized_at"
        case preventiveReport = "preventive_report"
        case correctiveReport = "corrective_report"
        case calibrationReport = "calibration_report"
        case generatedReport = "generated_report"
    }
}

struct APIMaintenanceComment: Codable, Identifiable {
    let id: String
    let scope: String
    let authorUserID: String
    let authorName: String
    let authorRole: String
    let message: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, scope, message
        case authorUserID = "author_user_id"
        case authorName = "author_name"
        case authorRole = "author_role"
        case createdAt = "created_at"
    }
}

struct APIReportEditor: Codable {
    let activityID: String
    let activityType: String
    let status: String
    let actualDate: String
    let activityStartedAt: Date
    let activityEndedAt: Date?
    let reportVersionID: String?
    let documentStatus: String?
    let preventiveDraft: APIPreventiveReportWrite?
    let correctiveDraft: APICorrectiveReportWrite?
    let calibrationRequired: Bool
    let calibrationDraft: APICalibrationReportWrite?
    let templateSteps: [APITemplateStep]
    let availableParticipants: [APIEditorUser]
    let actionTypes: [APIEditorActionType]
    let equipmentAssets: [APIEditorAsset]
    let stockAssets: [APIEditorAsset]
    let inventoryLocations: [String]
    let sapOrder: String?
    let sapOrderEditable: Bool
    let availableTools: [APIEditorTool]
    let requiredToolNames: [String]
    let participants: [APIStoredParticipant]
    let evidence: [APIStoredEvidence]
    let comments: [APIMaintenanceComment]

    enum CodingKeys: String, CodingKey {
        case status, participants, evidence, comments
        case sapOrder = "sap_order"
        case sapOrderEditable = "sap_order_editable"
        case availableTools = "available_tools"
        case requiredToolNames = "required_tool_names"
        case activityID = "activity_id"
        case activityType = "activity_type"
        case actualDate = "actual_date"
        case activityStartedAt = "activity_started_at"
        case activityEndedAt = "activity_ended_at"
        case reportVersionID = "report_version_id"
        case documentStatus = "document_status"
        case preventiveDraft = "preventive_draft"
        case correctiveDraft = "corrective_draft"
        case calibrationRequired = "calibration_required"
        case calibrationDraft = "calibration_draft"
        case templateSteps = "template_steps"
        case availableParticipants = "available_participants"
        case actionTypes = "action_types"
        case equipmentAssets = "equipment_assets"
        case stockAssets = "stock_assets"
        case inventoryLocations = "inventory_locations"
    }
}

struct APIReportWriteResult: Decodable {
    let reportID: String
    let versionID: String
    let versionNumber: Int
    let documentStatus: String
    let savedAt: Date
    let calibrationVersionID: String?

    enum CodingKeys: String, CodingKey {
        case reportID = "report_id"
        case versionID = "version_id"
        case versionNumber = "version_number"
        case documentStatus = "document_status"
        case savedAt = "saved_at"
        case calibrationVersionID = "calibration_version_id"
    }
}

private struct APICommentWrite: Encodable {
    let message: String
}

struct ReportAPIService {
    private let client: APIClient

    init(baseURLString: String) {
        client = APIClient(baseURLString: baseURLString)
    }

    func editor(activityID: String, accessToken: String) async throws -> APIReportEditor {
        try await client.get(
            "/api/v1/maintenance-activities/\(activityID)/report-editor",
            bearerToken: accessToken
        )
    }

    func preventiveGuide(
        activityID: String,
        accessToken: String,
        previousReportsLimit: Int = 10,
        previousReportsOffset: Int = 0
    ) async throws -> APIPreventiveGuide {
        try await client.get(
            "/api/v1/maintenance-activities/\(activityID)/preventive-guide",
            bearerToken: accessToken,
            queryItems: [
                URLQueryItem(
                    name: "previous_reports_limit",
                    value: String(previousReportsLimit)
                ),
                URLQueryItem(
                    name: "previous_reports_offset",
                    value: String(previousReportsOffset)
                ),
            ]
        )
    }

    func comments(activityID: String, accessToken: String) async throws -> [APIMaintenanceComment] {
        try await client.get(
            "/api/v1/maintenance-activities/\(activityID)/comments",
            bearerToken: accessToken
        )
    }

    func save(
        activityID: String,
        draft: APIReportDraftWrite,
        finalize: Bool,
        accessToken: String
    ) async throws -> APIReportWriteResult {
        if finalize {
            return try await client.post(
                "/api/v1/maintenance-activities/\(activityID)/report-finalize",
                body: draft,
                bearerToken: accessToken
            )
        }
        return try await client.put(
            "/api/v1/maintenance-activities/\(activityID)/report-draft",
            body: draft,
            bearerToken: accessToken
        )
    }

    func addComment(
        activityID: String,
        message: String,
        accessToken: String
    ) async throws -> APIMaintenanceComment {
        try await client.post(
            "/api/v1/maintenance-activities/\(activityID)/comments",
            body: APICommentWrite(message: message),
            bearerToken: accessToken
        )
    }

    func versionDetail(versionID: String, accessToken: String) async throws -> APIReportVersionDetail {
        try await client.get(
            "/api/v1/report-versions/\(versionID)",
            bearerToken: accessToken
        )
    }

    func generatePDF(versionID: String, accessToken: String) async throws -> APIGeneratedReport {
        try await client.post(
            "/api/v1/report-versions/\(versionID)/generate-pdf",
            bearerToken: accessToken
        )
    }

    func downloadPDF(versionID: String, accessToken: String) async throws -> Data {
        try await client.getData(
            "/api/v1/report-versions/\(versionID)/pdf",
            bearerToken: accessToken
        )
    }
}

extension Array where Element == APISignaturePoint {
    var cgPoints: [CGPoint] {
        map { CGPoint(x: $0.x, y: $0.y) }
    }
}

extension Array where Element == CGPoint {
    var apiPoints: [APISignaturePoint] {
        map { APISignaturePoint(x: $0.x, y: $0.y) }
    }
}

extension APIReportEditor {
    func formParticipants(
        preferredWrites: [APIReportParticipantWrite]
    ) -> [ReportFormParticipant] {
        let preferred = Dictionary(
            uniqueKeysWithValues: preferredWrites.map { ($0.userID, $0) }
        )
        let stored = Dictionary(
            uniqueKeysWithValues: participants.map { ($0.userID, $0) }
        )
        return availableParticipants.map { user in
            let local = preferred[user.id]
            let remote = stored[user.id]
            return ReportFormParticipant(
                id: user.id,
                name: user.name,
                role: user.role,
                isSelected: local?.selected ?? remote?.selected ?? true,
                strokes: local?.signatureStrokes.map(\.cgPoints)
                    ?? remote?.signatureStrokes.map(\.cgPoints)
                    ?? []
            )
        }
    }
}
