> **Current 1.4 behavior:** [Interaction update](INTERACTION-UPDATE.md) supersedes older Calendar-slot/tab-bar instructions below. Three live slots are reserved for sports, music and native Clock; Calendar is swipe-only. Setup is in the menu bar. Hold-and-swipe merges. The compact strip fits the camera band. Approval/delivery integrations remain unimplemented; the update documents supported hook research.

# Notch placement, pull-down and three activities — 1.3 preview

This update corrects the previous preview's regression: it positioned the island below the menu bar and made the sports strip too wide. The new layout is anchored at the **physical MacBook camera**, centered horizontally on its cutout and flush with the screen's top edge. It prefers the built-in notched display when available. External/non-notched displays use a top-center fallback.

## Placement and interaction

- Geometry uses the screen frame and validated auxiliary camera bounds. It does not anchor to the visible frame below the menu bar. Malformed auxiliary bounds fall back to a bounded camera width rather than producing a display-wide strip.
- Compact content uses equal-width ears with an empty camera region, for sports, music, Calendar and Clock alike. A typical 180-point camera produces a 500-point primary strip rather than the previous 680+ points. The two other activities occupy separate small panels at left and right, with click-through gaps.
- Three activities appear simultaneously: for example cricket in the center, Clock at left and Calendar at right. A fourth remains accessible through tabs. Slot order stays stable when scores/countdowns change.
- Hovering the primary still expands it. Drag down on the compact strip or top header to open and pin it; drag up on the expanded handle/header or press Escape to collapse it. A downward scroll over the compact strip also opens it. Expanded lists retain vertical scrolling. Click or drag down on a satellite to open its activity.
- The panel expands downward with a fixed camera center/top edge. Expanded controls begin below the physical camera region. Reduce Motion and Low Power Mode suppress geometry animation. No global input monitor or keyboard injection is used.

## Native Clock controls

Pause/Resume and Cancel are attempted through Apple's public Accessibility action mechanism on the native Clock app's existing controls. They are **experimental**, not a supported Clock integration API. [Apple AXPress action](https://developer.apple.com/documentation/applicationservices/kaxpressaction). There is no in-app timer engine, duration mirror, independent alarm, or new timer creation.

Controls appear only when a parsed English Clock timer has a unique semantic card identifier and enabled native buttons advertising AXPress. To bound work, control discovery covers at most the first three observed timers per scan. Unsupported cards remain observation-only with Open Clock available. Cancel asks for confirmation in the island.

Before sending an action the adapter rereads Clock, checks the PID, permissions, timer identity, observed state, countdown drift and freshness (five-second maximum), and compares the old and fresh AX card/button objects. Ambiguous, changed, stale, missing or unsupported controls do not receive actions. Commands are serialized and lifecycle teardown invalidates pending control work. After an action, the island reads Clock again; it does not optimistically fabricate a paused/canceled state.

The desktop inspection tool still fails with a ScreenCaptureKit capture error on this machine. Consequently these controls have **not** been demonstrated against the installed Clock UI. Synthetic fixtures test parsing and command eligibility, not native button behavior. Other locales and unsupported Clock versions may expose no controls. Do not describe this as universally working background timer control.

## Preserved behavior

All existing sports/parsers/expanded scorecards, music handling and native Clock observation remain. Calendar is read-only: ended events leave the island, the collapsed activity advances only to another event today, and Apple Calendar events are never edited or deleted. Clock control authorization does not authorize calendar edits.

## Validation

- 73 local executable checks: 21 core, 8 presentation, 21 Calendar, 23 notch geometry/control policy checks.
- Checks cover top anchoring, fixed camera center during expansion, negative display coordinates, bounded widths, non-overlapping three-panel geometry, three-slot selection/overflow, pull-down/push-up, same-day Calendar rollover and stale/wrong-timer/wrong-state control rejection.
- Actual SwiftUI primary/satellite views were rendered with synthetic cricket/Clock/Calendar fixtures in collapsed, expanded Calendar and expanded Clock states and visually inspected. Fixtures do not access real Calendar data or operate a real timer.
- Release Apple silicon packaging, plist validation and strict ad hoc signature verification are run. Full-Xcode CI also runs XCTest and builds both architectures. Hardware notch placement, live gestures/focus, native Clock AX actions and energy measurements still require on-device acceptance. The preview remains unnotarized.

Manual acceptance: hover and pull down at the physical notch; verify the camera gap stays fixed and controls avoid the camera; push up on the handle; scroll the agenda without collapsing; show cricket + native timer + same-day Calendar together; finish a Calendar event and verify only the island changes; pause/resume a test timer from the island only when identified native controls are offered; reject/cancel the confirmation once; test display removal, sleep and permission revocation.

This follow-up supersedes the earlier two-slot/below-camera/read-only-Clock design notes. The narrower current scope is authoritative; broader report stages remain future work.
