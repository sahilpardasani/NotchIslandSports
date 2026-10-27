# Approval requests — preview 1.6 build 10

## What is connected

| Source | Coverage |
| --- | --- |
| Codex CLI / supported local Codex desktop sessions | Synchronous `PermissionRequest` hooks. Review/trust the installed hook in the source. |
| ChatGPT desktop local coding sessions | Only sessions that actually load and run the local Codex hook configuration. This is not universal ChatGPT notification interception. |
| Claude Code CLI / supported local desktop Code sessions | Synchronous `PermissionRequest` hooks loaded on this Mac. |
| Generic ChatGPT chat, Claude Chat/Cowork, cloud-only or remote sessions | No verified direct approval integration in this build. Respond in the originating app. |
| Claude sandbox network prompt / general notifications | Not intercepted by the PermissionRequest adapter. These are not actionable approval cards. |

The sources define their own hook support and managed restrictions. A successful installation is not proof that a particular session loads the hook. No private notification scraping or automatic clicking of source-app buttons is used.

Official contracts: [OpenAI lifecycle hooks](https://learn.chatgpt.com/docs/hooks), [Claude Code hooks](https://code.claude.com/docs/en/hooks), [Claude desktop Code](https://code.claude.com/docs/en/desktop). Both PermissionRequest contracts support an allow/deny response; an empty response leaves the normal approval flow in control. Source policies still apply. Local hooks do not establish a universal desktop or cloud approval API.

## Configure once

1. Install the packaged app in a stable location and open **About → Configure**.
2. Select **Connect Codex…** and/or **Connect Claude Code…**. This installs the bundled helper in your private Application Support folder and adds one PermissionRequest handler. Existing settings and unrelated hooks are preserved, with a private backup before a change.
3. For Codex, review and trust the new handler in `/hooks`. Restart local sessions as required by the source. The app does not bypass hook trust, change permission modes or remove organizational restrictions.
4. Trigger a harmless request that genuinely requires permission in the source. The notch shows an orange **Approval needed** activity. Expand it to read all hook-supplied request fields and choose **Approve once**, **Deny**, or **Use app prompt**.

Codex configuration: `hooks.json` under the app process's `CODEX_HOME` when set, otherwise `~/.codex/hooks.json`. Claude Code configuration: `~/.claude/settings.json`. Custom remote/configuration directories are not automatically discovered. Reconnecting is idempotent. Disable **Approval requests** to stop the listener; installed handlers then return immediately to the normal prompt when no endpoint is available. To remove a handler entirely, remove only the command ending in `--notch-approval codex` or `--notch-approval claude-code` from the relevant PermissionRequest group; preserve other hooks.

## Interaction and semantics

- Pending requests receive an orange attention satellite without automatically expanding or stealing keyboard focus. A new request separates merged activities; the primary remains stable. Up to three slots remain visible. Additional activities remain reachable by swiping; Calendar still uses no slot.
- Menu crowding can merge satellites. **Select Widget → Approvals** or sideways paging still reaches the request. This is urgency within the notch, not an entitlement to bypass macOS Focus or system notification settings.
- The expanded view shows the complete JSON supplied by the hook in a selectable, scrollable view. It is not a transcript reader and cannot display context the source omitted. Requests above 256 KiB fall back to the source rather than showing truncated details with an approval button.
- Approval applies only to the exact waiting connection/request ID. The app never executes the command itself, alters tool input or returns permanent permission changes. Resolving one request does not automatically select another for approval.
- After two minutes, source cancellation, disconnect, app disable, sleep or lock, the connection returns without an approval decision. The ordinary source prompt remains responsible. An unavailable helper or app must never grant permission.
- Source execution may still be denied by another hook or policy. Sending a decision is not proof that the tool ran.

## Privacy, security and energy

The listener is a Unix-domain socket in a private random directory. Both peers check the local user identity; a per-listener random secret is read through an owner-only file without following symlinks. Fresh timestamps, UUID replay checks, packet/connection limits and short handshake deadlines reject malformed or replayed traffic. No TCP server, browser injection, screen recording or idle request polling is added. The socket uses event-driven reads and per-pending-request timeouts.

Request text stays in memory while pending and is removed on resolution/disconnect. Request content is not logged or persisted. Configuration backups contain the pre-existing settings and are owner-only. The shared local-user boundary is not a defense against another malicious process already running as that same user with access to the private helper/secret. Provider labels reflect the configured local hook, not cryptographic attestation by OpenAI or Anthropic.

## Verification and remaining device checks

Automated coverage includes both hook schemas, invalid tokens/providers/events, old timestamps, full long details, oversized payload fallback, exact-ID response binding, one-time decisions, idempotent settings merge, preserving unrelated policies, stdin EOF handling, and local socket request/decision/disconnect/replay behavior. The local coding sandbox blocks socket binding; full socket checks run on macOS CI with normal process permissions. Synthetic UI renders use explicitly fake requests and approve no agent action.

Before calling a source/version fully supported, test in a disposable project: receive a real permission request, inspect every field, deny it, approve a second harmless request once, cancel a third in the source, and test app quit/sleep/timeout. Repeat with multiple sessions and custom managed policies. Actual ChatGPT/Codex and Claude live hook sessions have not been verified end-to-end here. General desktop Chat/Cowork coverage is not implemented.
