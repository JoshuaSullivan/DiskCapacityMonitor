import Foundation

/// Deletes Windows Defender diagnostic logs from the shared system support directory.
///
/// The path lives under the system `/Library`, so deletion may require Full Disk Access
/// or admin rights; permission failures are reported rather than thrown to the user.
struct DefenderLogsCleanup: CleanupAction {
    let title = "Delete Windows Defender Logs"

    static let directory = URL(
        fileURLWithPath: "/Library/Application Support/Windows/Defender/wdavdiag",
        isDirectory: true
    )

    func run() async -> CleanupResult {
        let directory = Self.directory
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return CleanupResult(summary: "No Defender diagnostic logs found.")
        }
        do {
            let reclaimed = try FileSystemUtility.removeContents(of: directory)
            return CleanupResult(
                bytesReclaimed: reclaimed,
                summary: "Cleared Windows Defender diagnostic logs."
            )
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain,
               nsError.code == NSFileWriteNoPermissionError || nsError.code == NSFileReadNoPermissionError {
                return .failure("Permission denied. Grant this app Full Disk Access (or run as admin) to clear:\n\(directory.path)")
            }
            return .failure("Couldn't clear Defender logs: \(error.localizedDescription)")
        }
    }
}
