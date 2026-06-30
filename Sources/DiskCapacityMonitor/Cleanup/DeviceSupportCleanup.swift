import Foundation

/// Removes outdated Xcode DeviceSupport symbol folders — those superseded by a newer
/// OS version for the same device. Covers iOS, tvOS, and watchOS DeviceSupport dirs.
struct DeviceSupportCleanup: CleanupAction {
    let title = "Prune Outdated Device Symbols"

    private static let relativePaths = [
        "Library/Developer/Xcode/iOS DeviceSupport",
        "Library/Developer/Xcode/tvOS DeviceSupport",
        "Library/Developer/Xcode/watchOS DeviceSupport",
    ]

    func run() async -> CleanupResult {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        var reclaimed: Int64 = 0
        var removedNames: [String] = []
        var errors: [String] = []

        for relative in Self.relativePaths {
            let dir = home.appendingPathComponent(relative, isDirectory: true)
            guard fm.fileExists(atPath: dir.path) else { continue }

            let names = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
            let superseded = DeviceSupportParser.supersededFolders(in: names)

            for name in superseded {
                let target = dir.appendingPathComponent(name, isDirectory: true)
                let size = FileSystemUtility.directorySize(at: target)
                do {
                    try fm.removeItem(at: target)
                    reclaimed += size
                    removedNames.append(name)
                } catch {
                    errors.append("Couldn't remove \(name): \(error.localizedDescription)")
                }
            }
        }

        let summary: String
        if removedNames.isEmpty {
            summary = "No outdated device symbols found."
        } else {
            summary = "Removed \(removedNames.count) outdated symbol folder(s):\n"
                + removedNames.sorted().joined(separator: "\n")
        }
        return CleanupResult(bytesReclaimed: reclaimed, summary: summary, errors: errors)
    }
}
