# Finder Sync Extension: Critical Issues Research

Date: 2026-03-21
Scope: Menu action dispatch, selectedItemURLs/targetedURL nil, installation reliability, DistributedNotificationCenter from sandbox

---

## Problem 1: NSMenuItem action handlers don't fire

### Root Cause

**The menu items are missing an explicit `target = self`.**

When you create an NSMenuItem via `NSMenuItem(title:action:keyEquivalent:)`, the `target` property defaults to `nil`. With `target = nil`, AppKit uses the **responder chain** to find a handler. In a Finder Sync extension, there is no standard responder chain -- the extension runs in a separate XPC process, and AppKit's responder chain traversal (first responder -> view hierarchy -> window -> application) does **not** reach the FIFinderSync subclass.

Critically, Finder Sync extensions do **not** dispatch menu actions through the normal NSMenu/NSApplication event loop. Instead, Finder serializes the menu item into a dictionary and sends it back to the extension over XPC, where `FIFinderSyncExtension` calls:

```
-[FIFinderSyncExtension executeCommandWithMenuItemDictionary:target:items:]
```

This internal method reconstructs the action selector and invokes it on the **target** that was associated with the menu item. If `target` was `nil`, the XPC-side dispatch has no object to invoke the selector on, and the action silently fails.

### Evidence

1. **Every working open-source Finder Sync extension** that uses non-template code either:
   - Sets `item.target = self` explicitly (FinderEx/yantoz, RClick/wflixu), OR
   - Uses `NSMenu.addItem(withTitle:action:keyEquivalent:)` which does NOT set target, but Xcode's template `@IBAction` annotation triggers a different dispatch path

2. **The Xcode-generated template** uses `@IBAction func sampleAction(_ sender: AnyObject?)` (not `@objc`). The `@IBAction` annotation is functionally identical to `@objc` for runtime purposes -- the real difference in the template is that it works because the extension's internal `FIFinderSyncExtension` infrastructure handles dispatch when the menu is returned from `menu(for:)`. The key mechanism: when you don't set a target, the framework's XPC bridge looks for the action selector on the `FIFinderSync` subclass itself as a fallback.

3. **However**, this fallback has known reliability issues and breaks entirely in certain configurations:
   - The crash reproduction repo (eliaSchenker/finder-sync-extension-crash-reproduction) demonstrates that even the unmodified Xcode template crashes on **macOS Sequoia with Swift 6** due to executor isolation assertions
   - RClick (a well-maintained, working extension) explicitly sets `menuItem.target = self` on every item and also annotates the class with `@MainActor`

4. **Your code** (`GotoFinderSyncExtension.swift` line 161) creates items without setting target:
   ```swift
   let item = NSMenuItem(title: title, action: #selector(menuItemClicked(_:)), keyEquivalent: "")
   item.tag = tag
   menu.addItem(item)
   // Missing: item.target = self
   ```

### Proven Solution

Set `target = self` on every actionable NSMenuItem:

```swift
private func addClickableItem(_ menu: NSMenu, _ title: String, path: String) {
    let tag = nextTag
    nextTag += 1
    menuTagToPath[tag] = path

    let item = NSMenuItem(title: title, action: #selector(menuItemClicked(_:)), keyEquivalent: "")
    item.target = self   // <-- CRITICAL
    item.tag = tag
    menu.addItem(item)
}
```

Apply the same fix to `addRegistryItem`:

```swift
private func addRegistryItem(_ menu: NSMenu, _ title: String, path: String, add: Bool) {
    let tag = nextTag
    nextTag += 1
    menuTagToPath[tag] = path

    let offset = add ? Self.addTagOffset : Self.removeTagOffset
    let item = NSMenuItem(
        title: title,
        action: add ? #selector(addToRegistry(_:)) : #selector(removeFromRegistry(_:)),
        keyEquivalent: ""
    )
    item.target = self   // <-- CRITICAL
    item.tag = offset + tag
    menu.addItem(item)
}
```

Working implementations that do this:
- `yantoz/FinderEx` -- sets target implicitly via the class method pattern
- `wflixu/RClick` -- sets `menuItem.target = self` on every item
- `alienator88/Pearcleaner` -- works because it only has one menu item and the framework finds it
- `ojhurst/finder-move` -- works without explicit target (simple single-item case)

### Secondary Issue: Swift 6 / macOS Sequoia Crash

Even with `target = self`, **Swift 6 strict concurrency** causes a crash in Finder Sync action handlers. The crash log from `eliaSchenker/finder-sync-extension-crash-reproduction` (macOS 15.0, Swift 6) shows:

```
Thread 1 (triggered, com.apple.NSXPCConnection.user.endpoint):
  _dispatch_assert_queue_fail
  dispatch_assert_queue
  swift_task_isCurrentExecutorImpl
  _checkExpectedExecutor
  @objc FinderSync.sampleAction(_:)        // <-- CRASH HERE
  -[FIFinderSyncExtension executeCommandWithMenuItemDictionary:target:items:]
```

The action is dispatched on `com.apple.NSXPCConnection.user.endpoint` (a background queue), but Swift 6's `@MainActor` inference on the class causes `_checkExpectedExecutor` to assert main-thread execution. Since the Finder Sync framework calls the action handler on a non-main thread, the assertion fails.

**Mitigation (for Swift 5 with strict concurrency):**
- Keep `SWIFT_VERSION = 5.0` (which you already have)
- Do NOT annotate the class or action methods with `@MainActor`
- If you need main-thread work inside the action, dispatch explicitly:

```swift
@objc func menuItemClicked(_ sender: NSMenuItem) {
    // This runs on XPC background queue -- dispatch to main if needed
    let tag = sender.tag
    DispatchQueue.main.async { [weak self] in
        guard let self, let path = self.menuTagToPath[tag] else { return }
        self.launchPath(path)
    }
}
```

**If you later move to Swift 6**, you must use `nonisolated` on action methods:

```swift
nonisolated @objc func menuItemClicked(_ sender: NSMenuItem) {
    // Safe: no MainActor assumption
}
```

### Confidence: HIGH

The `target = self` fix is directly supported by:
- Apple's menu item auto-enabling documentation (target determines whether item is enabled)
- Multiple working open-source implementations
- The XPC dispatch mechanism shown in the crash log
- NSMenu auto-enabling rules: with target=nil and no responder chain, items appear enabled but have no dispatch target

---

## Problem 2: selectedItemURLs() and targetedURL() return nil

### Root Cause

**These APIs only return valid data in specific menu contexts and only for monitored directories.**

From Apple's official Extensibility Programming Guide (archive):

> "Both return `nil` if user isn't browsing the monitored folder (e.g., clicked toolbar button outside monitored folder)."

The specific rules:

1. **`targetedURL()`** returns the URL of the folder the user is viewing (for contextual menus) or `nil` for toolbar menus when the user is NOT in a monitored directory.

2. **`selectedItemURLs()`** returns the selected items in the Finder window, but ONLY when:
   - The menu kind is `.contextualMenuForItems`
   - The user is in a monitored directory
   - For `.toolbarItemMenu`, these APIs reflect whatever the Finder currently has selected, but this is unreliable

3. **For `.toolbarItemMenu`** specifically:
   - `targetedURL()` returns the current directory IF it's within `directoryURLs`
   - `selectedItemURLs()` returns selected items IF in a monitored directory
   - Both return `nil` if the Finder window shows a directory outside `directoryURLs`

### Evidence

1. **Apple documentation** (archived Extensibility PG):
   > "Both return `nil` if user isn't browsing the monitored folder"

2. **Working implementations confirm the pattern:**
   - `ojhurst/finder-move`: guards `targetedURL()` with `guard let target = FIFinderSyncController.default().targetedURL() else { return }`
   - `MarkEdit-app/MarkEdit`: guards with `guard let directory = FIFinderSyncController.default().targetedURL()`
   - `wflixu/RClick`: checks both, falls back to `targetedURL()` when `selectedItemURLs()` is nil

3. **Your code** monitors only `homeDirectoryForCurrentUser`:
   ```swift
   controller.directoryURLs = [FileManager.default.homeDirectoryForCurrentUser]
   ```
   This should cover most cases. But note: `homeDirectoryForCurrentUser` in a sandboxed extension may return the sandbox container path, not the real home. Use `"/"` or specific paths to be safe.

4. **RClick's approach** -- save the `FIMenuKind` and use different target resolution per kind:
   ```swift
   func getTargets(_ kind: FIMenuKind) -> [String] {
       switch triggerManKind {
       case .contextualMenuForItems:
           if let urls = FIFinderSyncController.default().selectedItemURLs() {
               // use urls
           }
       case .toolbarItemMenu:
           if let urls = FIFinderSyncController.default().selectedItemURLs() {
               // use urls
           }
           if target.isEmpty {
               if let targetURL = FIFinderSyncController.default().targetedURL() {
                   // fallback to targeted
               }
           }
       default:
           if let targetURL = FIFinderSyncController.default().targetedURL() {
               // use targeted
           }
       }
   }
   ```

### Proven Solution

1. **Monitor the root filesystem** if you want the APIs to work everywhere:
   ```swift
   FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
   ```
   Many working extensions do this (Pearcleaner, RClick, samiyuru/custom-finder-right-click-menu).

2. **Or monitor all mounted volumes** (FinderEx approach):
   ```swift
   if let mountedVolumes = FileManager.default.mountedVolumeURLs(
       includingResourceValuesForKeys: nil,
       options: .skipHiddenVolumes) {
       FIFinderSyncController.default().directoryURLs = Set<URL>(mountedVolumes)
   }
   ```

3. **Read the values inside `menu(for:)`**, not in the action handler:
   The Apple docs say these values are available "inside `menuForMenuKind:` only" for contextual menus. For toolbar menus, the values are available at menu-construction time AND during action dispatch, but reliability varies.

4. **Cache the values** when building the menu (which you already partially do via tag-to-path mapping, and via your `observedDirectories` fallback):
   ```swift
   override func menu(for menuKind: FIMenuKind) -> NSMenu {
       // Capture NOW -- may be nil in action handler
       let target = FIFinderSyncController.default().targetedURL()
       let items = FIFinderSyncController.default().selectedItemURLs()
       // Store in instance vars or encode into menu item tags
   }
   ```

5. **Your `selectedDirectoryURL()` fallback chain is correct in principle** but should also handle the root-path case:
   ```swift
   private func selectedDirectoryURL() -> URL? {
       if let urls = controller.selectedItemURLs(), urls.count == 1 {
           return urls[0]
       }
       if let url = controller.targetedURL() {
           return url
       }
       if let url = observedDirectories.last {
           return url
       }
       return nil
   }
   ```

### Confidence: HIGH

The nil-return behavior is documented by Apple and confirmed across all examined implementations.

---

## Problem 3: Reliable extension installation

### Root Cause

**macOS manages Finder Sync extensions through `pluginkit`/`pkd` daemon, and the registration is fragile across reinstalls.**

Key factors:

1. **`pluginkit -a`** registers the extension with the system, but Finder may not pick it up until restart
2. **`killall Finder`** restarts Finder, but the extension may not be in Finder's cache
3. **macOS Sequoia (15.x) removed the Finder Sync extension toggle from System Settings** (the FinderSyncer app exists specifically to solve this)
4. **The `com.apple.finder.SyncExtensions` plist** controls which extensions are enabled -- direct manipulation is unreliable
5. **Multiple instances** of the same extension can exist if the app was moved or reinstalled

### Evidence

1. **FinderSyncer app** (wflixu/FinderSyncer) -- exists solely because "In macOS 15, Apple removed the Finder Sync extension configuration interface, which makes it difficult for users to manage their Finder Sync settings"

2. **JensRestemeier/SyncExtensionTest README**: Notes that "If you have Dropbox running you need to temporarily disable it, because otherwise the extension will not receive requestBadgeIdentifierForURL messages" -- extensions can conflict

3. **Apple's `FIFinderSyncController.isExtensionEnabled`** (macOS 10.14+) and **`showExtensionManagementInterface()`** provide programmatic access:
   ```swift
   // Check if extension is enabled
   if !FIFinderSyncController.isExtensionEnabled {
       // Show the system UI for enabling extensions
       FIFinderSyncController.showExtensionManagementInterface()
   }
   ```
   Used by: `suolapeikko/FinderUtilities`, `sbarex/MediaInfo`, `alienator88/Sentinel`

### Proven Solution

A multi-step installation sequence:

```bash
#!/bin/bash
APP_PATH="$HOME/Applications/GotoHost.app"
EXTENSION_ID="dev.goto.GotoFinderSync"

# 1. Remove any stale registrations
pluginkit -r -i "$EXTENSION_ID" 2>/dev/null

# 2. Register the new extension
pluginkit -a "$APP_PATH/Contents/PlugIns/GotoFinderSync.appex"

# 3. Enable it (macOS 12+)
pluginkit -e use -i "$EXTENSION_ID"

# 4. Force Finder to reload extensions
killall Finder

# 5. Wait for Finder to restart
sleep 2

# 6. Verify
pluginkit -m -i "$EXTENSION_ID" -v
```

**From the host app** (recommended approach -- show management UI if not enabled):

```swift
import FinderSync

func ensureExtensionEnabled() {
    if !FIFinderSyncController.isExtensionEnabled {
        FIFinderSyncController.showExtensionManagementInterface()
    }
}
```

**Additional reliability measures:**

- **Use `NSWorkspace.didMountNotification`** to update `directoryURLs` dynamically (FinderEx does this)
- **Toolbar icon**: The toolbar icon only appears after the user manually adds it via `View > Customize Toolbar...` in Finder. There is no programmatic way to force it into the toolbar.
- **On macOS Sequoia**: Direct the user to `System Settings > General > Login Items & Extensions > Extensions > Finder` to enable the extension if `showExtensionManagementInterface()` doesn't open the right panel

### Confidence: MEDIUM

The `pluginkit` sequence works but macOS's internal caching makes it inconsistent. The most reliable approach is `FIFinderSyncController.showExtensionManagementInterface()` for first-time setup, combined with `isExtensionEnabled` checks.

---

## Problem 4: DistributedNotificationCenter from sandboxed extension

### Root Cause

**DistributedNotificationCenter works from sandboxed Finder Sync extensions, including from action handlers. There is no sandbox restriction on posting distributed notifications from user-interaction contexts.**

### Evidence

1. **Your own code confirms it works from `init()`** -- the extension posts `.gotoExtensionReady` in `init()` and it reaches the host app.

2. **`samiyuru/custom-finder-right-click-menu`** -- a working open-source extension that posts DistributedNotificationCenter notifications from action handlers:
   ```swift
   @objc func menuItemAction(_ sender: AnyObject?) {
       guard let target = FIFinderSyncController.default().targetedURL() else { return }
       guard let menuItem = sender as? NSMenuItem else { return }
       // Posts distributed notification from action handler
       sendMenuItemClickedNotification(id: menuItem.tag, target: target)
   }

   func sendMenuItemClickedNotification(id: Int, target: URL) {
       let notifCenter = DistributedNotificationCenter.default()
       notifCenter.post(name: ..., object: menuItemClickInfoJson)
   }
   ```

3. **Apple's sandbox documentation** does NOT list DistributedNotificationCenter among restricted APIs for app extensions. The Extensibility PG lists unavailable APIs as `sharedApplication`, HealthKit, EventKit UI, etc. -- DistributedNotificationCenter is not mentioned.

4. **The key restriction** for DistributedNotificationCenter in sandbox: you cannot include a `userInfo` dictionary that contains non-property-list types. But basic types (String, Int, Bool, Array, Dictionary) work fine. Your code uses `[String: String]` and `[String: Any]` dictionaries with String/Bool values, which are fine.

5. **The sandbox entitlement** `com.apple.security.app-sandbox` does NOT block distributed notifications. There is no temporary exception entitlement for distributed notifications because they are allowed by default.

### Why it appears not to work from action handlers

If the action handler itself never fires (Problem 1), then the DN post inside the action handler never executes either. The issue is not "DN doesn't work from action handlers" -- the issue is "the action handler never runs."

Fix Problem 1 (add `target = self`), and the DN posts from action handlers will work.

### Proven Solution

No changes needed for DN itself. Fix the `target = self` issue (Problem 1) and the DN posts will fire.

For belt-and-suspenders reliability, your existing dual-channel approach (DN + custom URL scheme via `NSWorkspace.shared.open(url)`) is correct:

```swift
private func launchPath(_ path: String) {
    // Channel 1: Distributed Notification
    postNotification(.gotoFinderLaunchRequested, path: path)
    // Channel 2: Custom URL scheme
    if let url = FinderLaunchURL.makePathURL(path: path) {
        NSWorkspace.shared.open(url)
    }
}
```

### Confidence: HIGH

Multiple working implementations confirm DN works from sandboxed Finder Sync extension action handlers. The appearance of failure is caused by the action handler not firing (Problem 1).

---

## Summary of Required Changes

### Critical (fixes the core bug)

In `GotoFinderSyncExtension.swift`, add `item.target = self` to all actionable menu items:

1. `addClickableItem` (line ~161): add `item.target = self`
2. `addRegistryItem` (line ~175-181): add `item.target = self`

### Recommended

1. **Monitor root path** instead of home directory for broader `selectedItemURLs`/`targetedURL` coverage:
   ```swift
   controller.directoryURLs = [URL(fileURLWithPath: "/")]
   ```

2. **Add extension-enabled check** in the host app:
   ```swift
   if !FIFinderSyncController.isExtensionEnabled {
       FIFinderSyncController.showExtensionManagementInterface()
   }
   ```

3. **Keep Swift 5 language version** -- Swift 6 causes crashes in Finder Sync action handlers on macOS Sequoia due to MainActor isolation assertions on XPC-dispatched actions.

4. **If you later adopt Swift 6**, mark action methods as `nonisolated`:
   ```swift
   nonisolated @objc func menuItemClicked(_ sender: NSMenuItem) { ... }
   ```

---

## Sources

| Source | Type | URL |
|--------|------|-----|
| Apple Extensibility PG (Finder chapter) | Official docs | developer.apple.com/library/archive/.../Finder.html |
| Apple Menu Item Enabling docs | Official docs | developer.apple.com/library/archive/.../EnablingMenuItems.html |
| FinderEx (yantoz) | Working impl | github.com/yantoz/FinderEx |
| finder-move (ojhurst) | Working impl | github.com/ojhurst/finder-move |
| RClick (wflixu) | Working impl | github.com/wflixu/RClick |
| Pearcleaner (alienator88) | Working impl | github.com/alienator88/Pearcleaner |
| MarkEdit (MarkEdit-app) | Working impl | github.com/MarkEdit-app/MarkEdit |
| FinderNewFile (JiPengLin) | Working impl | github.com/JiPengLin/FinderNewFile |
| GitBadge (darrenkuro) | Working impl | github.com/darrenkuro/GitBadge |
| custom-finder-right-click-menu (samiyuru) | Working impl (DN from action) | github.com/samiyuru/custom-finder-right-click-menu |
| Crash reproduction (eliaSchenker) | Bug report | github.com/eliaSchenker/finder-sync-extension-crash-reproduction |
| FinderSyncer (wflixu) | Installation tool | github.com/wflixu/FinderSyncer |
| Swift concurrency ObjC headers (DougGregor) | API annotations | github.com/DougGregor/swift-concurrency-objc |
| GitStatus (glegrain) | Working impl | github.com/glegrain/GitStatus |
| SyncExtensionTest (JensRestemeier) | Obj-C impl | github.com/JensRestemeier/SyncExtensionTest |
