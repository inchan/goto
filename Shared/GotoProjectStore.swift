import Foundation

public enum GotoProjectStoreError: Error {
    case pathNotDirectory(String)
    case parentNotReadable(String)
}

public enum GotoProjectStore {
    nonisolated(unsafe) static var storeURLOverride: URL?

    public static var storeURL: URL {
        if let storeURLOverride {
            return storeURLOverride
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".goto", isDirectory: false)
    }

    public static var watchedStoreURL: URL {
        return storeURL.deletingLastPathComponent()
            .appendingPathComponent(storeURL.lastPathComponent + "_watched", isDirectory: false)
    }

    static func normalize(_ path: String) -> String {
        let expanded: String
        if path.hasPrefix("~") {
            expanded = (path as NSString).expandingTildeInPath
        } else {
            expanded = path
        }
        return URL(fileURLWithPath: expanded)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }

    private static func isDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    private static func isGitManagedDirectory(_ path: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", path, "rev-parse", "--show-toplevel"]

        let output = Pipe()
        let errorOutput = Pipe()
        process.standardOutput = output
        process.standardError = errorOutput

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return false
        }

        guard process.terminationStatus == 0 else {
            return false
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let topLevel = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !topLevel.isEmpty
        else {
            return false
        }

        return normalize(topLevel) == normalize(path)
    }

    private static func rawLoad() -> [String] {
        guard let content = try? String(contentsOf: storeURL, encoding: .utf8) else {
            return []
        }
        return content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func saveEntries(_ entries: [String]) throws {
        let sorted = Array(Set(entries)).sorted()
        let content = sorted.joined(separator: "\n") + "\n"
        let data = Data(content.utf8)

        let tmp = storeURL.deletingLastPathComponent()
            .appendingPathComponent("projects.txt.tmp-\(ProcessInfo.processInfo.processIdentifier)")

        try data.write(to: tmp, options: .atomic)

        if FileManager.default.fileExists(atPath: storeURL.path) {
            _ = try FileManager.default.replaceItemAt(
                storeURL,
                withItemAt: tmp,
                backupItemName: nil,
                options: []
            )
        } else {
            try FileManager.default.moveItem(at: tmp, to: storeURL)
        }
    }

    public static func load() -> [String] {
        return rawLoad()
            .map { normalize($0) }
            .filter { !$0.isEmpty }
            .sorted()
    }

    @discardableResult
    public static func add(_ path: String) throws -> Bool {
        let norm = normalize(path)
        guard isDirectory(norm) else {
            throw GotoProjectStoreError.pathNotDirectory(norm)
        }
        var entries = rawLoad().map { normalize($0) }
        if entries.contains(norm) { return false }
        entries.append(norm)
        try saveEntries(entries)
        return true
    }

    @discardableResult
    public static func remove(_ path: String) throws -> Bool {
        let norm = normalize(path)
        var entries = rawLoad().map { normalize($0) }
        let before = entries.count
        entries.removeAll { $0 == norm }
        if entries.count == before { return false }
        try saveEntries(entries)
        return true
    }

    @discardableResult
    public static func addSubdirs(_ parent: String) throws -> Int {
        let normParent = normalize(parent)
        guard isDirectory(normParent) else {
            throw GotoProjectStoreError.pathNotDirectory(normParent)
        }
        let dirEntries: [String]
        do {
            dirEntries = try FileManager.default.contentsOfDirectory(atPath: normParent)
        } catch {
            throw GotoProjectStoreError.parentNotReadable(normParent)
        }

        var count = 0
        for entry in dirEntries {
            guard !entry.hasPrefix(".") else { continue }
            let childPath = (normParent as NSString).appendingPathComponent(entry)
            guard isDirectory(childPath) else { continue }
            guard isGitManagedDirectory(childPath) else { continue }
            let added = try add(childPath)
            if added { count += 1 }
        }
        addWatched(normParent)
        return count
    }

    @discardableResult
    public static func removeSubdirs(_ parent: String) throws -> Int {
        let normParent = normalize(parent)
        let prefix = normParent.hasSuffix("/") ? normParent : normParent + "/"

        var entries = rawLoad().map { normalize($0) }
        let before = entries.count

        entries = entries.filter { p in
            guard p.hasPrefix(prefix) else { return true }
            let remainder = String(p.dropFirst(prefix.count))
            return remainder.contains("/")
        }

        let removed = before - entries.count
        if removed > 0 {
            try saveEntries(entries)
        }
        return removed
    }

    // MARK: - Watched subdirs

    private static func rawLoadWatched() -> [String] {
        guard let content = try? String(contentsOf: watchedStoreURL, encoding: .utf8) else {
            return []
        }
        return content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func saveWatchedEntries(_ entries: [String]) throws {
        let sorted = Array(Set(entries)).sorted()
        let content = sorted.joined(separator: "\n") + "\n"
        let data = Data(content.utf8)

        let tmp = watchedStoreURL.deletingLastPathComponent()
            .appendingPathComponent("watched.txt.tmp-\(ProcessInfo.processInfo.processIdentifier)")

        try data.write(to: tmp, options: .atomic)

        if FileManager.default.fileExists(atPath: watchedStoreURL.path) {
            _ = try FileManager.default.replaceItemAt(
                watchedStoreURL,
                withItemAt: tmp,
                backupItemName: nil,
                options: []
            )
        } else {
            try FileManager.default.moveItem(at: tmp, to: watchedStoreURL)
        }
    }

    public static func loadWatched() -> [String] {
        return rawLoadWatched()
            .map { normalize($0) }
            .filter { !$0.isEmpty }
            .sorted()
    }

    @discardableResult
    public static func addWatched(_ path: String) -> Bool {
        let norm = normalize(path)
        var entries = rawLoadWatched().map { normalize($0) }
        if entries.contains(norm) { return false }
        entries.append(norm)
        try? saveWatchedEntries(entries)
        return true
    }

    @discardableResult
    public static func removeWatched(_ path: String) -> Bool {
        let norm = normalize(path)
        var entries = rawLoadWatched().map { normalize($0) }
        let before = entries.count
        entries.removeAll { $0 == norm }
        if entries.count == before { return false }
        try? saveWatchedEntries(entries)
        return true
    }

    @discardableResult
    public static func syncWatched() -> (added: Int, removed: Int) {
        var addedCount = 0
        var removedCount = 0

        var watched = loadWatched()
        var watchedChanged = false

        for parent in watched {
            let prefix = parent.hasSuffix("/") ? parent : parent + "/"

            // Helper: is `p` a direct child of `parent`?
            func isDirectChild(_ p: String) -> Bool {
                guard p.hasPrefix(prefix) else { return false }
                let remainder = String(p.dropFirst(prefix.count))
                return !remainder.contains("/")
            }

            if !isDirectory(parent) {
                // Parent gone: remove all registered direct children, then drop parent from watched.
                let entries = rawLoad().map { normalize($0) }
                for entry in entries where isDirectChild(entry) {
                    if (try? remove(entry)) == true {
                        removedCount += 1
                    }
                }
                continue
            }

            // Parent exists.
            // Add: direct-child dirs that are git roots and not yet registered.
            if let dirEntries = try? FileManager.default.contentsOfDirectory(atPath: parent) {
                for childName in dirEntries {
                    guard !childName.hasPrefix(".") else { continue }
                    let childPath = (parent as NSString).appendingPathComponent(childName)
                    guard isDirectory(childPath) else { continue }
                    guard isGitManagedDirectory(childPath) else { continue }
                    if (try? add(childPath)) == true {
                        addedCount += 1
                    }
                }
            }

            // Remove: registered direct children whose folder no longer exists on disk.
            let entries = rawLoad().map { normalize($0) }
            for entry in entries where isDirectChild(entry) {
                guard !isDirectory(entry) else { continue }
                if (try? remove(entry)) == true {
                    removedCount += 1
                }
            }
        }

        // Drop watched parents that no longer exist.
        let survivingWatched = watched.filter { isDirectory($0) }
        if survivingWatched.count != watched.count {
            watched = survivingWatched
            watchedChanged = true
        }

        if watchedChanged {
            try? saveWatchedEntries(watched)
        }

        return (addedCount, removedCount)
    }
}
