import SwiftUI
import UniformTypeIdentifiers

struct DetailView: View {
    @Bindable var store: AppStore
    @State private var isDropTargeted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HeaderPanel(store: store)
                SafeModeBanner()
                DropZonePanel(store: store, isTargeted: isDropTargeted)
                    .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                        handleDrop(providers)
                    }
                if let message = store.errorMessage {
                    ErrorBanner(message: message)
                }
                SettingsStrip(store: store)
                TemplatePanel(store: store)
                CategoryPanel(store: store)
                PlanPanel(store: store)
                ResultPanel(store: store)

                HStack(alignment: .top, spacing: 18) {
                    FilePreviewPanel(store: store)
                    HistoryPanel(store: store)
                }
            }
            .padding(24)
        }
        .background(.background)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = item as? URL
            }
            guard let url else { return }
            Task { @MainActor in
                await store.acceptDroppedURL(url, autoScan: true)
            }
        }
        return true
    }
}

private struct HeaderPanel: View {
    @Bindable var store: AppStore

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("TidyDrop")
                    .font(.largeTitle.weight(.semibold))
                Text("Drop a folder. Let local AI tidy it.")
                    .foregroundStyle(.secondary)
                if let summary = store.summary {
                    HStack(spacing: 14) {
                        StatLabel(title: "Files", value: "\(summary.totalFiles)")
                        StatLabel(title: "Images", value: "\(summary.images)")
                        StatLabel(title: "Docs", value: "\(summary.pdfs + summary.documents + summary.text)")
                        StatLabel(title: "Code", value: "\(summary.code)")
                    }
                    .padding(.top, 6)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                Text(store.folderURL?.lastPathComponent ?? "No Folder")
                    .font(.headline)
                Text(store.settings.outputFolder.isEmpty ? "Output folder not set" : store.settings.outputFolder)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(22)
        .tidydropGlass(cornerRadius: 26)
    }
}

private struct DropZonePanel: View {
    @Bindable var store: AppStore
    var isTargeted: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "folder.badge.plus")
                .font(.title2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("Drop a folder here")
                    .font(.headline)
                Text(store.folderURL?.path ?? "Choose or drag a folder to prepare a safe local scan.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if store.folderURL != nil {
                Button("Scan") {
                    Task { await store.scan() }
                }
                .controlSize(.small)
                .disabled(store.isBusy)
            }
        }
        .padding(18)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(isTargeted ? Color.primary.opacity(0.45) : Color.secondary.opacity(0.16), style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [7, 5]))
        }
        .background(isTargeted ? Color.primary.opacity(0.045) : Color.clear, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .tidydropGlass(cornerRadius: 22)
        .animation(.smooth(duration: 0.18), value: isTargeted)
    }
}

private struct SafeModeBanner: View {
    private let items = [
        ("lock", "Local only"),
        ("doc.on.doc", "Copy by default"),
        ("trash.slash", "Never deletes"),
        ("square.on.square", "Never overwrites"),
        ("eye", "Preview before apply"),
        ("arrow.uturn.backward", "Undo enabled")
    ]

    var body: some View {
        HStack(spacing: 12) {
            Text("Safe Mode")
                .font(.headline)
            Divider()
                .frame(height: 18)
            ForEach(items, id: \.1) { item in
                Label(item.1, systemImage: item.0)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .tidydropGlass(cornerRadius: 18)
    }
}

private struct ErrorBanner: View {
    var message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.callout)
            .foregroundStyle(.primary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct TemplatePanel: View {
    @Bindable var store: AppStore

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Sorting Templates")
                    .font(.headline)
                Text("Start with practical categories, then edit them freely.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                ForEach(SortingTemplate.all) { template in
                    Button(template.name) {
                        store.applyTemplate(template)
                    }
                }
            } label: {
                Label("Choose Template", systemImage: "rectangle.3.group")
            }
            .controlSize(.small)
        }
        .padding(16)
        .tidydropGlass(cornerRadius: 22)
    }
}

private struct ResultPanel: View {
    @Bindable var store: AppStore

    var body: some View {
        if let run = store.lastAppliedRun, let summary = store.applySummary {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Last Result")
                        .font(.headline)
                    Spacer()
                    Text(run.runID)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 18) {
                    StatLabel(title: run.mode == .copy ? "Copied" : "Moved", value: "\(summary.completed)")
                    StatLabel(title: "Skipped", value: "\(summary.skipped)")
                    StatLabel(title: "Conflicts", value: "\(summary.conflicts)")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Output")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(run.outputFolder)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button {
                        Task { await store.openOutputFolder() }
                    } label: {
                        Label("Open Output", systemImage: "folder")
                    }
                    .controlSize(.small)
                    Button {
                        Task { await store.previewUndo(runID: run.runID) }
                    } label: {
                        Label("Undo Run", systemImage: "arrow.uturn.backward")
                    }
                    .controlSize(.small)
                }
            }
            .padding(18)
            .tidydropGlass(cornerRadius: 22)
        }
    }
}

private struct StatLabel: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 58, alignment: .leading)
    }
}
