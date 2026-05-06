import Foundation

enum GotoProjectSortField: String, Codable {
    case name
    case createdAt
}

enum GotoSortDirection: String, Codable {
    case ascending
    case descending
}

struct GotoCLIConfig: Codable {
    var parentSortField: GotoProjectSortField = .name
    var parentSortDirection: GotoSortDirection = .descending
    var projectSortField: GotoProjectSortField = .name
    var projectSortDirection: GotoSortDirection = .descending
}

enum GotoSortOption: CaseIterable {
    case nameAscending
    case nameDescending
    case createdAtAscending
    case createdAtDescending

    init?(identifier: String) {
        guard let option = Self.allCases.first(where: { $0.identifier == identifier }) else {
            return nil
        }
        self = option
    }

    var title: String {
        switch self {
        case .nameAscending:
            return "이름 오름차순"
        case .nameDescending:
            return "이름 내림차순"
        case .createdAtAscending:
            return "생성일 오름차순"
        case .createdAtDescending:
            return "생성일 내림차순"
        }
    }

    var identifier: String {
        "\(field.rawValue):\(direction.rawValue)"
    }

    var field: GotoProjectSortField {
        switch self {
        case .nameAscending, .nameDescending:
            return .name
        case .createdAtAscending, .createdAtDescending:
            return .createdAt
        }
    }

    var direction: GotoSortDirection {
        switch self {
        case .nameAscending, .createdAtAscending:
            return .ascending
        case .nameDescending, .createdAtDescending:
            return .descending
        }
    }

    var next: GotoSortOption {
        switch self {
        case .nameAscending:
            return .nameDescending
        case .nameDescending:
            return .createdAtAscending
        case .createdAtAscending:
            return .createdAtDescending
        case .createdAtDescending:
            return .nameAscending
        }
    }
}

struct GotoProjectDisplayItem {
    let parent: String
    let name: String
}

enum GotoProjectList {
    static let recentLimit = 3

    static func displayItem(for path: String) -> GotoProjectDisplayItem {
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent
        guard !name.isEmpty else {
            return GotoProjectDisplayItem(parent: "", name: path)
        }

        return GotoProjectDisplayItem(
            parent: url.deletingLastPathComponent().lastPathComponent,
            name: name
        )
    }

    static func displayPath(for path: String) -> String {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        if path == homePath {
            return "~"
        }
        if path.hasPrefix(homePath + "/") {
            return "~" + path.dropFirst(homePath.count)
        }
        return path
    }

    static func loadRecentProjects(availableProjects: [String]) -> [String] {
        guard let content = try? String(contentsOf: GotoSettings.recentProjectsURL, encoding: .utf8) else {
            return []
        }

        let available = Set(availableProjects)
        var seen = Set<String>()
        var recents: [String] = []

        for line in content.components(separatedBy: .newlines) {
            let path = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty, available.contains(path), !seen.contains(path) else {
                continue
            }
            seen.insert(path)
            recents.append(path)
            if recents.count == recentLimit {
                break
            }
        }

        return recents
    }

    static func recordRecentProject(_ path: String, availableProjects: [String]) {
        var recents = loadRecentProjects(availableProjects: availableProjects)
        recents.removeAll { $0 == path }
        recents.insert(path, at: 0)
        let content = recents.prefix(recentLimit).joined(separator: "\n") + "\n"
        try? content.write(to: GotoSettings.recentProjectsURL, atomically: true, encoding: .utf8)
    }

    static func sortedProjects(_ projects: [String], config: GotoCLIConfig) -> [String] {
        projects.sorted { compareProjects($0, $1, config: config) }
    }

    static func orderedProjects(
        _ projects: [String],
        config: GotoCLIConfig
    ) -> (displayProjects: [String], recentCount: Int) {
        let recents = loadRecentProjects(availableProjects: projects)
        let recentSet = Set(recents)
        let remaining = projects
            .filter { !recentSet.contains($0) }
            .sorted { compareProjects($0, $1, config: config) }
        return (recents + remaining, recents.count)
    }

    private static func compareProjects(_ lhs: String, _ rhs: String, config: GotoCLIConfig) -> Bool {
        let parent = parentComparison(lhs, rhs, config: config)
        if parent != .orderedSame {
            return parent == .orderedAscending
        }

        let project = projectComparison(lhs, rhs, config: config)
        if project != .orderedSame {
            return project == .orderedAscending
        }

        return lhs.localizedStandardCompare(rhs) == .orderedAscending
    }

    private static func parentComparison(_ lhs: String, _ rhs: String, config: GotoCLIConfig) -> ComparisonResult {
        switch config.parentSortField {
        case .name:
            return compareStrings(
                displayItem(for: lhs).parent,
                displayItem(for: rhs).parent,
                direction: config.parentSortDirection
            )
        case .createdAt:
            return compareDates(
                creationDate(for: parentPath(for: lhs)),
                creationDate(for: parentPath(for: rhs)),
                direction: config.parentSortDirection
            )
        }
    }

    private static func projectComparison(_ lhs: String, _ rhs: String, config: GotoCLIConfig) -> ComparisonResult {
        switch config.projectSortField {
        case .name:
            return compareStrings(
                displayItem(for: lhs).name,
                displayItem(for: rhs).name,
                direction: config.projectSortDirection
            )
        case .createdAt:
            return compareDates(creationDate(for: lhs), creationDate(for: rhs), direction: config.projectSortDirection)
        }
    }

    private static func creationDate(for path: String) -> Date {
        let url = URL(fileURLWithPath: path)
        let values = try? url.resourceValues(forKeys: [.creationDateKey])
        return values?.creationDate ?? .distantPast
    }

    private static func parentPath(for path: String) -> String {
        URL(fileURLWithPath: path).deletingLastPathComponent().path
    }

    private static func compareStrings(
        _ lhs: String,
        _ rhs: String,
        direction: GotoSortDirection
    ) -> ComparisonResult {
        let result = lhs.localizedStandardCompare(rhs)
        if direction == .ascending {
            return result
        }
        if result == .orderedAscending { return .orderedDescending }
        if result == .orderedDescending { return .orderedAscending }
        return .orderedSame
    }

    private static func compareDates(_ lhs: Date, _ rhs: Date, direction: GotoSortDirection) -> ComparisonResult {
        if lhs == rhs { return .orderedSame }
        let ascending: ComparisonResult = lhs < rhs ? .orderedAscending : .orderedDescending
        if direction == .ascending {
            return ascending
        }
        return ascending == .orderedAscending ? .orderedDescending : .orderedAscending
    }
}

extension GotoSettings {
    nonisolated(unsafe) static var cliConfigURLOverride: URL?
    nonisolated(unsafe) static var recentProjectsURLOverride: URL?

    static var cliConfigURL: URL {
        cliConfigURLOverride ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".goto_config")
    }

    static var recentProjectsURL: URL {
        recentProjectsURLOverride ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".goto_recent")
    }

    static func cliConfig() -> GotoCLIConfig {
        guard let data = try? Data(contentsOf: cliConfigURL),
              let config = try? JSONDecoder().decode(GotoCLIConfig.self, from: data)
        else {
            return GotoCLIConfig()
        }
        return config
    }

    static func saveCLIConfig(_ config: GotoCLIConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: cliConfigURL, options: .atomic)
    }

    static func sortOption(
        field: GotoProjectSortField,
        direction: GotoSortDirection
    ) -> GotoSortOption {
        switch (field, direction) {
        case (.name, .ascending):
            return .nameAscending
        case (.name, .descending):
            return .nameDescending
        case (.createdAt, .ascending):
            return .createdAtAscending
        case (.createdAt, .descending):
            return .createdAtDescending
        }
    }
}
