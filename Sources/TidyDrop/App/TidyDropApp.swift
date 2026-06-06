import AppKit
import SwiftUI

@main
struct TidyDropApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup("TidyDrop", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 980, minHeight: 680)
                .task {
                    await store.start()
                }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("TidyDrop") {
                Button("Scan Folder") {
                    Task { await store.scan() }
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Classify") {
                    Task { await store.classifyAndPlan() }
                }
                .keyboardShortcut(.return, modifiers: [.command])

                Button("Apply Reviewed Plan") {
                    Task { await store.applyPlan() }
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView(store: store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
