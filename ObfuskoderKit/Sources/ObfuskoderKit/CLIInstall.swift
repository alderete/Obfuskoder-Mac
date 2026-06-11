import Foundation

/// Pure decision logic for the app's "Install Command Line Tool" flow
/// (SPEC-CLI §6). Presentation lives in the app target; this is the
/// unit-testable half (BLD-10).
public enum CLIInstall {
    /// What stands at the destination path before installing.
    public enum ExistingItem: Equatable, Sendable {
        case symlink(destination: String)
        case file
        case directory
    }

    /// What the installer should do (SPEC-CLI §6.4 decision table).
    public enum Action: Equatable, Sendable {
        case createLink
        case alreadyInstalled
        case confirmReplace
        case refuseDirectory
    }

    public static func action(existing: ExistingItem?, sourcePath: String) -> Action {
        switch existing {
        case nil: .createLink
        case .symlink(let destination) where destination == sourcePath: .alreadyInstalled
        case .symlink, .file: .confirmReplace
        case .directory: .refuseDirectory
        }
    }

    /// INST-4: true when the app runs somewhere a symlink must not point into
    /// (Gatekeeper app translocation, or a disk image / removable volume).
    public static func isEphemeralLocation(_ bundlePath: String) -> Bool {
        bundlePath.contains("/AppTranslocation/") || bundlePath.hasPrefix("/Volumes/")
    }

    /// INST-11: folders assumed to be on PATH (/etc/paths defaults + Homebrew);
    /// any other install folder earns the PATH hint.
    public static let assumedPathFolders: Set<String> = [
        "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin", "/opt/homebrew/bin"
    ]

    /// INST-10: the copyable Terminal command. The app never runs this itself.
    /// Paths are single-quoted with embedded quotes escaped ('\'') so the
    /// command survives copy/paste even for folders containing apostrophes.
    public static func sudoInstallCommand(folder: String, sourcePath: String) -> String {
        "sudo mkdir -p \(shellQuoted(folder)) && sudo ln -sf \(shellQuoted(sourcePath)) \(shellQuoted(folder + "/obfuskode"))"
    }

    private static func shellQuoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// INST-6: the panel's initial directory — first existing candidate, else home.
    public static func defaultInstallFolder(existsCheck: (String) -> Bool, home: String) -> String {
        for candidate in ["/usr/local/bin", "/opt/homebrew/bin"] where existsCheck(candidate) {
            return candidate
        }
        return home
    }
}
