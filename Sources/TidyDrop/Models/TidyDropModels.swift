import Foundation

enum RunMode: String, Codable, CaseIterable, Identifiable {
    case copy
    case move

    var id: String { rawValue }
}

struct Category: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var description: String
    var rules: String
}

struct FileItem: Codable, Identifiable, Hashable {
    var id: String
    var path: String
    var name: String
    var `extension`: String
    var size: Int
    var mime: String
    var lastModified: String
    var fileKind: String
    var contentPreview: String
    var metadataSummary: String
    var thumbnail: String?
    var supportedLevel: String

    enum CodingKeys: String, CodingKey {
        case id, path, name, size, mime, thumbnail
        case `extension` = "extension"
        case lastModified = "last_modified"
        case fileKind = "file_kind"
        case contentPreview = "content_preview"
        case metadataSummary = "metadata_summary"
        case supportedLevel = "supported_level"
    }
}

struct ScanSummary: Codable, Hashable {
    var totalFiles: Int
    var images: Int
    var pdfs: Int
    var documents: Int
    var text: Int
    var code: Int
    var archives: Int
    var media: Int
    var unsupported: Int

    enum CodingKeys: String, CodingKey {
        case images, pdfs, documents, text, code, archives, media, unsupported
        case totalFiles = "total_files"
    }
}

struct ScanResponse: Codable {
    var files: [FileItem]
    var summary: ScanSummary
}

struct ClassificationResult: Codable, Identifiable, Hashable {
    var id: String { fileID }
    var fileID: String
    var originalPath: String
    var suggestedCategoryID: String
    var confidence: Double
    var reason: String
    var suggestedFilename: String?
    var shouldRename: Bool
    var needsReview: Bool

    enum CodingKeys: String, CodingKey {
        case confidence, reason
        case fileID = "file_id"
        case originalPath = "original_path"
        case suggestedCategoryID = "suggested_category_id"
        case suggestedFilename = "suggested_filename"
        case shouldRename = "should_rename"
        case needsReview = "needs_review"
    }
}

struct OperationPlan: Codable, Identifiable, Hashable {
    var id: String { runID }
    var runID: String
    var createdAt: String
    var sourceFolder: String
    var outputFolder: String
    var mode: RunMode
    var operations: [OperationEntry]

    enum CodingKeys: String, CodingKey {
        case mode, operations
        case runID = "run_id"
        case createdAt = "created_at"
        case sourceFolder = "source_folder"
        case outputFolder = "output_folder"
    }
}

struct PlanConflict: Codable, Hashable {
    var type: String
    var message: String
}

struct OperationEntry: Codable, Identifiable, Hashable {
    var id: String
    var type: RunMode
    var enabled: Bool
    var originalPath: String
    var targetPath: String
    var actualPath: String?
    var categoryID: String
    var suggestedFilename: String?
    var confidence: Double
    var reason: String
    var status: String
    var undoStatus: String
    var conflict: PlanConflict?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case id, type, enabled, confidence, reason, status, conflict, error
        case originalPath = "original_path"
        case targetPath = "target_path"
        case actualPath = "actual_path"
        case categoryID = "category_id"
        case suggestedFilename = "suggested_filename"
        case undoStatus = "undo_status"
    }
}

struct UndoPreview: Codable, Hashable {
    var runID: String
    var mode: RunMode
    var actions: [UndoAction]

    enum CodingKeys: String, CodingKey {
        case mode, actions
        case runID = "run_id"
    }
}

struct UndoAction: Codable, Identifiable, Hashable {
    var id: String { operationID }
    var operationID: String
    var originalPath: String
    var currentPath: String?
    var undoTargetPath: String?
    var status: String
    var message: String

    enum CodingKeys: String, CodingKey {
        case status, message
        case operationID = "operation_id"
        case originalPath = "original_path"
        case currentPath = "current_path"
        case undoTargetPath = "undo_target_path"
    }
}

struct HealthResponse: Codable {
    struct Ollama: Codable {
        var baseURL: String
        var running: Bool
        var message: String

        enum CodingKeys: String, CodingKey {
            case running, message
            case baseURL = "base_url"
        }
    }

    var status: String
    var ollama: Ollama
}
