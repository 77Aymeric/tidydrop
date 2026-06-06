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
    var models: [String] = []
    var selectedFileID: String?
    var selectedRunID: String?
    var isBusy = false
    var statusMessage = "Ready"
    var errorMessage: String?
    var ollamaRunning = false
    var ollamaMessage = "Checking Ollama"

    private let backend = BackendProcess()
    private let api = APIClient()

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

    func start() async {
        backend.startIfNeeded()
        try? await Task.sleep(for: .milliseconds(700))
        await refreshStatus()
        await refreshHistory()
    }

    func refreshStatus() async {
        do {
            let health = try await api.health()
            ollamaRunning = health.ollama.running
            ollamaMessage = health.ollama.message
            models = try await api.models()
            if settings.textModel.isEmpty {
                settings.textModel = models.first ?? ""
            }
            if settings.visionModel.isEmpty {
                settings.visionModel = models.first ?? ""
            }
        } catch {
            ollamaRunning = false
            ollamaMessage = "Backend is starting. Try again in a moment."
            errorMessage = "TidyDrop backend is starting. Try again in a moment."
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
        await run("Scanning folder") {
            let response = try await api.scan(folder: folderURL.path, settings: settings)
            files = response.files
            summary = response.summary
            selectedFileID = response.files.first?.id
            results = []
            plan = nil
            if response.summary.totalFiles == 0 {
                errorMessage = "No files found in this folder."
                statusMessage = "No files found."
            } else {
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
        await run("Classifying locally") {
            let nextResults = try await api.classify(files: files, categories: categories, settings: settings)
            let nextPlan = try await api.plan(
                sourceFolder: folderURL.path,
                files: files,
                categories: categories,
                results: nextResults,
                settings: settings
            )
            results = nextResults
            plan = nextPlan
            statusMessage = "Generated \(nextPlan.operations.count) proposed operations."
            if nextPlan.operations.isEmpty {
                errorMessage = "Classification completed, but no operations were generated."
            }
        }
    }

    func applyPlan() async {
        guard let plan else { return }
        await run("Applying reviewed plan") {
            self.plan = try await api.apply(plan: plan)
            self.lastAppliedRun = self.plan
            await refreshHistory()
            statusMessage = "Apply complete. Run saved."
        }
    }

    func previewUndo(runID: String) async {
        await run("Preparing undo") {
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
        await run("Applying undo") {
            self.undoPreview = try await api.undoApply(runID: undoPreview.runID)
            await refreshHistory()
            if self.undoPreview?.actions.contains(where: { $0.status == "conflict" || $0.status == "error" }) == true {
                errorMessage = "Undo finished with conflicts or errors."
            }
            statusMessage = "Undo complete."
        }
    }

    func applyTemplate(_ template: SortingTemplate) {
        categories = template.categories
        statusMessage = "Applied template: \(template.name)"
        errorMessage = nil
    }

    func openOutputFolder() async {
        guard let path = lastAppliedRun?.outputFolder ?? plan?.outputFolder ?? optionalOutputFolder else { return }
        await run("Opening output folder") {
            try await api.openFolder(path)
            statusMessage = "Opened output folder."
        }
    }

    private var optionalOutputFolder: String? {
        settings.outputFolder.isEmpty ? nil : settings.outputFolder
    }

    func updateOperation(_ operation: OperationEntry) {
        guard var currentPlan = plan,
              let index = currentPlan.operations.firstIndex(where: { $0.id == operation.id }) else { return }
        currentPlan.operations[index] = operation
        plan = currentPlan
    }

    func updateCategory(_ category: Category) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[index] = category
    }

    func addCategory() {
        categories.append(Category(id: "category-\(Date().timeIntervalSince1970)", name: "New Category", description: "", rules: ""))
    }

    func removeCategory(_ category: Category) {
        guard categories.count > 1 else { return }
        categories.removeAll { $0.id == category.id }
    }

    private func run(_ message: String, operation: () async throws -> Void) async {
        isBusy = true
        statusMessage = message
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await operation()
        } catch {
            statusMessage = error.localizedDescription
            errorMessage = error.localizedDescription
        }
    }
}
