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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(.secondary)
                Text(statusTitle)
                    .font(.callout)
                    .fontWeight(.medium)
                Spacer()
                if store.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Button("Refresh") {
                Task { await store.refreshStatus() }
            }
            .controlSize(.small)
        }
        .padding(12)
        .tidydropGlass(cornerRadius: 18)
    }

    private var statusTitle: String {
        if !store.ollamaRunning { return "Ollama offline" }
        if store.models.isEmpty { return "No models installed" }
        return "Ollama ready"
    }

    private var statusMessage: String {
        if !store.ollamaRunning { return store.ollamaMessage }
        if store.models.isEmpty { return "Install a local Ollama model, then refresh." }
        return "Local classification is available."
    }

    private var statusIcon: String {
        if store.ollamaRunning && !store.models.isEmpty { return "checkmark.circle" }
        return "exclamationmark.circle"
    }
}
