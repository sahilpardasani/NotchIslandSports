> **1.5 update:** [Restored UI and timer controls](TIMER-UI-RESTORATION.md) is the current UI/Clock behavior. Headerless scorecards, bottom handle, compact countdown with circular native buttons; setup stays in the menu bar.

> **Current preview:** [Version 1.6 build 10](PREVIEW-1.6.md) supersedes historical interaction/setup descriptions below. Calendar is a compact swipe page, native Music/Spotify share the system media activity, and inward satellite swipes merge. Local permission-hook approvals are implemented with explicit user decisions; generic desktop chat approvals remain unavailable. See [APPROVALS.md](APPROVALS.md) and the preview notes for exact coverage and live-test limitations.

> **Current 1.4 behavior:** [Interaction update](INTERACTION-UPDATE.md) supersedes older Calendar-slot/tab-bar instructions below. Three live slots are reserved for sports, music and native Clock; Calendar is swipe-only. Setup is in the menu bar. Hold-and-swipe merges. The compact strip fits the camera band. Approval/delivery integrations remain unimplemented; the update documents supported hook research.

> Latest follow-up: [notch restoration and three activities](NOTCH-RESTORATION.md) supersedes the earlier below-camera/two-slot placement and observation-only Clock behavior. Clock controls are now experimental and user-triggered; Calendar remains strictly read-only.

# NotchIslandSports implementation report

**For:** Astra/Fabel or another AI coding agent  
**Prepared:** October 27, 2026  
**Repository:** [sahilpardasani/NotchIslandSports](https://github.com/sahilpardasani/NotchIslandSports)  
**Inspected revision:** [`eb1b54dd38f9bf90012f3735ed757cec4e311cd1`](https://github.com/sahilpardasani/NotchIslandSports/tree/eb1b54dd38f9bf90012f3735ed757cec4e311cd1), default branch `main`; commit dated May 26, 2026.

## 1. Decision and scope

Evolve the existing SwiftUI/AppKit application into a small activity host. Preserve its sports models and useful expanded views, replace mutually exclusive sports/media modes with a deterministic activity coordinator, and fix lifecycle, networking, rendering, and playback correctness before adding external integrations.

An iPhone-inspired split presentation is achievable with the application's own AppKit panels and SwiftUI views. It must be described as a custom Mac overlay. It cannot be assumed to receive Apple’s or other developers’ Live Activity payloads. Apple documents iPhone Live Activities appearing in the Mac menu bar on macOS Tahoe 26 and later; this is a system-managed experience, not an API for importing those activities into this notch overlay. The broad ActivityKit description mentioning Mac does not establish native cross-app activity access. [Apple’s continuity behavior](https://support.apple.com/en-ie/120684), [ActivityKit](https://developer.apple.com/documentation/ActivityKit).

Ship a reliable first release with split sports/media, accessible animations, and measured energy improvements. The user explicitly requires **native Apple Clock timers only**: do not add app-owned timers, copied Shortcut countdowns, custom timer alarms, or a substitute timer engine. Add native Clock observation and ChatGPT/Claude desktop observation only behind explicit experimental gates. Prefer approved official delivery integrations; use a narrowly scoped browser extension only where an actual, permitted tracking page exists and has been validated.

### Implementation follow-up (October 27, 2026)

An initial preview now implements lifecycle/polling fixes, request-generation checks, four-request network concurrency, stable two-slot sports/music/Clock selection, targeted Music/Spotify controls, and an opt-in read-only Clock AX prototype. All 13 sports and their scorecards remain in the source. See the companion `IMPLEMENTATION.md` and `BUILDING.md` for exact implementation scope and validation. This report remains the broader staged plan; its future exit gates are **not** claims that every feature is implemented. Native Clock has synthetic parser checks only; no live UI compatibility or measured battery benefit is claimed.

### Evidence boundaries

- The source snapshot was retrieved through GitHub, including all 56 Swift/Markdown/plist/YAML files. Core lifecycle, panel, media, networking, sports coordination, representative feed parsers, views, and build definitions were inspected. The repository ZIP was not executed or verified against source.
- The referenced conversation was read. It confirms simultaneous activities, native Clock timers, desktop approval alerts, Maps, four delivery services, animations, and lower battery use. Earlier assistant replies were returned as opaque content references, so their assertions are not treated as evidence.
- At the original report stage, a Release SwiftPM build was attempted with Apple Swift 6.4 and the selected Command Line Tools. It failed before source compilation: the first attempt encountered a module-cache access restriction; after redirecting caches into the workspace, SwiftPM's manifest sandbox failed with `sandbox-exec: sandbox_apply: Operation not permitted`. This does **not** establish that repository code fails to compile. That original attempt did not establish a successful build. Consult the follow-up validation notes for later build results; UI execution, native integration compatibility, notarization and energy measurement remain unverified.
- All numerical budgets below are proposed engineering acceptance targets, not measured results or promises of additional battery hours. Integration availability was researched on the report date and must be revalidated when implementation starts.
- Source links below are pinned to the inspected commit. Rebase the findings against the agent's actual checkout before editing. Do not treat README marketing claims as test results.

## 2. Repository-specific findings and immediate fixes

| Priority | Evidence in the inspected code | Required change and verification |
|---|---|---|
| P0 | [`NowPlayingManager.swift:192`](https://github.com/sahilpardasani/NotchIslandSports/blob/eb1b54dd38f9bf90012f3735ed757cec4e311cd1/Sources/Services/NowPlayingManager.swift#L192) sends System Events key codes 16, 19, and 20 for playback. These are ordinary keyboard key codes, not media transport commands. | Remove these actions. Route play/pause/next/previous to the identified provider using its supported commands; otherwise disable the control. Verify no characters appear in an unrelated focused editor. |
| P0 | [`SportsDataManager.swift:765`](https://github.com/sahilpardasani/NotchIslandSports/blob/eb1b54dd38f9bf90012f3735ed757cec4e311cd1/Sources/Services/SportsDataManager.swift#L765) captures the selected match, awaits a detail request, then unconditionally assigns `activeMatch = updatedMatch` at line 843. | Add request generations and identity checks. A slow response for match A must never overwrite match B selected while A was in flight. Cancellation alone is insufficient. |
| P1 | [`AppDelegate.swift:111`](https://github.com/sahilpardasani/NotchIslandSports/blob/eb1b54dd38f9bf90012f3735ed757cec4e311cd1/Sources/App/AppDelegate.swift#L111) calls `startPolling()` and launches another initial fetch; wake calls `startPolling()` plus `refresh()`. [`SportsDataManager.swift:404`](https://github.com/sahilpardasani/NotchIslandSports/blob/eb1b54dd38f9bf90012f3735ed757cec4e311cd1/Sources/Services/SportsDataManager.swift#L404) already fetches immediately. | Give one lifecycle coordinator ownership. Deduplicate launch, wake, manual, and scheduled refreshes. Retain task handles; stopping timers currently does not cancel outstanding requests/tasks. |
| P1 | Sports discovery runs every 30 seconds and selected detail every 15 seconds. `fetchAllMatches()` invokes 13 services regardless of the UI sport filter. Cricket and tennis each fan out over three dates; soccer covers nine leagues. | Separate subscribed live scores, expanded detail, and background discovery. Filter requests by enabled sports/leagues, cache historical dates, bound concurrency and retries. Count HTTP requests, not just top-level refresh calls. |
| P1 | [`NotchPanelController.swift:252`](https://github.com/sahilpardasani/NotchIslandSports/blob/eb1b54dd38f9bf90012f3735ed757cec4e311cd1/Sources/Panel/NotchPanelController.swift#L252) observes every `dataManager.objectWillChange` and schedules an animated panel frame update. | Observe an equatable layout descriptor only. A score, loading, or error update that leaves geometry unchanged must cause zero frame mutations. |
| P1 | [`NotchContentView.swift:87`](https://github.com/sahilpardasani/NotchIslandSports/blob/eb1b54dd38f9bf90012f3735ed757cec4e311cd1/Sources/Views/NotchContentView.swift#L87) owns the media manager. `showMediaMode` switches collapsed content between sports and media. Expansion geometry is duplicated between this view and the panel controller; the view allows media height 160 while the controller bases height on sports. | Move service ownership to the composition root. Introduce activity selection and one shared layout calculation. Views should render snapshots and dispatch actions, not start providers. |
| P1 | [`NowPlayingManager.swift:48`](https://github.com/sahilpardasani/NotchIslandSports/blob/eb1b54dd38f9bf90012f3735ed757cec4e311cd1/Sources/Services/NowPlayingManager.swift#L48) loads `/System/Library/PrivateFrameworks/MediaRemote.framework` and `MRMediaRemoteGetNowPlayingInfo`; a 1.5-second timer starts at initialization. | Explicitly label this implementation private/unsupported. Isolate behind a build flag and capability probe, default off in the supported build. Provide start/suspend/stop and bounded callback handling. Never call symbol lookup success proof of compatibility. |
| P1 | Media artwork is decoded and its color computed before comparing the new track with the old one, even if bytes are unchanged. Elapsed time is part of equality. | Separate metadata from position anchors; cache artwork/color by digest, downsample once, and avoid metadata publication for every progress tick. Keep decoding away from UI execution where safe. |
| P1 | [`NowPlayingViews.swift:12`](https://github.com/sahilpardasani/NotchIslandSports/blob/eb1b54dd38f9bf90012f3735ed757cec4e311cd1/Sources/Views/NowPlayingViews.swift#L12) has a 0.15-second random waveform timer; line 145 has a 0.1-second progress timer. Progress adds 0.1 at line 327, so delayed ticks drift. Paused waveform still receives timer callbacks. | Replace accumulated ticks with time anchors. Disable decorative motion by default in compact mode; stop its scheduling when paused/hidden/locked. A view remaining mounted is not permission to keep running a clock. |
| P1 | The panel is 600/500 points wide even when visible content is narrower. Hover tracking uses the entire visible rect; `hitTest` delegates to its superclass and `ignoresMouseEvents` is false. | Test transparent-window click interception explicitly. Use correctly sized separate surfaces for the primary and detached secondary activity if necessary; SwiftUI `contentShape` alone does not prove click-through to another application. |
| P1 | [`NotchContentView.swift:103`](https://github.com/sahilpardasani/NotchIslandSports/blob/eb1b54dd38f9bf90012f3735ed757cec4e311cd1/Sources/Views/NotchContentView.swift#L103) and [`CollapsedScoreView.swift:16`](https://github.com/sahilpardasani/NotchIslandSports/blob/eb1b54dd38f9bf90012f3735ed757cec4e311cd1/Sources/Views/CollapsedScoreView.swift#L16) clamp the camera spacer to 170 points. Panel positioning uses `NSScreen.main`. | Derive camera exclusion from each chosen display's measured geometry; never cap it below the physical cutout. Persist display choice and handle display removal and coordinate transforms. |
| P1 | [`APIClient.swift:36`](https://github.com/sahilpardasani/NotchIslandSports/blob/eb1b54dd38f9bf90012f3735ed757cec4e311cd1/Sources/Services/APIClient.swift#L36) already has URLCache, 15/30-second timeouts, and protocol cache policy. It does not coordinate duplicate requests, retry schedules, or provider freshness. | Retain those useful pieces. Add single-flight requests, bounded response sizes, Retry-After handling, conditional validation when supported, endpoint TTLs, and cancellation preservation. Do not claim the app currently has no cache. |
| P1 | Empty sport results fall back to old arrays; several parsers catch endpoint errors and return empty arrays. There are no per-provider freshness timestamps. | Distinguish successful empty, partial, failed, and stale responses. A genuinely empty day must eventually clear obsolete games. A failed provider must not silently look live. |
| P2 | `AnyMatch.id` returns a bare upstream ID; merging and restoring often match only that ID. | Use provider/sport/league/event composite identity. Migrate saved selections rather than silently forgetting them. |
| P2 | Sleep handling stops only sports timers. Screen-change observation exists in both AppDelegate and panel controller. Source search found no implemented Reduce Motion behavior and almost no accessibility-specific labeling beyond the menu icon. | Centralize event observers, store/remove tokens, suspend all providers and visuals, and add a keyboard/VoiceOver interaction path. Do not confuse missing explicit labels with proof that all default SwiftUI accessibility is absent. |
| P1 release | [`project.yml`](https://github.com/sahilpardasani/NotchIslandSports/blob/eb1b54dd38f9bf90012f3735ed757cec4e311cd1/project.yml) uses ad hoc signing and disables Hardened Runtime. [`Info.plist`](https://github.com/sahilpardasani/NotchIslandSports/blob/eb1b54dd38f9bf90012f3735ed757cec4e311cd1/Sources/App/Info.plist) permits arbitrary network loads and lacks an Apple Events usage explanation. | Separate Debug/Release signing, remove global ATS bypass after endpoint verification, and add only permissions needed by enabled features. Fix resource/build parity; do not ship a quarantine-removal recipe as the release installation path. |

The source tree has no test target or CI workflow. `Package.swift` declares Swift tools 5.9, macOS 12, and one executable with no resources; it excludes the plist. `project.yml` describes an application target and resources. This is two different packaging paths, not two already-equivalent application builds. [Package definition](https://github.com/sahilpardasani/NotchIslandSports/blob/eb1b54dd38f9bf90012f3735ed757cec4e311cd1/Package.swift).

## 3. Integration feasibility: public, conditional, experimental, unavailable

**Labels:** Public = documented underlying API; Conditional = documented service but account/access/version constraints; Experimental = mechanism exists but target data contract is unstable or unverified; Private = undocumented Apple implementation; Unavailable = no supported route established for the requested behavior. A public mechanism does not automatically make an integration supported.

| Requested capability | Classification and honest delivery promise |
|---|---|
| Split island and animation | **Public, app-owned UI.** AppKit panels and SwiftUI can present two activities. This does not modify hardware or Apple's Dynamic Island implementation. |
| Sports | **Existing implementation, unofficial feed contract.** ESPN endpoints in source are reachable-style web feeds, not evidence of a licensed public developer API or SLA. Retain via an adapter, fixtures, freshness, and limits; assess provider permission/licensing before wider distribution. |
| Universal Now Playing | **Existing private integration.** No supported universal cross-app metadata/control API was established in this review. `MPNowPlayingInfoCenter` publishes an app's media information; it is not a reader for all players. App-specific scripting or a browser extension can support a narrower, validated list. [Apple media API](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter). |
| App-owned timers | **Excluded by the user.** Do not implement them, even as a fallback when native Clock is unavailable. |
| Automatically mirror arbitrary native Clock timers | **Experimental; supported full synchronization unavailable.** No documented cross-app Clock timer enumeration/change stream was established. AlarmKit concerns alarms created for your app, not permission to read Clock's database. A Shortcut-started mirror or AX observation needs separate validation. [AlarmKit](https://developer.apple.com/documentation/AlarmKit?language=o_8), [Clock timer behavior](https://support.apple.com/en-gw/guide/clock-mac/apdw3d5aebf9/mac). |
| ChatGPT desktop approvals | **Native notifications exist; third-party event subscription not established.** OpenAI documents permission/question notifications. This does not give NotchIsland access to them. Prototype targeted Accessibility observation only with opt-in; otherwise offer Open ChatGPT and ordinary native notifications. [OpenAI notifications](https://learn.chatgpt.com/docs/notifications). |
| Claude desktop approvals | **Surface-dependent.** Generic Claude Chat/Cowork approval observation is not proven by Claude Code hooks. Claude Code has documented hooks; test whether the exact Desktop Code session and execution host honor the relevant settings. AX is a separate experimental fallback. [Claude hooks](https://code.claude.com/docs/en/hooks), [Desktop documentation](https://code.claude.com/docs/en/desktop). |
| Apple Maps | **Public for an app-owned route/ETA; automatic observation unavailable.** MapKit computes a requested route and ETA, and can open Maps. It does not establish access to the route currently selected in the Maps app or its live maneuver stream. [MKDirections](https://developer.apple.com/documentation/mapkit/mkdirections). |
| Uber Eats | **Conditional official path.** Uber Consumer Delivery APIs describe tracking, account linking, and order history, but detailed access is early-access/case-by-case. Existing Eats merchant APIs are not a general consumer-account reader. Validate whether orders placed outside this integration are visible. [Consumer Delivery](https://developer.uber.com/docs/consumer-delivery/introduction), [merchant integration](https://developer.uber.com/docs/eats/guides/order-integration). |
| DoorDash | **Conditional business integration; generic consumer tracking unproven.** Drive retrieves deliveries created by the integration; Marketplace partner APIs have limited access. Neither establishes reading an arbitrary user's DoorDash app orders. A user-provided tracking link may be opened without parsing. [Drive API](https://developer.doordash.com/en-US/api/drive/), [Marketplace access](https://developer.doordash.com/en-US/docs/marketplace/faq/getting_started/). |
| Swiggy | **Documented official MCP route, access-gated production.** `track_food_order` documents status/ETA and active orders; `get_food_orders` documents order history. Use approved OAuth/client access and validate account coverage. Do not claim Swiggy lacks an official integration. [Tracking tool](https://mcp.swiggy.com/builders/docs/reference/food/track_food_order/), [order list](https://mcp.swiggy.com/builders/docs/reference/food/get_food_orders/), [developer access](https://mcp.swiggy.com/builders/docs/start/developer/). |
| Zomato | **Official MCP exists; restricted/unresolved permission for this app.** The current README offers personal-use access requests and restricts OAuth redirects, while also retaining a disclaimer against third-party apps without integration discussion. Obtain explicit provider approval for this use and distribution. Do not label generally available or impossible. [Official manifest](https://github.com/Zomato/mcp-server-manifest/blob/master/README.md). |
| Read all macOS Notification Center content | **No public notification-listener API established.** `UNUserNotificationCenter` manages your app's notifications, including delivered items. It cannot be used as a ChatGPT/Claude/Clock notification scraper. [Apple API scope](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter?language=objc). |

Do not use Notification Center databases, private Clock stores, process injection, cookie extraction, undocumented cross-app broadcasts, or screen/OCR polling as the production design. A private MediaRemote experiment is already a separate risk; it must not become a pretext for adding more private system integrations. Notarization does not turn private APIs into supported APIs.

## 4. Proposed architecture and migration map

Retain the macOS 12 baseline initially. Use `ObservableObject`/Combine and availability-gated newer APIs; adopting Observation, newer animation APIs, App Intents, or Swift concurrency clock conveniences must not silently raise the deployment target. Choose an explicit minimum supported OS in Stage 0 and test it. Native Clock is not present on every macOS version the current app targets.

```text
AppDelegate / AppEnvironment
  ├─ LifecycleCoordinator + PermissionCenter + PowerPolicy
  ├─ ProviderRegistry
  │   ├─ SportsProvider → existing service parsers → HTTPClient
  │   ├─ MediaProvider → supported per-app adapters / optional private adapter
  │   ├─ NativeClockProvider → opt-in, read-only experimental Clock adapter
  │   ├─ ApprovalProvider → authenticated hook bridge / experimental AX adapters
  │   ├─ RouteProvider → explicit MapKit route
  │   └─ DeliveryProvider → approved official adapter / optional browser bridge
  └─ ActivityStore → ActivityCoordinator → LayoutDescriptor
                                        └─ NotchPanelController → SwiftUI views
```

### Core contracts

These are proposed types, not claims that the repository already implements them:

```swift
struct ActivityID: Hashable, Codable, Sendable {
    let provider: String
    let accountScope: String // opaque local identifier, not an email/address
    let externalID: String  // sport + league + event where appropriate
}

enum ActivityKind: String, Codable, Sendable {
    case sports, media, timer, approval, route, delivery
}

enum ActivityPhase: String, Codable, Sendable {
    case active, paused, needsAttention, completed, cancelled, unknown
}

// Define typed, Sendable payload structs; do not pass [String: Any] to the UI.
// ActivitySnapshot: id, kind, phase, revision, sourceGeneration,
// observedAt, providerUpdatedAt?, staleAfter, expiresAt?, confidence,
// sensitivity, capabilities, typed payload, allowed action identifiers.
// ProviderCapability: supported / needsPermission / needsAccount /
// unavailable(reason) / experimental / degraded(lastSuccess, reason).
```

Keep transport state separate from domain state: a network failure makes an active delivery stale, not cancelled; permission revocation makes a provider disconnected, not completed. Confidence should distinguish authoritative, observed, inferred, and manual data. Both timestamps and source labels must be available to expanded UI.

Use an actor-owned store and typed provider events (`upsert`, `remove`, `capabilityChanged`). Project a small equatable presentation model onto the main actor. Retain bounded event buffering; coalesce redundant score/progress updates but preserve terminal and attention transitions. Reject older revisions and events from a cancelled/replaced provider generation. Do not let transport timestamps alone reorder a newer domain state.

Each provider exposes idempotent `start`, `suspend(reason)`, `resume`, `stop`, event delivery, and an action handler. `stop` cancels requests, timers, subscriptions, observers and child processes. Provider startup belongs to the app environment, not a SwiftUI `body`, `.onAppear`, or child `@StateObject`.

`ActivityCoordinator` is a pure selection reducer with an injected clock and user preferences. It produces primary ID, optional secondary ID, overflow IDs, expanded ID, and transition reason. It must be independently testable without AppKit, network access, or real timers.

`LayoutDescriptor` is the single geometry source: target display, camera exclusion, compact/expanded state, primary/secondary frames, content sizes, safe padding, and animation policy. AppKit and SwiftUI consume the same descriptor. Compare before committing frames; publish text changes separately from layout changes.

### Suggested source changes

| Location | Migration |
|---|---|
| `Sources/App/AppDelegate.swift` | Composition root, status-menu actions, lifecycle wiring; remove duplicate startup/wake work. |
| `Sources/Core/Activities/` (new) | IDs, payloads, reducer, store, capability/freshness rules, action dispatcher. |
| `Sources/Core/Scheduling/` (new) | Poll coordinator, request budget, clock abstraction, power/lifecycle policy. |
| `Sources/Services/SportsDataManager.swift` | Initially wrap with SportsProvider, then move feed scheduling out. Keep a temporary presentation facade for existing sports views. |
| `Sources/Services/NowPlayingManager.swift` | Split metadata adapter, transport controls, artwork cache, position anchor, and optional private adapter. |
| `Sources/Providers/{Timers,Approvals,Routes,Delivery}/` (new) | Independent integrations with documented capability probes and fixture adapters. |
| `Sources/Panel/` | Shared layout engine, display selection, one panel coordinator, tested hit regions. |
| `Sources/Views/NotchContentView.swift` | Render `IslandPresentation`; replace `showMediaMode` and duplicated dimensions. |
| `Sources/Views/NowPlayingViews.swift` | Local progress rendering, source-specific controls, static/optional decorative waveform. |
| `Tests/` and fixtures (new) | Reducer, scheduling, parser, cancellation/race, persistence, privacy, and UI regression coverage. |

Extract a small `IslandCore` SwiftPM library and test target, with UI remaining in the executable/app target. Make XcodeGen consume the same core files/package without duplicate compilation. Preserve current saved sport/match preferences using a versioned migration.

## 5. Split presentation, interaction, and animation specification

### Layout states

| State | Behavior |
|---|---|
| No active activities | Quiet idle capsule or user-selected hidden state; no continuous animation. Menu item remains discoverable. |
| One activity | Single compact island; reserve the actual physical camera rectangle. |
| Two activities | Primary compact island plus a detached minimal secondary bubble with an initial 8-point visual gap. This is two activities, not the two teams of one match. |
| Three or more | Stable primary and secondary, with remaining items in an expanded activity list. No automatic carousel by default. |
| Expanded | Expand the selected activity below the camera-safe area; retain a usable route to the other activity. Escape returns to compact. |
| Unavailable provider | Explain the missing permission/account/capability in settings. Never fill the island with simulated live data outside a visibly labeled demo. |

On notched screens, place readable content beside or below the cutout. The secondary bubble must fit entirely in drawable space and must not silently cover essential menu-bar controls. If width is insufficient, move the compact presentation below the menu bar or use a user-selected floating position. Never draw important content behind the camera. On non-notched screens, use a centered floating layout. Hardware architecture (Intel/Apple silicon) does not determine whether a display has a notch.

Use `NSScreen.safeAreaInsets`, auxiliary top areas, and actual screen coordinates, with fallback bounds validation. Prefer a stable display ID over `NSScreen.main` as persistent identity. Test nonzero/negative display origins, scaled modes, menu-bar auto-hide, Spaces, full-screen apps, clamshell mode, unplug/replug, and changing the primary display. [NSScreen geometry](https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets).

### Deterministic selection rules

1. Exclude dismissed, expired, unsupported, and disconnected-without-valid-snapshot activities from automatic promotion. User-pinned stale content can remain with a visible stale label.
2. Preserve an activity currently expanded or being interacted with. Attention events may mark the other slot; never steal keyboard focus or replace an approval being reviewed.
3. Initial default ranking: confirmed native Clock expiration only when explicitly observable, confirmed approval waiting, delivery arrived/route event requiring attention, user-pinned activity, live sport, playing media, running timer, active delivery/route estimate, paused media, completed history.
4. This ranking is a product default, not an OS requirement. A pinned sport plus media should remain split during routine updates; promote a timer near expiry using a defined 30-second threshold only once, without repeated swapping.
5. Break ties by user selection, current slot occupancy, creation order, then stable ID. Use an initial 5-second minimum dwell for nonurgent automatic replacements. Never rank by every refresh timestamp.
6. On completion, preserve a compact result briefly (initial 10 seconds) then merge if only one activity remains. Timer alerts wait for acknowledgment; stale approvals become “Status unknown” after their source-specific timeout, not silently “Approved.”

### Interaction

- Hover either region to preview that activity with a cancellable 120–180 ms debounce. Movement between regions must not collapse/reopen repeatedly. Click pins expansion; Escape dismisses it.
- A menu action and configurable keyboard shortcut open the island without hovering. Tab/Shift-Tab traverse controls, Enter/Space activates, and focus returns to the invoking app when closed.
- Clicking an approval opens the source app or a verified deep link. Do not invent conversation URL schemes. Initial implementation has no Approve/Deny buttons for scraped UI.
- A secondary bubble has a meaningful accessible name/value and at least a 32 × 32-point usable target, preferably 44 × 44 where layout permits. Transparent gap and margins must pass clicks through; test with clickable controls behind the panel.
- Use separate borderless nonactivating panels for disjoint compact surfaces if this is the cleanest way to eliminate a large invisible blocking rectangle. Coordinate them as one presentation; use an explicit focusable expanded surface for keyboard input. Do not assume the current panel's `becomesKeyOnlyIfNeeded` solves every keyboard interaction.

### Animation policy

Start with a 0.30–0.38-second split/merge transition, modest spring damping around 0.85, and a 0.12–0.18-second content crossfade. These values are tunable design inputs. Use stable activity identities and shared geometry; avoid recreating provider/view ownership during transitions.

Choose one owner for outer window geometry. Do not simultaneously drive the same dimensions with unrelated AppKit frame animations and SwiftUI springs. Bound transient expansion so shadows and content do not clip. Interrupted animations must retarget from the current presentation, not jump back to the previous model frame.

Reduce Motion uses an immediate geometry change or a short opacity transition; eliminate bounce, scaling, and decorative pulses. Reduce Transparency uses opaque surfaces. Low Power Mode disables ambient waveform and looping live indicators. Data changes may animate briefly; steady-state content must settle with no per-frame rendering loop.

**Acceptance:** sports+media, media+timer, sports+timer, and timer+approval each render as two independently accessible activities; 100 rapid add/remove/update sequences leave no orphan panels, wrong activity content, or leaked subscriptions. A third activity remains reachable. The expanded activity survives unrelated score updates. Split/merge preserves camera exclusion, pointer routing, and focus at every tested display scale.

## 6. Provider implementation details and acceptance criteria

### 6.1 Sports

Preserve the 13 current sport cases and the detailed cricket, tennis, football, soccer, baseball, basketball, hockey, F1, and generic views. Keep Hindi presentation and existing match selection behavior unless a specific regression is approved. Avoid a wholesale parser rewrite while introducing the activity layer.

Separate discovery data from subscribed score data and rich detail. An expanded scorecard may need detail more often; a collapsed score must still update from the cheapest sufficient source. Do not stop all sports updates merely because the user collapses the panel.

For each endpoint record schema version/fixture, league/date identity, fetch time, last successful payload, HTTP validators, freshness budget and request cost. Cache previous-day/final data longer than live scores. Initial discovery should cover enabled sports, with explicit on-demand “all sports” browsing. A provider error must remain distinct from an empty successful result. Preserve last known data only with age and status.

Use composite IDs throughout persistence and merge logic. Capture match identity and selection generation before awaiting detail; validate both before publishing. Merge scoreboard and detail using field ownership/freshness rather than allowing older detail to overwrite newer scores. Record a bounded hash/version for semantic equality so unchanged payloads do not rebuild the view tree.

**Acceptance:** fixture tests for live/upcoming/final/postponed/abandoned/malformed/empty/partial responses; delayed A detail cannot replace B; duplicate IDs from different sports do not collide; a provider outage is visibly stale; a recovery clears stale status; cricket over notation is not treated as a decimal fraction; no regressions in saved match/league restoration or Hindi labels. Feed freshness SLO is measured from fetch completion to render, separately from unknown upstream delay.

### 6.2 Now Playing

Move the manager out of `NotchContentView`. Each adapter supplies source identity, metadata, playback state, position/rate anchor, artwork reference, and explicit supported commands. A browser adapter must identify one selected tab/media element; multiple players cannot all respond to one action.

Supported-route candidates are Music/Spotify automation where their installed scripting dictionaries support the required operations, provider APIs with appropriate authorization, and a consented browser extension for known sites. Availability varies; validate and publish a tested matrix. Apple Events require Automation consent and a meaningful `NSAppleEventsUsageDescription`; Hardened Runtime/sandbox entitlements depend on the chosen packaging and target. Do not request blanket Accessibility for an integration that only needs Apple Events.

Retain MediaRemote only as an isolated optional experiment: runtime symbol checks, OS/build compatibility matrix, timeout/late-callback rejection, zero polling when disabled, and graceful “Unavailable” state. Do not replace one private function with another and call it public. An out-of-process helper may contain crashes but does not change API support status.

Replace current all-browser/all-player seek scripts. A command targets the source that produced the displayed track; unsupported seek, next, or previous controls are absent/disabled. Do not launch Music or Spotify while discovering players. Handle player termination and source switching without stale controls.

Position is `anchorPosition + elapsedContinuousTime * playbackRate`, clamped to known duration. Re-anchor on pause, seek, track change and provider updates. Unknown duration/live streams use an indeterminate presentation. Progress rendering may update once a second while visible; smooth scrubbing is allowed during direct interaction. Artwork is decoded/downsampled once per content hash and stored in a bounded cache. Random bars are decorative, not an audio waveform; no microphone/system-audio capture is needed.

**Acceptance:** two players plus two video tabs demonstrate controls affect only the displayed source; paused/ended/closed players stop their animation tasks; one artwork change causes one decode; unchanged metadata causes no panel layout mutation; sleep/wake does not accumulate progress drift; missing private symbols do not crash the supported build; no ordinary keystrokes are injected into another app.

### 6.3 Native Apple Clock timers only

The user explicitly excludes in-app timers. Implement one native Clock observation provider; do not create/pause/resume/cancel timers inside NotchIsland, persist substitute deadlines, schedule timer notifications, copy durations from Shortcuts, or infer expiration from a local countdown. Apple Clock owns timer creation, state, and alarms. An “Open Clock” action is appropriate.

**Native Clock bridge (experimental):** Investigate actual supported macOS/Clock versions: available Shortcuts actions, scripting dictionary, AX elements and notifications, multiple-timer identity and pause/resume visibility. This review found no `.sdef` in the installed Clock bundle, which is an observation about this environment, not proof of every version's capabilities. No documented public API for enumerating unrelated Clock timers has been established.

For an opt-in AX experiment, read only `com.apple.clock`, use semantic element identifiers/roles, bound work off the main thread, parse only needed timer fields, and show last-observed time. The initial adapter recognizes English Pause/Resume + Cancel controls grouped with one countdown. These are synthetic parser fixtures, **not verified compatibility with the installed Clock UI**. Do not enable it by default or advertise reliable background synchronization.

If a window is hidden/minimized/closed/unreadable, permission is revoked, or a partial/ambiguous tree is returned, remove the claimed countdown and show guidance. Stop observation during sleep/inactive sessions. On resume read Clock again; never advance a saved countdown and assume Clock kept running. Prefer supported AX notifications with a bounded reconciliation interval and no screen recording, private database reads, or automated clicks. [AX observation API](https://developer.apple.com/documentation/applicationservices/1460133-axobservercreate?changes=_4).

**Acceptance:** Test timers created outside NotchIsland, rename, pause/resume, cancel, two timers, tab changes, minimized/hidden/closed windows, app quit, permission revocation, sleep/wake and reboot on each advertised macOS/Clock version and locale. Unsupported versions must show unavailable. Alarms must come from Clock only. If these checks cannot pass, ship an explicitly limited prototype or an unavailable state; an app-owned timer is never an acceptable substitute.

### 6.4 ChatGPT and Claude approval notifications

The default card is **“ChatGPT needs attention”** or **“Claude needs attention”**, with Open and Dismiss. It must not imply that the utility has approved a request or knows the full action details.

Use this order of preference:

1. A documented event hook/API for the exact source surface and version, if available and enabled by the user.
2. A user-configured local bridge from a workflow the user owns.
3. Targeted Accessibility observation of the desktop app as an opt-in experimental integration.
4. Native app notifications and an Open-app shortcut if none of the above works reliably.

Claude Code exposes `PermissionRequest` and `Notification` hooks. Their scope is Claude Code, including only Desktop Code contexts that actually load the relevant configuration. They are not proof of generic Claude Chat or Cowork coverage. Current docs describe some permission notifications as delayed and distinguish network prompts, so measure end-to-end behavior on the actual session type. Hooks used for attention must forward a minimal event and return without supplying an allow/deny decision. Do not block the agent waiting for NotchIsland. [Hook contract](https://code.claude.com/docs/en/hooks).

ChatGPT's documented permission/question notifications confirm a user feature, not an external subscription contract. A plugin/MCP tool that an agent happens to call is not a reliable catch-all approval hook. Codex terminal/CLI notification facilities must be labeled separately and must not be advertised as covering every ChatGPT desktop approval. [OpenAI desktop notification scope](https://learn.chatgpt.com/docs/notifications).

For AX, verify bundle identity and process lifetime, attach `AXObserver`, subscribe only to supported relevant events, and inspect a bounded subtree. The public AX mechanism is stable; target UI labels, roles, and identifiers may change. Do not classify arbitrary chat prose containing “approve” as a pending request. Require corroborating dialog/control structure; test multiple languages and modal types. Coalesce events and use slow, bounded reconciliation only while an eligible target is running and observation is enabled. No OCR loop, keylogging, global screenshot capture, or scanning transcripts.

Use a paired local IPC transport for hooks: a restricted Unix-domain socket/helper or authenticated native messaging. Verify sender identity where available, use owner-only filesystem permissions and a per-install secret, reject oversized/malformed/replayed messages, and rate-limit. An open unauthenticated localhost HTTP listener or custom URL containing arbitrary command text is insufficient. Accept data, never executable instructions. Payload fields: schema version, event ID, provider, opaque session ID, created time, expiry, attention type, optional safe display title and allowlisted source link.

**Acceptance:** known approval produces one card; repeated events deduplicate; ordinary conversation containing approval words produces none; permission denial/revocation stops access; source termination invalidates pending certainty; spoofed IPC is rejected; no conversation bodies or command arguments appear in logs; opening the source app leaves approval to its own UI. Publish separate coverage rows for ChatGPT, Claude Chat, Claude Cowork, Claude Code local Desktop, and Claude Code CLI/remote sessions.

### 6.5 Apple Maps

First implement **Route estimate**: the user chooses origin/destination in NotchIsland or explicitly shares/imports a supported route link. Use `MKDirections` for the requested route and ETA, retain route identity, show the last update, and provide Open in Maps. Request location only if the user chooses current location; manually supplied endpoints require no location permission.

Recalculate on explicit refresh, substantial location change, or a conservative elapsed interval while the route is active. Bound retries and cancel superseded requests. Initial stationary ETA refresh target: 2–5 minutes, slower under low power; adjust only with evidence and server limits. Stop location and route requests when the user ends tracking. The route request returns directions/steps, not proof the person has reached a particular maneuver. Do not fabricate live turn-by-turn navigation from a static route.

An AX observer of the Maps app is optional research, not part of the supported route adapter. A future iPhone companion could share navigation data it legitimately owns with user consent; it cannot generically read other apps' Live Activities.

**Acceptance:** switching destinations cannot publish the old route; offline and throttled results are stale/failed honestly; no location acquisition before opt-in; end tracking stops updates; an ETA shows its provenance and is never labeled as the current Apple Maps session unless a validated bridge actually supplies that session.

### 6.6 Uber Eats, DoorDash, Swiggy, and Zomato

Use one typed delivery model with provider-specific adapters: order identity/account scope, merchant display name, state, ETA interval, observed time, source, safe tracking link, and capability status. Normalize to placed/accepted/preparing/ready/picked-up/arriving/delivered/cancelled/unknown while preserving the original provider state. Never infer “delivered” simply because an ETA reached zero. Support multiple orders and status corrections.

**Official adapter work:**

- **Uber Eats:** apply for Consumer Delivery access and confirm read-only tracking scopes, OAuth desktop flow, production permission, region coverage, and whether pre-existing/app-created orders are visible. Merchant endpoints and Uber Direct deliveries are different products. Until access is approved, implement fixtures and Open tracking link only.
- **DoorDash:** use Drive only for deliveries the approved integration actually owns; do not pass arbitrary consumer order IDs to it. For ordinary consumer orders, prove a permitted tracking source before promising live status. Marketplace onboarding is not interchangeable with consumer authorization.
- **Swiggy:** prototype against the official documented Food MCP tracking tools using the provider's supported auth/development flow. Inspect live tool schemas after authorization rather than hardcoding an assumed REST API. Ask for production access when required. Keep tracking calls deterministic: an LLM, ordering flow, and permanent Node sidecar are not inherently required merely because the transport is MCP. Test active orders placed in the Swiggy app as well as those originating through supported integrations. [Swiggy production guidance](https://mcp.swiggy.com/builders/docs/build/ship-to-production/).
- **Zomato:** the current official README both invites personal-use applications and retains a third-party-app restriction. Record this ambiguity, seek the provider's approval and redirect allowlisting, and keep this adapter gated. Do not reuse ChatGPT/Claude's OAuth redirect URI or credentials. Tool schemas and access to existing orders are not verified here; do not invent tool names.

For all four, a tracking-only feature must expose only an audited read allowlist. Reject ordering, cart mutation, payment, cancellation and tipping tools even if a server advertises them. Store tokens in Keychain, support logout/revocation, and avoid embedding client secrets in a distributable Mac binary. Use the provider-approved public-client PKCE flow or a properly operated backend as required. Provider text remains untrusted data.

**Browser fallback, only after a feasibility spike:** prefer a WebExtension/content script attached to a user-selected tracking tab, optional per-origin permission, DOM MutationObserver plus a bounded debounce, normalized payloads, and authenticated native messaging. Browser extension infrastructure is public, but each website parser is experimental. Support only tested browsers/providers/locales. A DOM change observer cannot make a background page update itself or defeat browser tab suspension. Never keep hidden headless browsers alive just to simulate a live feed.

Do not assume Swiggy/Zomato offer the same desktop tracking pages in every market. If there is no accessible permitted page, show unsupported for that browser path. Do not extract cookies, intercept private API tokens, bypass CAPTCHAs, or replay internal authenticated endpoints. Validate tracking URLs and redirects against provider allowlists; do not accept arbitrary network destinations. Avoid exposing order tokens in telemetry. A user-pasted ETA is a clearly labeled manual estimate.

On tab close/suspension/logout or parser mismatch, retain last-known status with age, then expire it; never imply continuity from a dead tab. For official polling, begin around 60 seconds for an active order, 30 seconds near an explicitly reported arrival if provider limits permit, and stop at a terminal state after one confirmation. Verified webhooks/push can replace polling only when the provider and deployment support them; an MCP call does not itself prove a push subscription exists.

**Acceptance per provider:** authenticated account consent, correct order/account isolation, an order placed through the intended real user path, changed ETA/status, two concurrent orders, delivered/cancelled states, token expiration, logout, rate limiting, offline recovery, and complete stop after terminal/disabled state. Store redacted contract fixtures. If only a tracking link or manual estimate works, label exactly that capability; fixture demos do not satisfy live integration acceptance.

## 7. Battery and performance program

### Scheduling and lifecycle

Introduce a single `PollCoordinator` with keyed requests, retained tasks, deadlines, cancellation, per-host/global concurrency limits, and backoff. Start at four concurrent network requests globally and two per host. Coalesce requests for the same endpoint/account/date. On stop or provider replacement, cancel the active task and reject late results using its generation.

Suggested starting policy, subject to provider contracts and measured freshness:

| State | Fetch/render policy |
|---|---|
| No subscriptions; provider disabled | Zero provider polling, zero animations, no idle tab scans. |
| Enabled sports discovery; no live selection | Refresh enabled leagues every 10–15 minutes; refresh sooner near a known event start or on explicit browsing. |
| Selected live sport, compact | Cheapest sufficient score source every 30 seconds; rich detail every 60–120 seconds only if still needed. |
| Selected live sport, expanded | Score/detail requests every 15–30 seconds, sharing a response where possible. |
| Final/history data | Cache for 30–60 minutes or longer where safe; one short correction window after a match ends; no perpetual live-detail polling. |
| Media | Events where supported; narrow supported-adapter reconciliation only as needed. Experimental private polling should back off substantially when idle, with no subsecond metadata polling. |
| Observed native Clock timer | Prefer Clock AX events; bounded read-only reconciliation, initially every 2 seconds active / 5 low power / 15 idle. Show observed values, not a locally generated countdown; no timer notifications or deadlines. |
| Approval | Event-driven bridge/AX; no universal 1 Hz UI tree scan. |
| Route/delivery | Only active user-authorized tracking, using the provider-specific policies above. |
| Hidden/display asleep/session inactive | Stop rendering/decorative clocks immediately; suspend nonessential discovery and expensive integrations. Stop native Clock observation and reconcile from Clock on resume; preserve explicitly requested tracking semantics. |
| System sleep | Cancel in-process nonessential work; no sleep-prevention assertion. On wake, recompute time and schedule one deduplicated refresh with jitter. |
| Low Power Mode or elevated thermal state | Disable ambient animation; lengthen optional discovery/route/delivery intervals, reduce concurrency, and display stale age honestly. Keep timer semantics and essential attention events correct. |

Use nonzero timer tolerance/leeway for discretionary work, initially about 10–20% where freshness permits. Clock remains the alarm authority; this application does not schedule timer expiration. Apple recommends reducing timer wakeups and using event-driven work where possible. `NSBackgroundActivityScheduler` is suitable for discretionary maintenance, not a precise timer alarm or guaranteed sports deadline. [Apple timer guidance](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/Timers.html).

Observe workspace sleep/wake and screen sleep/wake, session activity, Low Power Mode, thermal changes, and network-path changes using documented APIs with availability checks. Provide immediate privacy hide and lock/session-inactive handling; validate the exact lock signal on supported OS versions rather than treating an undocumented distributed-notification name as a guaranteed contract. Do not infer invisibility from application activation alone: this utility is often visible while another app is active.

Honor App Nap and avoid global `beginActivity` assertions that keep the system awake. A visible overlay may reduce App Nap opportunities, so removing unnecessary work matters even if App Nap exists. [Apple App Nap guidance](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/AppNap.html).

### Network, memory, and rendering

- Preserve cancellation errors instead of wrapping them into ordinary network failures and retrying. On 401/403 require account action; on 429 honor Retry-After; on transient failures use capped exponential backoff plus jitter. Start with 30/60/120/300-second retry delays, limited by source policy; no retry storm on wake.
- Do not confuse task cancellation with a guarantee the remote server saw no request. Ensure read retries are safe and no delivery mutation methods exist in the tracking adapter.
- Keep URLCache but validate actual cache headers/hit rates. Add application TTLs where responses lack useful caching. Use conditional requests only when validators are supplied, and handle 304 consistently with cached payloads. Do not append cache-busting timestamps.
- Decode network payloads and transform large scorecards off the main actor using typed Sendable data. Current `@MainActor` coordination does not prove all parser work runs there; profile before claiming a specific bottleneck. Main actor owns only view projections and AppKit state.
- Batch semantic state commits; avoid publishing many properties independently for one response. Cache derived display strings and expensive translations/layout calculations where profiling demonstrates cost. Keep image/color caches bounded, e.g. 16 MB initially, and record hit/miss/eviction counts.
- Stop all `repeatForever` and timeline work when invisible, paused, Reduce Motion, or Low Power Mode applies. Removing a view is not the only suspension mechanism. A paused timer callback that returns early still causes wakeups.
- Avoid animating NSPanel frames on score/progress changes, excessive blur/shadow layers, and blanket `drawingGroup()` rasterization without profiling. A decorative waveform must not subscribe to actual audio capture.
- Use structured OSLog categories/signposts for fetch, decode, store update, layout, animation, and provider lifecycle. Log endpoint categories and opaque IDs, not full tracking URLs, auth headers, addresses, chat text, or AppleScript payloads.

### Measurement protocol and release budgets

Capture the baseline at the pinned revision before changes. Run Release builds without a debugger, on the same hardware, OS, display brightness/refresh rate, external-display setup, network conditions, battery/AC mode, and media source. Record all of those conditions. Warm up for 2 minutes, collect each steady-state scenario for 15 minutes, repeat at least three times, and report medians plus spread. Run a separate two-hour leak/retention test.

Use deterministic recorded fixtures for comparable rendering/network-response timing, then a separate live-feed soak for real request volume and failures. Measure NotchIsland and any helper/browser-extension overhead; offloading work to a browser is not an energy saving if system cost rises.

Scenarios: idle enabled/disabled, one live sport compact, expanded scorecard, playing/paused media, sport+media split, timer+media, pending approval, active delivery, all providers enabled with no activities, offline/backoff, Low Power Mode, hidden, screen asleep, sleep/wake repeated, and repeated display attach/detach.

Use Instruments Time Profiler, Allocations/Leaks, Animation Hitches/Core Animation, and available energy/system tracing. Activity Monitor CPU/Energy Impact is supplementary and not a battery-watt meter. Use `powermetrics` only on supported hardware with the required privileges and attribution caveats; record CPU/GPU package energy and total-system effects rather than pretending it is precise per-app battery consumption. Signposts and request metrics must remain available without Instruments.

| Metric | Initial acceptance target |
|---|---|
| Disabled/no activity | Zero application-owned periodic provider polls and animation timers; no networking after teardown. OS/framework incidental wakeups measured separately. |
| Idle visible utility | Mean CPU ≤0.5% of one logical core over the 15-minute run; ≤1 measured process wakeup/second as an initial diagnostic target. If the environment prevents this, record trace/evidence and revise explicitly rather than hiding it. |
| Compact sports+media | Mean CPU ≤2% of one logical core, no persistent GPU animation when ambient motion is off; no more than one visible 1 Hz time renderer. |
| Duplicate work | At most one in-flight request per endpoint/account/key; exactly one launch/wake refresh generation; zero stale-selection overwrites. |
| Network improvement | At least 75% fewer requests in a reproducible single-sport subscription scenario versus the all-sports baseline, while meeting the declared score refresh interval. Report bytes as well as request counts. |
| Frame/layout | Zero panel frame mutations for unchanged geometry. For 60 Hz target displays, p95 transition frame time within 16.7 ms; report hitch count and 120 Hz behavior separately. No main-thread synchronous stall >50 ms in scripted interactions. |
| Memory | Initial resident/footprint target ≤150 MB for the normal two-activity case; report the chosen metric consistently. No sustained growth after cache warmup; ≤10 MB drift over a two-hour repeat scenario is an initial investigation threshold. |
| Event responsiveness | p95 local event receipt-to-visible update <250 ms, excluding deliberate debounce and source notification delay. No false claim of end-to-end freshness when the upstream source is delayed. |
| Sleep/wake | No app sleep-prevention assertion; no rendering during suspension; correct countdown reconciliation and one refresh generation within 5 seconds after resume when connectivity allows. |

Do not claim “X% less battery” from CPU samples alone. Report before/after CPU, wakeups, network bytes, rendering activity, memory, and controlled energy readings with limitations. Improvements must preserve accuracy; simply freezing scores is not a valid optimization.

## 8. Accessibility, privacy, and permissions

Use native controls with labels, values, selected states and hints. VoiceOver should read “Cricket, India 185 for 4, live, updated 20 seconds ago” or “Timer, tea, 2 minutes remaining,” not decorative glyphs. Announce meaningful attention/status transitions once; do not announce every timer second or score refresh. Provide text/icon distinctions for live, paused, stale and failed states, independent of color.

Verify contrast, enlarged text, localization including Hindi and right-to-left layouts, keyboard-only operation, Switch Control compatibility where practical, Reduce Motion, Reduce Transparency and Increased Contrast. Keep the menu-bar entry as a stable fallback to settings, activity selection and quit.

| Permission/data | Request only for | Failure behavior |
|---|---|---|
| Notifications | Explicit app alerts only; native timer alarms remain in Clock | In-app state continues; show alert limitation. |
| Automation / Apple Events | Specific supported media player adapter | Disable that adapter's controls; no fallback keystroke injection. |
| Accessibility | Explicit native Clock or desktop-approval experiment | Adapter stops and says permission required; other providers continue. |
| Location | User-selected current-location route | Allow manual origin; stop location when route ends. |
| Browser origin permission | A chosen provider's tracking page | Open tracking link only. |
| OAuth | Approved delivery/provider account integration | Disconnect/expire data on revocation; no credential scraping. |

Core sports and split UI should not require Full Disk Access, Screen Recording, microphone access, or Input Monitoring. Do not ask for these permissions merely to make an unsupported integration appear possible.

Default approval cards omit conversation titles and command details; delivery cards omit address, phone number, driver identity and precise location. Keep only data needed to show status. Store secrets in Keychain; keep nonsecret preferences in versioned local storage. Delete completed delivery details by default after a short documented retention window, and provide Clear history/Disconnect. Logs and diagnostics must be redacted and exportable only by explicit user action.

Hide sensitive cards on session inactivity/lock with the validated lifecycle mechanism, and offer a reliable manual privacy-hide shortcut. Do not promise every screen-sharing tool can be detected or prevented from capturing the overlay; provide a user-controlled sharing mode and test capture-exclusion behavior separately if implemented. Do not create urgency popovers that bypass the user's quiet-mode intent. macOS Focus does not automatically govern a custom overlay's attention policy; expose explicit quiet controls.

Threat tests must cover malicious webpage titles, fake approval messages, forged IPC, oversized artwork/payloads, invalid URLs, account switching, replayed events, expired credentials and prompt-like content. Providers supply data only; the app never executes text received from an order page, notification, chat or MCP result.

## 9. Staged delivery plan with exit gates

Each stage is a reviewable commit/PR series. Keep existing functionality usable throughout. Do not start with all integrations at once, and do not block supported core work on inaccessible third-party APIs.

| Stage | Work | Exit gate |
|---|---|---|
| 0 — Reproduce and baseline | Record actual commit/toolchain/OS, inspect local instructions, establish supported OS/architecture matrix, fix build settings if needed, add deterministic fixtures and a test target, capture baseline metrics. | Reproducible app bundle and core tests on a supported Mac; source-to-binary provenance; baseline report. Environment failures recorded separately. |
| 1 — Correctness and energy foundation | Fix key-code controls, request races, duplicate launch/wake fetches, cancellation, single-flight requests, fresh/stale semantics, observer ownership, private media isolation. | Race tests pass; no ordinary keyboard events; zero disabled-provider work; one launch/wake generation; a supported build starts without MediaRemote. |
| 2 — Activity model and split shell | Add core contracts/reducer, wrap current sports/media, consolidate geometry, add stable two-slot selection and overflow, display selection/hit testing. | Pairwise activities render and interact independently; unchanged score updates do not move windows; non-notched/notched/multi-display tests pass. |
| 3 — Native Clock and accessible motion | Add an opt-in read-only native Clock prototype, explicit unavailable states, split/merge animation, keyboard and VoiceOver paths, reduced-motion/power variants. No in-app timer engine or notifications. | Native Clock version/locale compatibility recorded or marked unverified; 100 transition stress test passes; no background observation/animation leaks; accessibility checklist recorded. |
| 4 — Reliable media/sports release | Validate named player adapters, optimize artwork, tune subscribed sports discovery/detail, parser/freshness regression tests. | Named source/control matrix passes; network reduction and compact CPU targets met with fresh scores; private route remains explicitly optional. |
| 5 — Desktop approval and Clock research | Capability probes and small opt-in prototypes for exact versions; document hook versus AX coverage; do not use paired Shortcut estimates as native timer support. | Each integration is either demonstrated on its advertised matrix or marked unavailable/limited. Generic Chat/Cowork coverage cannot be inferred from a Code-hook demo. |
| 6 — Routes and delivery | App-owned MapKit route estimate; approved official adapters, starting with available Swiggy development access; per-provider access review; browser spike only where justified. | Real authorized tracking path passes provider acceptance; unavailable providers have honest UI; no mutations/auth scraping; external-data threat tests pass. |
| 7 — Soak, packaging and distribution | Repeat performance protocol, compatibility/accessibility tests, hardened signing, notarization/stapling, clean-machine install/update tests, docs and release notes. | Evidence meets budgets or documents approved exceptions; no private integration presented as supported; reproducible notarized release artifacts and rollback plan. |

Suggested first PR: only remove unsafe key-code controls, fix late detail-response overwrite, deduplicate startup/wake requests, and add meaningful tests for those paths. Suggested second PR: lifecycle/scheduler extraction. Then introduce the activity reducer and split UI. Avoid burying correctness changes inside a large visual rewrite.

Feature flags should be local and individually reversible: `splitActivities`, `experimentalClockObservation`, `experimentalDesktopApprovals`, `experimentalMediaRemote`, and individual delivery adapters. Production defaults must match the demonstrated capability matrix. Unsupported integrations cannot be silently enabled by remote configuration.

## 10. Xcode, Swift toolchain, SwiftPM, and XcodeGen

**Answer:** You do not need to use the Xcode editor to work on this project. A matching Swift compiler plus Apple's macOS SDK can compile SwiftUI/AppKit code from the command line. The current SwiftPM target is a possible executable build path. For a polished app bundle, signing, extensions, UI tests and rigorous Instruments profiling, installing full Xcode is the practical recommendation. XcodeGen does not replace Xcode's compiler/build tools.

Apple's standalone Command Line Tools package includes the macOS SDK/toolchain, but `xcodebuild` and `xctrace` are full-Xcode tools. A Swift.org toolchain alone is not a replacement for the Apple platform SDK and matching tools. [Apple CLT documentation](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools?changes=_8%2C_8), [Xcode command-line tools](https://developer.apple.com/documentation/xcode/xcode-command-line-tool-reference), [Swift on macOS](https://www.swift.org/install/macos/).

| Work | Full Xcode installation? |
|---|---|
| Run a finished compatible `.app` | No. End users need the supported macOS and any feature permissions, not development tools. |
| Edit Swift in an AI agent or another editor | No. |
| `swift build` / core `swift test` with compatible macOS SDK | Often possible with standalone CLT. Validate the exact compiler/SDK and target; the original review attempt was environment-blocked; subsequent preview results are recorded separately. Some CLT installations omit XCTest; the preview includes Foundation-only checks. |
| Build `.xcodeproj` with `xcodebuild`, including an XcodeGen-generated project | Yes; the IDE window need not be open. |
| Generate a project using XcodeGen | XcodeGen is a separate generator; generation alone does not build/sign the app. Tool installation has its own requirements. |
| Manually package/sign a SwiftPM-built executable | Possible with appropriate command-line tools, resources/plist handling and certificates; more work than the existing XcodeGen application target. |
| Instruments profiling via GUI or `xctrace`; Xcode UI-test workflow | Full Xcode is the recommended/required tool provider for these workflows. |
| Notarization | Requires valid Developer ID signing and Apple's service credentials, not editing in the IDE. Use available `notarytool`/`stapler` tools or the documented Notary API. Check installed tools rather than assuming every CLT version includes the same utilities. |

### Recommended build route: existing XcodeGen spec

1. Install a supported full Xcode version and select its developer directory. Record `xcodebuild -version`, `xcrun swift --version`, and SDK version. Accept required first-run setup.
2. Install/pin XcodeGen. Update `project.yml` deliberately: modern tested Xcode metadata, correct Swift language mode, Debug/Release settings, resources, test targets, entitlements and signing. `swift-tools-version: 5.9` is a manifest tool minimum; it does not mean the Xcode `SWIFT_VERSION` language-mode setting should remain `5.9`. Verify generated settings and use a supported mode such as `5.0` for staged migration or `6.0` after concurrency fixes.
3. Generate the project, inspect generated schemes, build Release, and run tests. Do not assume the scheme exists before checking it.

```sh
xcodegen generate --spec project.yml
xcodebuild -list -project NotchIslandSports.xcodeproj
# Use the verified generated scheme:
xcodebuild -project NotchIslandSports.xcodeproj \
  -scheme NotchIslandSports -configuration Release \
  -derivedDataPath build/DerivedData build
```

XcodeGen turns YAML into an Xcode project; it is well suited to agent edits and reproducible project regeneration. Pin its version and keep manual project edits out of the workflow if YAML is authoritative. [XcodeGen project](https://github.com/yonaskolb/XcodeGen).

### Alternative: SwiftPM and an explicit bundling script

```sh
xcrun swift --version
xcrun --sdk macosx --show-sdk-path
swift build -c release
# Run after adding the planned test target:
swift test
```

These commands produce/test Swift package products; `swift build` does not automatically reproduce this project's application bundle, Info.plist substitutions, icon assets, login behavior, entitlements, or release signing. The current manifest has no resource declarations. A bundling script must create `NotchIslandSports.app/Contents/{MacOS,Resources}`, copy the binary/resources, generate a fully resolved plist, compile/package assets using available tools or provide a prepared `.icns`, then sign and validate the bundle.

Do not copy the current plist with unresolved `$(PRODUCT_NAME)`/`$(EXECUTABLE_NAME)` placeholders into a hand-built app. Test real bundle behavior, including `LSUIElement`, Automation consent and notifications. Decide whether supported architectures remain arm64 and x86_64, confirm toolchain/SDK support, and validate both slices; `swift build` on one machine is not automatically a universal binary. Full Xcode is the lower-maintenance route as browser extensions or helpers are added.

### Signing and notarization

Ad hoc signing is suitable for some local development builds, not a substitute for Developer ID distribution. For direct downloads, use an Apple Developer Program team with a Developer ID Application certificate, Hardened Runtime, a secure timestamp and only required entitlements. Signing identity stability also matters for persistent privacy permissions. App Sandbox and Hardened Runtime are different mechanisms; enabling one does not imply the other.

The repo currently has `ENABLE_HARDENED_RUNTIME: NO`; change Release, validate Apple Events functionality with the appropriate entitlement if that adapter ships, and avoid broad runtime exceptions. Private API usage is unsuitable for an App Store-compatible supported variant; App Store distribution also brings sandbox/review constraints. Successful notarization is a security/signing check, not App Review or proof of API support. [Apple notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [Developer ID](https://developer.apple.com/developer-id/).

Example sequence for an already packaged app, with credentials held outside the repository:

```sh
# Sign nested helpers/extensions first with their own required entitlements.
# Then sign the outer app; supply a reviewed entitlements file if required.
codesign --force --options runtime --timestamp \
  --sign 'Developer ID Application: YOUR NAME (TEAMID)' \
  build/NotchIslandSports.app
codesign --verify --deep --strict --verbose=2 build/NotchIslandSports.app
ditto -c -k --keepParent build/NotchIslandSports.app build/NotchIslandSports.zip
xcrun notarytool submit build/NotchIslandSports.zip \
  --keychain-profile NOTCH_NOTARY --wait
# Inspect the submission log and require Accepted before continuing.
xcrun stapler staple build/NotchIslandSports.app
xcrun stapler validate build/NotchIslandSports.app
spctl --assess --type execute --verbose=2 build/NotchIslandSports.app
# Recreate the distributed ZIP after stapling the app.
ditto -c -k --keepParent build/NotchIslandSports.app build/NotchIslandSports.zip
```

Do not use `--deep` as a shortcut for signing nested code; it appears above only for verification. Do not put private keys/passwords in YAML, source, scripts or PRs. Apple's Notary REST API is an alternative to the submission/status portion of `notarytool`; it does not build, locally sign, or staple the app for you. [Notary API workflow](https://developer.apple.com/documentation/notaryapi/submitting-software-for-notarization-over-the-web).

Test the actual downloaded/quarantined artifact on a clean account/Mac, including a network-offline launch after stapling and upgrade preserving settings. Publish version, commit, checksums, architecture/minimum-OS information and truthful integration limitations. Replace README advice to recursively clear quarantine with the normal signed/notarized installation flow.

## 11. Required test suite and agent handoff checklist

Use deterministic unit tests where logic has meaningful failure modes, and manual/UI tests where system behavior matters. Do not call a passing mock suite proof of external integration compatibility.

- **Reducer:** 0/1/2/3+ activities, stable tie-breaking, manual pinning, attention promotion, expiration, stale source, explicit dismiss, and completion merge. Replay arbitrary event order with an injected clock.
- **Scheduler:** one request per key, concurrency cap, stop/cancel, late callbacks, offline/backoff, Retry-After, no disabled work, no duplicate wake burst, and budget/freshness tradeoffs.
- **Sports:** redacted fixtures across every current sport; active-selection race; detail/score merge ownership; empty versus failure; composite IDs and preference migration.
- **Timers/media:** clock jumps, sleep/reboot/relaunch semantics, pause/resume, deduplicated expiration; media source routing, position anchors and artwork caching.
- **Window/UI:** physical notch and non-notch displays, menu-bar settings, multiple displays/scales/Spaces, full-screen, transparent click-through, keyboard focus, long labels and large text.
- **Accessibility:** VoiceOver reads both activities and controls in order; one attention announcement; no every-second announcements; motion/transparency settings honored without restart.
- **Integration contracts:** record OS version, desktop-app version, browser version, adapter version, permissions and provider access for every passing capability. Exercise refusal/revocation and unavailable states.
- **Privacy/security:** no unauthenticated events, action injection, arbitrary URL execution, credential leakage, accidental delivery mutations, sensitive logs or hidden-screen scraping.
- **Performance/release:** before/after traces under the same scenarios, helper/browser cost, two-hour soak, signed bundle verification, accepted notarization and clean-machine launch.

For each stage, the implementing agent must return: changed files and rationale; automated/manual verification results; measured metrics where relevant; limitations and unresolved external access; exact supported configuration; migration/rollback notes. Do not fabricate test results, mock approvals as real approvals, or mark native Clock synchronization complete because an independent timer counts down.

## 12. Completion definition

The supported core is complete when two activities coexist with correct geometry and focus, existing sports remain useful, media controls target the correct source, native Clock observation either passes its version-specific checks or is clearly unavailable/experimental, accessibility works without hover, and repeatable metrics demonstrate reduced unnecessary work.

The broader request is complete only when each named integration is either implemented and demonstrated for its stated scope or explicitly delivered as restricted/experimental/unavailable with a tested fallback. External access restrictions are not solved by misleading UI. Full Xcode is recommended for this project's release and profiling work, while command-line editing/build orchestration remains entirely viable.

## Preview 1.6 implementation update

See [PREVIEW-1.6.md](PREVIEW-1.6.md) for the current behavior and verification limits. It supersedes earlier menu, hover and media transport details: hover implementation is deleted, the six-entry menu is restored, setup appears once outside the notch, native Clock recovers after permission changes and can inspect readable background windows, and a vendored event-driven MediaRemote adapter supports browser session metadata/transport. Native Clock and YouTube end-to-end operation are not yet confirmed in this execution environment; upstream media self-tests did not establish an active session and computer inspection was unavailable. Do not equate successful builds and fixtures with live compatibility.

### Version 1.6 build 8 maintenance update

The version remains 1.6.0. Compact labels are explicitly clipped and cricket overs/targets move to expanded content; the primary footprint is smaller. A single window reveal replaces competing layout animations, with gesture recognition during the drag and generation-safe reversal. Clock setup requires an explicit Connect/Skip choice, waits for permission, selects the native Timers tab through a bounded explicit setup action and cannot finish while a selected Clock integration is unresolved. See PREVIEW-1.6.md for details and the 137-check verification scope. Older generated download packages are removed from this chat's outputs; source history is preserved.

### Music title and playback motion (build 8)

Long titles now scroll to the end and back with eased movement and a 1.6-second reading pause at each end, in both the compact and expanded media views. Short titles remain stationary. Compact trailing content is five cyan playback bars instead of the creator name; artist metadata remains in the expanded view. Bars are decorative playback indicators, not microphone capture or audio amplitude analysis. Full titles remain available to accessibility.

Motion redraws only its small text/bar surfaces at a maximum requested 30 frames/second while playback and the provider are active and the surface is visible. Motion stops when paused, suspended, in Low Power Mode or with Reduce Motion; hidden expanded content never runs a decorative animation. This introduces no media polling or idle repeating task. User-requested macOS adaptation informed by [Apple’s Live Activities design guidance](https://developer.apple.com/design/human-interface-guidelines/live-activities) and [Dynamic Island interaction guidance](https://support.apple.com/en-ie/guide/iphone/iph28f50d10d/ios), not a claim of Apple’s private Now Playing implementation or continuous ActivityKit animation support.

### Gesture and browser-session follow-up (build 8)

One continuous press-and-drag recognizer now replaces the competing long-press/exclusive-swipe pair. Hold for about 0.3 seconds, then drag sideways at least 22 points to merge/separate; a quick sideways drag changes pages. Pull down/up uses 18 points. Recognition waits for a dominant direction and commits once. Expanded input is confined to the header and bottom handle, preserving media sliders and scrolling. Trackpad scrolling now works on both satellite capsules too; click-hold while scrolling sideways toggles merge/separate. No hover behavior was added.

Satellites slide 32 points outward/inward with a 0.32-second eased fade; stale completions are guarded during reversal. New media sessions automatically separate the live slots. A manual merge remains through ordinary metadata updates and pauses. Session disappearance closes an open music panel and merges its slot; the next playing session splits again.

The media lifecycle now rejects old paused metadata at app startup, keeps a session that was observed playing when paused, and clears it on metadata withdrawal, source-app termination, adapter failure or sleep. A vendored adapter correction clears the entire stale snapshot when MediaRemote reports no player PID, rather than retaining its old title and bundle. These are Now Playing session signals, not direct browser tab enumeration. YouTube, Netflix and Prime Video work only when the browser exposes their session to macOS. If a browser retains paused metadata after a tab closes, exact tab closure is unavailable to this adapter; no claim of universal tab detection is made. An explicit browser extension would be required to promise tab-level lifecycle across those sites.

Expanded media content now uses 180 points instead of 220 (206 when a connection/control message needs room). Cricket uses 320 instead of 360, preserving its scrolling scorecard and bottom handle. The camera band and handle are added separately, so trimming the empty footer does not move content behind the physical notch.


### Version 1.6 build 9 follow-up

Implemented compact Calendar paging without event mutation or slot consumption; inward satellite merge gestures; bounded event-driven menu geometry and conservative fallback placement; curved media controls surface; circular missing-artwork placeholder; explicit Music/Spotify native command routing with fallback after system transport failure. All existing sports/details and native Clock policies remain. See PREVIEW-1.6.md for acceptance checks, privacy boundaries and measured-vs-unverified distinctions. Native media discovery remains private MediaRemote, not a public Apple Music/Spotify discovery API. The physical notch's viewing-angle reflections cannot be fixed in software. Status-item geometry may be unavailable, so menu avoidance is best effort, especially on unusual display arrangements. No live native-player compatibility or battery savings are asserted.


### Version 1.6 build 10 approval follow-up

The user explicitly requested direct one-request approval from the notch, superseding the notification-only first-stage restriction in section 6.4. The implemented path uses documented synchronous PermissionRequest response contracts, never a scraped button or generic notification. An authenticated local IPC helper waits for an explicit user choice, then returns allow/deny for that exact request only. No automatic decisions, rewritten input or permanent permissions are returned. Full request details, queue handling, configuration merge/backups, cancellation/expiry and source coverage are specified in APPROVALS.md. Generic ChatGPT chat and Claude Chat/Cowork remain unconnected; hook support for local coding sessions must not be generalized to them.
