import Foundation

public enum FinderSelectionError: Error, Equatable, Sendable {
    case emptySelection
    case multipleSelections(count: Int)
    case unsupportedURL(String)
    case missingPath(String)
    case notDirectory(String)
}

public struct FinderSelection: Sendable {
    public init() {}

    public func resolveSelectedDirectory(from urls: [URL]) throws -> ValidatedDirectory {
        guard !urls.isEmpty else {
            throw FinderSelectionError.emptySelection
        }

        guard urls.count == 1 else {
            throw FinderSelectionError.multipleSelections(count: urls.count)
        }

        let url = urls[0]
        guard url.isFileURL else {
            throw FinderSelectionError.unsupportedURL(url.absoluteString)
        }

        let resolvedURL = url.resolvingSymlinksInPath().standardizedFileURL
        let path = resolvedURL.path

        guard FileManager.default.fileExists(atPath: path) else {
            throw FinderSelectionError.missingPath(path)
        }

        guard RegistryStore.directoryExists(at: path) else {
            throw FinderSelectionError.notDirectory(path)
        }

        return ValidatedDirectory(path: path)
    }
}
