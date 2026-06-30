import Foundation
import ServiceManagement

/// Wraps `SMAppService.mainApp` to manage the "launch at login" login item.
///
/// This only works when the app runs from a properly built, code-signed `.app` bundle
/// (see `Scripts/package.sh`). When run as a bare SwiftPM binary (`swift run`), there is
/// no bundle and registration will fail — the toggle reports the error rather than
/// silently no-op'ing.
enum LoginItemManager {
    /// Whether the app is currently registered to launch at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// The raw service status, useful for messaging (e.g. `.requiresApproval`).
    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    /// Registers or unregisters the app as a login item.
    /// - Throws: An error if the (un)registration can't be performed — e.g. when not
    ///   running from a signed bundle, or when the user must approve it in Settings.
    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            guard service.status != .enabled else { return }
            try service.register()
        } else {
            guard service.status == .enabled else { return }
            try service.unregister()
        }
    }
}
