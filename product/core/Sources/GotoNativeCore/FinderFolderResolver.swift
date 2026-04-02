import Foundation

public enum FinderFolderResolver: Sendable {
    public static func resolvedFolderURL(
        selectedItemURLs: [URL]?,
        targetedURL: URL?
    ) -> URL? {
        if let selected = selectedItemURLs?.first {
            return normalize(url: selected)
        }

        if let targetedURL {
            return normalize(url: targetedURL)
        }

        return nil
    }

    public static func normalize(url: URL) -> URL {
        var isDirectory: ObjCBool = false

        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            return isDirectory.boolValue ? url : url.deletingLastPathComponent()
        }

        return url.deletingLastPathComponent()
    }
}
