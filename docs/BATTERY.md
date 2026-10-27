# Battery changes — 1.6 build 12

The app now does less background discovery and avoids UI work for unchanged state. These are reductions in scheduled work, not a measured battery-life percentage. The design and hold/swipe gestures are unchanged.

| Work | Before | Build 12 |
| --- | --- | --- |
| Discover all 13 sports with picker closed | Every 5 minutes | Every 15 minutes; 30 in Low Power Mode or serious/critical thermal pressure |
| Selected live score | 30 seconds collapsed / 15 expanded | Unchanged; existing power/backoff rules retained |
| Open match picker or Refresh Now | Fetch immediately | Unchanged; the full catalog remains available |
| Brief sleep/wake | Rediscover all sports on every resume | Reuse the completed discovery within its freshness window; refresh selected detail on wake |
| Clock closed | Check every 15 seconds | No repeating check; application launch/activation reconnects |
| Clock permission absent | Check every 15 seconds | No background check; setup still checks each second while visible, app activation also checks permission |
| Clock open, no readable timers | Check every 15 seconds | 30 seconds normally / 60 conserving power, plus native structure/focus/value discovery events |
| Clock paused | Full scan every 2 seconds | Every 4 seconds, while keeping the five-second control validation limit |
| Clock countdown value notifications | Could cause extra scans between scheduled checks | Existing timer ticks no longer request full scans; scheduled running checks remain 2 seconds (4 conserving power) |
| Repeated Clock snapshots | Publish timers, timestamp and status each scan | Publish only changed timers/status; keep freshness timestamp internally |
| Media position events | Every changed timestamp published the whole track | Update position anchor silently; publish changed metadata, source, play state, rate, duration or position corrections over 0.75 seconds |
| Expanded media progress | Entire page evaluated every second | Only the progress/time subview ticks; stops when hidden, suspended, paused or duration unavailable; 2 seconds conserving power |

The small media satellite now uses cached artwork with a static music-note fallback, eliminating its animated bars without extra network requests. Visible title scrolling and playback bars elsewhere retain their existing 30 fps cap. They stop when paused, hidden, under Reduce Motion or conserving power. Pull-down and swipe animations remain unchanged. Artwork is still decoded only when its data changes. The normal media helper and approvals socket remain event-driven, Calendar remains boundary/event-driven, and sleep/display sleep/inactive-session handling still stops providers.

Clock is an experimental Accessibility adapter. Where native notifications are unavailable, discovering a newly created timer can wait for the empty-state reconciliation interval. Pause/resume/cancel still reread and validate the exact native controls on user action; no control validation was loosened and no local timers were added. Permission changes outside setup are picked up on application activation or reopening setup.

## Verification

`scripts/check-energy.swift` exercises the real media manager with providers stopped: 3,600 equivalent position events cause no extra track publications, while title/artist/album/artwork/source/duration changes, seeks, pause and resume still publish. A separate synthetic monotonic-clock test checks one hour of accurate progress. It also checks cold/warm/expired discovery, setup and empty/paused/running Clock policies, including control freshness tolerance. Existing geometry, gestures, Clock identity, Calendar rollover, media lifecycle and approval tests remain required.

Local builds and synthetic tests cannot establish device battery drain. For a controlled comparison, use the same Mac, brightness, power mode and media/sports state, allow launch work to settle, then compare build 11 and 12 over identical 15-minute idle, playing-collapsed, expanded and Clock scenarios. Observe CPU and Energy Impact for NotchIslandSports **and** its media helper; record network activity and wakeups with Instruments when available. Exclude compilation and unrelated browser changes. Do not infer a battery-life percentage from scheduled poll counts or a short Activity Monitor sample.

The nominal background sports sweep count drops from 12 to 4 per hour in normal mode, excluding startup and explicit refreshes. With Clock closed its periodic 240 checks/hour become zero. These are policy counts, not measured energy savings.
