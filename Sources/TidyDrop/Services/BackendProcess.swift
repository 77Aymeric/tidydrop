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

    func stop() {
        process?.terminate()
        process = nil
    }
}
