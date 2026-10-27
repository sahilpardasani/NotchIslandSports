# Vendored source

Upstream: https://github.com/ungive/mediaremote-adapter
Pinned Git tree: 0e82bf1c44ec39554fbfc402ec88a48c6ae2a0fd (retrieved 2026-10-27).
BSD-3-Clause; LICENSE is included in the distributed app.
Built from Objective-C sources with the installed Apple command-line SDK; no opaque binary download.
Local modification: send.m checks the expected source bundle ID and title immediately before sending transport commands. A small global-command race remains.
This uses private MediaRemote through the system Perl interpreter. It is experimental, not a public Apple API or an App Store guarantee. It does not change system settings, SIP, or entitlements.
