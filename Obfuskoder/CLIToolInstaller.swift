import AppKit
import ObfuskoderKit

/// Presents the "Install Command Line Tool…" flow (SPEC-CLI §6).
/// Decisions are pure functions in ObfuskoderKit.CLIInstall; this type only
/// inspects the filesystem and drives the panel/alerts. Stateless (INST-2).
@MainActor
enum CLIToolInstaller {
    static let toolName = "obfuskode"

    static func run() {
        // INST-4: a symlink into a translocated/mounted bundle would break.
        guard !CLIInstall.isEphemeralLocation(Bundle.main.bundleURL.path) else {
            presentInfo(title: UIStrings.cliMoveToApplicationsTitle,
                        body: UIStrings.cliMoveToApplicationsBody)
            return
        }
        let source = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/\(toolName)")
            .standardizedFileURL
        // INST-5: never offer a path to a dangling link — not even via Terminal.
        guard FileManager.default.fileExists(atPath: source.path) else {
            presentInfo(title: UIStrings.cliMissingToolTitle,
                        body: UIStrings.cliMissingToolBody)
            return
        }
        // INST-6: the panel IS the sandbox permission grant.
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = UIStrings.cliInstallPrompt
        panel.message = UIStrings.cliInstallPanelMessage
        panel.directoryURL = URL(fileURLWithPath: defaultFolder(), isDirectory: true)
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        install(into: folder, source: source)
    }

    private static func defaultFolder() -> String {
        CLIInstall.defaultInstallFolder(
            existsCheck: { FileManager.default.fileExists(atPath: $0) },
            home: NSHomeDirectory())
    }

    private static func install(into folder: URL, source: URL) {
        let target = folder.appendingPathComponent(toolName)
        switch CLIInstall.action(existing: existingItem(at: target), sourcePath: source.path) {
        case .alreadyInstalled:
            presentSuccess(target: target.path, folder: folder.path, alreadyInstalled: true)
        case .createLink:
            createLink(target: target, source: source, folder: folder)
        case .confirmReplace:
            guard confirmReplace() else { return }
            // Re-check after the (unbounded) modal: the item could have changed
            // type while the dialog was up, so re-derive the action rather than
            // blindly removing what the decision table promised never to touch.
            switch existingItem(at: target) {
            case .symlink, .file:
                do {
                    try FileManager.default.removeItem(at: target)
                } catch {
                    // Surface the real reason (e.g. permission) instead of
                    // letting createLink fail later with a misleading message.
                    presentFailure(folder: folder.path, source: source.path,
                                   reason: error.localizedDescription)
                    return
                }
                createLink(target: target, source: source, folder: folder)
            case .directory:
                presentFailure(folder: folder.path, source: source.path,
                               reason: UIStrings.cliFailReasonDirectory)
            case .none:
                createLink(target: target, source: source, folder: folder)
            }
        case .refuseDirectory:
            presentFailure(folder: folder.path, source: source.path,
                           reason: UIStrings.cliFailReasonDirectory)
        }
    }

    private static func existingItem(at url: URL) -> CLIInstall.ExistingItem? {
        let fm = FileManager.default
        if let destination = try? fm.destinationOfSymbolicLink(atPath: url.path) {
            let resolved = URL(fileURLWithPath: destination,
                               relativeTo: url.deletingLastPathComponent())
                .standardizedFileURL.path
            return .symlink(destination: resolved)
        }
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return nil }
        return isDirectory.boolValue ? .directory : .file
    }

    private static func createLink(target: URL, source: URL, folder: URL) {
        do {
            try FileManager.default.createSymbolicLink(at: target, withDestinationURL: source)
            presentSuccess(target: target.path, folder: folder.path, alreadyInstalled: false)
        } catch {
            presentFailure(folder: folder.path, source: source.path,
                           reason: error.localizedDescription)
        }
    }

    // MARK: Alerts

    private static func presentInfo(title: String, body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.runModal()
    }

    /// INST-9: Cancel is the default; Replace is explicitly destructive (INST-12).
    private static func confirmReplace() -> Bool {
        let alert = NSAlert()
        alert.messageText = UIStrings.cliReplaceTitle
        alert.informativeText = UIStrings.cliReplaceBody
        alert.addButton(withTitle: UIStrings.cancel)
        let replaceButton = alert.addButton(withTitle: UIStrings.replace)
        replaceButton.hasDestructiveAction = true
        return alert.runModal() == .alertSecondButtonReturn
    }

    /// INST-10: failures explain the reason and offer the copyable sudo command.
    private static func presentFailure(folder: String, source: String, reason: String?) {
        let command = CLIInstall.sudoInstallCommand(folder: folder, sourcePath: source)
        let alert = NSAlert()
        alert.messageText = UIStrings.cliFailTitle
        alert.informativeText = UIStrings.cliFailBody(
            reason: reason ?? UIStrings.cliFailReasonPermission(folder: folder),
            command: command)
        alert.addButton(withTitle: UIStrings.cliCopyCommand)
        alert.addButton(withTitle: UIStrings.cancel)
        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
        }
    }

    /// INST-11: success names the link; off-PATH folders get the PATH hint.
    private static func presentSuccess(target: String, folder: String, alreadyInstalled: Bool) {
        let alert = NSAlert()
        alert.messageText = UIStrings.cliSuccessTitle
        var body = alreadyInstalled ? UIStrings.cliAlreadyInstalledBody(target: target)
                                    : UIStrings.cliSuccessBody(target: target)
        if !CLIInstall.assumedPathFolders.contains(folder) {
            body += "\n\n" + UIStrings.cliPathHint(folder: folder)
        }
        alert.informativeText = body
        alert.runModal()
    }
}
