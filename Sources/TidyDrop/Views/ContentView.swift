import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var store: AppStore
    @State private var isChoosingFolder = false
    @State private var isConfirmingApply = false

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 230, ideal: 260)
        } detail: {
            DetailView(store: store)
        }
        .searchable(text: .constant(""), placement: .toolbar, prompt: "Search files")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    isChoosingFolder = true
                } label: {
                    Label("Choose Folder", systemImage: "folder")
                }

                Button {
                    Task { await store.scan() }
                } label: {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
                .disabled(store.folderURL == nil || store.isBusy)

                Button {
                    Task { await store.classifyAndPlan() }
                } label: {
                    Label("Classify", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.files.isEmpty || store.isBusy)

                Button {
                    isConfirmingApply = true
                } label: {
                    Label("Apply", systemImage: "checkmark.circle")
                }
                .disabled(store.plan == nil || store.isBusy)
            }
        }
        .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                store.chooseFolder(url)
                Task { await store.scan() }
            }
        }
        .confirmationDialog("Apply reviewed plan?", isPresented: $isConfirmingApply) {
            Button("Apply Plan") {
                Task { await store.applyPlan() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("TidyDrop will \(store.settings.mode == .copy ? "copy files" : "move files") without deleting or overwriting existing files.")
        }
    }
}
