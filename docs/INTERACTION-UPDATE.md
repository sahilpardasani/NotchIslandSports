# NotchIslandSports 1.4 — live slots, gestures and compact height

This is the current behavior, superseding the 1.3 Calendar-as-a-slot and tab-bar design. Existing sports parsers/scorecards, music handling, native Clock observation and read-only Calendar access are preserved.

## What changed

- **Up to three live activities:** sports, media and native Apple Clock. Calendar is excluded in the core selection policy even if explicitly preferred; it never creates a satellite, displaces a live activity or fills overflow. Future delivery providers remain unimplemented.
- **Calendar by swipe:** swipe horizontally on the collapsed strip, or the expanded header, to browse available live activities and Calendar. Calendar opens as an agenda page while live slot identities remain unchanged. Calendar is reachable when no events or live activities exist. Header arrows and menu → Select Widget provide accessible alternatives. Returning to collapsed mode restores the live primary.
- **Hold and swipe to merge:** click/press and hold still for at least 0.35 seconds, then drag horizontally more than 20 points on the main strip/header or a satellite. The recognizer is exclusive with ordinary swipe recognition, so merging does not also change the primary activity. All live activities remain tracked and reachable. Merge survives provider refreshes and app restart. Menu → Separate Live Activities (up to 3), or Command-S while the app handles keyboard input, restores the split. VoiceOver has explicit merge/separate/next/previous actions.
- **Menu-bar management:** Select Widget, Select Sport, Select Match, Calendar Settings, Clock Settings, Experimental System Media, Refresh and Simulate Notch live in the menu. Calendar connection/disconnection and native Clock permission/refresh/disable/open-app controls no longer occupy the island. Player transport and verified native timer Pause/Resume/Cancel remain on their activity pages.
- **Smaller collapsed strip:** on a normal 32-point camera/menu-bar band the old 36-point panel is now 32 points high, including both satellites. It stays flush with the top edge and no longer extends four points into the app below. The physical camera gap and center remain fixed. Non-notched displays use 33 points instead of 36. This is a point-based adjustment; physical millimeters vary with display scaling.
- **Transitions:** downward expansion uses a 0.30-second eased AppKit resize and upward collapse 0.24 seconds, with a fixed top/camera center. A 0.18-second opacity transition changes the content, with the expanded content laid out at its destination height and clipped by the moving panel rather than compressed during expansion. Satellites fade on merge/split. Duplicate refreshes do not restart an in-flight resize. Reduce Motion and Low Power Mode suppress geometry/content animation. Expanded scrolling and sliders retain their gestures; header swipes navigate. Vertical trackpad scrolling on the header pulls down or pushes up. No global input monitor or continuous animation timer was added.

Calendar events still advance at their end boundary to the next eligible event **today**; ended events leave the island's agenda. The adapter never deletes, saves or changes an Apple Calendar event. The expanded agenda may include future dates. There is no calendar compact activity in this version.

## Native Clock limitations

Only real Apple Clock timers are observed. No in-app timer engine, alarm or substitute timer is present. Observation and controls remain an opt-in experimental Accessibility adapter. Native Pause/Resume/Cancel appear only when the existing Clock UI exposes uniquely identified, enabled native buttons; fresh state and identity are rechecked before each action. Cancel requires confirmation. Unsupported or ambiguous UI cannot be controlled. Keep Clock's Timers view open; hidden/closed/unreadable views may not expose a timer. Real Clock compatibility, focus behavior and gestures still need hardware testing. Synthetic fixtures are not proof of native timer control.

## Approval notifications and delivery status

**ChatGPT/Claude approval notifications are not implemented in this build.** There is no notification interception, fake approval badge or automated click of an Approve button.

Current official documentation does offer narrower routes worth implementing in a separate, opt-in adapter:

- [OpenAI lifecycle hooks](https://learn.chatgpt.com/docs/hooks) document Codex `PermissionRequest` and normal-flow fallthrough when a hook returns no decision. This supports a future notification-only relay for configured Codex sessions. It does not establish a universal subscription to every ChatGPT desktop approval. [ChatGPT notifications](https://learn.chatgpt.com/docs/notifications) document the app's own permission/question alerts, not a cross-app notification feed.
- [Claude Code hooks](https://code.claude.com/docs/en/hooks) document `PermissionRequest` and `Notification` with `permission_prompt`. The reference describes permission notifications in Claude Code sessions hosted by Claude Desktop (version-dependent timing/support). That is narrower than generic Claude Chat/Cowork approval interception.
- A future relay must require explicit setup, authenticate its local sender, bound/deduplicate/expire payloads, avoid storing prompts or commands by default, stop on disable/sleep, and route the user to the originating approval. Notification hooks must return no allow/deny decision. Live approval acceptance requires a separate validated request/response contract and explicit user action.
- Apple Maps and Uber Eats/DoorDash/Swiggy/Zomato tracking remain future work. No existing public source in this implementation provides their live state. macOS/iPhone Live Activities are not automatically available to this app. A delivery adapter would be eligible for a live slot only after it can provide real, consented, fresh data.

## Validation

90 local executable checks: 21 core, 23 presentation, 21 Calendar, 25 geometry/native-control checks. Added regression coverage includes Calendar exclusion even when preferred/alone, three live slots, bidirectional browsing, Calendar availability changes while its page stays open, merge persistence, no double cycle on held drag, threshold rejection, and collapsed height equal to the camera band. Existing same-day event rollover and stale native-control checks still pass.

The actual SwiftUI views were rendered with synthetic sports/music/Clock/Calendar data in split, merged and expanded states and inspected. No real Calendar data was accessed and no native timer was operated by these fixtures. Release packaging, plist validation and strict ad hoc signature verification were run locally. Full-Xcode CI runs XCTest and builds both architectures; check the PR for its result at the current commit.

These checks do not establish measured animation frame pacing, live Clock compatibility, VoiceOver behavior, energy savings or Intel runtime compatibility. Preview packaging is ad hoc signed and unnotarized. No Xcode editor is needed to run the packaged app; command-line builds remain supported with a compatible Swift/macOS SDK toolchain. See [BUILDING.md](BUILDING.md).

## Manual acceptance

1. Quit the old instance and open this build; at the physical notch the collapsed strip must fit the top band and leave app content below unobscured. Verify scaled displays and external-display removal.
2. Enable sports + music + readable Clock timer: three live activities; connect Calendar and confirm no additional slot or displacement.
3. Swipe to Calendar, scroll vertically through the agenda, swipe the header back, then collapse. Let today's event end and confirm advancement inside the agenda without editing Apple Calendar.
4. Hold then drag the main strip or a satellite sideways: merge once without changing the primary. Refresh, restart, then restore Separate Live Activities from the menu.
5. Pull down / swipe up repeatedly and reverse direction mid-animation. The top anchor must stay fixed; content must not jump or compress. Test both click-drag and trackpad horizontal scrolling, mouse hover, Escape and header arrows. Check frame pacing on the actual display.
6. Repeat with Reduce Motion/Low Power Mode, permission revocation, screen sleep and lock/unlock. Confirm no stuck invisible satellite, unexpected app focus or extra polling.
