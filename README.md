# Disk Capacity Monitor

A small macOS menu-bar app that shows the available space on a selected drive and
offers one-click cleanup shortcuts useful on a developer machine.

## Features

- **Menu-bar readout** of free space on the selected volume, in human-readable units
  with one decimal of precision (e.g. `35.4GB`, `200.2MB`).
- **Low-space warning**: the text turns red and a ⚠︎ glyph appears when free space drops
  below a threshold (default **2%** of total).
- **Multiple volumes**: the dropdown lists every mounted volume with its free/total
  space; pick which one is shown in the menu bar. Defaults to the system disk (`/`).
  The choice is remembered between launches.
- **Periodic refresh** every 20–60s (default 30s) while awake; the timer pauses on
  system sleep and refreshes again on wake. A manual **Refresh Now** is also available.
- **Free Up Space** shortcuts:
  - **Delete Derived Data…** — clears Xcode's Derived Data (reads
    `IDECustomDerivedDataLocation`, falling back to the default path). *Confirms first.*
  - **Delete Windows Defender Logs** — clears
    `/Library/Application Support/Windows/Defender/wdavdiag/`.
  - **Prune Outdated Device Symbols** — removes superseded folders in
    `~/Library/Developer/Xcode/iOS DeviceSupport` (and tvOS/watchOS), keeping the newest
    OS version per device.
  - **Reset Simulators…** — opens a dialog listing simulators whose container exceeds a
    size threshold (default 50 MB), each with a checkbox; reset only the ones you select.
  - **Clean Dead Simulator Caches** — removes the contents of each simulator's
    `data/Library/Caches/com.apple.containermanagerd/Dead` directory (orphaned app
    containers left behind by `containermanagerd` after uninstalls); the `Dead` directory
    itself is preserved.
- **Settings** for units (decimal/binary), warning threshold, refresh interval, and the
  simulator size threshold.

## Build & run

Requires macOS 14+ and a recent Swift toolchain.

```sh
swift build   # compile
swift test    # run unit tests
swift run     # launch (appears in the menu bar; no Dock icon)
```

The app runs as an accessory (no Dock icon, no main window); quit it from the menu's
**Quit** item.

## Permissions

Some cleanup actions touch protected locations and need elevated access:

- **Windows Defender logs** live under the system `/Library` and may require **Full Disk
  Access** (System Settings → Privacy & Security → Full Disk Access) or admin rights.
  If a deletion is blocked, the app reports it instead of failing silently.
- **Reset Simulators / Derived Data / device symbols** operate on your user Library and
  generally work without extra permissions.

## Notes / not yet implemented

- Distribution/signing/notarization and launch-at-login are out of scope for this
  SwiftPM-only setup.
