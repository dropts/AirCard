#!/usr/bin/env bash
set -e

# Resolve the script's own directory. ${BASH_SOURCE[0]} is empty when the script
# is started with `sh build.sh` (/bin/sh), so fall back to $0 -- otherwise the
# relative paths below (tools/create-dmg, dmg_assets) silently break.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
cd "$SCRIPT_DIR"

# `sh build.sh` runs this under /bin/sh, where bash-only features above degrade
# (BASH_SOURCE is empty). Re-exec with bash so the rest of the script behaves
# identically no matter how it was invoked.
if [ -z "$BASH_VERSION" ]; then
    echo "NOTE: invoked as \`sh $0\`; re-executing with bash. Use \`./build.sh\` or \`bash build.sh\`."
    exec bash "$0" "$@"
fi

echo "==> [1/6] Building universal helper binaries (device_helper & airtraffic_host)..."
make clean
make all

APP_NAME="AirCard"
# Lowest macOS version the build supports. Kept at 13.0 so the app runs on
# macOS 13 (Ventura) and newer. The Swift sources must not use any API that is
# gated behind macOS 14 or later.
MACOS_MIN_VERSION="${MACOS_MIN_VERSION:-13.0}"
APP_DIR="build/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
BIN_DIR="${RESOURCES_DIR}/bin"
LIB_DIR="${RESOURCES_DIR}/lib"

echo "==> [2/6] Scaffolding ${APP_NAME}.app bundle structure..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$BIN_DIR" "$LIB_DIR"

# Write Info.plist
# Unquoted heredoc on purpose: ${MACOS_MIN_VERSION} must be expanded here.
cat << EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>AirCard</string>
    <key>CFBundleIdentifier</key>
    <string>com.mak5er.aircard</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>AirCard</string>
    <key>CFBundleDisplayName</key>
    <string>AirCard</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.4</string>
    <key>CFBundleVersion</key>
    <string>8</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MACOS_MIN_VERSION}</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "==> [3/6] Bundling universal tools & libraries..."
# Copy App Icon
if [ -f "dmg_assets/AppIcon.icns" ]; then
    cp "dmg_assets/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

# Copy universal device_helper and airtraffic_host. Device discovery and log
# streaming both run through device_helper, which talks to MobileDevice.framework
# directly, so the bundle needs no libimobiledevice tooling.
cp build/device_helper "$BIN_DIR/"
cp build/airtraffic_host "$BIN_DIR/"

# Copy python backend scripts
cp apply_card_skin.py "$RESOURCES_DIR/"
cp aircard.py "$RESOURCES_DIR/"
cp aircard_backend.py "$RESOURCES_DIR/"
cp card_assets.py "$RESOURCES_DIR/"

# A bundle without these cannot talk to a device at all, so fail here instead
# of shipping an app that reports "No iPhone found" for every user.
for tool in device_helper airtraffic_host; do
    if [ ! -x "${BIN_DIR}/${tool}" ]; then
        echo "ERROR: ${BIN_DIR}/${tool} is missing from the bundle." >&2
        exit 1
    fi
done

echo "==> [4/6] Compiling universal Swift binary (arm64 + x86_64)..."
# swiftc does not flag duplicated keys in a dictionary literal, but the app then
# traps on launch when the table is built, so fail the build instead.
LOCALIZATION_DUPES=$(grep -oE '^[[:space:]]*"([^"\\]|\\.)*"[[:space:]]*:' Localization.swift \
    | sed -E 's/^[[:space:]]*//; s/[[:space:]]*:$//' | sort | uniq -d)
if [ -n "$LOCALIZATION_DUPES" ]; then
    echo "ERROR: duplicate key(s) in Localization.swift:" >&2
    echo "$LOCALIZATION_DUPES" >&2
    exit 1
fi
if [ -z "${SWIFT_SDK:-}" ]; then
    SWIFT_SDK="$(xcrun --sdk macosx --show-sdk-path)"
    CLT_SWIFTUI_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
    if [ "$(xcode-select -p)" = "/Library/Developer/CommandLineTools" ] && [ -d "$CLT_SWIFTUI_SDK" ]; then
        SWIFT_SDK="$CLT_SWIFTUI_SDK"
    fi
fi
echo "    target: macOS ${MACOS_MIN_VERSION} (arm64 + x86_64)"
SWIFT_SOURCES=(AirCardApp.swift Localization.swift)
swiftc -sdk "$SWIFT_SDK" -O -parse-as-library -target arm64-apple-macosx${MACOS_MIN_VERSION} "${SWIFT_SOURCES[@]}" -o build/AirCard_arm64
swiftc -sdk "$SWIFT_SDK" -O -parse-as-library -target x86_64-apple-macosx${MACOS_MIN_VERSION} "${SWIFT_SOURCES[@]}" -o build/AirCard_x86_64
lipo -create -output "${MACOS_DIR}/AirCard" build/AirCard_arm64 build/AirCard_x86_64
chmod +x "${MACOS_DIR}/AirCard"

echo "==> [5/6] Setting permissions and signing ${APP_NAME}.app bundle..."
chmod -R 755 "$APP_DIR"
xattr -cr "$APP_DIR" 2>/dev/null || true
codesign --force --deep --sign - "$APP_DIR"

echo "==> [6/6] Generating styled DMG (${APP_NAME}.dmg)..."
DMG_STAGING="/tmp/aircard_dmg_staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING/.background"
cp -R "$APP_DIR" "$DMG_STAGING/"
cp "dmg_assets/background_700.png" "$DMG_STAGING/.background/"
cp "dmg_assets/README.txt" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

rm -f "build/${APP_NAME}.dmg"

# The window layout is written straight into .DS_Store by
# tools/make_dmg_window.py. It is deliberately NOT driven through Finder with
# AppleScript (what create-dmg does): that needs the "Automation" permission and
# dies with -1743 "Not authorized to send Apple events to Finder" on any machine
# that never granted it -- right after the artwork has already been copied, so
# the build aborts with no DMG at all. Writing .DS_Store needs no permission.
#
# Geometry lives in make_dmg_window.py: the window is 28 pt taller than the
# background artwork because the title bar sits inside those bounds (700x488
# => a 700x460 content area, exactly what background_700.png is drawn for).
# README.txt stays at y=332; any lower and its cell overruns the content area,
# which brings back a phantom scrollbar.
MOUNT_POINT="/Volumes/${APP_NAME}"
if [ -d "$MOUNT_POINT" ]; then
    hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true
    sleep 1
fi

PYTHON_BIN="${PYTHON_BIN:-}"
if [ -z "$PYTHON_BIN" ]; then
    for candidate in python3 /usr/bin/python3; do
        if command -v "$candidate" >/dev/null 2>&1 && \
           "$candidate" -c 'import sys; sys.path.insert(0, "tools/pylib"); import ds_store, mac_alias' >/dev/null 2>&1; then
            PYTHON_BIN="$candidate"
            break
        fi
    done
fi
if [ -z "$PYTHON_BIN" ]; then
    echo "ERROR: no python3 able to import the vendored ds_store/mac_alias in tools/pylib." >&2
    exit 1
fi
echo "    python: $PYTHON_BIN"

RW_IMAGE="build/${APP_NAME}_rw.dmg"
rm -f "$RW_IMAGE"
hdiutil create -volname "${APP_NAME}" -srcfolder "$DMG_STAGING" -format UDRW -ov -o "$RW_IMAGE" >/dev/null
# Mounting at a fixed path keeps us from having to parse `hdiutil` output to
# discover where the image landed -- that parsing is exactly what used to break.
hdiutil attach -mountpoint "$MOUNT_POINT" -readwrite -nobrowse -noverify "$RW_IMAGE" >/dev/null

"$PYTHON_BIN" tools/make_dmg_window.py "$MOUNT_POINT"
chflags hidden "$MOUNT_POINT/.background"
SetFile -a E "$MOUNT_POINT/${APP_NAME}.app" 2>/dev/null || true
sync
sleep 1

hdiutil detach "$MOUNT_POINT" >/dev/null
hdiutil convert "$RW_IMAGE" -format UDZO -ov -o "build/${APP_NAME}.dmg" | tail -3
rm -f "$RW_IMAGE"

echo "============================================================"
echo "🎉 SUCCESS: build/${APP_NAME}.dmg is ready!"
echo "============================================================"
