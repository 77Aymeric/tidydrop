import SwiftUI

struct FilePreviewPanel: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)

            if let file = store.selectedFile {
                VStack(alignment: .leading, spacing: 8) {
                    Text(file.name)
                        .font(.title3.weight(.semibold))
                    Text("\(file.fileKind) · \(file.supportedLevel) · \(Formatters.bytes(file.size))")
                        .foregroundStyle(.secondary)
                    Text(file.metadataSummary)
                        .font(.callout)
                    ScrollView {
                        Text(file.contentPreview.isEmpty ? "Metadata only." : file.contentPreview)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(minHeight: 120, maxHeight: 220)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if let result = store.selectedResult {
                        Divider()
                        Text("Suggested: \(store.categories.first { $0.id == result.suggestedCategoryID }?.name ?? result.suggestedCategoryID)")
                            .font(.callout.weight(.medium))
                        Text("\(Formatters.percent(result.confidence)) · \(result.reason)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ContentUnavailableView("No file selected", systemImage: "doc")
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(18)
        .tidydropGlass(cornerRadius: 22)
    }
}
