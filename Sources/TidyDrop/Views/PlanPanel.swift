import AppKit
import SwiftUI

struct PlanPanel: View {
    @Bindable var store: AppStore
    @State private var previewOperation: OperationEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Review Plan")
                    .font(.headline)
                Spacer()
                if let plan = store.plan {
                    Text("\(plan.operations.filter(\.enabled).count) enabled")
                        .foregroundStyle(.secondary)
                }
            }

            if let plan = store.plan {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Text("Action")
                            .frame(width: 54, alignment: .leading)
                        Text("Original")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Target Folder")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Proposed Name")
                            .frame(width: 180, alignment: .leading)
                        Text("Confidence")
                            .frame(width: 72, alignment: .trailing)
                        Text("")
                            .frame(width: 48)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    Divider()
                    ForEach(plan.operations) { operation in
                        OperationRow(
                            store: store,
                            operation: operation,
                            onPreview: {
                                store.selectForPreview(operation)
                                previewOperation = operation
                            }
                        )
                        if operation.id != plan.operations.last?.id {
                            Divider()
                        }
                    }
                }
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                let message = store.files.isEmpty ? "No files found. Choose or drop a folder, then scan." : "Classify files to generate a before/after plan."
                ContentUnavailableView("No plan yet", systemImage: "list.bullet.rectangle", description: Text(message))
                    .frame(maxWidth: .infinity, minHeight: 180)
            }
        }
        .padding(18)
        .tidydropGlass(cornerRadius: 22)
        .sheet(item: $previewOperation) { operation in
            ReviewFilePreview(store: store, operation: operation)
        }
    }
}

private struct OperationRow: View {
    @Bindable var store: AppStore
    @State var operation: OperationEntry
    var onPreview: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $operation.enabled)
                .labelsHidden()
                .frame(width: 54, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Button(action: onPreview) {
                    Text(Formatters.basename(operation.originalPath))
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .help("Preview this file")
                Text(operation.originalPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Picker("", selection: $operation.categoryID) {
                    ForEach(store.categories) { category in
                        Text(category.name).tag(category.id)
                    }
                }
                .labelsHidden()
                Text(targetFolder)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                TextField("Filename", text: proposedFilenameBinding)
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .help("This reviewed filename will be used when automatic renaming is enabled.")
                Text(operation.reason.isEmpty ? "No reason provided." : operation.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(width: 180, alignment: .leading)
            Text(Formatters.percent(operation.confidence))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)
            HStack(spacing: 4) {
                Button(action: onPreview) {
                    Image(systemName: "eye")
                }
                .help("Preview")
                Button {
                    store.revealOriginal(operation)
                } label: {
                    Image(systemName: "folder")
                }
                .help("Show original in Finder")
            }
            .buttonStyle(.borderless)
            .frame(width: 48)
        }
        .padding(11)
        .opacity(operation.enabled ? 1 : 0.52)
        .onChange(of: operation) { _, newValue in
            store.updateOperation(newValue)
        }
    }

    private var proposedFilenameBinding: Binding<String> {
        Binding(
            get: {
                operation.suggestedFilename ?? Formatters.basename(operation.targetPath)
            },
            set: { value in
                operation.suggestedFilename = value
            }
        )
    }

    private var targetFolder: String {
        URL(fileURLWithPath: operation.targetPath).deletingLastPathComponent().path
    }
}

private struct ReviewFilePreview: View {
    @Bindable var store: AppStore
    var operation: OperationEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(Formatters.basename(operation.originalPath))
                        .font(.title2.weight(.semibold))
                    Text(operation.originalPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button {
                    store.openOriginal(operation)
                } label: {
                    Label("Open", systemImage: "arrow.up.forward.app")
                }
                Button {
                    store.revealOriginal(operation)
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
                Button("Done") {
                    dismiss()
                }
            }

            if let file = store.file(for: operation) {
                if file.fileKind == "image",
                   let image = NSImage(contentsOfFile: file.path) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 420)
                        .background(.quaternary.opacity(0.25))
                } else {
                    ScrollView {
                        Text(file.contentPreview.isEmpty ? file.metadataSummary : file.contentPreview)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }
                    .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                }

                Divider()
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                    GridRow {
                        Text("Destination").foregroundStyle(.secondary)
                        Text(operation.targetPath).textSelection(.enabled)
                    }
                    GridRow {
                        Text("Confidence").foregroundStyle(.secondary)
                        Text(Formatters.percent(operation.confidence))
                    }
                    GridRow {
                        Text("Reason").foregroundStyle(.secondary)
                        Text(operation.reason)
                    }
                }
                .font(.callout)
            }
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 520)
    }
}
