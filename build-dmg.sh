#!/bin/bash
set -euo pipefail

APP_NAME="ExifUI"
SCHEME="ExifUI"
PROJECT="ExifUI.xcodeproj"
BUILD_DIR="$(mktemp -d)"
DMG_DIR="$(mktemp -d)"
OUTPUT_DIR="${1:-$HOME/Desktop}"
DMG_PATH="$OUTPUT_DIR/$APP_NAME.dmg"

echo "==> Building $APP_NAME (Release)..."
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    archive \
    -quiet

echo "==> Exporting app..."
# Create export options plist
EXPORT_PLIST="$BUILD_DIR/exportOptions.plist"
cat > "$EXPORT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    -exportPath "$BUILD_DIR/export" \
    -exportOptionsPlist "$EXPORT_PLIST" \
    -quiet

echo "==> Creating DMG..."
cp -R "$BUILD_DIR/export/$APP_NAME.app" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

# Remove old DMG if it exists
rm -f "$DMG_PATH"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Cleanup
rm -rf "$BUILD_DIR" "$DMG_DIR"

echo "==> Done: $DMG_PATH"
