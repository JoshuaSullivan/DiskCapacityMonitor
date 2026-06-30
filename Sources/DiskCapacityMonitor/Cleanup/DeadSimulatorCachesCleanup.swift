import Foundation

/// Removes "Dead" app-container caches left behind by CoreSimulator's
/// `containermanagerd` after apps are uninstalled from a simulator.
///
/// For each simulator device, these accumulate at the fixed relative path
/// `data/Library/Caches/com.apple.containermanagerd/Dead`. To match the behaviour of
/// the reference script, the `Dead` directory's *contents* are removed but the
/// directory itself is left in place (so containermanagerd needn't recreate it).
struct DeadSimulatorCachesCleanup: CleanupAction {
    let title = "Clean Dead Simulator Caches"

    /// Root of the per-device simulator containers. Injectable for testing.
    let devicesRoot: URL

    /// Fixed relative path of the Dead cache within a device container.
    static let deadRelativePath = "data/Library/Caches/com.apple.containermanagerd/Dead"

    static var defaultDevicesRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/CoreSimulator/Devices", isDirectory: true)
    }

    init(devicesRoot: URL = DeadSimulatorCachesCleanup.defaultDevicesRoot) {
        self.devicesRoot = devicesRoot
    }

    func run() async -> CleanupResult {
        let fm = FileManager.default
        guard fm.fileExists(atPath: devicesRoot.path) else {
            return CleanupResult(summary: "No simulators found.")
        }

        let deviceDirs = (try? fm.contentsOfDirectory(
            at: devicesRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var reclaimed: Int64 = 0
        var cleared: [String] = []
        var errors: [String] = []

        for deviceDir in deviceDirs {
            guard (try? deviceDir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                continue
            }

            let deadDir = deviceDir.appendingPathComponent(Self.deadRelativePath, isDirectory: true)
            guard fm.fileExists(atPath: deadDir.path) else { continue }

            // Skip Dead directories that are already empty.
            let contents = (try? fm.contentsOfDirectory(atPath: deadDir.path)) ?? []
            guard !contents.isEmpty else { continue }

            do {
                let removed = try FileSystemUtility.removeContents(of: deadDir)
                reclaimed += removed
                cleared.append(label(for: deviceDir))
            } catch {
                errors.append("\(label(for: deviceDir)): \(error.localizedDescription)")
            }
        }

        let summary: String
        if cleared.isEmpty {
            summary = "No dead simulator caches found."
        } else {
            summary = "Cleared dead caches for \(cleared.count) simulator\(cleared.count == 1 ? "" : "s"):\n"
                + cleared.sorted().joined(separator: "\n")
        }
        return CleanupResult(bytesReclaimed: reclaimed, summary: summary, errors: errors)
    }

    /// Builds a friendly "Name (iOS 17.4)" label from the device's `device.plist`,
    /// falling back to the UUID folder name.
    private func label(for deviceDir: URL) -> String {
        let plist = deviceDir.appendingPathComponent("device.plist")
        guard let dict = NSDictionary(contentsOf: plist) else {
            return deviceDir.lastPathComponent
        }
        let name = (dict["name"] as? String) ?? deviceDir.lastPathComponent
        if let runtime = dict["runtime"] as? String {
            return "\(name) (\(SimulatorResetService.runtimeDisplayName(from: runtime)))"
        }
        return name
    }
}
