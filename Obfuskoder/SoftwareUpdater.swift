import Foundation
import Combine
import Sparkle
import ObfuskoderKit

/// Owns the Sparkle updater and adapts it to the app. The only file that
/// imports Sparkle. Applies the user's `UpdateFrequency` and republishes
/// Sparkle's `canCheckForUpdates` so the menu item can enable/disable.
@MainActor
@Observable
final class SoftwareUpdater {
    @ObservationIgnored private let controller: SPUStandardUpdaterController
    @ObservationIgnored private var cancellable: AnyCancellable?
    private(set) var canCheckForUpdates = false

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

        // Apply the persisted cadence (default monthly) before the first check.
        let stored = UserDefaults.standard.string(forKey: SettingsKeys.updateFrequency)
            .flatMap(UpdateFrequency.init(rawValue:)) ?? AppConfig.defaultUpdateFrequency
        apply(stored)

        // Republish Sparkle's KVO-observable canCheckForUpdates on the main actor.
        cancellable = controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] value in self?.canCheckForUpdates = value }
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }

    func apply(_ frequency: UpdateFrequency) {
        let updater = controller.updater
        updater.automaticallyChecksForUpdates = frequency.automaticallyChecks
        if let interval = frequency.checkInterval {
            updater.updateCheckInterval = interval
        }
    }
}
