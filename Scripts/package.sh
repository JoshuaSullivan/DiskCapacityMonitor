#!/usr/bin/env bash
#
# package.sh — Build, bundle, code-sign, and install Disk Capacity Monitor as a
# proper macOS .app so it can run at login.
#
# It produces a signed `DiskCapacityMonitor.app` (an LSUIElement menu-bar app) and,
# by default, installs it to /Applications. Launch-at-login is then toggled from the
# app's own Settings window (Settings → Startup → "Launch at login").
#
# Signing identity:
#   The script auto-detects your first "Apple Development" code-signing identity, so
#   anyone who clones the repo can build with their own certificate. Override it with
#   the CODESIGN_IDENTITY environment variable or --identity, or pass --adhoc to sign
#   locally without a certificate (note: SMAppService login items are unreliable when
#   ad-hoc signed).
#
# Usage:
#   ./Scripts/package.sh                       # build, sign, install to /Applications
#   ./Scripts/package.sh --no-install          # build + sign into ./dist only
#   ./Scripts/package.sh --identity "Apple Development: Jane (TEAMID)"
#   CODESIGN_IDENTITY="..." ./Scripts/package.sh
#   ./Scripts/package.sh --adhoc               # ad-hoc signature, no certificate
#   ./Scripts/package.sh --help

set -euo pipefail

# ── Configurable metadata (override via environment) ──────────────────────────

EXECUTABLE_NAME="DiskCapacityMonitor"
APP_NAME="${APP_NAME:-DiskCapacityMonitor}"          # .app bundle base name
DISPLAY_NAME="${DISPLAY_NAME:-Disk Capacity Monitor}"
BUNDLE_ID="${BUNDLE_ID:-com.diskcapacitymonitor.DiskCapacityMonitor}"
SHORT_VERSION="${SHORT_VERSION:-1.0}"
BUILD_VERSION="${BUILD_VERSION:-1}"
MIN_MACOS="${MIN_MACOS:-14.0}"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"

# ── Paths ─────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"

# ── Options ───────────────────────────────────────────────────────────────────

INSTALL=true
IDENTITY="${CODESIGN_IDENTITY:-}"
ADHOC=false

usage() {
    sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-install) INSTALL=false ;;
        --identity)   IDENTITY="${2:?--identity requires a value}"; shift ;;
        --adhoc)      ADHOC=true ;;
        --help|-h)    usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
    esac
    shift
done

log() { printf '\033[1m▸ %s\033[0m\n' "$*"; }

# ── Resolve signing identity ──────────────────────────────────────────────────

if $ADHOC; then
    IDENTITY="-"
elif [[ -z "$IDENTITY" ]]; then
    IDENTITY="$(security find-identity -v -p codesigning \
        | awk -F'"' '/Apple Development/ { print $2; exit }')"
    if [[ -z "$IDENTITY" ]]; then
        echo "warning: no 'Apple Development' identity found — falling back to ad-hoc signing." >&2
        echo "         Login-at-launch via SMAppService may not work reliably when ad-hoc signed." >&2
        IDENTITY="-"
    fi
fi
log "Signing identity: ${IDENTITY}"

# ── Build (release) ───────────────────────────────────────────────────────────

log "Building release binary…"
swift build -c release --package-path "$ROOT_DIR"
BIN_PATH="$(swift build -c release --package-path "$ROOT_DIR" --show-bin-path)/${EXECUTABLE_NAME}"
[[ -f "$BIN_PATH" ]] || { echo "error: built binary not found at $BIN_PATH" >&2; exit 1; }

# ── Assemble the .app bundle ─────────────────────────────────────────────────

log "Assembling ${APP_NAME}.app…"
rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"

cp "$BIN_PATH" "${APP_BUNDLE}/Contents/MacOS/${EXECUTABLE_NAME}"

cat > "${APP_BUNDLE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>            <string>${EXECUTABLE_NAME}</string>
    <key>CFBundleIdentifier</key>            <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>                  <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>           <string>${DISPLAY_NAME}</string>
    <key>CFBundlePackageType</key>           <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key> <string>6.0</string>
    <key>CFBundleShortVersionString</key>    <string>${SHORT_VERSION}</string>
    <key>CFBundleVersion</key>               <string>${BUILD_VERSION}</string>
    <key>LSMinimumSystemVersion</key>        <string>${MIN_MACOS}</string>
    <key>LSUIElement</key>                   <true/>
    <key>NSHighResolutionCapable</key>       <true/>
    <key>NSPrincipalClass</key>              <string>NSApplication</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "${APP_BUNDLE}/Contents/PkgInfo"

# ── Code sign ─────────────────────────────────────────────────────────────────

log "Code signing…"
codesign --force --options runtime --timestamp=none \
    --sign "$IDENTITY" "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
log "Signed. Bundle: ${APP_BUNDLE}"

# ── Install ───────────────────────────────────────────────────────────────────

if $INSTALL; then
    DEST="${INSTALL_DIR}/${APP_NAME}.app"
    log "Installing to ${DEST}…"
    if [[ -w "$INSTALL_DIR" || -w "$DEST" ]]; then
        rm -rf "$DEST"
        cp -R "$APP_BUNDLE" "$DEST"
    else
        echo "  ${INSTALL_DIR} is not writable; using sudo (you may be prompted)…"
        sudo rm -rf "$DEST"
        sudo cp -R "$APP_BUNDLE" "$DEST"
    fi
    log "Installed: ${DEST}"
    echo
    echo "Next steps:"
    echo "  1. Open ${DISPLAY_NAME} from ${INSTALL_DIR} (or: open \"$DEST\")."
    echo "  2. In its menu, choose Settings… → Startup → enable \"Launch at login\"."
    echo "  3. Grant Full Disk Access if you plan to clear Windows Defender logs."
else
    log "Skipping install (--no-install). Built bundle is at: ${APP_BUNDLE}"
fi
