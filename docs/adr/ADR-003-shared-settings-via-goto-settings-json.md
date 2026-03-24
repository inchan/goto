# ADR-003: Shared settings via ~/.goto-settings JSON

## Status

Accepted

## Context

Finder click-behavior settings (e.g. single-click action, default
terminal) must be readable by both the host app and the Finder Sync
extension. App Groups require additional entitlements and provisioning
profiles, which complicates the build for an open-source CLI tool.

## Decision

Store shared settings as a JSON file at `~/.goto-settings`. Each
process reads the file on every access (no in-memory caching). Writes
are performed atomically (write-to-temp then rename) to prevent
partial-read corruption across processes.

## Consequences

- Cross-process settings work without App Groups or any sandboxing
  entitlement beyond file-system access to the home directory.
- No caching means each read hits disk; acceptable given the small
  file size and infrequent access pattern.
- Atomic writes prevent corruption but do not provide locking;
  near-simultaneous writes from two processes could result in one
  write being lost (acceptable given the UI-driven write frequency).
- The user can hand-edit the file if needed; JSON is human-readable.
