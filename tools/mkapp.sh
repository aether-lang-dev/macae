#!/usr/bin/env bash
# mkapp.sh — wrap an Aether binary as a macOS .app bundle.
#
#   tools/mkapp.sh <binary> <AppName> <bundle.identifier> [out_dir] [icon.icns] [version]
#
# Produces <out_dir>/<AppName>.app with Contents/MacOS/<AppName>, an
# Info.plist (CFBundleIdentifier, name, version, LSMinimumSystemVersion,
# NSHighResolutionCapable), the icon if given, and an ad-hoc code signature
# (`codesign --sign -`), which Apple silicon requires to launch at all.
#
# What this does NOT do: notarize. A download from outside the App Store
# needs `codesign` with a Developer ID certificate and `notarytool` — both
# need a paid developer account. Locally built and run, ad-hoc is enough.
#
# Why a bundle matters: Finder shows the icon and name; NSBundle answers
# (mac.bundle); UNUserNotificationCenter, Launch Services registration,
# "Open With", Full Disk Access granted BY APP rather than by binary path.
set -eu
bin="${1:?binary}"; name="${2:?AppName}"; bid="${3:?bundle.id}"
out="${4:-.}"; icon="${5:-}"; ver="${6:-1.0}"
[ -x "$bin" ] || { echo "mkapp: $bin is not an executable" >&2; exit 1; }
app="$out/$name.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/$name"
chmod +x "$app/Contents/MacOS/$name"
icon_line=""
if [ -n "$icon" ]; then
    cp "$icon" "$app/Contents/Resources/AppIcon.icns"
    icon_line="    <key>CFBundleIconFile</key><string>AppIcon</string>"
fi
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>$name</string>
    <key>CFBundleIdentifier</key><string>$bid</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>$name</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$ver</string>
    <key>CFBundleVersion</key><string>$ver</string>
    <key>LSMinimumSystemVersion</key><string>11.0</string>
    <key>NSHighResolutionCapable</key><true/>
$icon_line
</dict>
</plist>
PLIST
printf 'APPL????' > "$app/Contents/PkgInfo"
codesign --force --sign - "$app" >/dev/null 2>&1 || {
    echo "mkapp: codesign failed (is Xcode / the Command Line Tools installed?)" >&2; exit 1; }
echo "$app"
