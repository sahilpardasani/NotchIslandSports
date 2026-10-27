#!/bin/bash
# Build a local preview application with SwiftPM; no Xcode editor required.
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
configuration="${CONFIGURATION:-release}"
swift_args=(--configuration "$configuration")
if [[ -n "${NOTCH_BUILD_SYSTEM:-}" ]]; then swift_args+=(--build-system "$NOTCH_BUILD_SYSTEM"); fi
if [[ "${NOTCH_PACKAGE_SANDBOX:-1}" == "0" ]]; then swift_args+=(--disable-sandbox); fi
if [[ -n "${NOTCH_DEBUG_INFO:-}" ]]; then swift_args+=(-debug-info-format "$NOTCH_DEBUG_INFO"); fi
if [[ -n "${NOTCH_MACOS_SDK:-}" ]]; then swift_args+=(--sdk "$NOTCH_MACOS_SDK"); fi
if [[ -n "${NOTCH_ARCH:-}" ]]; then swift_args+=(--arch "$NOTCH_ARCH"); fi
swift build "${swift_args[@]}"
bin_dir="$(swift build "${swift_args[@]}" --show-bin-path)"
app="$root/build/NotchIslandSports.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/NotchIslandSports" "$app/Contents/MacOS/NotchIslandSports"
/usr/bin/sed \
  -e 's/$(EXECUTABLE_NAME)/NotchIslandSports/g' \
  -e 's/$(PRODUCT_BUNDLE_IDENTIFIER)/com.notchislandsports.app/g' \
  -e 's/$(PRODUCT_NAME)/NotchIslandSports/g' \
  -e 's/$(MACOSX_DEPLOYMENT_TARGET)/12.0/g' \
  Sources/App/Info.plist > "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 1.6.0' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion 18' "$app/Contents/Info.plist"
# The current asset catalog contains no icon images. Preserve any supplied resources.
if [[ -d Resources ]]; then cp -R Resources/. "$app/Contents/Resources/"; fi
cp "$bin_dir/notch-approval-hook" "$app/Contents/Resources/notch-approval-hook"
/usr/bin/codesign --force --sign - "$app/Contents/Resources/notch-approval-hook"
bash scripts/build-media-adapter.sh "$app/Contents"
/usr/bin/plutil -lint "$app/Contents/Info.plist"
/usr/bin/codesign --force --sign - "$app"
/usr/bin/codesign --verify --strict "$app"
/usr/bin/ditto -c -k --keepParent "$app" "$root/build/NotchIslandSports-preview.zip"
printf 'Built local preview: %s\n' "$app"
printf 'This preview is ad hoc signed, not Developer ID signed or notarized.\n'
