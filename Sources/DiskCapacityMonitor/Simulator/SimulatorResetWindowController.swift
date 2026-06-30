import AppKit
import SwiftUI

/// Hosts the `SimulatorResetView` in a standalone window and reports the outcome.
@MainActor
final class SimulatorResetWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let viewModel = SimulatorResetViewModel()
    private let onComplete: (CleanupResult?) -> Void
    private var didComplete = false

    init(onComplete: @escaping (CleanupResult?) -> Void) {
        self.onComplete = onComplete
        super.init()
    }

    func show() {
        viewModel.onClose = { [weak self] result in
            guard let self else { return }
            self.finish(result)
            self.window?.close()
        }

        let hosting = NSHostingController(rootView: SimulatorResetView(viewModel: viewModel))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Reset Simulators"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Covers the user clicking the window's close button.
        if !didComplete { finish(nil) }
    }

    private func finish(_ result: CleanupResult?) {
        guard !didComplete else { return }
        didComplete = true
        onComplete(result)
    }
}
