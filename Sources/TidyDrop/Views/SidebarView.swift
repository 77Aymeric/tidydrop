import SwiftUI

struct SidebarView: View {
    @Bindable var store: AppStore

    var body: some View {
        List(selection: $store.selectedFileID) {
            Section("Folder") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.folderURL?.path ?? "No folder selected")
                        .font(.callout)
                        .lineLimit(2)
                    Text(store.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Files") {
                if store.files.isEmpty {
                    Text("Scan a folder to list files.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.files) { file in
                        FileRow(file: file)
                            .tag(file.id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            BackendStatusView(store: store)
                .padding(12)
        }
    }
}

private struct FileRow: View {
    var file: FileItem

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .lineLimit(1)
                Text("\(file.fileKind) · \(Formatters.bytes(file.size))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } icon: {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
        }
    }

    private var iconName: String {
        switch file.fileKind {
        case "image": "photo"
        case "pdf": "doc.richtext"
        case "code": "chevron.left.forwardslash.chevron.right"
        case "archive": "archivebox"
        case "audio": "waveform"
        case "video": "film"
        default: "doc"
        }
    }
}

private struct BackendStatusView: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("System status")
                    .font(.callout.weight(.medium))
                Spacer()
                if store.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            StatusLine(title: "Backend", value: store.backendStatus, icon: backendIcon)

            StatusLine(title: "Ollama", value: ollamaTitle, icon: ollamaIcon)

            if !store.ollamaRunning {
                Text("Ollama is not running.\nStart it with: ollama serve")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            } else if store.models.isEmpty {
                Text("No model found. Install a local Ollama model, then refresh.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Button("Refresh") {
                Task { await store.refreshStatus() }
            }
            .controlSize(.small)
        }
        .padding(12)
        .tidydropGlass(cornerRadius: 18)
    }

    private var backendIcon: String {
        store.backendStatus == "Ready" ? "checkmark.circle" : "clock"
    }

    private var ollamaTitle: String {
        if !store.ollamaRunning { return "Not running" }
        if store.models.isEmpty { return "No model found" }
        return "Connected"
    }

    private var ollamaIcon: String {
        if store.ollamaRunning && !store.models.isEmpty { return "checkmark.circle" }
        return "exclamationmark.circle"
    }
}

private struct StatusLine: View {
    var title: String
    var value: String
    var icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text("\(title):")
                .font(.caption.weight(.medium))
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
