import SwiftUI
import ObfuskoderKit

@main
struct ObfuskoderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var model = AppModel()
    @State private var store = PresetStore(fileURL: ObfuskoderApp.presetsURL())

    var body: some Scene {
        Window(UIStrings.appName, id: "main") {
            ContentView()
                .environment(model)
                .environment(store)
                .frame(minWidth: 720, minHeight: 420)
        }
        .windowResizability(.contentMinSize)
        .commands { AppCommands(model: model) }

        Settings {
            SettingsView()
                .environment(model)
        }
    }

    /// presets.json in the sandbox Application Support container (SPEC §6.7/§9.2).
    static func presetsURL() -> URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Obfuskoder", isDirectory: true)
        return dir.appendingPathComponent("presets.json")
    }
}
