import AppKit

/// Owns the application's top-level objects. The app has no main window and no Dock
/// icon; everything lives in the status (menu) bar.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = StatusItemController()
        controller.start()
        statusController = controller
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusController?.stop()
    }
}
