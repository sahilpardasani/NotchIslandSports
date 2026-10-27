# 1.5 preview — restored content-first UI and native timer controls

## UI

The expanded island returns to the older scorecard-focused design: no Sports/Music/Calendar/Clock tabs, navigation title bar or top close button. Existing sport scorecards remain intact; a subtle bottom handle collapses the view. The physical camera/top anchor, thin collapsed strip, up to three live activities, swipe-only Calendar, persisted hold-and-swipe merge, battery policies and read-only Calendar behavior are retained. Settings remain in the menu bar.

The timer pull-down is now a compact panel (440 × 170 points for one timer with a 32-point camera band), rather than the previous 620 × 360 diagnostic layout. It shows:

- Large orange remaining time read from native Clock, with a small Timer/Paused label.
- A circular orange Pause/Resume button and circular gray Cancel button. These are actual SwiftUI buttons wired to native command dispatch, with accessible names, pressed feedback and disabled states.
- A bottom collapse handle. No Open Clock, Enable Observation, experimental banner, last-observed timestamp or technical paragraph in the active timer UI.
- At most two rows in the viewport when multiple readable timers exist; additional rows scroll. Unsupported native controls are visibly disabled with a short status. Setup/diagnostics are available in menu → Clock Settings → Clock Status.

Cancel still requests confirmation. No duration, total-time progress ring or independent countdown is invented. Clock remains responsible for the timer and alarm.

The visual direction follows the iPhone's compact activity/expanded controls pattern. Apple's guide documents touch-and-hold expansion, swipe-up collapse and activity switching: [Apple Dynamic Island guide](https://support.apple.com/en-ie/guide/iphone/iph28f50d10d/ios). Visual timer references were also searched to compare the prominent countdown and circular pause/close controls. This remains an AppKit/SwiftUI overlay adapted to a Mac camera cutout, not ActivityKit integration or an exact claim about every iOS version.

Swipe across the top camera-band ears or bottom handle to change pages. Pull/scroll down to open; push/scroll up on those regions or press Escape to collapse. Body scrolling and timer/player controls retain their interactions. The menu's Select Widget and accessibility actions provide navigation alternatives.

## Native Clock compatibility correction

Read-only inspection of the installed Clock app succeeded during this revision. Its selected sidebar timer has a semantic UUID and a summary duration, while CancelButton and PauseResumeButton live in a separate detail section. The previous card-only parser did not connect those sections and could disable otherwise usable controls.

The adapter now recognizes that structure only when exactly one selected UUID card and one matching detail section exist in the same window. Both sections must agree on paused/running state and remaining time (exact when paused, at most one second apart when running). The detail buttons must expose the expected identifiers and labels. Each snapshot maps the detail element and selected-card element without using screen coordinates. Generic card lookup now ignores duplicate identifiers on child text elements, preserving semantic container identity.

Before dispatch, the adapter re-reads native state and checks freshness, PID, permission, semantic timer ID, state/countdown drift, matching native detail/card/button objects and the card's current selected flag. Ambiguous selections, duplicate detail groups, cross-window associations, presets, stale states or unsupported buttons fail closed. The lookup stays within the existing bounded scan budgets and runs off the main thread. Only UUID container nodes need the new selected-state query.

For this selected-detail layout, the selected timer is exposed; the adapter does not invent state for other sidebar cards. Other supported layouts may expose multiple timers. Native Clock integration remains experimental and English-layout-specific. It may stop observing when Clock is hidden, minimized or closed. There is no supported general macOS Clock timer API used here, no app-owned timers and no automatic approval/permission bypass.

The existing paused timer was **not resumed, paused or cancelled during validation**. Read-only UI evidence establishes the structure; the successful parser checks do not establish end-to-end native AXPress compatibility. On-device action testing remains outstanding.

## Validation

- 109 standalone checks passed: 21 core, 23 presentation, 21 Calendar, 28 geometry/control-policy and 16 selected-detail checks. New cases cover selected-state absence, non-timer identifiers, empty summaries, state/duration mismatch, duplicate selected cards/details, different windows, one-second read rollover and changed selection. Sanitized synthetic fixtures reproduce the observed structure; personal timer identifiers are not stored.
- Release Apple silicon packaging, plist validation, ZIP validation and strict ad hoc signature verification. Full-Xcode CI runs XCTest and both architecture builds; see the current PR run.
- Actual SwiftUI views rendered and inspected with synthetic data: sports, Calendar, running/paused timer, unsupported controls, multiple timers, empty timers, split and merged states. These preview images are not live timer-control demonstrations.
- Hardware animation pacing, VoiceOver, full-screen/multiple displays and end-to-end Clock button actions remain manual acceptance checks. No measured battery savings or notarization claim is made.

## Install

Quit the previous instance. Extract the 1.5 Apple silicon app ZIP and open it. Xcode is not required to run the app. Preview signing is ad hoc and unnotarized; follow normal macOS security prompts. Command-line builds remain available through scripts/build-app.sh with a compatible Swift/macOS SDK toolchain. Setup stays in Clock Settings in the menu bar; do not run two preview instances together.
