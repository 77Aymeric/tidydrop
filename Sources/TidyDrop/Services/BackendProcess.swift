import Foundation

@MainActor
final class BackendProcess {
    private var process: Process?
    private(set) var lastError: String?

    var rootDirectory: URL {
        let bundleURL = Bundle.main.bundleURL
        let candidate = bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: candidate.appending(path: "backend").path) {
            return candidate
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    func startIfNeeded() -> Bool {
        if let process, process.isRunning { return true }
        process = nil
        lastError = nil

        if let bundledBackendURL {
            return startBundledBackend(at: bundledBackendURL)
        }

        let root = rootDirectory
        let venvPython = root.appending(path: ".venv/bin/python")
        guard FileManager.default.isExecutableFile(atPath: venvPython.path) else {
            lastError = "Backend environment missing. Run ./script/build_and_run.sh to install it."
            return false
        }

        let task = Process()
        task.currentDirectoryURL = root
        task.executableURL = venvPython
        task.arguments = ["-m", "uvicorn", "backend.main:app", "--host", "127.0.0.1", "--port", "3838"]
        task.environment = ProcessInfo.processInfo.environment.merging(["PYTHONPATH": root.path]) { _, new in new }

        configureLogs(for: task)

        do {
            try task.run()
            process = task
            return true
        } catch {
            process = nil
            lastError = error.localizedDescription
            return false
        }
    }

    private var bundledBackendURL: URL? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let executable = resources
            .appending(path: "backend")
            .appending(path: "TidyDropBackend")
            .appending(path: "TidyDropBackend")
        return FileManager.default.isExecutableFile(atPath: executable.path) ? executable : nil
    }

    private func startBundledBackend(at executable: URL) -> Bool {
        let task = Process()
        task.currentDirectoryURL = executable.deletingLastPathComponent()
        task.executableURL = executable
        task.environment = ProcessInfo.processInfo.environment
        configureLogs(for: task)

        do {
            try task.run()
            process = task
            return true
        } catch {
            process = nil
            lastError = "Bundled backend could not start: \(error.localizedDescription)"
            return false
        }
    }

    private func configureLogs(for task: Process) {
        let logDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".tidydrop")
            .appending(path: "logs")
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        let logURL = logDirectory.appending(path: "backend.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.truncateFile(atOffset: 0)
            task.standardOutput = handle
            task.standardError = handle
        }
    }

    func stop() {
        process?.terminate()
        process = nil
    }
}
