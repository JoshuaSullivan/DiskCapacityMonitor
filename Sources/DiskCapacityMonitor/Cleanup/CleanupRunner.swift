import AppKit

/// Runs a `CleanupAction` off the main thread, handling optional confirmation and
/// presenting a result alert. UI work stays on the main actor.
@MainActor
enum CleanupRunner {
    static func run(_ action: CleanupAction, onFinished: (() -> Void)? = nil) {
        if action.requiresConfirmation {
            let alert = NSAlert()
            alert.messageText = cleanTitle(action.title)
            alert.informativeText = action.confirmationMessage
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Delete")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate(ignoringOtherApps: true)
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        let title = action.title
        Task.detached(priority: .userInitiated) {
            let result = await action.run()
            await MainActor.run {
                presentResult(result, title: title)
                onFinished?()
            }
        }
    }

    private static func presentResult(_ result: CleanupResult, title: String) {
        let alert = NSAlert()
        alert.messageText = cleanTitle(title)

        var lines: [String] = []
        if !result.summary.isEmpty { lines.append(result.summary) }
        if result.bytesReclaimed > 0 {
            lines.append("Reclaimed \(ByteSizeFormatter.string(fromBytes: result.bytesReclaimed, binary: UserSettings.shared.useBinaryUnits)).")
        }
        if !result.errors.isEmpty {
            lines.append("")
            lines.append(contentsOf: result.errors)
        }
        alert.informativeText = lines.joined(separator: "\n")
        alert.alertStyle = result.errors.isEmpty ? .informational : .warning
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private static func cleanTitle(_ title: String) -> String {
        title.replacingOccurrences(of: "…", with: "")
    }
}
