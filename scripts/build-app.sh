#!/usr/bin/env bash
# Baut Vorrat.app (Release) im Ordner build/. Danach einfach nach /Applications ziehen.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product Vorrat
BIN="$(swift build -c release --product Vorrat --show-bin-path)/Vorrat"

APP="build/Vorrat.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Vorrat"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Vorrat</string>
    <key>CFBundleDisplayName</key><string>Vorrat</string>
    <key>CFBundleIdentifier</key><string>local.vorrat.app</string>
    <key>CFBundleExecutable</key><string>Vorrat</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleDevelopmentRegion</key><string>de</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.lifestyle</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSSupportsAutomaticTermination</key><false/>
</dict>
</plist>
PLIST

# Ad-hoc-Signatur, damit macOS die App lokal ohne Warnung startet.
codesign --force --deep --sign - "$APP" >/dev/null

echo "Fertig: $APP"
echo "Installieren:  mv \"$APP\" /Applications/"
