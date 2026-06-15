import Foundation

enum APIError: Error, LocalizedError {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid backend response."
        case .server(let message):
            message
        }
    }
}

struct APIClient {
    var baseURL: URL
    var sessionToken: String

    init(
        baseURL: URL = URL(string: "http://127.0.0.1:0")!,
        sessionToken: String = ""
    ) {
        self.baseURL = baseURL
        self.sessionToken = sessionToken
    }

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        return encoder
    }()

    func health() async throws -> HealthResponse {
        try await get("/api/health")
    }

    func models() async throws -> [String] {
        let response: ModelsResponse = try await get("/api/ollama/models")
        return response.models
    }

    func scan(folder: String, settings: AppSettings) async throws -> ScanResponse {
        try await post(
            "/api/scan",
            body: ScanRequest(
                folderPath: folder,
                includeSubfolders: settings.includeSubfolders,
                ignoredExtensions: settings.ignoredExtensions
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty },
                excludedPaths: settings.outputFolder.isEmpty ? [] : [settings.outputFolder],
                maxFileSizeMB: settings.maxFileSizeMB
            )
        )
    }

    func classify(
        scanID: String,
        files: [FileItem],
        categories: [Category],
        settings: AppSettings,
        textModel: String,
        visionModel: String,
        confidenceThreshold: Double
    ) async throws -> [ClassificationResult] {
        let fallback = categories.first { $0.name.localizedCaseInsensitiveContains("review") }?.id ?? categories.last?.id ?? "review"
        let response: ClassifyResponse = try await post(
            "/api/classify",
            body: ClassifyRequest(
                scanID: scanID,
                fileIDs: files.map(\.id),
                categories: categories,
                settings: ClassifySettings(
                    textModel: textModel,
                    visionModel: visionModel,
                    confidenceThreshold: confidenceThreshold,
                    suggestRenaming: settings.suggestRenaming,
                    allowAICategories: settings.allowAICategories,
                    aiTimeoutSeconds: settings.aiTimeoutSeconds,
                    fallbackCategoryID: fallback
                )
            )
        )
        return response.results
    }

    func classify(
        scanID: String,
        file: FileItem,
        categories: [Category],
        settings: AppSettings,
        model: String,
        confidenceThreshold: Double
    ) async throws -> ClassificationResult {
        guard let result = try await classify(
            scanID: scanID,
            files: [file],
            categories: categories,
            settings: settings,
            textModel: model,
            visionModel: model,
            confidenceThreshold: confidenceThreshold
        ).first else {
            throw APIError.invalidResponse
        }
        return result
    }

    func discoverCategories(
        scanID: String,
        categories: [Category],
        settings: AppSettings
    ) async throws -> DiscoverCategoriesResponse {
        let fallback = categories.first { $0.name.localizedCaseInsensitiveContains("review") }?.id ?? categories.last?.id ?? "review"
        return try await post(
            "/api/categories/discover",
            body: DiscoverCategoriesRequest(
                scanID: scanID,
                categories: categories,
                settings: ClassifySettings(
                    textModel: settings.expertTextModel,
                    visionModel: "",
                    confidenceThreshold: settings.confidenceThreshold,
                    suggestRenaming: settings.suggestRenaming,
                    allowAICategories: settings.allowAICategories,
                    aiTimeoutSeconds: settings.aiTimeoutSeconds,
                    fallbackCategoryID: fallback
                )
            )
        )
    }

    func plan(
        scanID: String,
        categories: [Category],
        results: [ClassificationResult],
        settings: AppSettings
    ) async throws -> OperationPlan {
        try await post(
            "/api/plan",
            body: PlanRequest(
                scanID: scanID,
                categories: categories,
                results: results,
                settings: PlanSettingsPayload(
                    mode: settings.mode,
                    outputFolder: settings.outputFolder,
                    suggestRenaming: settings.suggestRenaming,
                    applyRenaming: settings.applyRenaming
                )
            )
        )
    }

    func apply(plan: OperationPlan) async throws -> OperationPlan {
        let edits = plan.operations.map {
            OperationEdit(
                operationID: $0.id,
                enabled: $0.enabled,
                categoryID: $0.categoryID,
                suggestedFilename: $0.suggestedFilename
            )
        }
        let response: ApplyResponse = try await post(
            "/api/apply",
            body: ApplyRequest(planID: plan.planID, edits: edits)
        )
        return response.run
    }

    func history() async throws -> [OperationPlan] {
        let response: HistoryResponse = try await get("/api/history")
        return response.runs
    }

    func undoPreview(runID: String) async throws -> UndoPreview {
        try await post("/api/undo/preview", body: RunIDRequest(runID: runID))
    }

    func undoApply(runID: String) async throws -> UndoPreview {
        try await post("/api/undo/apply", body: RunIDRequest(runID: runID))
    }

    func unloadOllamaModels(_ models: [String]) async {
        for model in Set(models.filter { !$0.isEmpty }) {
            guard let url = URL(string: "http://127.0.0.1:11434/api/generate") else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 5
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? encoder.encode(UnloadModelRequest(model: model))
            _ = try? await URLSession.shared.data(for: request)
        }
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable, Body: Encodable>(_ path: String, body: Body) async throws -> T {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = 660
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            if let serverError = try? decoder.decode(ServerError.self, from: data) {
                throw APIError.server(serverError.detail)
            }
            throw APIError.server("Backend returned HTTP \(http.statusCode).")
        }
    }
}

private struct UnloadModelRequest: Codable {
    var model: String
    var keepAlive = 0

    enum CodingKeys: String, CodingKey {
        case model
        case keepAlive = "keep_alive"
    }
}

private struct ServerError: Codable {
    var detail: String
}

private struct ModelsResponse: Codable {
    var models: [String]
}

private struct ScanRequest: Codable {
    var folderPath: String
    var includeSubfolders: Bool
    var ignoredExtensions: [String]
    var excludedPaths: [String]
    var maxFileSizeMB: Int

    enum CodingKeys: String, CodingKey {
        case folderPath = "folder_path"
        case includeSubfolders = "include_subfolders"
        case ignoredExtensions = "ignored_extensions"
        case excludedPaths = "excluded_paths"
        case maxFileSizeMB = "max_file_size_mb"
    }
}

private struct ClassifyRequest: Codable {
    var scanID: String
    var fileIDs: [String]
    var categories: [Category]
    var settings: ClassifySettings

    enum CodingKeys: String, CodingKey {
        case categories, settings
        case scanID = "scan_id"
        case fileIDs = "file_ids"
    }
}

private struct DiscoverCategoriesRequest: Codable {
    var scanID: String
    var categories: [Category]
    var settings: ClassifySettings

    enum CodingKeys: String, CodingKey {
        case categories, settings
        case scanID = "scan_id"
    }
}

private struct ClassifySettings: Codable {
    var textModel: String
    var visionModel: String
    var confidenceThreshold: Double
    var suggestRenaming: Bool
    var allowAICategories: Bool
    var aiTimeoutSeconds: Int
    var fallbackCategoryID: String
    var maxAICategories = 5

    enum CodingKeys: String, CodingKey {
        case textModel = "text_model"
        case visionModel = "vision_model"
        case confidenceThreshold = "confidence_threshold"
        case suggestRenaming = "suggest_renaming"
        case allowAICategories = "allow_ai_categories"
        case aiTimeoutSeconds = "ai_timeout_seconds"
        case fallbackCategoryID = "fallback_category_id"
        case maxAICategories = "max_ai_categories"
    }
}

private struct ClassifyResponse: Codable {
    var results: [ClassificationResult]
}

struct DiscoverCategoriesResponse: Codable {
    var categories: [Category]
    var addedCategories: [Category]

    enum CodingKeys: String, CodingKey {
        case categories
        case addedCategories = "added_categories"
    }
}

private struct PlanRequest: Codable {
    var scanID: String
    var categories: [Category]
    var results: [ClassificationResult]
    var settings: PlanSettingsPayload

    enum CodingKeys: String, CodingKey {
        case categories, results, settings
        case scanID = "scan_id"
    }
}

private struct PlanSettingsPayload: Codable {
    var mode: RunMode
    var outputFolder: String
    var suggestRenaming: Bool
    var applyRenaming: Bool

    enum CodingKeys: String, CodingKey {
        case mode
        case outputFolder = "output_folder"
        case suggestRenaming = "suggest_renaming"
        case applyRenaming = "apply_renaming"
    }
}

private struct ApplyRequest: Codable {
    var planID: String
    var edits: [OperationEdit]

    enum CodingKeys: String, CodingKey {
        case edits
        case planID = "plan_id"
    }
}

private struct OperationEdit: Codable {
    var operationID: String
    var enabled: Bool
    var categoryID: String
    var suggestedFilename: String?

    enum CodingKeys: String, CodingKey {
        case enabled
        case operationID = "operation_id"
        case categoryID = "category_id"
        case suggestedFilename = "suggested_filename"
    }
}

private struct ApplyResponse: Codable {
    var run: OperationPlan
}

private struct HistoryResponse: Codable {
    var runs: [OperationPlan]
}

private struct RunIDRequest: Codable {
    var runID: String

    enum CodingKeys: String, CodingKey {
        case runID = "run_id"
    }
}
