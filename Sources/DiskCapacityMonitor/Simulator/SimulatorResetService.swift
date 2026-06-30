import Foundation

/// A simulator device with its on-disk container size.
struct SimulatorDevice: Identifiable, Hashable {
    let id: String          // UDID
    let name: String
    let runtimeName: String
    let state: String
    let containerURL: URL
    var sizeBytes: Int64
}

/// Lists Simulator devices and resets (erases) selected ones via `xcrun simctl`.
struct SimulatorResetService {
    private let xcrun = "/usr/bin/xcrun"

    private static let devicesRoot = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Developer/CoreSimulator/Devices", isDirectory: true)

    // MARK: simctl JSON

    private struct DeviceList: Decodable {
        let devices: [String: [Device]]
    }

    private struct Device: Decodable {
        let udid: String
        let name: String
        let state: String
        let isAvailable: Bool?
        let dataPath: String?
    }

    /// Lists available devices with their container size already computed.
    /// - Throws: If `simctl` can't be launched or its output can't be parsed.
    func listDevicesWithSizes() throws -> [SimulatorDevice] {
        let result = try Shell.run(xcrun, ["simctl", "list", "devices", "--json"])
        guard result.succeeded, let data = result.standardOutput.data(using: .utf8) else {
            throw SimulatorError.commandFailed(result.standardError)
        }

        let decoded = try JSONDecoder().decode(DeviceList.self, from: data)
        var devices: [SimulatorDevice] = []

        for (runtimeKey, entries) in decoded.devices {
            let runtimeName = Self.runtimeDisplayName(from: runtimeKey)
            for entry in entries where entry.isAvailable != false {
                let container = Self.container(for: entry)
                let size = FileSystemUtility.directorySize(at: container)
                devices.append(
                    SimulatorDevice(
                        id: entry.udid,
                        name: entry.name,
                        runtimeName: runtimeName,
                        state: entry.state,
                        containerURL: container,
                        sizeBytes: size
                    )
                )
            }
        }
        return devices.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    /// Shuts down (if booted) and erases the given device.
    func reset(_ device: SimulatorDevice) -> CleanupResult {
        if device.state.caseInsensitiveCompare("Booted") == .orderedSame {
            _ = try? Shell.run(xcrun, ["simctl", "shutdown", device.id])
        }
        do {
            let result = try Shell.run(xcrun, ["simctl", "erase", device.id])
            guard result.succeeded else {
                return .failure("\(device.name): \(result.standardError.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            return CleanupResult(bytesReclaimed: device.sizeBytes,
                                 summary: "Reset \(device.name).")
        } catch {
            return .failure("\(device.name): \(error.localizedDescription)")
        }
    }

    // MARK: Helpers

    private static func container(for entry: Device) -> URL {
        // Prefer simctl's reported dataPath parent; fall back to the standard location.
        if let dataPath = entry.dataPath {
            return URL(fileURLWithPath: dataPath).deletingLastPathComponent()
        }
        return devicesRoot.appendingPathComponent(entry.udid, isDirectory: true)
    }

    /// Converts `com.apple.CoreSimulator.SimRuntime.iOS-17-4` into `iOS 17.4`.
    static func runtimeDisplayName(from key: String) -> String {
        guard let last = key.split(separator: ".").last else { return key }
        let parts = last.split(separator: "-")
        guard let platform = parts.first else { return String(last) }
        let version = parts.dropFirst().joined(separator: ".")
        return version.isEmpty ? String(platform) : "\(platform) \(version)"
    }

    enum SimulatorError: LocalizedError {
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .commandFailed(let message):
                let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? "simctl failed." : trimmed
            }
        }
    }
}
