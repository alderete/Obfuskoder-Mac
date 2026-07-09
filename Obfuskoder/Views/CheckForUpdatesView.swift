import SwiftUI

/// The Check for Updates… menu item. A View (not a bare Button in Commands) so
/// its disabled state tracks the updater's observable `canCheckForUpdates`.
struct CheckForUpdatesView: View {
    let updater: SoftwareUpdater

    var body: some View {
        Button(UIStrings.checkForUpdates) { updater.checkForUpdates() }
            .disabled(!updater.canCheckForUpdates)
    }
}
