import SwiftUI

struct SettingsView: View {
    @Bindable var store: AppStore

    var body: some View {
        Form {
            Picker("Default mode", selection: $store.settings.mode) {
                ForEach(RunMode.allCases) { mode in
                    Text(mode.rawValue.capitalized).tag(mode)
                }
            }
            Toggle("Include subfolders", isOn: $store.settings.includeSubfolders)
            Toggle("Suggest renaming", isOn: $store.settings.suggestRenaming)
            Toggle("Apply suggested names", isOn: $store.settings.applyRenaming)
            TextField("Ignored extensions", text: $store.settings.ignoredExtensions)
            Stepper("Max file size: \(store.settings.maxFileSizeMB) MB", value: $store.settings.maxFileSizeMB, in: 1...500)
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420)
    }
}
