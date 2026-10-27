# Preview 1.6 (build 11) — restored centered score layout

This update supersedes the menu, hover, setup and media-control descriptions in earlier preview notes. Existing sports, read-only Calendar rollover, physical-notch positioning, compact height, reduced-motion handling and provider sleep policies remain.


## Build 11 layout correction (current)

Fixes the screenshot regression where the primary became a large blank camera section followed by both scores crammed on the right. Menu fallback used to reserve the whole left side and relocate both score labels into the right ear. The primary now keeps equal ears on opposite sides of the physical camera, the same compact height and a stable center through menu changes and expansion. Removed the asymmetric renderer so it cannot be reintroduced by a stale presentation value. The compact cricket team and multi-innings score scale together instead of sacrificing the team abbreviation first. Title scrolling is unchanged.

Menu-aware placement now applies only to satellite pills: they move to a free side or hide when neither side fits, with their activities still accessible by swiping. The primary remains centered even with long app menus. This deliberately prioritizes a stable, readable score layout; it cannot guarantee that unusually long macOS menus never intersect the primary.

Version stays 1.6.0; bundle/About build is 11. Approval hooks, native media/Clock, Calendar, merge gestures and the no-hover policy are preserved. Regression checks cover unavailable menu geometry, either crowded side, both sides crowded, merged state, expansion and a display with a negative origin. Actual-view renders include the supplied NAGA `187 & 46/4` / SIKM `184` score with fallback placement. Live display appearance remains a device check.

## Build 10 approvals retained

Adds local Codex and Claude Code PermissionRequest hooks, including supported desktop coding sessions, with an orange pending activity, full hook request details and Approve once / Deny / Use app prompt controls. Setup installs the helper and merges hook configuration once; Codex hook trust must still be granted in the source. Requests expire after two minutes and never auto-approve. Generic ChatGPT chat, Claude Chat/Cowork, cloud and remote approvals are not connected. See [approval setup, contracts and verification](APPROVALS.md).

Build 10 introduced approvals; version remains 1.6.0. Existing no-hover behavior, six top-level menu items, native Clock, Calendar, sports and media remain. The approval entry is inside Select Widget.

## Build 9 changes retained

These changes originated in build 9 and remain; they replace build 8 behavior where noted.

- Spotify (`com.spotify.client`) and Apple Music (`com.apple.Music`) use the shared event-driven Now Playing feed for title, artwork, progress, pause state and split presence. No browser tab is required. Both apps share one media slot: macOS selects the current player. Playing creates an activity; pausing the observed session retains controls; source withdrawal or quitting removes it. Cached paused metadata at startup does not create an activity.
- If a system transport command fails for either native player, a fixed AppleScript command targets that exact app only after checking the displayed title, bundle ID, current system player and running PID again. Play/pause, previous/next and ±15-second seek are covered. Automation consent may be requested on first fallback use. Browser failures never fall through to Music or Spotify. Detection still depends on experimental/private MediaRemote; native fallback is transport only, not an independent discovery API. Native app playback has not been verified end-to-end here.
- Swiping to Calendar stays collapsed, displaying the current/next same-day event. Pull down explicitly opens the agenda; swipe up returns to compact Calendar. Calendar never occupies a live-activity slot and no events are deleted or changed.
- A plain inward drag on either small pill merges all satellites into the primary. It follows the pill's actual side after relocation. Hold and swipe on the primary restores separate activities; keyboard/accessibility actions remain available.
- Compact positioning considers application-menu and status-window bounds. Build 11 keeps primary content centered; crowding on one side moves satellite pills to the other and hides excess pills if no gap fits. The physical camera stays covered. The reader is debounced and event-driven, bounds work on a utility queue, stops during suspension, and publishes changed geometry only. No new idle polling loop, screen recording or menu-title collection is added.
- Accurate application-menu bounds use already-granted Accessibility permission. When unavailable, reserve the app-menu side conservatively, plus 240 points for right-side system controls. Placement remains best effort: macOS does not expose every status item consistently; re-evaluation occurs on app/window/layout/display changes. Expanded panels still open centered under the camera.
- Expanded media has curved shoulders and a lower contour around playback controls and the swipe handle. Missing artwork uses a circular music emblem. Actual album artwork remains intact.
- Panel backing uses sRGB and opaque black content. Software cannot eliminate the physical camera housing's optical reflections or make it invisible from every viewing angle.

Validation: 203 standalone checks plus the no-hover source guard; release compilation and synthetic renders of actual SwiftUI views. Tests cover native media identities/lifecycle, safe native routing, inward gestures, compact Calendar and crowded-menu geometry. Live menu placement, native player controls and frame pacing still require device verification. No battery/FPS improvement is claimed from fixtures alone.

Implementation references: [application menu accessibility attribute](https://developer.apple.com/documentation/applicationservices/kaxmenubarattribute), [screen camera-safe area](https://developer.apple.com/documentation/appkit/nsscreen/auxiliarytopleftarea), [window geometry metadata](https://developer.apple.com/documentation/coregraphics/cgwindowlistcopywindowinfo(_:_:)).

## Build 8 changes retained

The following changes originated in build 8 and remain unless superseded above.

- The compact primary is now camera width + 224 points (404 points with a 180-point camera), with satellites capped at 96 points. The physical camera remains centered and every capsule stays inside the camera/menu-bar band. This leaves more room for the app menu; third-party overlays cannot reserve menu-bar space across every possible app/menu configuration.
- Sports satellites show score only, stripping parenthesized overs/target commentary. Their labels are explicitly constrained and clipped to their capsules. Full score details remain in the expanded sports page.
- A single native frame transition reveals a fixed-size expanded surface. Expanded content no longer springs/reflows at a different speed from the window. Opacity follows the actual visible height, the currently displayed page stays mounted during collapse, and per-window generations reject stale animation completions during reversals. Opening/closing use 0.38/0.32-second easing. Reduced Motion and low-power conditions still skip motion. There is no idle animation timer or hover tracking.
- Drag gestures commit once while moving rather than waiting for release; trackpad pulls remain supported. Sliders and scrolling in the content area keep their gestures.
- First-time Clock setup explicitly offers Connect Apple Clock or Skip Clock. A previously explicit disabled preference is respected. Done remains disabled while permission or a connection is pending. Accessibility permission is checked once per second only while setup is open; after the grant, an explicit connection action launches Clock without activating it, locates a unique native Timers tab and selects it without starting or modifying timers. Cold launch gets at most three bounded attempts and a six-second overall timeout. Unsupported layouts show Retry instead of falsely claiming setup succeeded.
- Completed setup is retained. Missing/revoked Accessibility permission or an unfinished connection reopens the setup window at launch when Clock is enabled. Replacing an ad hoc signed app may still require the user to grant macOS permission again; the app cannot grant its own permissions.

Build 8 verification: 171 standalone checks plus the no-hover guard passed. A release build and actual SwiftUI layout renders passed. New checks cover compact score truncation, smaller geometry, Clock setup readiness/permission revocation, and retaining/reversing the displayed page during collapse. Live display frame pacing and native timer control still require device verification; no measured FPS claim is made. The user’s supplied screenshot confirms browser-media metadata is appearing in the earlier 1.6 app.

## Visible changes

- No hover behavior: the tracking-area class, enter/exit handlers, delayed exit work, observable hover state and presentation subscription have been removed. Pointer entry and exit cannot expand or collapse any island. App-specific hover hints were removed too.
- Pull down to open; swipe up to collapse. Clicking remains an accessible alternative. No island close cross, match-selector close cross or page arrows. The bottom handle and Escape remain available.
- Top-level menu matches the requested six entries: Select Widget, Select Match…, Refresh Now, Simulate Notch Layout, About, Quit. Sport filtering remains under Select Widget and in the match selector.
- A separate setup window appears until Done is selected. Preferences persist; reopen through About → Configure. No permission/setup buttons appear inside timer content. macOS still requires the user to grant protected permissions.
- Up to three live slots for sports, media and native Clock. Calendar stays on a swipe-accessible page and never consumes a live slot. Hold and swipe sideways toggles merge/separate; existing merge preferences are preserved.
- Native timer controls are circular Pause/Resume and Stop (with cancellation confirmation), plus the observed duration. No app-owned timers.

## Clock corrections and limits

Previously, granting Accessibility after the adapter entered its denied state could leave it stopped until a Clock activation or explicit refresh. The adapter now checks for permission changes on application activation and retries every 15 seconds while enabled but denied. Refresh Now refreshes Clock, Calendar and media too.

Hidden or minimized Clock windows are no longer rejected before reading their accessible contents. A readable, uniquely identified native timer can still be observed and controlled in the background. Closed windows, unsupported Clock layouts or unavailable accessibility data still cannot be read. Keep Clock running on its Timers page; it may be behind other apps. English native controls remain the recognized layout.

Cancel confirmation now resolves the latest snapshot of the same semantic timer before checking freshness. It still re-reads the native tree and validates the timer identity, selected sidebar anchor, state and exact native button before AXPress. Other timers are never selected automatically. Accessibility access is opt-in and revocable.

A replaced ad hoc signed preview may require macOS to re-authorize Accessibility. A stable Developer ID signature is needed before promising permissions will survive every downloaded update. This is an experimental Accessibility adapter, not a public Clock timer API.

## Browser media correction

The previous implementation relied on direct MRMediaRemoteGetNowPlayingInfo, which is restricted on newer macOS versions, polled idle media every 30 seconds, and explicitly enabled transport controls only for Music/Spotify. That combination explains missing browser activity and disabled browser controls.

The packaged app now includes a source-built, BSD-3-Clause mediaremote-adapter, pinned to upstream Git tree 0e82bf1c44ec39554fbfc402ec88a48c6ae2a0fd. It uses private MediaRemote through the system Perl interpreter. This remains experimental and can break with macOS updates. It does not scan browser tabs, inject browser JavaScript, synthesize media keys, download executable code at runtime or change system protections.

One event-driven helper receives complete metadata snapshots with a 150 ms debounce. Browser media advertised through macOS Now Playing can occupy a separate activity slot and use the existing media panel. No independent 30-second discovery poll runs while this stream is active. The helper stops on sleep/session suspension, integration disable and app termination, with generation checks rejecting late callbacks. Failed listeners retry after 30 seconds. Stream buffers are limited to 8 MB, decoded artwork to 4 MB, and artwork is cached until changed.

User-clicked controls invoke system transport commands. A local adapter patch checks the expected bundle ID and title immediately before dispatch; stale commands are rejected. Because transport is a global private API, a small race between validation and dispatch remains. Seek/next/previous availability depends on the browser/player; successful dispatch does not prove that a player honored the action.

References: [upstream adapter](https://github.com/ungive/mediaremote-adapter), [reported direct API regression](https://github.com/aviwad/LyricFever/issues/94). The bundled license is in the app’s Resources folder.

## Verification

- 203 standalone logic checks passed: activity selection/gestures, Calendar boundaries, geometry, Clock parsing/control policy, browser metadata parsing and limits. A separate source guard fails if hover state, tracking areas or pointer entry/exit/movement handlers are introduced.
- Release app compiled with Command Line Tools and macOS 26.5 SDK. Strict ad hoc signature and ZIP checks are performed on the packaged output.
- Actual SwiftUI fixture renders reviewed for timer and media content. These are synthetic layout previews, not proof of live integrations.
- The native media helper launched and returned valid empty JSON in the current environment. Its upstream self-test did not establish an active session (exit 4 with the command-line test publisher; exit 3 with a bundled publisher that did not report ready). This is not a passing live compatibility result.
- Clock/Safari computer inspection repeatedly failed with ScreenCaptureKit -3811. Native timer operations and YouTube play/pause have therefore NOT been verified end-to-end in this environment. Do not present them as proven until the device acceptance checks below pass.
- No measured battery percentage or CPU savings claim is made.

## Device acceptance checks

1. Quit older copies, install the new app in one stable location, complete setup, and restart. Setup should not reappear after Done.
2. Move the pointer across every capsule and away repeatedly. Neither expansion nor collapse should occur. Pull down, then swipe up; the top edge must stay at the physical notch.
3. Start a YouTube video in Safari or Chrome while a sports activity is present. With Separate Live Activities enabled, expect a media satellite; open it and check title, artwork if exposed, pause/resume and source changes. Stop playback and close the tab; confirm stale media clears when macOS clears its session.
4. Start a disposable timer in Apple Clock. Grant Accessibility once, return from Settings, and confirm automatic observation. Test Pause/Resume/Stop from the notch; cancel the confirmation first, then confirm it. Check another timer is untouched. Repeat with Clock behind other windows, hidden/minimized if macOS still exposes it, and after permission revocation.
5. Show sports + music + timer, then swipe to Calendar. It must stay compact and must not replace a live slot. Pull down to open the agenda, swipe up to return to compact Calendar. Let an event end and confirm only the island advances to the next same-day event; Apple Calendar itself must be unchanged.
6. Sleep/wake and disable/re-enable integrations. No duplicate helper or stale activity should survive. Verify actual Energy Impact and wakeups before making battery claims.

### Music title and playback motion (build 8)

Long titles now scroll to the end and back with eased movement and a 1.6-second reading pause at each end, in both the compact and expanded media views. Short titles remain stationary. Compact trailing content is five cyan playback bars instead of the creator name; artist metadata remains in the expanded view. Bars are decorative playback indicators, not microphone capture or audio amplitude analysis. Full titles remain available to accessibility.

Motion redraws only its small text/bar surfaces at a maximum requested 30 frames/second while playback and the provider are active and the surface is visible. Motion stops when paused, suspended, in Low Power Mode or with Reduce Motion; hidden expanded content never runs a decorative animation. This introduces no media polling or idle repeating task. User-requested macOS adaptation informed by [Apple’s Live Activities design guidance](https://developer.apple.com/design/human-interface-guidelines/live-activities) and [Dynamic Island interaction guidance](https://support.apple.com/en-ie/guide/iphone/iph28f50d10d/ios), not a claim of Apple’s private Now Playing implementation or continuous ActivityKit animation support.

### Gesture and browser-session follow-up (build 8)

One continuous press-and-drag recognizer now replaces the competing long-press/exclusive-swipe pair. Hold for about 0.3 seconds, then drag sideways at least 22 points to merge/separate; a quick sideways drag changes pages. Pull down/up uses 18 points. Recognition waits for a dominant direction and commits once. Expanded input is confined to the header and bottom handle, preserving media sliders and scrolling. Trackpad scrolling now works on both satellite capsules too; click-hold while scrolling sideways toggles merge/separate. No hover behavior was added.

Satellites slide 32 points outward/inward with a 0.32-second eased fade; stale completions are guarded during reversal. New media sessions automatically separate the live slots. A manual merge remains through ordinary metadata updates and pauses. Session disappearance closes an open music panel and merges its slot; the next playing session splits again.

The media lifecycle now rejects old paused metadata at app startup, keeps a session that was observed playing when paused, and clears it on metadata withdrawal, source-app termination, adapter failure or sleep. A vendored adapter correction clears the entire stale snapshot when MediaRemote reports no player PID, rather than retaining its old title and bundle. These are Now Playing session signals, not direct browser tab enumeration. YouTube, Netflix and Prime Video work only when the browser exposes their session to macOS. If a browser retains paused metadata after a tab closes, exact tab closure is unavailable to this adapter; no claim of universal tab detection is made. An explicit browser extension would be required to promise tab-level lifecycle across those sites.

Expanded media content now uses 180 points instead of 220 (206 when a connection/control message needs room). Cricket uses 320 instead of 360, preserving its scrolling scorecard and bottom handle. The camera band and handle are added separately, so trimming the empty footer does not move content behind the physical notch.

The main collapsed cricket island also shows only team abbreviations and scores, with no overs suffix (for example, `ZIM 132/7` and `177 AFG`). Overs and target details remain in the expanded scorecard.

### Additional build 9 device checks

- Play a song in Spotify, then Apple Music. Verify the one media slot switches source and artwork, pause/resume, previous/next, and ±15 seconds on seekable local tracks. Quit the displayed player: its stale pill must disappear. Check native playback with no browser running. Deny Automation: fallback must fail visibly without opening another app or changing playback elsewhere.
- With three activities, swipe either satellite toward the camera without holding. Only the primary remains. Provider updates must not undo the merge; hold and swipe on the primary to split again.
- Switch between short and long app menus and multiple displays, with and without Accessibility permission. Satellite pills should relocate or hide before overlapping measured menus; the primary must remain centered with one score on each side. Verify no hover behavior and no idle layout/AX loop.
