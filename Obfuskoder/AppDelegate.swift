import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true   // focused single-window utility (SPEC §10)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftUI's Commands API can only place a custom item before/after the whole
        // system Cut/Copy/Paste group — not between Copy and Paste. Per macOS convention,
        // move "Copy Snippet" (⇧⌘C) to sit right after the standard Copy item. Done on the
        // next runloop tick, after SwiftUI has finished building the menu.
        DispatchQueue.main.async { Self.placeCopySnippetAfterCopy() }
    }

    /// Relocates the existing (SwiftUI-created) "Copy Snippet" menu item to immediately
    /// follow the standard Copy item, preserving its action and validation.
    private static func placeCopySnippetAfterCopy() {
        guard let editMenu = NSApp.mainMenu?.items
            .compactMap({ $0.submenu })
            .first(where: { menu in menu.items.contains { $0.action == #selector(NSText.copy(_:)) } })
        else { return }

        func isStandardCopy(_ item: NSMenuItem) -> Bool {
            item.keyEquivalent == "c" && !item.keyEquivalentModifierMask.contains(.shift)
        }
        func isCopySnippet(_ item: NSMenuItem) -> Bool {
            item.keyEquivalent == "c" && item.keyEquivalentModifierMask.contains(.shift)
        }

        guard let snippetItem = editMenu.items.first(where: isCopySnippet),
              let copyIndex = editMenu.items.firstIndex(where: isStandardCopy)
        else { return }

        if editMenu.index(of: snippetItem) == copyIndex + 1 { return }   // already in place

        editMenu.removeItem(snippetItem)
        let insertAt = (editMenu.items.firstIndex(where: isStandardCopy).map { $0 + 1 })
            ?? editMenu.numberOfItems
        editMenu.insertItem(snippetItem, at: insertAt)
    }
}
