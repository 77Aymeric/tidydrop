import SwiftUI
import UniformTypeIdentifiers

struct SettingsStrip: View {
    @Bindable var store: AppStore
    @State private var isChoosingOutputFolder = false
    @State private var showsMoreSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroup(title: "Essentials") {
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

                SettingRow(
                    title: "Smart folders",
                    help: "Group files by project, client, subject and date."
                ) {
                    Toggle("Let AI create meaningful folders.", isOn: $store.settings.allowAICategories)
                        .toggleStyle(.switch)
                }

                SettingRow(
                    title: "Reviewed names",
                    help: "Apply filename suggestions after you review them."
                ) {
                    Toggle("Use approved filename suggestions.", isOn: $store.settings.applyRenaming)
                        .toggleStyle(.switch)
                }
            }

            DisclosureGroup(isExpanded: $showsMoreSettings) {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()

                    SettingsGroup(title: "Scan") {
                        SettingRow(
                            title: "Scan subfolders",
                            help: "Include files inside folders too."
                        ) {
                            Toggle("Also scan folders inside the selected folder.", isOn: $store.settings.includeSubfolders)
                                .toggleStyle(.switch)
                        }

                        SettingRow(
                            title: "Ignored file types",
                            help: "Skipped during scan."
                        ) {
                            TextField(".tmp, .DS_Store, .lock", text: $store.settings.ignoredExtensions)
                        }

                        SettingRow(
                            title: "Max file size to analyze",
                            help: "Larger files use filename and metadata only."
                        ) {
                            Stepper("\(store.settings.maxFileSizeMB) MB", value: $store.settings.maxFileSizeMB, in: 1...500)
                        }
                    }

                    SettingsGroup(title: "AI Models") {
                        ModelPickerRow(
                            title: "Fast model",
                            help: "First pass across every file.",
                            selection: $store.settings.fastModel,
                            models: store.models,
                            emptyLabel: "No model selected"
                        )

                        ModelPickerRow(
                            title: "Expert text model",
                            help: "Creates folders and rechecks uncertain text.",
                            selection: $store.settings.expertTextModel,
                            models: store.models,
                            emptyLabel: "No model selected"
                        )

                        ModelPickerRow(
                            title: "Expert vision model",
                            help: "Rechecks uncertain images.",
                            selection: $store.settings.expertVisionModel,
                            models: store.models,
                            emptyLabel: "Use expert text model"
                        )
                    }

                    SettingsGroup(title: "Review") {
                        SettingRow(
                            title: "Expert review",
                            help: "Recheck uncertain fast-pass results."
                        ) {
                            Toggle("Use expert models for uncertain files.", isOn: $store.settings.expertReviewEnabled)
                                .toggleStyle(.switch)
                        }

                        if store.settings.expertReviewEnabled {
                            SettingRow(
                                title: "Expert threshold",
                                help: "Results below this confidence are escalated."
                            ) {
                                PercentageSlider(value: $store.settings.expertReviewThreshold, range: 0.5...1)
                            }
                        }

                        SettingRow(
                            title: "Minimum confidence",
                            help: "Less confident files go to To Review."
                        ) {
                            PercentageSlider(value: $store.settings.confidenceThreshold)
                        }
                    }

                    SettingsGroup(title: "Naming And Runtime") {
                        SettingRow(
                            title: "Suggest better names",
                            help: "Generate filenames from file content."
                        ) {
                            Toggle("Suggest clearer filenames.", isOn: $store.settings.suggestRenaming)
                                .toggleStyle(.switch)
                        }

                        SettingRow(
                            title: "AI timeout",
                            help: "Stop a slow local model request."
                        ) {
                            Stepper("Stop after \(store.settings.aiTimeoutSeconds) sec", value: $store.settings.aiTimeoutSeconds, in: 15...600, step: 15)
                        }
                    }
                }
                .padding(.top, 10)
            } label: {
                Label("More Settings", systemImage: "slider.horizontal.3")
                    .font(.callout.weight(.medium))
            }
            .padding(.top, 2)
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

private struct ModelPickerRow: View {
    var title: String
    var help: String
    @Binding var selection: String
    var models: [String]
    var emptyLabel: String

    var body: some View {
        SettingRow(title: title, help: help) {
            Picker(title, selection: $selection) {
                Text(emptyLabel).tag("")
                ForEach(models, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
        }
    }
}

private struct PercentageSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1

    var body: some View {
        HStack(spacing: 10) {
            Slider(value: $value, in: range, step: 0.05)
            Text(Formatters.percent(value))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
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
