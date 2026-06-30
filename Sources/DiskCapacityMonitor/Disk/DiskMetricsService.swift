import Foundation

/// Reads capacity information for mounted volumes using `URLResourceValues`.
struct DiskMetricsService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    private static let resourceKeys: Set<URLResourceKey> = [
        .volumeNameKey,
        .volumeTotalCapacityKey,
        .volumeAvailableCapacityForImportantUsageKey,
        .volumeIsBrowsableKey,
        .volumeIsRootFileSystemKey,
    ]

    /// All user-visible mounted volumes, including the system root.
    func mountedVolumes() -> [VolumeInfo] {
        let keys = Array(Self.resourceKeys)
        guard let urls = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else {
            return []
        }

        return urls.compactMap { info(for: $0) }
            .sorted { lhs, rhs in
                // System volume first, then alphabetical by name.
                if lhs.isSystemVolume != rhs.isSystemVolume { return lhs.isSystemVolume }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    /// The system/root volume (`/`), if available.
    func systemVolume() -> VolumeInfo? {
        info(for: URL(fileURLWithPath: "/"))
    }

    /// Capacity info for the volume that contains `url`, or `nil` if it can't be read
    /// or isn't a browsable volume.
    func info(for url: URL) -> VolumeInfo? {
        guard let values = try? url.resourceValues(forKeys: Self.resourceKeys) else {
            return nil
        }

        // Skip non-browsable volumes (e.g. system snapshots, hidden helpers).
        if values.volumeIsBrowsable == false { return nil }

        guard
            let total = values.volumeTotalCapacity,
            let available = values.volumeAvailableCapacityForImportantUsage
        else {
            return nil
        }

        let isRoot = values.volumeIsRootFileSystem ?? (url.path == "/")
        let name = values.volumeName ?? url.lastPathComponent

        return VolumeInfo(
            id: url.path,
            url: url,
            name: name.isEmpty ? url.path : name,
            totalCapacity: Int64(total),
            availableCapacity: Int64(available),
            isSystemVolume: isRoot
        )
    }
}
