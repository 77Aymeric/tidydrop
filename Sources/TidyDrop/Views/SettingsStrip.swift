import SwiftUI

struct SettingsStrip: View {
    @Bindable var store: AppStore

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                Picker("Mode", selection: $store.settings.mode) {
                    ForEach(RunMode.allCases) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
                TextField("Output folder", text: $store.settings.outputFolder)
                Picker("Text model", selection: $store.settings.textModel) {
                    Text("None").tag("")
                    ForEach(store.models, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
            }
            GridRow {
                Toggle("Subfolders", isOn: $store.settings.includeSubfolders)
                Toggle("Suggest names", isOn: $store.settings.suggestRenaming)
                Toggle("Apply names", isOn: $store.settings.applyRenaming)
            }
            GridRow {
                TextField("Ignored extensions", text: $store.settings.ignoredExtensions)
                Stepper("Max \(store.settings.maxFileSizeMB) MB", value: $store.settings.maxFileSizeMB, in: 1...500)
                Slider(value: $store.settings.confidenceThreshold, in: 0...1, step: 0.05) {
                    Text("Confidence")
                } minimumValueLabel: {
                    Text("0")
                } maximumValueLabel: {
                    Text(Formatters.percent(store.settings.confidenceThreshold))
                }
            }
        }
        .controlSize(.small)
        .textFieldStyle(.roundedBorder)
        .padding(16)
        .tidydropGlass(cornerRadius: 22)
    }
}
