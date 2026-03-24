import Foundation

public enum FinderClickMode: String, Equatable, Sendable, CaseIterable, Identifiable, Codable {
    case direct         // click → open current folder immediately, no menu
    case list           // click → show project list only, no auto-open
    case directPlusList // click → auto-open current folder AND show project list

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .direct:         return "Open folder directly"
        case .list:           return "Show project list"
        case .directPlusList: return "Open folder + show list"
        }
    }
}

public struct FinderPreference: Equatable, Sendable, Codable {
    public var clickMode: FinderClickMode
    public var enabled: Bool

    public init(clickMode: FinderClickMode = .directPlusList, enabled: Bool = true) {
        self.clickMode = clickMode
        self.enabled = enabled
    }

    public static let `default` = FinderPreference()
}
