> **Current 1.4 behavior:** [Interaction update](INTERACTION-UPDATE.md) supersedes older Calendar-slot/tab-bar instructions below. Three live slots are reserved for sports, music and native Clock; Calendar is swipe-only. Setup is in the menu bar. Hold-and-swipe merges. The compact strip fits the camera band. Approval/delivery integrations remain unimplemented; the update documents supported hook research.

# Calendar follow-up — 1.2 preview

The calendar UI shown in the user's screenshot was not present in either available GitHub branch or source snapshot. This follow-up adds a native Apple Calendar integration to the existing preview and addresses the observed overflow with a bounded agenda. It preserves the prior sports, music and native Clock work.

## Exact behavior

- **Apple Calendar events are never edited or deleted.** The adapter only requests access and reads events. It has no EventKit save/remove calls.
- When an event ends, its card stops appearing in the island's upcoming agenda. The collapsed calendar activity immediately selects the next eligible event **today**, using an end-exclusive comparison (`end > now`). A next event can be later today or another event still in progress.
- If no eligible events remain today, the calendar activity leaves the compact slots. Tomorrow's events are not substituted. Other active activities can occupy the vacated slot.
- The expanded agenda still lists upcoming events over 14 days. That list is independent of the same-day compact selection. Reading/filtering this list never changes the Calendar database.
- Ongoing overnight events count as today's events. Timed appointments take precedence over all-day entries. All-day entries are a fallback if there are no timed entries remaining today. Overlaps use earliest start, then stable identity. Canceled and personally declined events are excluded when returned by EventKit.
- Start/end/midnight boundaries use one one-shot timer with 0.1-second tolerance. An ended event is removed from the in-memory display without requiring an EventKit notification or polling every second. Store changes, date/time-zone/clock changes and wake trigger reconciliation/refetch. Sleep/display sleep/inactive session clears personal event content and stops the scheduler; resume reads fresh data.

## Setup and privacy

Choose the menu-bar icon → **Apple Calendar… → Connect Apple Calendar**. Grant Calendar access when macOS asks. This is opt-in; access is not requested at launch. In the expanded calendar, choose **Show in island** to make Calendar the primary collapsed activity.

Calendar events stay on this Mac and are not logged, uploaded, or persisted by this feature. Titles, times and calendar colors come from EventKit's locally available calendars; remote sync freshness is controlled by macOS/account providers. Disconnect clears the island's event snapshot and scheduled boundary. It does not revoke the OS permission; that is managed in System Settings.

On macOS 14+, reading events requires the OS permission named Full Access, although this implementation performs reads only. macOS 12–13 uses the older event-access request. [Apple's permission documentation](https://developer.apple.com/documentation/EventKit/accessing-calendar-using-eventkit-and-eventkitui). Store changes refetch immutable event values rather than reusing stale managed EventKit objects. [Apple's change-notification guidance](https://developer.apple.com/documentation/EventKit/updating-with-notifications).

## Layout

The calendar uses a single agenda column with a compact date heading, grouped day labels, two-line event titles, calendar colors and NOW/NEXT badges. The scrolling viewport, black background and clipping bounds share the panel size. There is no separate overflowing date sidebar or “more events” label painted below the panel. Calendar panel height is capped to the display; the entire island is clipped to its rounded bounds. Full titles remain available in tooltips/accessibility text.

## Validation

- 21 calendar checks cover exact end-time rollover, gaps, overlaps, overnight/all-day events, same-day cutoff, next-day activation, deletion in an externally changed snapshot, invalid dates, deterministic ordering and DST midnight scheduling.
- Existing 21 core and 5 presentation checks also pass: 47 executable checks total. XCTest regression tests are included for CI.
- Release Apple silicon packaging, plist and ad hoc signature verification pass locally.
- Normal (560 × 390), narrow (360 × 260), and empty agenda fixtures were rendered from SwiftUI and visually inspected. Content stays inside the scroll viewport; no cards or labels paint below the background. The fixtures contain invented events, not the user's calendar.
- Real permission prompts, account-specific EventKit behavior, sleep/wake delivery, live end-time timing and VoiceOver remain manual checks. Full Xcode/XcodeGen and Intel runtime testing remain separate. The preview is ad hoc signed, not notarized.

Manual check: create or use two same-day events in Apple Calendar, show Calendar in the island, wait for the first end time, verify the second appears without a manual refresh, and verify both events remain in Apple Calendar. Repeat with only a tomorrow event remaining: no tomorrow event may appear in the collapsed island. Test a long title, many events, permission revocation, sleep across two boundaries, and midnight.
