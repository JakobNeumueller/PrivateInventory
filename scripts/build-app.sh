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

# App-Icon: aus der 1024er-Vorlage mit Apple-Tools erzeugen, sonst die fertige .icns verwenden.
if command -v iconutil >/dev/null && command -v sips >/dev/null; then
    ICONSET="build/AppIcon.iconset"
    rm -rf "$ICONSET" && mkdir -p "$ICONSET"
    for size in 16 32 128 256 512; do
        sips -z $size $size Resources/AppIcon-1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        sips -z $((size * 2)) $((size * 2)) Resources/AppIcon-1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
    rm -rf "$ICONSET"
else
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Vorrat</string>
    <key>CFBundleDisplayName</key><string>Vorrat</string>
    <key>CFBundleIdentifier</key><string>local.vorrat.app</string>
    <key>CFBundleExecutable</key><string>Vorrat</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
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

touch "$APP"

echo "Fertig: $APP"
echo "Installieren (ersetzt eine ältere Version):"
echo "  rm -rf /Applications/Vorrat.app && mv \"$APP\" /Applications/"
echo "Falls das Dock noch das alte Symbol zeigt:  killall Dock"
