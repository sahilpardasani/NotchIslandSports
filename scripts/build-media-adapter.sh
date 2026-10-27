#!/bin/bash
# Compile audited vendored sources; no downloaded binaries or runtime downloads.
set -euo pipefail
cd "$(dirname "$0")/.."
destination="${1:?app Contents directory required}"
sdk="${NOTCH_MACOS_SDK:-$(xcrun --sdk macosx --show-sdk-path)}"
archs="${NOTCH_ARCH:-${ARCHS:-$(uname -m)}}"
arch_args=()
for arch in $archs; do arch_args+=(-arch "$arch"); done
vendor="$PWD/Vendor/mediaremote-adapter"
framework="$destination/Frameworks/MediaRemoteAdapter.framework"
mkdir -p "$framework/Versions/A/Resources" "$destination/Resources"
xcrun clang -dynamiclib -fobjc-arc -fmodules "${arch_args[@]}" -isysroot "$sdk" -mmacosx-version-min=12.0 \
  -I "$vendor/include" -I "$vendor/src" "$vendor"/src/adapter/*.m "$vendor"/src/private/*.m "$vendor"/src/utility/*.m \
  -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
  -install_name '@rpath/MediaRemoteAdapter.framework/Versions/A/MediaRemoteAdapter' \
  -o "$framework/Versions/A/MediaRemoteAdapter"
cat > "$framework/Versions/A/Resources/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>com.notchislandsports.MediaRemoteAdapter</string><key>CFBundleExecutable</key><string>MediaRemoteAdapter</string><key>CFBundlePackageType</key><string>FMWK</string><key>CFBundleVersion</key><string>1</string></dict></plist>
PLIST
ln -sfn A "$framework/Versions/Current"
ln -sfn Versions/Current/MediaRemoteAdapter "$framework/MediaRemoteAdapter"
ln -sfn Versions/Current/Resources "$framework/Resources"
cp "$vendor/bin/mediaremote-adapter.pl" "$destination/Resources/"
cp "$vendor/LICENSE" "$destination/Resources/MediaRemoteAdapter-LICENSE.txt"
codesign --force --sign - "$framework"
