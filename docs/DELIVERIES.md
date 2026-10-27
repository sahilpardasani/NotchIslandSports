# Delivery tracking — version 1.6 build 20

## Swiggy

Open **About NotchIslandSports → Configure → Connect Swiggy**. Complete phone/OTP sign-in on Swiggy's own website. If your account has several saved addresses, choose one once in Configure; Swiggy requires an address identifier to fetch orders, but returns active orders across all your delivery addresses. No address is changed and no order is placed.

Swipe sideways to **Deliveries** when an active order is available, or choose **Select Widget → Deliveries**. The compact page shows the restaurant and provider ETA/status. Pull down for current tracking details and the last update time; swipe up to collapse. Hold-and-swipe returns to the full sports score and the existing small media/timer pills. Deliveries do not shrink sports or take either companion slot. Multiple active orders appear in the expanded list.

Credentials are stored in macOS Keychain, not preferences or logs. The connection uses Swiggy's documented dynamic client registration, a temporary localhost callback, OAuth state, and PKCE S256. The listener closes after the callback, cancellation, or three minutes. HTTP redirects cannot forward credentials to a different endpoint. Refresh tokens rotate in Keychain. Disconnect removes the local connection and displayed orders; it does not cancel any food order.

Only `get_addresses`, `get_food_orders`, and `get_food_delivery_status` are allowed by this client. Swiggy's current OAuth scope is broader than read-only, but this app blocks every other tool before network dispatch. It never submits, edits, pays for, or cancels an order.

New active orders are checked approximately once per minute while awake. With no active order in Low Power Mode, discovery backs off to five minutes. Tracking obeys the provider's `pollIntervalSec` (at least 15 seconds), HTTP rate-limit delays, and network-error backoff. Delivered/cancelled orders disappear and stop tracking. Missing ETA is not invented, provider clock differences are accounted for, and stale cards expire during outages. Sleep/session lock stops requests. Sports retain their independent fast refresh cadence.

Public OAuth metadata and localhost client registration were verified against Swiggy; registration returned HTTP 201. Automated checks cover real loopback callback routing plus synthetic authenticated HTTP/JSON/SSE, token refresh, active-order discovery, timing, terminal removal and read-only enforcement. **No user has signed in to this preview during development, so a real-account OTP/token/order round-trip remains unverified.** This preview uses Swiggy's documented localhost development path. Broader production distribution still requires its access/redirect approval process.

Sources: [authentication](https://mcp.swiggy.com/builders/docs/start/authenticate/), [developer access](https://mcp.swiggy.com/builders/docs/start/developer/), [active orders](https://mcp.swiggy.com/builders/docs/reference/food/get_food_orders/), [delivery state and polling](https://mcp.swiggy.com/builders/docs/reference/food/get_food_delivery_status/).

## Other providers — investigated, not enabled

**DoorDash:** its official personal-use CLI supports structured order status and JSON output, but is currently restricted to approved private-beta testers. This is a candidate for a local read-only adapter after account access is granted. The separate corporate MCP product is also private beta and explicitly unavailable for consumer-facing products. No beta access or user connection is configured here. [Personal CLI](https://developer.doordash.com/en-US/docs/cli/overview/about_cli/), [MCP eligibility](https://developer.doordash.com/en-US/docs/mcp/overview/about_mcp/).

**Zomato:** an official MCP server supports order tracking. Its published manifest limits redirect URIs and explicitly disallows third-party apps without an integration discussion. A NotchIslandSports callback needs provider approval; using another client's callback would not be a legitimate connection. This corrects the earlier research note that did not find a consumer tracking source. [Official manifest and access form](https://github.com/Zomato/mcp-server-manifest).

**Uber Eats:** published Eats APIs access connected merchants' orders; their customer login flow does not provide the required order-reading scopes. Uber Direct can track deliveries created by that partner integration. Neither establishes access to a person's arbitrary existing Eats orders. A partner agreement or a validated user-authorized browser tracking adapter would be needed. No browser scraping adapter is shipped without a real tracking page and lifecycle tests. [Eats authentication](https://developer.uber.com/docs/eats/guides/authentication), [partner scope](https://developer.uber.com/docs/eats/guides/getting-started), [Direct tracking](https://developer.uber.com/docs/deliveries/direct/api/v1/get-eats-deliveries-orders-orderid).

For these providers, compatible iPhone Live Activities can still appear in **macOS's system menu bar** after iPhone Mirroring is configured. That is separate from importing them into this app. [Apple setup](https://support.apple.com/en-ie/120684).
