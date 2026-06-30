import AppKit

// Entry point. This is a menu-bar ("accessory") app: no Dock icon, no main window.
@main
enum DiskCapacityMonitor {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
