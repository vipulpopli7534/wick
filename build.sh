#!/usr/bin/env bash
# Builds Wick.app (universal: Apple Silicon + Intel) with only the Xcode Command Line Tools.
#
#   ./build.sh            build into ./build/Wick.app
#   ./build.sh --install  build, copy to /Applications and launch it
#   ./build.sh --zip      build and create ./build/Wick.zip (for GitHub releases)
set -euo pipefail

APP_NAME="Wick"
BUNDLE_ID="${BUNDLE_ID:-io.github.wick.app}"
VERSION="${VERSION:-1.0.0}"
MIN_MACOS="11.0"

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/$APP_NAME.app"

INSTALL=false
ZIP=false
for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=true ;;
    --zip) ZIP=true ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

if ! command -v swiftc >/dev/null 2>&1; then
  echo "swiftc not found. Install the Xcode Command Line Tools with:  xcode-select --install"
  exit 1
fi

SDK="$(xcrun --sdk macosx --show-sdk-path)"
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
SDK_MAJOR="${SDK_VERSION%%.*}"
echo "→ Using $(swiftc --version 2>&1 | head -1)"
echo "→ macOS SDK $SDK_VERSION"

FLAGS=()
if [ "$SDK_MAJOR" -ge 13 ]; then
  FLAGS+=(-D HAS_SMAPPSERVICE)   # "Open at login" needs the macOS 13 SDK
else
  echo "  (SDK older than 13: building without the 'Open at login' option. Run 'softwareupdate --install -a' or update the Command Line Tools to get it.)"
fi

echo "→ Compiling $APP_NAME $VERSION"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD/obj"

for ARCH in arm64 x86_64; do
  swiftc -O -swift-version 5 -parse-as-library ${FLAGS[@]+"${FLAGS[@]}"} \
    -sdk "$SDK" -target "$ARCH-apple-macos$MIN_MACOS" \
    "$ROOT"/Sources/*.swift \
    -o "$BUILD/obj/$APP_NAME-$ARCH"
done
lipo -create -output "$APP/Contents/MacOS/$APP_NAME" "$BUILD/obj/$APP_NAME-arm64" "$BUILD/obj/$APP_NAME-x86_64"

sed -e "s/__VERSION__/$VERSION/g" -e "s/__BUNDLE_ID__/$BUNDLE_ID/g" \
  "$ROOT/Resources/Info.plist" > "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature so macOS treats it as a proper app (notifications, login item).
codesign --force --deep --sign - "$APP"
echo "✓ Built $APP"

if $ZIP; then
  rm -f "$BUILD/$APP_NAME.zip"
  ditto -c -k --keepParent "$APP" "$BUILD/$APP_NAME.zip"
  echo "✓ Zipped $BUILD/$APP_NAME.zip"
fi

if $INSTALL; then
  pkill -x "$APP_NAME" 2>/dev/null || true
  rm -rf "/Applications/$APP_NAME.app"
  cp -R "$APP" "/Applications/$APP_NAME.app"
  open "/Applications/$APP_NAME.app"
  echo "✓ Installed to /Applications and launched. Look for the candle in your menu bar 🕯️"
fi
