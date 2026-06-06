import SwiftUI
import UniformTypeIdentifiers

struct SettingsStrip: View {
    @Bindable var store: AppStore
    @State private var isChoosingOutputFolder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroup(title: "Destination") {
                SettingRow(
                    title: "File action",
                    help: "Choose what happens when you apply the plan."
                ) {
                    Picker("File action", selection: $store.settings.mode) {
                        Text("Copy files").tag(RunMode.copy)
                        Text("Move files").tag(RunMode.move)
                    }
                    .pickerStyle(.segmented)
                    .help("Copy keeps originals untouched. Recommended.")

                    Text(store.settings.mode == .copy ? "Keeps originals untouched. Safest option." : "Moves originals, but undo is available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SortedFolderRow(store: store, isChoosingOutputFolder: $isChoosingOutputFolder)
            }

            SettingsGroup(title: "Scan") {
                SettingRow(
                    title: "Scan subfolders",
                    help: "Include files inside folders too."
                ) {
                    Toggle("Also scan folders inside the selected folder.", isOn: $store.settings.includeSubfolders)
                        .toggleStyle(.switch)
                        .help("Also scan folders inside the selected folder.")
                }

                SettingRow(
                    title: "Ignored file types",
                    help: "Skipped during scan."
                ) {
                    TextField(".tmp, .DS_Store, .lock", text: $store.settings.ignoredExtensions)
                        .help("Extensions or filenames skipped during scan.")
                }

                SettingRow(
                    title: "Max file size to analyze",
                    help: "Larger files are still listed, but analyzed with filename and metadata only."
                ) {
                    Stepper("\(store.settings.maxFileSizeMB) MB", value: $store.settings.maxFileSizeMB, in: 1...500)
                        .help("Larger files are still listed, but analyzed with filename and metadata only.")
                }
            }

            SettingsGroup(title: "AI") {
                SettingRow(
                    title: "Ollama text model",
                    help: "Used for PDFs, documents, code and metadata."
                ) {
                    Picker("Ollama text model", selection: $store.settings.textModel) {
                        Text("No model selected").tag("")
                        ForEach(store.models, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .help("Used for PDFs, documents, code and metadata.")
                }

                SettingRow(
                    title: "Minimum confidence",
                    help: "Less confident files go to “To Review”."
                ) {
                    HStack(spacing: 10) {
                        Slider(value: $store.settings.confidenceThreshold, in: 0...1, step: 0.05) {
                            Text("Minimum confidence")
                        }
                        Text(Formatters.percent(store.settings.confidenceThreshold))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .trailing)
                    }
                    .help("Higher value means safer sorting, but more files to review.")
                }
            }

            SettingsGroup(title: "Naming") {
                SettingRow(
                    title: "Suggest better names",
                    help: "AI can propose clearer filenames."
                ) {
                    Toggle("TidyDrop suggests names based on file content.", isOn: $store.settings.suggestRenaming)
                        .toggleStyle(.switch)
                        .help("TidyDrop suggests names based on file content.")
                }

                SettingRow(
                    title: "Rename automatically",
                    help: "Off by default. You can review names before applying."
                ) {
                    Toggle("Only enable this if you trust the suggestions.", isOn: $store.settings.applyRenaming)
                        .toggleStyle(.switch)
                        .help("Only enable this if you trust the suggestions.")
                }
            }
        }
        .controlSize(.small)
        .textFieldStyle(.roundedBorder)
        .padding(16)
        .tidydropGlass(cornerRadius: 22)
        .fileImporter(isPresented: $isChoosingOutputFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                store.chooseOutputFolder(url)
            }
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
    }
}

private struct SettingRow<Control: View>: View {
    var title: String
    var help: String
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(help)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 190, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                control
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SortedFolderRow: View {
    @Bindable var store: AppStore
    @Binding var isChoosingOutputFolder: Bool

    var body: some View {
        SettingRow(
            title: "Sorted folder",
            help: "Where TidyDrop will place organized files."
        ) {
            HStack(spacing: 10) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.settings.outputFolder.isEmpty ? "Will be created inside the selected folder." : store.settings.outputFolder)
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if store.settings.outputFolder.isEmpty, store.folderURL == nil {
                        Text("Choose a folder to start.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(store.settings.outputFolder.isEmpty ? "Choose output folder" : "Change") {
                    isChoosingOutputFolder = true
                }
                Button("Default") {
                    store.resetOutputFolderToDefault()
                }
                .disabled(store.folderURL == nil)
            }
            .padding(10)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .help("Where TidyDrop will place organized files.")
        }
    }
}
