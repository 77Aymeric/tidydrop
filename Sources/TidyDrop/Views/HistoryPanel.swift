import SwiftUI

struct HistoryPanel: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("History")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await store.refreshHistory() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }

            if store.runs.isEmpty {
                ContentUnavailableView("No runs", systemImage: "clock.arrow.circlepath")
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                ForEach(store.runs.prefix(6)) { run in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(run.runID)
                                .font(.callout.weight(.medium))
                            Text("\(run.mode.rawValue) · \(run.operations.count) operations")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Undo") {
                            Task { await store.previewUndo(runID: run.runID) }
                        }
                        .controlSize(.small)
                    }
                    Divider()
                }
            }

            if let undo = store.undoPreview {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Undo Preview")
                        .font(.callout.weight(.medium))
                    Text("\(undo.actions.count) reverse actions ready.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(undo.actions.prefix(3)) { action in
                        HStack {
                            Text(action.status.capitalized)
                                .font(.caption.weight(.medium))
                            Text(action.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                    Button("Apply Undo") {
                        Task { await store.applyUndo() }
                    }
                    .controlSize(.small)
                }
                .padding(12)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(18)
        .tidydropGlass(cornerRadius: 22)
    }
}
