import Testing
import Foundation
@testable import ObfuskoderKit

private let source = "/Applications/Obfuskoder.app/Contents/Helpers/obfuskode"

@Test func nothingAtTargetCreatesLink() {
    #expect(CLIInstall.action(existing: nil, sourcePath: source) == .createLink)
}

@Test func correctSymlinkIsAlreadyInstalled() {
    #expect(CLIInstall.action(existing: .symlink(destination: source),
                              sourcePath: source) == .alreadyInstalled)
}

@Test func wrongSymlinkNeedsConfirmation() {
    #expect(CLIInstall.action(existing: .symlink(destination: "/old/path/obfuskode"),
                              sourcePath: source) == .confirmReplace)
}

@Test func regularFileNeedsConfirmation() {
    #expect(CLIInstall.action(existing: .file, sourcePath: source) == .confirmReplace)
}

@Test func directoryIsRefused() {
    #expect(CLIInstall.action(existing: .directory, sourcePath: source) == .refuseDirectory)
}

@Test func translocatedAndVolumePathsAreEphemeral() {     // INST-4
    #expect(CLIInstall.isEphemeralLocation(
        "/private/var/folders/ab/xyz/T/AppTranslocation/123-456/d/Obfuskoder.app"))
    #expect(CLIInstall.isEphemeralLocation("/Volumes/Obfuskoder/Obfuskoder.app"))
    #expect(!CLIInstall.isEphemeralLocation("/Applications/Obfuskoder.app"))
}

@Test func defaultFolderPrefersUsrLocalBin() {            // INST-6
    #expect(CLIInstall.defaultInstallFolder(existsCheck: { _ in true },
                                            home: "/Users/x") == "/usr/local/bin")
    #expect(CLIInstall.defaultInstallFolder(existsCheck: { $0 == "/opt/homebrew/bin" },
                                            home: "/Users/x") == "/opt/homebrew/bin")
    #expect(CLIInstall.defaultInstallFolder(existsCheck: { _ in false },
                                            home: "/Users/x") == "/Users/x")
}

@Test func sudoCommandQuotesPaths() {                     // INST-10
    let command = CLIInstall.sudoInstallCommand(folder: "/usr/local/bin", sourcePath: source)
    #expect(command == "sudo mkdir -p '/usr/local/bin' && sudo ln -sf '\(source)' '/usr/local/bin/obfuskode'")
}

@Test func pathFolderSetCoversEtcPathsAndHomebrew() {     // INST-11
    #expect(CLIInstall.assumedPathFolders.contains("/usr/local/bin"))
    #expect(CLIInstall.assumedPathFolders.contains("/opt/homebrew/bin"))
    #expect(!CLIInstall.assumedPathFolders.contains("/Users/x/bin"))
}
