import Foundation

@MainActor
final class BackendProcess {
    private var process: Process?
    private var sessionFileURL: URL?
    private(set) var lastError: String?
    private(set) var baseURL: URL?
    private(set) var sessionToken: String?

    var rootDirectory: URL {
        let bundleURL = Bundle.main.bundleURL
        let candidate = bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: candidate.appending(path: "backend").path) {
            return candidate
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    func startIfNeeded() -> Bool {
        if let process, process.isRunning, baseURL != nil, sessionToken != nil { return true }
        process = nil
        lastError = nil
        baseURL = nil
        sessionToken = nil

        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let sessionURL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".tidydrop/runtime")
            .appending(path: "session-\(UUID().uuidString).json")
        try? FileManager.default.createDirectory(
            at: sessionURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? FileManager.default.removeItem(at: sessionURL)
        sessionFileURL = sessionURL

        if let bundledBackendURL {
            guard startBundledBackend(at: bundledBackendURL, token: token, sessionURL: sessionURL) else {
                return false
            }
            return loadSession(expectedToken: token, from: sessionURL)
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
        task.arguments = ["-m", "backend.standalone"]
        task.environment = ProcessInfo.processInfo.environment.merging([
            "PYTHONPATH": root.path,
            "TIDYDROP_PORT": "0",
            "TIDYDROP_SESSION_TOKEN": token,
            "TIDYDROP_SESSION_FILE": sessionURL.path
        ]) { _, new in new }

        configureLogs(for: task)

        do {
            try task.run()
            process = task
            return loadSession(expectedToken: token, from: sessionURL)
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

    private func startBundledBackend(at executable: URL, token: String, sessionURL: URL) -> Bool {
        let task = Process()
        task.currentDirectoryURL = executable.deletingLastPathComponent()
        task.executableURL = executable
        task.environment = ProcessInfo.processInfo.environment.merging([
            "TIDYDROP_PORT": "0",
            "TIDYDROP_SESSION_TOKEN": token,
            "TIDYDROP_SESSION_FILE": sessionURL.path
        ]) { _, new in new }
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

    private func loadSession(expectedToken: String, from url: URL) -> Bool {
        struct Session: Decodable {
            let port: Int
            let token: String
        }

        for _ in 0..<100 {
            if let data = try? Data(contentsOf: url),
               let session = try? JSONDecoder().decode(Session.self, from: data),
               session.token == expectedToken,
               let url = URL(string: "http://127.0.0.1:\(session.port)") {
                baseURL = url
                sessionToken = session.token
                return true
            }
            Thread.sleep(forTimeInterval: 0.03)
        }
        process?.terminate()
        process = nil
        lastError = "Backend did not publish a valid private session."
        return false
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
        if let sessionFileURL {
            try? FileManager.default.removeItem(at: sessionFileURL)
        }
        sessionFileURL = nil
        baseURL = nil
        sessionToken = nil
    }
}
