import Foundation

public enum AppConfig {
    public static let defaultDebounceSeconds: Double = 0.4
    public static let minDebounceSeconds: Double = 0.1
    public static let maxDebounceSeconds: Double = 1.0
    public static let defaultFallbackMessage = "Enable JavaScript to view email"
    public static let accentHex = "5E7C50"
    public static let maxSelfCheckAttempts = 8
}
