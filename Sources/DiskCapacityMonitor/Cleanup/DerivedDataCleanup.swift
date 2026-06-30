import Foundation

/// Deletes the contents of Xcode's Derived Data directory.
///
/// Resolves the location from Xcode's `IDECustomDerivedDataLocation` default when set,
/// otherwise falls back to `~/Library/Developer/Xcode/DerivedData`.
struct DerivedDataCleanup: CleanupAction {
    let title = "Delete Derived Data…"
    let requiresConfirmation = true
    var confirmationMessage: String {
        "This permanently deletes everything in:\n\(Self.resolvedLocation().path)\n\nXcode will rebuild it on the next build."
    }

    func run() async -> CleanupResult {
        let location = Self.resolvedLocation()
        guard FileManager.default.fileExists(atPath: location.path) else {
            return CleanupResult(summary: "No Derived Data found at \(location.path).")
        }
        do {
            let reclaimed = try FileSystemUtility.removeContents(of: location)
            return CleanupResult(
                bytesReclaimed: reclaimed,
                summary: "Cleared Derived Data at \(location.path)."
            )
        } catch {
            return .failure("Couldn't clear Derived Data: \(error.localizedDescription)")
        }
    }

    /// Reads Xcode's configured Derived Data location, falling back to the default path.
    static func resolvedLocation() -> URL {
        let fallback = defaultLocation()
        guard
            let result = try? Shell.run("/usr/bin/defaults",
                                        ["read", "com.apple.dt.Xcode", "IDECustomDerivedDataLocation"]),
            result.succeeded
        else {
            return fallback
        }
        return sanitizedLocation(forRawValue: result.standardOutput, fallback: fallback)
    }

    /// The default Derived Data path, `~/Library/Developer/Xcode/DerivedData`.
    static func defaultLocation() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true)
    }

    /// Pure validation of a raw `IDECustomDerivedDataLocation` value. Returns `fallback`
    /// for empty/relative/`"Default"` values and refuses bare roots (`/`, `/Users`, …) as
    /// deletion targets even if the stored value is corrupt.
    static func sanitizedLocation(forRawValue rawValue: String, fallback: URL) -> URL {
        let raw = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return fallback }

        // Xcode stores an absolute path here when a custom location is set.
        let expanded = (raw as NSString).expandingTildeInPath
        guard expanded.hasPrefix("/") else { return fallback }

        let standardized = URL(fileURLWithPath: expanded).standardizedFileURL
        guard standardized.path != "/", standardized.pathComponents.count >= 3 else {
            return fallback
        }
        return URL(fileURLWithPath: standardized.path, isDirectory: true)
    }
}
