# ADR-005: Finder Sync extension cannot use NSWorkspace.open(url:) from sandbox

## Status

Accepted

## Context

The Finder Sync extension initially attempted to communicate with the
host app by opening a custom URL scheme (`goto-host://...`) via
`NSWorkspace.shared.open(_:)`. In practice, this call is silently
blocked by the sandbox with no error or callback, making it unreliable
for extension-to-host communication.

## Decision

Use `DistributedNotificationCenter` for all extension-to-host
communication. The URL scheme (`goto-host://`) is retained exclusively
for external callers (e.g. `open goto-host://navigate?path=/foo` from
a shell script or another app) where the caller is not sandboxed.

## Consequences

- All IPC between the extension and host is notification-based,
  providing a single, consistent communication channel.
- The URL scheme remains useful for scripting and third-party
  integrations but is never invoked from the extension itself.
- Two IPC surfaces exist (notifications + URL scheme), so the host
  must handle both; however, they share the same action-dispatch
  logic internally.
- Future macOS sandbox policy changes won't break the primary
  extension communication path.
