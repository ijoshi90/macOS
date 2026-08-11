#!/usr/bin/env bash
# build_app.sh — builds Packages Installer.app and places it in ./dist/
# Usage:  bash build_app.sh          (debug)
#         bash build_app.sh release  (optimised)

set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-debug}"
BINARY_NAME="PackagesInstaller"
APP_NAME="Packages Installer"
APP_BUNDLE="dist/${APP_NAME}.app"

printf '\n\033[1m▶  Building %s (%s)…\033[0m\n\n' "$APP_NAME" "$CONFIG"

# ── 1. Swift build ────────────────────────────────────────
if [[ "$CONFIG" == "release" ]]; then
    swift build -c release
    BINARY=".build/release/$BINARY_NAME"
else
    swift build
    BINARY=".build/debug/$BINARY_NAME"
fi

# ── 2. Assemble .app skeleton ─────────────────────────────
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$RESOURCES"

# Binary
cp "$BINARY" "$MACOS/$BINARY_NAME"

# Info.plist
cp Sources/PackagesInstaller/Resources/Info.plist "$CONTENTS/Info.plist"

# Bundled resources (packages.json + install_core.sh)
cp packages.json               "$RESOURCES/packages.json"
cp scripts/install_core.sh     "$RESOURCES/install_core.sh"
chmod +x "$RESOURCES/install_core.sh"

# SPM resource bundle if present
BUNDLE_DIR=".build/${CONFIG}/PackagesInstaller_PackagesInstaller.bundle"
if [[ -d "$BUNDLE_DIR" ]]; then
    cp -R "$BUNDLE_DIR" "$RESOURCES/"
fi

# ── 3. App icon ───────────────────────────────────────────
ICON_SRC="Sources/PackagesInstaller/Resources/AppIcon.png"
if [[ -f "$ICON_SRC" ]]; then
    ICONSET="$RESOURCES/AppIcon.iconset"
    mkdir -p "$ICONSET"
    for size in 16 32 64 128 256 512 1024; do
        sips -z "$size" "$size" "$ICON_SRC" \
             --out "$ICONSET/icon_${size}x${size}.png"   &>/dev/null
        if [[ $size -le 512 ]]; then
            sips -z $(( size * 2 )) $(( size * 2 )) "$ICON_SRC" \
                 --out "$ICONSET/icon_${size}x${size}@2x.png" &>/dev/null
        fi
    done
    iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns" 2>/dev/null \
        && rm -rf "$ICONSET" \
        || printf '  [warn] iconutil failed — app will use default icon\n'
fi

# ── 4. Code-sign (ad-hoc, no Developer ID required) ──────
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null \
    && printf '  [ok]   Ad-hoc signed.\n' \
    || printf '  [warn] codesign failed — app may show a security warning on first launch.\n'

# ── 5. Done ───────────────────────────────────────────────
printf '\n\033[1;32m✓  Built: %s\033[0m\n' "$(pwd)/$APP_BUNDLE"
printf '   Double-click or: open "%s"\n\n' "$APP_BUNDLE"

if [[ "${2:-}" != "--no-open" ]]; then
    open "$APP_BUNDLE"
fi
