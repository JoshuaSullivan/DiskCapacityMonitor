import AppKit
import SwiftUI

/// Hosts the Settings view in a reusable window.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let viewModel = SettingsViewModel()
    private let onClosed: () -> Void

    /// Forwarded from the view model so the app can re-apply changed settings.
    var onSettingsChanged: (() -> Void)? {
        get { viewModel.onChange }
        set { viewModel.onChange = newValue }
    }

    init(onClosed: @escaping () -> Void) {
        self.onClosed = onClosed
        super.init()
    }

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: SettingsView(viewModel: viewModel))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        onClosed()
    }
}
