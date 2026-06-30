import SwiftUI

/// Drives the simulator-reset selection dialog: loads devices with sizes, tracks the
/// user's checkbox selection, and performs the resets.
@MainActor
final class SimulatorResetViewModel: ObservableObject {
    enum Phase {
        case loading
        case ready
        case resetting
    }

    @Published var phase: Phase = .loading
    @Published private(set) var devices: [SimulatorDevice] = []
    @Published var selection: Set<String> = []
    @Published private(set) var loadError: String?

    private let threshold = UserSettings.shared.simulatorSizeThresholdBytes
    private let binaryUnits = UserSettings.shared.useBinaryUnits

    /// Called when the dialog should close. `nil` means cancelled (no resets run).
    var onClose: ((CleanupResult?) -> Void)?

    var thresholdDescription: String {
        ByteSizeFormatter.string(fromBytes: threshold, binary: binaryUnits)
    }

    var selectedBytes: Int64 {
        devices.filter { selection.contains($0.id) }.reduce(0) { $0 + $1.sizeBytes }
    }

    func sizeString(_ bytes: Int64) -> String {
        ByteSizeFormatter.string(fromBytes: bytes, binary: binaryUnits)
    }

    func isSelected(_ id: String) -> Bool { selection.contains(id) }

    func setSelected(_ id: String, _ selected: Bool) {
        if selected { selection.insert(id) } else { selection.remove(id) }
    }

    func selectAll() { selection = Set(devices.map(\.id)) }
    func deselectAll() { selection.removeAll() }

    func load() {
        phase = .loading
        let threshold = self.threshold
        Task.detached(priority: .userInitiated) {
            let service = SimulatorResetService()
            let result = Result { try service.listDevicesWithSizes() }
            await MainActor.run {
                switch result {
                case .success(let all):
                    self.devices = all.filter { $0.sizeBytes >= threshold }
                    self.loadError = nil
                case .failure(let error):
                    self.devices = []
                    self.loadError = error.localizedDescription
                }
                self.phase = .ready
            }
        }
    }

    func cancel() {
        onClose?(nil)
    }

    func reset() {
        let targets = devices.filter { selection.contains($0.id) }
        guard !targets.isEmpty else { return }
        phase = .resetting
        Task.detached(priority: .userInitiated) {
            let service = SimulatorResetService()
            var bytes: Int64 = 0
            var errors: [String] = []
            var succeeded = 0
            for device in targets {
                let result = service.reset(device)
                bytes += result.bytesReclaimed
                errors.append(contentsOf: result.errors)
                if result.errors.isEmpty { succeeded += 1 }
            }
            let summary = "Reset \(succeeded) simulator\(succeeded == 1 ? "" : "s")."
            let outcome = CleanupResult(bytesReclaimed: bytes, summary: summary, errors: errors)
            await MainActor.run { self.onClose?(outcome) }
        }
    }
}

/// Checkbox list of simulators (above the size threshold) the user can selectively reset.
struct SimulatorResetView: View {
    @ObservedObject var viewModel: SimulatorResetViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reset Simulators")
                .font(.headline)

            content

            Divider()
            footer
        }
        .padding(16)
        .frame(width: 460, height: 420)
        .onAppear { viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            centered { ProgressView("Measuring simulators…") }
        case .resetting:
            centered { ProgressView("Resetting…") }
        case .ready:
            if let error = viewModel.loadError {
                centered {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                        Text(error).multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.secondary)
                }
            } else if viewModel.devices.isEmpty {
                centered {
                    Text("No simulators with more than \(viewModel.thresholdDescription) of content.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                deviceList
            }
        }
    }

    private var deviceList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Simulators with more than \(viewModel.thresholdDescription) of content:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("All") { viewModel.selectAll() }
                    .buttonStyle(.link)
                Button("None") { viewModel.deselectAll() }
                    .buttonStyle(.link)
            }
            List(viewModel.devices) { device in
                Toggle(isOn: Binding(
                    get: { viewModel.isSelected(device.id) },
                    set: { viewModel.setSelected(device.id, $0) }
                )) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.name)
                            Text(device.runtimeName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(viewModel.sizeString(device.sizeBytes))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
            }
            .listStyle(.inset)
        }
    }

    private var footer: some View {
        HStack {
            if viewModel.phase == .ready, !viewModel.selection.isEmpty {
                Text("\(viewModel.selection.count) selected · \(viewModel.sizeString(viewModel.selectedBytes)) reclaimable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel") { viewModel.cancel() }
                .keyboardShortcut(.cancelAction)
            Button("Reset Selected") { viewModel.reset() }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.selection.isEmpty || viewModel.phase != .ready)
        }
    }

    private func centered<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack { Spacer(); content(); Spacer() }
            .frame(maxWidth: .infinity)
    }
}
