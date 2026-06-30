import SwiftUI

/// Backs the Settings window; reads/writes through `UserSettings` and notifies the app
/// when a value changes so it can re-apply (e.g. restart the refresh timer).
@MainActor
final class SettingsViewModel: ObservableObject {
    private let settings = UserSettings.shared

    /// Invoked after any setting changes.
    var onChange: (() -> Void)?

    @Published var refreshInterval: Double {
        didSet { settings.refreshInterval = refreshInterval; onChange?() }
    }
    @Published var useBinaryUnits: Bool {
        didSet { settings.useBinaryUnits = useBinaryUnits; onChange?() }
    }
    @Published var lowSpacePercent: Double {
        didSet { settings.lowSpaceThresholdFraction = lowSpacePercent / 100.0; onChange?() }
    }
    @Published var simulatorThresholdMB: Double {
        didSet { settings.simulatorSizeThresholdBytes = Int64(simulatorThresholdMB * 1_000_000); onChange?() }
    }

    init() {
        let settings = UserSettings.shared
        refreshInterval = settings.refreshInterval
        useBinaryUnits = settings.useBinaryUnits
        lowSpacePercent = settings.lowSpaceThresholdFraction * 100.0
        simulatorThresholdMB = Double(settings.simulatorSizeThresholdBytes) / 1_000_000
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Display") {
                Picker("Units", selection: $viewModel.useBinaryUnits) {
                    Text("Decimal (GB, 1000-based)").tag(false)
                    Text("Binary (GiB, 1024-based)").tag(true)
                }

                Stepper(value: $viewModel.lowSpacePercent, in: 0.5...25, step: 0.5) {
                    Text("Warn below \(viewModel.lowSpacePercent, specifier: "%.1f")% free")
                }
            }

            Section("Refresh") {
                Stepper(value: $viewModel.refreshInterval, in: 20...60, step: 5) {
                    Text("Every \(Int(viewModel.refreshInterval)) seconds")
                }
            }

            Section("Simulators") {
                Stepper(value: $viewModel.simulatorThresholdMB, in: 10...2000, step: 10) {
                    Text("Hide sims smaller than \(Int(viewModel.simulatorThresholdMB)) MB")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 320)
    }
}
