# Downloading and building the preview

## Download a built app

Open this repository's **Actions → Build preview**, choose a successful run for the preview branch/PR, and download `NotchIslandSports-preview-arm64` (Apple silicon) or `NotchIslandSports-preview-x86_64` (Intel) from **Artifacts**. GitHub may require sign-in. Extract the artifact ZIP, then the contained preview ZIP. Quit the old app before running the new app.

The root `NotchIslandSports.zip` is the older build and is not updated by this work. The preview artifacts are ad hoc signed, not Developer ID signed/notarized. Keep your existing app as a backup. Follow normal macOS security prompts; this project does not ask you to disable Gatekeeper or clear quarantine. A signed/notarized public release still needs the owner's Developer ID credentials.

## Command-line build without using the Xcode editor

On your Mac, install Apple's Command Line Tools:

```sh
xcode-select --install
```

Complete the Apple installer. Download this branch's source with **Code → Download ZIP**, extract it, open Terminal in that folder, then run:

```sh
swift --version
bash scripts/check-core.sh
bash scripts/build-app.sh
```

The app is written to `build/NotchIslandSports.app`, and a shareable local preview archive to `build/NotchIslandSports-preview.zip`. The script resolves the plist placeholders, preserves supplied resources and applies an ad hoc local signature. It builds the current machine's architecture by default. The current asset catalog has no actual app-icon images.

A compatible Swift toolchain and macOS SDK are required. If the selected SDK reports missing SwiftUI macros/toolchain mismatches, install/select a matching stable toolchain/SDK; a bare Swift compiler is not enough. An explicitly installed SDK can be selected with:

```sh
NOTCH_MACOS_SDK=/absolute/path/to/MacOSX.sdk bash scripts/build-app.sh
```

Some minimal CLT installations do not include XCTest; use `scripts/check-core.sh` there. Full Xcode and `swift test` run the XCTest suite. Full Xcode is also recommended for Instruments, UI tests, XcodeGen builds and distribution signing. Neither the full IDE nor Command Line Tools are required simply to run a compatible built app.

## XcodeGen alternative

Install full Xcode and XcodeGen, then:

```sh
xcodegen generate
xcodebuild -list -project NotchIslandSports.xcodeproj
xcodebuild -project NotchIslandSports.xcodeproj -scheme NotchIslandSports -configuration Release build
```

`project.yml` remains the project source. XcodeGen generates a project; it does not replace Xcode's `xcodebuild`. Core logic is shared by the SwiftPM and Xcode targets. The preview configuration retains ad hoc signing; configure a dedicated Release signing profile and Hardened Runtime for a Developer ID release, test required Apple Events entitlements, submit with `notarytool`, staple and validate. Never commit signing credentials.

See [implementation notes](IMPLEMENTATION.md) for preservation scope, experimental native Clock/media limitations, and required manual tests.

## SDK workaround used for this preview

This Mac's default CLT SDK reported missing `SwiftUIMacros`. The installed older SDK successfully compiled the preview using:

```sh
NOTCH_MACOS_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
NOTCH_BUILD_SYSTEM=native NOTCH_DEBUG_INFO=none bash scripts/build-app.sh
```

Use that path only if the SDK exists on your Mac. In this agent's restricted environment, `NOTCH_PACKAGE_SANDBOX=0` and workspace-local compiler caches were also necessary for SwiftPM's nested build sandbox; a normal Terminal build may not need them. Prefer a matching stable toolchain for release builds. See the recorded validation in `IMPLEMENTATION.md`.

### Preview 1.6 media helper

`scripts/build-app.sh` also compiles the pinned Objective-C sources in `Vendor/mediaremote-adapter` using `xcrun clang`, bundles the system-Perl launcher and BSD license, and signs the nested framework before the app. No CMake or downloaded binary is needed. `NOTCH_ARCH=arm64` or `x86_64` selects a preview architecture. XcodeGen runs the same helper packaging step; its architecture list supports a universal helper. Running only `swift build` produces an executable without this packaged browser-media adapter; use the app build script to test the complete app. Private MediaRemote and native Clock Accessibility remain experimental. Developer ID signing and notarization are still required for normal public distribution; an ad hoc preview is not notarized.
