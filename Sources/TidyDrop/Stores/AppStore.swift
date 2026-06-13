import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppStore {
    var folderURL: URL?
    var categories: [Category] = [
        Category(id: "documents", name: "Documents", description: "PDFs, notes and office files", rules: ""),
        Category(id: "code", name: "Code", description: "Source files, scripts and configs", rules: ""),
        Category(id: "media", name: "Media", description: "Images, screenshots, audio and video", rules: ""),
        Category(id: "review", name: "To Review", description: "Ambiguous files", rules: "Use this when confidence is low.")
    ]
    var settings = AppSettings()
    var files: [FileItem] = []
    var summary: ScanSummary?
    var results: [ClassificationResult] = []
    var plan: OperationPlan?
    var runs: [OperationPlan] = []
    var undoPreview: UndoPreview?
    var lastAppliedRun: OperationPlan?
    var lastAddedAICategories: [Category] = []
    var lastExpertReviewCount = 0
    var lastExpertImprovementCount = 0
    var models: [String] = []
    var selectedFileID: String?
    var selectedRunID: String?
    var isBusy = false
    var canStopCurrentWork = false
    var progressTitle = ""
    var progressDetail = ""
    var progressCompleted = 0
    var progressTotal = 0
    var activityLog: [String] = []
    var statusMessage = "Ready"
    var errorMessage: String?
    var backendStatus = "Starting..."
    var ollamaRunning = false
    var ollamaMessage = "Not checked yet"

    private let backend = BackendProcess()
    private let api = APIClient()
    private var stopRequested = false

    var selectedFile: FileItem? {
        guard let selectedFileID else { return files.first }
        return files.first { $0.id == selectedFileID } ?? files.first
    }

    var selectedResult: ClassificationResult? {
        guard let selectedFile else { return nil }
        return results.first { $0.fileID == selectedFile.id }
    }

    var applySummary: (completed: Int, skipped: Int, conflicts: Int)? {
        guard let run = lastAppliedRun else { return nil }
        let completed = run.operations.filter { $0.status == "done" }.count
        let skipped = run.operations.filter { $0.status == "skipped" || !$0.enabled }.count
        let conflicts = run.operations.filter { $0.status == "conflict" || $0.conflict != nil }.count
        return (completed, skipped, conflicts)
    }

    var defaultOutputFolder: String? {
        folderURL?.appending(path: "TidyDrop Sorted").path
    }

    var effectiveOutputFolderDescription: String {
        if !settings.outputFolder.isEmpty {
            return settings.outputFolder
        }
        return defaultOutputFolder ?? "Will be created inside the selected folder."
    }

    func start() async {
        if !backend.startIfNeeded() {
            backendStatus = "Error"
            errorMessage = backend.lastError ?? "Backend could not start."
            return
        }
        await waitForBackend()
        await refreshHistory()
    }

    private func waitForBackend() async {
        backendStatus = "Starting..."
        for _ in 0..<30 {
            do {
                let health = try await api.health()
                backendStatus = health.status == "ok" ? "Ready" : "Error"
                ollamaRunning = health.ollama.running
                ollamaMessage = health.ollama.running ? "Connected" : "Ollama is not running.\nStart it with: ollama serve"
                models = try await api.models()
                selectRecommendedModelsIfAvailable()
                errorMessage = nil
                return
            } catch {
                try? await Task.sleep(for: .milliseconds(350))
            }
        }
        backendStatus = "Error"
        errorMessage = backend.lastError ?? "Backend did not become ready. Check ~/.tidydrop/logs/backend.log."
    }

    func refreshStatus() async {
        if !backend.startIfNeeded() {
            backendStatus = "Error"
            errorMessage = backend.lastError ?? "Backend could not start."
            return
        }
        do {
            let health = try await api.health()
            backendStatus = health.status == "ok" ? "Ready" : "Error"
            ollamaRunning = health.ollama.running
            ollamaMessage = health.ollama.running ? "Connected" : "Ollama is not running.\nStart it with: ollama serve"
            models = try await api.models()
            selectRecommendedModelsIfAvailable()
        } catch {
            backendStatus = "Starting..."
            ollamaRunning = false
            ollamaMessage = "Not checked yet"
            errorMessage = "Backend is starting. Try again in a moment."
        }
    }

    func refreshHistory() async {
        runs = (try? await api.history()) ?? []
    }

    func chooseFolder(_ url: URL) {
        folderURL = url
        errorMessage = nil
        if settings.outputFolder.isEmpty {
            settings.outputFolder = url.appending(path: "TidyDrop Sorted").path
        }
    }

    func chooseOutputFolder(_ url: URL) {
        settings.outputFolder = url.path
        statusMessage = "Sorted folder updated."
        errorMessage = nil
    }

    func resetOutputFolderToDefault() {
        settings.outputFolder = defaultOutputFolder ?? ""
        statusMessage = "Sorted folder reset to default."
        errorMessage = nil
    }

    func acceptDroppedURL(_ url: URL, autoScan: Bool = false) async {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            errorMessage = "Dropped item does not exist."
            return
        }
        guard isDirectory.boolValue else {
            errorMessage = "Please drop a folder."
            statusMessage = "Please drop a folder."
            return
        }
        chooseFolder(url)
        statusMessage = "Folder ready: \(url.lastPathComponent)"
        if autoScan {
            await scan()
        }
    }

    func scan() async {
        guard let folderURL else {
            statusMessage = "Choose a folder first."
            errorMessage = "No folder selected. Choose or drop a folder to begin."
            return
        }
        await run("Scanning folder", canStop: true) {
            setProgress(title: "Scanning", detail: folderURL.lastPathComponent, completed: 0, total: 1)
            let response = try await api.scan(folder: folderURL.path, settings: settings)
            try Task.checkCancellation()
            files = response.files
            summary = response.summary
            selectedFileID = response.files.first?.id
            results = []
            plan = nil
            if response.summary.totalFiles == 0 {
                errorMessage = "No files found in this folder."
                statusMessage = "No files found."
            } else {
                setProgress(title: "Scan complete", detail: "\(response.summary.totalFiles) files found", completed: 1, total: 1)
                statusMessage = "Scanned \(response.summary.totalFiles) files."
            }
        }
    }

    func classifyAndPlan() async {
        guard let folderURL else {
            errorMessage = "No folder selected. Choose or drop a folder first."
            return
        }
        guard !categories.isEmpty else {
            errorMessage = "No categories defined. Add a category or choose a template."
            return
        }
        guard !files.isEmpty else {
            statusMessage = "Scan a folder before classification."
            errorMessage = "No files found. Scan a folder before classification."
            return
        }
        guard ollamaRunning else {
            errorMessage = "Ollama is not running. Start it with: ollama serve"
            return
        }
        guard !models.isEmpty else {
            errorMessage = "No Ollama model installed. Install a text or vision model, then refresh."
            return
        }
        guard !settings.fastModel.isEmpty else {
            errorMessage = "Choose a fast model before classification."
            return
        }
        if settings.allowAICategories && settings.expertTextModel.isEmpty {
            errorMessage = "Choose an expert text model to let AI create folders."
            return
        }
        if settings.expertReviewEnabled && settings.expertTextModel.isEmpty {
            errorMessage = "Choose an expert text model or turn off expert review."
            return
        }
        await run("Classifying locally", canStop: true) {
            var classificationCategories = ensureReviewCategory(categories)
            let phaseCount = 2
                + (settings.allowAICategories ? 1 : 0)
                + (settings.expertReviewEnabled ? 1 : 0)
            if settings.allowAICategories {
                statusMessage = "Discovering useful folders"
                setProgress(title: "Step 1 of \(phaseCount): Folder discovery", detail: "Expert text model · reviewing the full scan", completed: 0, total: files.count + 2)
                let discovered = try await api.discoverCategories(files: files, categories: classificationCategories, settings: settings)
                try Task.checkCancellation()
                classificationCategories = semanticClassificationCategories(discovered.categories)
                guard classificationCategories.contains(where: { $0.id != "review" }) else {
                    categories = ensureReviewCategory(categories)
                    lastAddedAICategories = []
                    results = []
                    plan = nil
                    statusMessage = "No semantic folders were discovered."
                    errorMessage = "The expert model did not create any project, client, subject, or period folders. Classification was stopped before producing a generic plan."
                    setProgress(
                        title: "Folder discovery needs review",
                        detail: "No meaningful semantic folders were returned",
                        completed: 1,
                        total: files.count + 2
                    )
                    await api.unloadOllamaModels([settings.expertTextModel])
                    return
                }
                categories = classificationCategories
                lastAddedAICategories = discovered.addedCategories
                appendActivity("AI suggested \(discovered.addedCategories.count) new folders.")
                await api.unloadOllamaModels([settings.expertTextModel])
            } else {
                lastAddedAICategories = []
            }
            statusMessage = "Running fast classification"
            let offset = settings.allowAICategories ? 1 : 0
            var total = files.count + offset + 1
            var nextResults: [ClassificationResult] = []
            nextResults.reserveCapacity(files.count)
            for (index, file) in files.enumerated() {
                guard !stopRequested else { throw CancellationError() }
                setProgress(
                    title: "Step \(settings.allowAICategories ? 2 : 1) of \(phaseCount): Fast pass",
                    detail: "\(settings.fastModel) · \(index + 1) of \(files.count) · \(file.name)",
                    completed: offset + index,
                    total: total
                )
                let result = try await api.classify(
                    file: file,
                    categories: classificationCategories,
                    settings: settings,
                    model: settings.fastModel,
                    confidenceThreshold: settings.expertReviewEnabled ? 0 : settings.confidenceThreshold
                )
                nextResults.append(result)
                appendActivity("\(file.name) → \(categoryName(for: result.suggestedCategoryID, in: classificationCategories))")
            }
            await api.unloadOllamaModels([settings.fastModel])

            let expertIndices = settings.expertReviewEnabled
                ? nextResults.indices.filter { needsExpertReview(nextResults[$0], file: files[$0]) }
                : []
            lastExpertReviewCount = expertIndices.count
            lastExpertImprovementCount = 0
            total += expertIndices.count

            if !expertIndices.isEmpty {
                statusMessage = "Reviewing uncertain files with expert models"
                let textIndices = expertIndices.filter { files[$0].fileKind != "image" }
                let imageIndices = expertIndices.filter { files[$0].fileKind == "image" }
                var expertCompleted = 0

                if !textIndices.isEmpty, !settings.expertTextModel.isEmpty {
                    for index in textIndices {
                        guard !stopRequested else { throw CancellationError() }
                        let file = files[index]
                        setProgress(
                            title: "Step \(settings.allowAICategories ? 3 : 2) of \(phaseCount): Expert review",
                            detail: "Text · \(expertCompleted + 1) of \(expertIndices.count) · \(file.name)",
                            completed: offset + files.count + expertCompleted,
                            total: total
                        )
                        let expertResult = try await api.classify(
                            file: file,
                            categories: classificationCategories,
                            settings: settings,
                            model: settings.expertTextModel,
                            confidenceThreshold: settings.confidenceThreshold
                        )
                        if shouldAcceptExpert(expertResult, over: nextResults[index]) {
                            if expertChangedDecision(expertResult, from: nextResults[index]) {
                                lastExpertImprovementCount += 1
                            }
                            nextResults[index] = expertResult
                        }
                        expertCompleted += 1
                        appendActivity("Expert text reviewed \(file.name)")
                    }
                    await api.unloadOllamaModels([settings.expertTextModel])
                }

                let imageExpertModel = settings.expertVisionModel.isEmpty
                    ? settings.expertTextModel
                    : settings.expertVisionModel
                if !imageIndices.isEmpty, !imageExpertModel.isEmpty {
                    for index in imageIndices {
                        guard !stopRequested else { throw CancellationError() }
                        let file = files[index]
                        setProgress(
                            title: "Step \(settings.allowAICategories ? 3 : 2) of \(phaseCount): Expert review",
                            detail: "Vision · \(expertCompleted + 1) of \(expertIndices.count) · \(file.name)",
                            completed: offset + files.count + expertCompleted,
                            total: total
                        )
                        let expertResult = try await api.classify(
                            file: file,
                            categories: classificationCategories,
                            settings: settings,
                            model: imageExpertModel,
                            confidenceThreshold: settings.confidenceThreshold
                        )
                        if shouldAcceptExpert(expertResult, over: nextResults[index]) {
                            if expertChangedDecision(expertResult, from: nextResults[index]) {
                                lastExpertImprovementCount += 1
                            }
                            nextResults[index] = expertResult
                        }
                        expertCompleted += 1
                        appendActivity("Expert vision reviewed \(file.name)")
                    }
                    await api.unloadOllamaModels([imageExpertModel])
                }
            } else if settings.expertReviewEnabled {
                appendActivity("Expert review skipped: every fast result passed the threshold.")
            }

            let failedResults = nextResults.filter(isClassificationFailure)
            guard failedResults.count < nextResults.count else {
                results = nextResults
                plan = nil
                statusMessage = "Classification failed for every file."
                errorMessage = "Ollama did not return a usable classification. No plan was created. Try again with a compatible model or a longer timeout."
                setProgress(
                    title: "Classification failed",
                    detail: "\(failedResults.count) of \(nextResults.count) files returned no usable result",
                    completed: total - 1,
                    total: total
                )
                return
            }
            let nextPlan = try await api.plan(
                sourceFolder: folderURL.path,
                files: files,
                categories: classificationCategories,
                results: nextResults,
                settings: settings
            )
            try Task.checkCancellation()
            setProgress(
                title: "Step \(phaseCount) of \(phaseCount): Building preview",
                detail: "\(nextPlan.operations.count) operations · \(lastExpertImprovementCount) expert improvements",
                completed: total,
                total: total
            )
            results = nextResults
            plan = nextPlan
            if lastAddedAICategories.isEmpty {
                statusMessage = "Generated \(nextPlan.operations.count) operations; experts improved \(lastExpertImprovementCount) of \(lastExpertReviewCount) reviews."
            } else {
                statusMessage = "Added \(lastAddedAICategories.count) folders; experts improved \(lastExpertImprovementCount) of \(lastExpertReviewCount) reviews."
            }
            if nextPlan.operations.isEmpty {
                errorMessage = "Classification completed, but no operations were generated."
            }
        }
    }

    func applyPlan() async {
        guard let plan else { return }
        await run("Applying reviewed plan", canStop: false) {
            self.plan = try await api.apply(plan: plan)
            self.lastAppliedRun = self.plan
            await refreshHistory()
            statusMessage = "Apply complete. Run saved."
        }
    }

    func previewUndo(runID: String) async {
        await run("Preparing undo", canStop: true) {
            undoPreview = try await api.undoPreview(runID: runID)
            selectedRunID = runID
            if undoPreview?.actions.contains(where: { $0.status == "conflict" }) == true {
                errorMessage = "Undo has a conflict. Review the undo preview before applying."
            }
            statusMessage = "Undo preview ready."
        }
    }

    func applyUndo() async {
        guard let undoPreview else { return }
        await run("Applying undo", canStop: false) {
            self.undoPreview = try await api.undoApply(runID: undoPreview.runID)
            await refreshHistory()
            if self.undoPreview?.actions.contains(where: { $0.status == "conflict" || $0.status == "error" }) == true {
                errorMessage = "Undo finished with conflicts or errors."
            }
            statusMessage = "Undo complete."
        }
    }

    func applyTemplate(_ template: SortingTemplate) {
        categories = ensureReviewCategory(template.categories)
        statusMessage = "Applied template: \(template.name)"
        errorMessage = nil
    }

    func openOutputFolder() async {
        guard let path = lastAppliedRun?.outputFolder ?? plan?.outputFolder ?? optionalOutputFolder else { return }
        await run("Opening output folder", canStop: false) {
            try await api.openFolder(path)
            statusMessage = "Opened output folder."
        }
    }

    func stopCurrentWork() {
        guard canStopCurrentWork else { return }
        stopRequested = true
        statusMessage = "Stopping and releasing Ollama memory..."
        progressTitle = "Stopping"
        progressDetail = "Cancelling the current request and unloading local models"
        Task {
            await api.unloadOllamaModels([
                settings.fastModel,
                settings.expertTextModel,
                settings.expertVisionModel
            ])
            backend.stop()
            backendStatus = "Stopped"
            isBusy = false
            canStopCurrentWork = false
            statusMessage = "Stopped. Ollama models released."
            progressTitle = "Stopped"
            progressDetail = "Refresh to restart the local backend."
            errorMessage = nil
        }
    }

    private var optionalOutputFolder: String? {
        settings.outputFolder.isEmpty ? nil : settings.outputFolder
    }

    func updateOperation(_ operation: OperationEntry) {
        guard var currentPlan = plan,
              let index = currentPlan.operations.firstIndex(where: { $0.id == operation.id }) else { return }
        let previous = currentPlan.operations[index]
        var updated = operation
        if previous.categoryID != updated.categoryID {
            updated.confidence = 1
            updated.reason = "Manually assigned during review."
        }
        if let category = categories.first(where: { $0.id == updated.categoryID }) {
            let originalName = URL(fileURLWithPath: updated.originalPath).lastPathComponent
            let proposedName = updated.suggestedFilename?.trimmingCharacters(in: .whitespacesAndNewlines)
            var filename = settings.applyRenaming && proposedName?.isEmpty == false
                ? sanitizeFilename(proposedName!, fallback: originalName)
                : originalName
            let originalExtension = URL(fileURLWithPath: originalName).pathExtension
            if settings.applyRenaming, !originalExtension.isEmpty {
                filename = replacingExtension(of: filename, with: originalExtension)
            }
            updated.conflict = nil
            updated.actualPath = nil
            updated.targetPath = URL(fileURLWithPath: currentPlan.outputFolder)
                .appending(path: sanitizeFilename(category.name, fallback: category.id))
                .appending(path: filename)
                .path
        }
        currentPlan.operations[index] = updated
        plan = currentPlan
    }

    func file(for operation: OperationEntry) -> FileItem? {
        files.first { $0.path == operation.originalPath }
    }

    func selectForPreview(_ operation: OperationEntry) {
        selectedFileID = file(for: operation)?.id
    }

    func openOriginal(_ operation: OperationEntry) {
        NSWorkspace.shared.open(URL(fileURLWithPath: operation.originalPath))
    }

    func revealOriginal(_ operation: OperationEntry) {
        NSWorkspace.shared.activateFileViewerSelecting([
            URL(fileURLWithPath: operation.originalPath)
        ])
    }

    func updateCategory(_ category: Category) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[index] = category
    }

    func addCategory() {
        categories.append(Category(id: "category-\(Date().timeIntervalSince1970)", name: "New Category", description: "", rules: ""))
    }

    func removeCategory(_ category: Category) {
        guard categories.count > 1, category.id != "review" else { return }
        categories.removeAll { $0.id == category.id }
    }

    private func ensureReviewCategory(_ categories: [Category]) -> [Category] {
        if categories.contains(where: { $0.id == "review" || $0.name == "To Review" }) {
            return categories
        }
        return categories + [
            Category(id: "review", name: "To Review", description: "Files TidyDrop is unsure about.", rules: "Use this when confidence is low.")
        ]
    }

    private func categoryName(for id: String, in categories: [Category]) -> String {
        categories.first { $0.id == id }?.name ?? "To Review"
    }

    private func sanitizeFilename(_ value: String, fallback: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:\\\0")
        let cleaned = value.components(separatedBy: forbidden).joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        return cleaned.isEmpty ? fallback : cleaned
    }

    private func replacingExtension(of filename: String, with originalExtension: String) -> String {
        let url = URL(fileURLWithPath: filename)
        let stem = url.deletingPathExtension().lastPathComponent
        return "\(stem).\(originalExtension)"
    }

    private func isClassificationFailure(_ result: ClassificationResult) -> Bool {
        result.confidence == 0 && result.reason.localizedCaseInsensitiveContains("Needs review:")
    }

    private func needsExpertReview(_ result: ClassificationResult, file: FileItem) -> Bool {
        isClassificationFailure(result)
            || result.needsReview
            || result.confidence < settings.expertReviewThreshold
            || result.suggestedCategoryID == "review"
            || isGenericCategory(result.suggestedCategoryID)
            || needsBetterFilename(result, file: file)
    }

    private func isGenericCategory(_ id: String) -> Bool {
        guard let category = categories.first(where: { $0.id == id }) else { return false }
        let genericNames = ["documents", "document", "code", "media", "images", "image", "archives", "archive"]
        return genericNames.contains(category.name.lowercased())
    }

    private func semanticClassificationCategories(_ candidates: [Category]) -> [Category] {
        let semantic = candidates.filter { category in
            category.id == "review" || !isGenericCategoryName(category.name)
        }
        return ensureReviewCategory(semantic)
    }

    private func isGenericCategoryName(_ name: String) -> Bool {
        let genericNames = [
            "documents", "document", "code", "media", "images", "image",
            "archives", "archive", "audio", "video", "other", "misc", "miscellaneous"
        ]
        return genericNames.contains(name.lowercased())
    }

    private func needsBetterFilename(_ result: ClassificationResult, file: FileItem) -> Bool {
        guard settings.suggestRenaming else { return false }
        let proposed = result.suggestedFilename?.lowercased()
        let current = file.name.lowercased()
        let stem = URL(fileURLWithPath: current).deletingPathExtension().lastPathComponent
        let genericTokens = ["copy", "old", "final", "draft", "tmp", "temp", "scan", "export", "doc", "item", "data", "notes"]
        let currentIsGeneric = genericTokens.contains(where: stem.contains)
            || stem.range(of: #"^[0-9_-]+$"#, options: .regularExpression) != nil
        return currentIsGeneric && (proposed == nil || proposed == current)
    }

    private func shouldAcceptExpert(_ expert: ClassificationResult, over fast: ClassificationResult) -> Bool {
        guard !isClassificationFailure(expert) else { return false }
        if fast.suggestedCategoryID == "review", expert.suggestedCategoryID != "review" {
            return true
        }
        if expert.suggestedCategoryID == "review", fast.suggestedCategoryID != "review" {
            return false
        }
        if expert.suggestedCategoryID != fast.suggestedCategoryID {
            return expert.confidence >= 0.65
        }
        let expertHasBetterName = expert.suggestedFilename != nil
            && expert.suggestedFilename != fast.suggestedFilename
        return expert.confidence >= fast.confidence - 0.05
            && (expert.confidence > fast.confidence || expertHasBetterName)
    }

    private func expertChangedDecision(_ expert: ClassificationResult, from fast: ClassificationResult) -> Bool {
        expert.suggestedCategoryID != fast.suggestedCategoryID
            || expert.suggestedFilename != fast.suggestedFilename
            || expert.needsReview != fast.needsReview
            || abs(expert.confidence - fast.confidence) >= 0.05
    }

    private func selectRecommendedModelsIfAvailable() {
        if settings.fastModel.isEmpty {
            settings.fastModel = models.first { $0.hasPrefix("qwen3.5:2b") } ?? ""
        }
        if settings.expertTextModel.isEmpty {
            settings.expertTextModel = models.first { $0.hasPrefix("qwen3.5:9b") } ?? ""
        }
        if settings.expertVisionModel.isEmpty {
            settings.expertVisionModel = models.first { $0.hasPrefix("gemma4:e4b-it-qat") } ?? ""
        }
    }

    private func setProgress(title: String, detail: String, completed: Int, total: Int) {
        progressTitle = title
        progressDetail = detail
        progressCompleted = completed
        progressTotal = total
    }

    private func appendActivity(_ message: String) {
        activityLog.insert(message, at: 0)
        if activityLog.count > 8 {
            activityLog.removeLast(activityLog.count - 8)
        }
    }

    private func run(_ message: String, canStop: Bool = false, operation: () async throws -> Void) async {
        isBusy = true
        canStopCurrentWork = canStop
        stopRequested = false
        activityLog = []
        progressTitle = message
        progressDetail = "Preparing..."
        progressCompleted = 0
        progressTotal = 0
        statusMessage = message
        errorMessage = nil
        defer {
            isBusy = false
            canStopCurrentWork = false
        }
        do {
            try await operation()
        } catch is CancellationError {
            await unloadConfiguredModels()
            statusMessage = "Stopped."
        } catch {
            await unloadConfiguredModels()
            if stopRequested {
                statusMessage = "Stopped."
                errorMessage = nil
            } else {
                statusMessage = error.localizedDescription
                errorMessage = error.localizedDescription
            }
        }
    }

    private func unloadConfiguredModels() async {
        await api.unloadOllamaModels([
            settings.fastModel,
            settings.expertTextModel,
            settings.expertVisionModel
        ])
    }
}
