import AppKit

/// Owns the menu-bar status item: renders the selected volume's free space (red with a
/// warning glyph when low), builds the dropdown menu, and drives periodic refreshes.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let metrics = DiskMetricsService()
    private let settings = UserSettings.shared

    private var volumes: [VolumeInfo] = []
    private var timer: Timer?
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    private var simResetController: SimulatorResetWindowController?
    private var settingsController: SettingsWindowController?

    // MARK: Lifecycle

    func start() {
        registerSleepWakeObservers()
        refresh()
        startTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        let nc = NSWorkspace.shared.notificationCenter
        if let sleepObserver { nc.removeObserver(sleepObserver) }
        if let wakeObserver { nc.removeObserver(wakeObserver) }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: settings.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func registerSleepWakeObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        sleepObserver = nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.timer?.invalidate()
                self?.timer = nil
            }
        }
        wakeObserver = nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
                self?.startTimer()
            }
        }
    }

    // MARK: Refresh

    func refresh() {
        volumes = metrics.mountedVolumes()
        let selected = currentSelectedVolume()
        updateButton(for: selected)
        rebuildMenu(selected: selected)
    }

    private var selectedVolumeID: String {
        settings.selectedVolumePath ?? "/"
    }

    private func currentSelectedVolume() -> VolumeInfo? {
        volumes.first { $0.id == selectedVolumeID }
            ?? volumes.first { $0.isSystemVolume }
            ?? volumes.first
    }

    private func updateButton(for volume: VolumeInfo?) {
        guard let button = statusItem.button else { return }

        guard let volume else {
            button.attributedTitle = NSAttributedString(string: "—")
            button.image = nil
            button.contentTintColor = nil
            button.toolTip = "No volume available"
            return
        }

        let free = ByteSizeFormatter.string(fromBytes: volume.availableCapacity, binary: settings.useBinaryUnits)
        let isLow = volume.fractionFree < settings.lowSpaceThresholdFraction
        let color: NSColor = isLow ? .systemRed : .labelColor

        button.attributedTitle = NSAttributedString(string: free, attributes: [
            .foregroundColor: color,
            .font: NSFont.menuBarFont(ofSize: 0),
        ])

        if isLow {
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill",
                                   accessibilityDescription: "Low disk space")
            button.imagePosition = .imageLeading
            button.contentTintColor = .systemRed
        } else {
            button.image = nil
            button.contentTintColor = nil
        }

        let total = ByteSizeFormatter.string(fromBytes: volume.totalCapacity, binary: settings.useBinaryUnits)
        button.toolTip = "\(volume.name): \(free) free of \(total)"
    }

    // MARK: Menu

    private func rebuildMenu(selected: VolumeInfo?) {
        let menu = NSMenu()

        if volumes.isEmpty {
            let item = NSMenuItem(title: "No volumes found", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for volume in volumes {
                let free = ByteSizeFormatter.string(fromBytes: volume.availableCapacity, binary: settings.useBinaryUnits)
                let total = ByteSizeFormatter.string(fromBytes: volume.totalCapacity, binary: settings.useBinaryUnits)
                let item = NSMenuItem(title: "\(volume.name) — \(free) free of \(total)",
                                      action: #selector(selectVolume(_:)),
                                      keyEquivalent: "")
                item.target = self
                item.representedObject = volume.id
                item.state = (volume.id == selected?.id) ? .on : .off
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        menu.addItem(makeCleanupMenuItem())
        menu.addItem(.separator())

        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Disk Capacity Monitor", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func makeCleanupMenuItem() -> NSMenuItem {
        let parent = NSMenuItem(title: "Free Up Space", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        let derived = NSMenuItem(title: "Delete Derived Data…", action: #selector(runDerivedData), keyEquivalent: "")
        derived.target = self
        submenu.addItem(derived)

        let defender = NSMenuItem(title: "Delete Windows Defender Logs", action: #selector(runDefenderLogs), keyEquivalent: "")
        defender.target = self
        submenu.addItem(defender)

        let symbols = NSMenuItem(title: "Prune Outdated Device Symbols", action: #selector(runDeviceSymbols), keyEquivalent: "")
        symbols.target = self
        submenu.addItem(symbols)

        let deadCaches = NSMenuItem(title: "Clean Dead Simulator Caches", action: #selector(runDeadSimCaches), keyEquivalent: "")
        deadCaches.target = self
        submenu.addItem(deadCaches)

        let resetSims = NSMenuItem(title: "Reset Simulators…", action: #selector(resetSimulators), keyEquivalent: "")
        resetSims.target = self
        submenu.addItem(resetSims)

        parent.submenu = submenu
        return parent
    }

    // MARK: Actions

    @objc private func selectVolume(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        settings.selectedVolumePath = id
        refresh()
    }

    @objc private func refreshNow() {
        refresh()
    }

    @objc private func runDerivedData() {
        CleanupRunner.run(DerivedDataCleanup()) { [weak self] in self?.refresh() }
    }

    @objc private func runDefenderLogs() {
        CleanupRunner.run(DefenderLogsCleanup()) { [weak self] in self?.refresh() }
    }

    @objc private func runDeviceSymbols() {
        CleanupRunner.run(DeviceSupportCleanup()) { [weak self] in self?.refresh() }
    }

    @objc private func runDeadSimCaches() {
        CleanupRunner.run(DeadSimulatorCachesCleanup()) { [weak self] in self?.refresh() }
    }

    @objc private func resetSimulators() {
        guard simResetController == nil else { return }
        let controller = SimulatorResetWindowController { [weak self] result in
            guard let self else { return }
            self.simResetController = nil
            if let result {
                self.presentSimulatorResult(result)
                self.refresh()
            }
        }
        simResetController = controller
        controller.show()
    }

    private func presentSimulatorResult(_ result: CleanupResult) {
        let alert = NSAlert()
        alert.messageText = "Reset Simulators"
        var lines: [String] = []
        if !result.summary.isEmpty { lines.append(result.summary) }
        if result.bytesReclaimed > 0 {
            lines.append("Reclaimed \(ByteSizeFormatter.string(fromBytes: result.bytesReclaimed, binary: settings.useBinaryUnits)).")
        }
        if !result.errors.isEmpty {
            lines.append("")
            lines.append(contentsOf: result.errors)
        }
        guard !lines.isEmpty else { return }
        alert.informativeText = lines.joined(separator: "\n")
        alert.alertStyle = result.errors.isEmpty ? .informational : .warning
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func showSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController { [weak self] in
                self?.settingsController = nil
            }
        }
        settingsController?.onSettingsChanged = { [weak self] in
            guard let self else { return }
            self.startTimer()
            self.refresh()
        }
        settingsController?.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
