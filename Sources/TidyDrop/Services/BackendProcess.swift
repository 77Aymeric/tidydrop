import Foundation

@MainActor
final class BackendProcess {
    private var process: Process?

    var rootDirectory: URL {
        let bundleURL = Bundle.main.bundleURL
        let candidate = bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: candidate.appending(path: "backend").path) {
            return candidate
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    func startIfNeeded() {
        guard process == nil else { return }

        let root = rootDirectory
        let venvPython = root.appending(path: ".venv/bin/python")
        let python = FileManager.default.isExecutableFile(atPath: venvPython.path) ? venvPython.path : "/usr/bin/python3"

        let task = Process()
        task.currentDirectoryURL = root
        task.executableURL = URL(fileURLWithPath: python)
        task.arguments = ["-m", "uvicorn", "backend.main:app", "--host", "127.0.0.1", "--port", "3838"]
        task.environment = ProcessInfo.processInfo.environment.merging(["PYTHONPATH": root.path]) { _, new in new }
        task.standardOutput = Pipe()
        task.standardError = Pipe()

        do {
            try task.run()
            process = task
        } catch {
            process = nil
        }
    }

    func stop() {
        process?.terminate()
        process = nil
    }
}
