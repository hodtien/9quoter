#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="9Quoter"
APP_DIR="$DIST_DIR/$APP_NAME.app"
VERSION="0.1.2"

rm -rf "$DIST_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

swift build -c release --package-path "$ROOT_DIR"

cp "$BUILD_DIR/9QuoterApp" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Packaging/Info.plist" "$APP_DIR/Contents/Info.plist"

chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
fi

pushd "$DIST_DIR" >/dev/null
zip -qr "$APP_NAME-$VERSION.zip" "$APP_NAME.app"
shasum -a 256 "$APP_NAME-$VERSION.zip" > "$APP_NAME-$VERSION.zip.sha256"
popd >/dev/null

echo "Built: $APP_DIR"
echo "Zip: $DIST_DIR/$APP_NAME-$VERSION.zip"
echo "SHA256: $(cut -d ' ' -f1 "$DIST_DIR/$APP_NAME-$VERSION.zip.sha256")"
