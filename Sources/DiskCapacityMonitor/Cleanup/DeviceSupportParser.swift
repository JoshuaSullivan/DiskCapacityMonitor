import Foundation

/// One parsed entry from an Xcode DeviceSupport directory.
struct DeviceSupportEntry: Equatable {
    /// The original folder name, used as the deletion key.
    let folderName: String
    /// Device model when the folder name includes one (e.g. `iPhone14,2`), else `nil`.
    let deviceModel: String?
    /// OS version components (e.g. `[16, 4, 1]`).
    let version: [Int]
    /// Build string inside parentheses, when present (e.g. `20E247`).
    let build: String?
}

/// Parses DeviceSupport folder names and decides which are superseded.
///
/// Folder names look like `16.4 (20E247)`, `16.4.1 (20E772a)`, or, on newer Xcode,
/// `iPhone14,2 16.4 (20E247)`. Entries are grouped by device model (or a single
/// generic group when no model is present); within each group only the newest OS
/// version is kept and the rest are reported as deletable.
enum DeviceSupportParser {
    private static let modelRegex = try! NSRegularExpression(
        pattern: "^([A-Za-z]+[0-9]+,[0-9]+)\\b"
    )
    private static let versionRegex = try! NSRegularExpression(
        pattern: "([0-9]+(?:\\.[0-9]+){1,3})"
    )
    private static let buildRegex = try! NSRegularExpression(
        pattern: "\\(([^)]+)\\)"
    )

    /// Parses a single folder name, or returns `nil` if no version can be found.
    static func parse(_ folderName: String) -> DeviceSupportEntry? {
        let range = NSRange(folderName.startIndex..., in: folderName)

        var deviceModel: String?
        if let match = modelRegex.firstMatch(in: folderName, range: range),
           let r = Range(match.range(at: 1), in: folderName) {
            deviceModel = String(folderName[r])
        }

        guard
            let versionMatch = versionRegex.firstMatch(in: folderName, range: range),
            let versionRange = Range(versionMatch.range(at: 1), in: folderName)
        else {
            return nil
        }
        let version = folderName[versionRange].split(separator: ".").compactMap { Int($0) }
        guard !version.isEmpty else { return nil }

        var build: String?
        if let match = buildRegex.firstMatch(in: folderName, range: range),
           let r = Range(match.range(at: 1), in: folderName) {
            build = String(folderName[r])
        }

        return DeviceSupportEntry(
            folderName: folderName,
            deviceModel: deviceModel,
            version: version,
            build: build
        )
    }

    /// Returns the folder names that are superseded by a newer OS version within the
    /// same device group. Unparseable names are never returned (left untouched).
    static func supersededFolders(in folderNames: [String]) -> [String] {
        let entries = folderNames.compactMap(parse)
        let groups = Dictionary(grouping: entries) { $0.deviceModel ?? "" }

        var toDelete: [String] = []
        for (_, groupEntries) in groups {
            guard groupEntries.count > 1 else { continue }
            // The newest entry is the max by version (then build) — keep it.
            guard let newest = groupEntries.max(by: { isOlder($0, than: $1) }) else { continue }
            for entry in groupEntries where entry.folderName != newest.folderName {
                toDelete.append(entry.folderName)
            }
        }
        return toDelete
    }

    /// Orders two entries: `lhs` is "older" (less) than `rhs` by version, then build.
    static func isOlder(_ lhs: DeviceSupportEntry, than rhs: DeviceSupportEntry) -> Bool {
        if lhs.version != rhs.version {
            return compareVersions(lhs.version, rhs.version) == .orderedAscending
        }
        // Same version: fall back to lexical build comparison as a best effort.
        return (lhs.build ?? "").compare(rhs.build ?? "", options: .numeric) == .orderedAscending
    }

    private static func compareVersions(_ lhs: [Int], _ rhs: [Int]) -> ComparisonResult {
        let count = max(lhs.count, rhs.count)
        for i in 0..<count {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l < r ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }
}
