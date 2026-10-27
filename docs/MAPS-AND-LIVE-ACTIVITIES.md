# Maps and iPhone Live Activities — integration status

Checked October 27, 2026. NotchIslandSports 1.6 build 18 adds Clock-reader recovery and visible island outlines. It does **not** import Apple Maps, Google Maps or third-party iPhone Live Activities into its custom panels.

## What works through macOS

macOS Tahoe 26 and later can display supported iPhone Live Activities in the system menu bar after iPhone Mirroring is configured. On the Mac, check System Settings → Notifications → Allow notifications from iPhone → Allow Live Activities from iPhone. Apple notes that this settings section appears after a successful Mirroring connection. On iPhone, the relevant app’s settings control whether its Live Activities are allowed. The activity must originate in that app; NotchIslandSports cannot create it on the app’s behalf. Clicking a system activity reveals details; interaction can open the source through iPhone Mirroring. This is the system’s interface and is separate from this app’s notch panels. [Apple setup and requirements](https://support.apple.com/en-us/120684).

Apple lists Maps directions as an example of activity shown in iPhone’s Dynamic Island. Google describes glanceable directions as showing upcoming guidance and estimated arrival, with Live Activities compatibility. These are design references, not an integration feed for another Mac app. [Apple’s Dynamic Island guide](https://support.apple.com/en-lamr/guide/iphone/iph28f50d10d/ios), [Google’s directions announcement](https://blog.google/products-and-platforms/products/maps/sustainable-immersive-maps-announcements/).

## Mac routes versus active navigation

| Source | Documented capability | Status in NotchIslandSports |
| --- | --- | --- |
| Apple Maps on Mac | Plan routes and inspect their steps; share/use directions across devices. | No verified API for observing the route selected in another Maps process. |
| MapKit | Compute routes requested by your own app. | This would be a separate route planner, not a mirror of an existing Maps trip. Not added. |
| Google Maps URLs | Launch Maps searches, directions and supported navigation actions. | A launch URL supplies no ongoing trip-state callback. Not advertised as tracking. |
| iPhone Apple/Google Maps Live Activity | Source app produces the activity; Apple can present compatible activities in its system surfaces. | No verified public consumer API for rehosting third-party activity payloads inside this app. |
| Other iPhone Live Activities (for example deliveries) | Depends on the source app creating an activity and system compatibility. | Same limitation; no fabricated ETA, maneuver, order status or progress. |

References: [Maps for Mac directions](https://support.apple.com/guide/maps/get-directions-mps4d8a6bd2f/mac), [MKDirections](https://developer.apple.com/documentation/mapkit/mkdirections), [Google Maps URLs](https://developers.google.com/maps/documentation/urls/get-started), [ActivityKit’s app-owned activity model](https://developer.apple.com/documentation/activitykit/activity), [Apple’s Live Activities design guidance](https://developer.apple.com/design/human-interface-guidelines/live-activities).

## What a real future connection needs

A navigation source must expose an authorized, tested stream containing a stable trip identifier, provider, current maneuver, distance to maneuver, ETA, last update, and explicit trip end/cancel. An iPhone companion cannot enumerate unrelated apps’ ActivityKit activities merely by being installed. A browser extension could potentially observe an explicitly authorized desktop Maps tab, but its actual page data, private-window permissions, expiry, route-change semantics and website compatibility must be validated before shipping. It would not establish access to iPhone navigation.

Until such a source exists, the supported option is the system menu-bar Live Activity. A mock navigation pill, a route-preview estimate mislabeled as a live trip, broad screen recording, and private notification-database scraping are not implemented.

## Native Clock verification

Build 18 recognizes UUID-based sidebar timers without requiring Cancel in the same card, handles wrappers around selected detail controls, chooses semantic button labels, and batches bounded accessibility reads. A failed read preserves a read-only last observation for less than ten seconds; an empty successful read removes it immediately. Native commands still require fresh matching elements. Recent timer presets with Start do not count as active timers.

The new cases pass synthetic regression checks. Live verification on the user's Clock was unavailable: computer-use capture failed, and a separate read-only diagnostic process reported no Accessibility trust. The installed app’s permission is independent. Do not describe the screenshot’s exact timer as verified working until the updated app observes it. Ad hoc preview updates can require reconnecting permissions; stable Developer ID signing is still needed for distribution. No in-app timer or inferred alarm was added.
