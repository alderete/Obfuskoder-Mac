import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    override init() {
        super.init()
        // Top-level menu items lose their icons; submenus, context menus, and
        // items flagged `shouldShowImage` keep theirs.
        NSMenuItem.disableIcons()
        // The app's own commands that do keep an icon:
        NSMenuItem.iconAllowlist = [UIStrings.copySnippet, UIStrings.clearForm]
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true   // focused single-window utility (SPEC §10)
    }
}
