import SwiftUI

struct PlanPanel: View {
    @Bindable var store: AppStore

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
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    Divider()
                    ForEach(plan.operations) { operation in
                        OperationRow(store: store, operation: operation)
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
    }
}

private struct OperationRow: View {
    @Bindable var store: AppStore
    @State var operation: OperationEntry

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $operation.enabled)
                .labelsHidden()
                .frame(width: 54, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(Formatters.basename(operation.originalPath))
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
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
                Text(proposedFilename)
                    .lineLimit(1)
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
        }
        .padding(11)
        .opacity(operation.enabled ? 1 : 0.52)
        .onChange(of: operation) { _, newValue in
            store.updateOperation(newValue)
        }
    }

    private var proposedFilename: String {
        operation.suggestedFilename ?? Formatters.basename(operation.targetPath)
    }

    private var targetFolder: String {
        URL(fileURLWithPath: operation.targetPath).deletingLastPathComponent().path
    }
}
