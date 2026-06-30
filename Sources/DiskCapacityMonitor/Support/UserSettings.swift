import Foundation

/// Centralized, type-safe wrapper around `UserDefaults` for persisted preferences.
final class UserSettings {
    static let shared = UserSettings()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.defaults.register(defaults: [
            Keys.refreshInterval: 30.0,
            Keys.useBinaryUnits: false,
            Keys.lowSpaceThresholdPercent: 2.0,
            Keys.simulatorSizeThresholdMB: 50.0,
        ])
    }

    private enum Keys {
        static let selectedVolumePath = "selectedVolumePath"
        static let refreshInterval = "refreshInterval"
        static let useBinaryUnits = "useBinaryUnits"
        static let lowSpaceThresholdPercent = "lowSpaceThresholdPercent"
        static let simulatorSizeThresholdMB = "simulatorSizeThresholdMB"
    }

    /// Path of the volume currently shown in the menu bar. `nil` => default to system disk.
    var selectedVolumePath: String? {
        get { defaults.string(forKey: Keys.selectedVolumePath) }
        set { defaults.set(newValue, forKey: Keys.selectedVolumePath) }
    }

    /// Seconds between automatic refreshes while awake. Clamped to 20...60.
    var refreshInterval: TimeInterval {
        get { min(max(defaults.double(forKey: Keys.refreshInterval), 20), 60) }
        set { defaults.set(min(max(newValue, 20), 60), forKey: Keys.refreshInterval) }
    }

    /// Decimal (base-1000) vs binary (base-1024) byte units.
    var useBinaryUnits: Bool {
        get { defaults.bool(forKey: Keys.useBinaryUnits) }
        set { defaults.set(newValue, forKey: Keys.useBinaryUnits) }
    }

    /// Free/total fraction below which the menu-bar text turns red. Stored as a percent.
    var lowSpaceThresholdFraction: Double {
        get { defaults.double(forKey: Keys.lowSpaceThresholdPercent) / 100.0 }
        set { defaults.set(newValue * 100.0, forKey: Keys.lowSpaceThresholdPercent) }
    }

    /// Simulators whose container is below this size (MB) are hidden from the reset dialog.
    var simulatorSizeThresholdBytes: Int64 {
        get { Int64(defaults.double(forKey: Keys.simulatorSizeThresholdMB) * 1_000_000) }
        set { defaults.set(Double(newValue) / 1_000_000, forKey: Keys.simulatorSizeThresholdMB) }
    }
}
