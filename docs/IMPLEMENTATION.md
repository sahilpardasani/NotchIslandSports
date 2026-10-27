> Latest follow-up: [notch restoration and three activities](NOTCH-RESTORATION.md) supersedes the earlier below-camera/two-slot placement and observation-only Clock behavior. Clock controls are now experimental and user-triggered; Calendar remains strictly read-only.

# Battery fixes and split activities — 1.1 preview

This preview preserves the existing 13 sports, feed parsers, scorecards, match picker, Hindi display, menu-bar entry and notch simulation. It changes the activity shell and scheduling. It does **not** implement the entire earlier report.

## Implemented

- Discovery remains available across all sports, but the background interval is now 5 minutes (2 while browsing) instead of 30 seconds. Selected live details update every 30 seconds compact / 15 seconds expanded. Low Power Mode and thermal pressure slow discretionary work.
- One retained discovery/detail request at a time, cancellable lifecycle, late-response/selection generation checks, bounded four-request network concurrency and cancellation-aware queued requests.
- No duplicate launch/wake refreshes. Sports, media and Clock observation stop on system/display sleep and inactive sessions. Updates resume once all suspension reasons clear.
- Cached discovery data is explicitly labeled and expires after 15 minutes without a nonempty refresh. Some upstream parsers still collapse partial failures into empty results; a complete provider result/freshness redesign remains follow-up work.
- Old detail responses cannot replace another selection (including A→B→A). A slower discovery response cannot replace newer selected detail. Match restoration/merging and selector identities include sport/league where available.
- Sports/music/native Clock selection has two stable compact slots and overflow reachable through tabs. Separate windows leave the split gap click-through. Layout/frame changes are deduplicated; score ticks no longer animate panel geometry.
- All interactive content sits below the camera/menu-bar exclusion area. The primary panel stays on a chosen available/notched display across normal updates. Display selection settings and a complete multi-display/full-screen verification matrix remain follow-up work.
- Media polling backs off from 5 seconds while playing to 15 paused / 30 with no metadata. Artwork decoding and color calculation reuse unchanged artwork. A one-second visible timeline replaces the ten-Hz progress counter, using an elapsed-time anchor. Decorative media bars are static; sports attention effects are bounded instead of endless.
- Removed fake media key codes and all-tab/all-player seek scripts. Identified Apple Music/Spotify sources use targeted Apple Events on an explicit button click. Unsupported source controls are disabled. Automation failures are visible.
- Native Clock observation is a separate, read-only Accessibility adapter. There are **no app-owned timers**, timer creation controls, custom alarm sounds or independent expiration notifications.
- Corrected a pre-existing NBA leader parsing fallback, added an Apple Events usage explanation, removed the global ATS exception, and added SwiftPM app packaging and preview CI.

## Native Clock: scope and setup

Open the menu-bar icon → Apple Clock… → Enable Clock Observation. Grant this application Accessibility access in System Settings → Privacy & Security → Accessibility, then choose Refresh Clock. Open Apple's Clock app and select Timers. Start/pause/cancel timers **in Clock**.

This is experimental, not a supported Clock API. It reads a bounded accessibility tree only from `com.apple.clock`; it never reads private databases, captures the screen, injects clicks, or creates a substitute timer. Currently the parser recognizes unambiguous English Pause/Resume + Cancel controls grouped with one countdown. Multiple recognizable timer cards are supported. Other UI versions/locales may expose a different structure and are intentionally rejected.

The compact value is the last directly observed Clock value, refreshed approximately every 2 seconds while readable (5 under Low Power Mode), not an independent simulated countdown. Idle observation backs off to 15 seconds, and process/AX events trigger reconciliation. Hidden/closed/unreadable windows, lost permission or ambiguous structure remove the countdown and show guidance. Clock remains responsible for alarms. No claim of reliable background timer synchronization is made until the real OS/Clock version passes manual testing.

## Media compatibility

The existing private MediaRemote metadata route is retained and clearly named **Experimental System Media** in the menu. It is enabled by default to preserve existing behavior and can be disabled. The supported-public-API-only distribution described in the report is **not** yet provided. This preview may fail to obtain media on some macOS versions and is not advertised as App Store compatible. Symbol absence/timeouts degrade to no activity.

Source identification also uses private MediaRemote. Only an identified running Music/Spotify source is eligible for controls, with a fresh PID check before dispatch. Browser metadata may display, but browser controls remain disabled rather than affecting unrelated tabs. Native player and browser compatibility requires real-device tests. Private API success is not guaranteed by successful compilation or notarization.

## Validation and remaining work

- Core checks cover deterministic split/overflow/merge, stale selection generations, polling policy, timestamp-based playback, conservative native Clock parsing, cancellation and bounded concurrency. Clock fixtures are synthetic contract tests, not captured proof of Apple's UI structure.
- XCTest tests are included for full-Xcode CI. `scripts/check-core.sh` provides a Foundation-only executable check for CLT installations lacking XCTest.
- Run the manual checklist below before treating the preview as a release. No measured battery percentage improvement, runtime UI pass, or native Clock compatibility claim follows from compilation alone.
- Still pending: robust per-provider sports freshness/result types, HTTP Retry-After/conditional-response coordination, event-driven public media adapters, polished animation/accessibility verification, native Clock UI compatibility fixtures, the report's longer performance soak, and Developer ID signing/notarization.
- ChatGPT/Claude approvals, Maps and delivery integrations are not part of this preview.

## Manual acceptance checklist

1. Compare all 13 existing sport views, Hindi cricket labels, match selection and saved selection against the previous app.
2. Change match A→B→A while requests are slow; the selected match must never jump due to an old response. Verify last-known/error labels offline.
3. Play Music/Spotify: sports remains visible, music appears separately, and clicking a slot opens the correct tab. When three activities exist, all are reachable. Unknown media sources must not receive transport actions.
4. Place a text editor in front and use playback controls: no letters/numbers should be typed. With two players, only the identified source may respond. Deny Automation and confirm an error, not another control route.
5. Clock: test a timer created externally, pause/resume, cancel, multiple timers, switching Clock tabs, minimized/closed windows, app quit, Accessibility revocation, screen sleep and restart. Record exact macOS/Clock version and locale. Unsupported states must remove the claimed countdown.
6. Hover/click both slots, the gap and surrounding app controls; test Escape, menu Open Island and keyboard traversal. The gap must pass through. Verify no offscreen content with scaled displays, negative display coordinates, full-screen/Spaces and display removal.
7. Enable Reduce Motion and Low Power Mode. Check transitions and steady-state idle behavior; confirm providers stop during sleep and resume without duplicate bursts.
8. Measure Release builds on the same hardware/workload for 15 minutes, three repeats, plus a two-hour retention run. Record CPU, wakeups, network requests/bytes, memory and rendering—not just subjective smoothness. Include Clock AX and browser overhead. Compare against the original commit.
9. Verify packaged architecture/minimum OS, signature, fresh-account permissions and normal Gatekeeper behavior. Preview builds are ad hoc signed and not notarized.

## Recorded local validation — October 27, 2026

- Release executable and packaged Apple silicon `.app` built successfully with Apple Swift 6.4 from Command Line Tools, requesting the installed macOS 26.5 SDK. The default SDK failed because its SwiftUI macros were missing from this CLT installation. The resulting Mach-O records minimum macOS 12.0; the bundled linker records SDK 27.0. Older macOS runtime compatibility is not established by this deployment target.
- 21 executable core checks and 5 presentation checks passed, including 100 unchanged availability updates without extra layout publications. `git diff --check`, plist validation and strict ad hoc signature verification passed.
- The native SwiftPM build engine and no debug information avoided a sandbox-blocked dSYM step. SwiftPM's nested manifest sandbox was disabled only for this constrained build. These are build-environment settings, not changes to macOS Gatekeeper.
- XCTest could not run locally because this CLT installation lacks XCTest. The suite is included for a full-Xcode CI runner. XcodeGen project generation is not locally verified.
- The desktop inspection tool failed before a Clock window could be inspected. No live native Clock, VoiceOver, split-window focus, media control, energy benchmark or Intel runtime pass is claimed. Keep this as a preview pending the manual checks above.
