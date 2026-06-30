import Foundation

/// Outcome of running a `CleanupAction`.
struct CleanupResult {
    var bytesReclaimed: Int64
    var summary: String
    var errors: [String]

    init(bytesReclaimed: Int64 = 0, summary: String = "", errors: [String] = []) {
        self.bytesReclaimed = bytesReclaimed
        self.summary = summary
        self.errors = errors
    }

    static func failure(_ message: String) -> CleanupResult {
        CleanupResult(bytesReclaimed: 0, summary: "", errors: [message])
    }
}

/// A reclaim-disk-space operation surfaced in the "Free Up Space" menu.
protocol CleanupAction: Sendable {
    /// Menu title for the action.
    var title: String { get }

    /// When `true`, the runner shows a confirmation alert before executing.
    var requiresConfirmation: Bool { get }

    /// Body shown in the confirmation alert (only used when `requiresConfirmation`).
    var confirmationMessage: String { get }

    /// Performs the cleanup. Implementations do file I/O and must not touch the UI.
    func run() async -> CleanupResult
}

extension CleanupAction {
    var requiresConfirmation: Bool { false }
    var confirmationMessage: String { "" }
}
