# ADR-001: Finder Sync IPC via DistributedNotificationCenter

## Status

Accepted

## Context

The Finder Sync extension runs in a sandboxed process and cannot
directly read `~/.goto` or `~/.goto-settings`. We needed a mechanism
for the host app to share the current project list and user preferences
with the extension without requiring App Groups or a shared container.

## Decision

The host app broadcasts the project list and preferences to the Finder
Sync extension via `DistributedNotificationCenter`. The extension
listens for these notifications and caches the received data in memory.
On startup, the extension sends a "ready" notification so the host can
immediately push the current state.

## Consequences

- Extension data is always slightly stale (updated on next broadcast).
- A "ready" handshake is required at extension startup to seed initial
  data; without the host running, the extension operates on an empty
  cache.
- No file-system sharing or App Group entitlement is needed between the
  two processes.
- Notification payload size is limited (~4 KB practical); large project
  lists may need pagination or a supplementary file-based channel.
