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
    var pinSortMode: GotoPinSortMode = .insertion
    var prefixColorEnabled: Bool = true
    var prefixPatternEnabled: Bool = true
    var recentLimit: Int = GotoCLIConfig.defaultRecentLimit

    static let defaultRecentLimit = 5
    static let recentLimitOptions: [Int] = [0, 1, 3, 5, 10]

    enum CodingKeys: String, CodingKey {
        case parentSortField, parentSortDirection
        case projectSortField, projectSortDirection
        case pinSortMode
        case prefixColorEnabled, prefixPatternEnabled
        case recentLimit
    }

    init(
        parentSortField: GotoProjectSortField = .name,
        parentSortDirection: GotoSortDirection = .descending,
        projectSortField: GotoProjectSortField = .name,
        projectSortDirection: GotoSortDirection = .descending,
        pinSortMode: GotoPinSortMode = .insertion,
        prefixColorEnabled: Bool = true,
        prefixPatternEnabled: Bool = true,
        recentLimit: Int = GotoCLIConfig.defaultRecentLimit
    ) {
        self.parentSortField = parentSortField
        self.parentSortDirection = parentSortDirection
        self.projectSortField = projectSortField
        self.projectSortDirection = projectSortDirection
        self.pinSortMode = pinSortMode
        self.prefixColorEnabled = prefixColorEnabled
        self.prefixPatternEnabled = prefixPatternEnabled
        self.recentLimit = GotoCLIConfig.sanitizedRecentLimit(recentLimit)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        parentSortField = try c.decodeIfPresent(GotoProjectSortField.self, forKey: .parentSortField) ?? .name
        parentSortDirection = try c.decodeIfPresent(GotoSortDirection.self, forKey: .parentSortDirection) ?? .descending
        projectSortField = try c.decodeIfPresent(GotoProjectSortField.self, forKey: .projectSortField) ?? .name
        projectSortDirection = try c.decodeIfPresent(GotoSortDirection.self, forKey: .projectSortDirection) ?? .descending
        pinSortMode = try c.decodeIfPresent(GotoPinSortMode.self, forKey: .pinSortMode) ?? .insertion
        prefixColorEnabled = try c.decodeIfPresent(Bool.self, forKey: .prefixColorEnabled) ?? true
        prefixPatternEnabled = try c.decodeIfPresent(Bool.self, forKey: .prefixPatternEnabled) ?? true
        let rawLimit = try c.decodeIfPresent(Int.self, forKey: .recentLimit) ?? GotoCLIConfig.defaultRecentLimit
        recentLimit = GotoCLIConfig.sanitizedRecentLimit(rawLimit)
    }

    static func sanitizedRecentLimit(_ value: Int) -> Int {
        max(0, min(value, 50))
    }

    static func nextRecentLimit(after current: Int) -> Int {
        let opts = recentLimitOptions
        if let idx = opts.firstIndex(of: current) {
            return opts[(idx + 1) % opts.count]
        }
        return opts.first ?? defaultRecentLimit
    }
}

enum GotoPinSortMode: String, Codable, CaseIterable {
    case insertion
    case nameAscending
    case nameDescending
    case createdAtAscending
    case createdAtDescending

    var title: String {
        switch self {
        case .insertion: return "추가순"
        case .nameAscending: return "이름 오름차순"
        case .nameDescending: return "이름 내림차순"
        case .createdAtAscending: return "생성일 오름차순"
        case .createdAtDescending: return "생성일 내림차순"
        }
    }

    var next: GotoPinSortMode {
        switch self {
        case .insertion: return .nameAscending
        case .nameAscending: return .nameDescending
        case .nameDescending: return .createdAtAscending
        case .createdAtAscending: return .createdAtDescending
        case .createdAtDescending: return .insertion
        }
    }
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

    static func namePatternPrefix(for name: String) -> (prefix: String, rest: String)? {
        guard let dashIdx = name.firstIndex(of: "-") else { return nil }
        let prefix = String(name[..<dashIdx])
        let rest = String(name[name.index(after: dashIdx)...])
        guard !prefix.isEmpty, !rest.isEmpty else { return nil }
        return (prefix, rest)
    }

    static func patternPrefixSet(in projects: [String]) -> Set<String> {
        var counts: [String: Int] = [:]
        for path in projects {
            let name = URL(fileURLWithPath: path).lastPathComponent
            if let parsed = namePatternPrefix(for: name) {
                counts[parsed.prefix, default: 0] += 1
            }
        }
        return Set(counts.filter { $0.value >= 2 }.keys)
    }

    static func cliDisplayItem(
        for path: String,
        sharedPrefixes: Set<String>,
        patternEnabled: Bool
    ) -> GotoProjectDisplayItem {
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent
        guard !name.isEmpty else {
            return GotoProjectDisplayItem(parent: "", name: path)
        }
        if patternEnabled,
           let parsed = namePatternPrefix(for: name),
           sharedPrefixes.contains(parsed.prefix) {
            return GotoProjectDisplayItem(parent: parsed.prefix, name: parsed.rest)
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

    static func loadRecentProjects(availableProjects: [String], limit: Int? = nil) -> [String] {
        guard let content = try? String(contentsOf: GotoSettings.recentProjectsURL, encoding: .utf8) else {
            return []
        }

        let effectiveLimit = limit ?? GotoSettings.cliConfig().recentLimit
        if effectiveLimit <= 0 {
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
            if recents.count == effectiveLimit {
                break
            }
        }

        return recents
    }

    static func recordRecentProject(_ path: String, availableProjects: [String], limit: Int? = nil) {
        let effectiveLimit = limit ?? GotoSettings.cliConfig().recentLimit
        // 저장 한도는 사용자 설정과 무관하게 일정 분량을 유지해 두면, 한도를 다시 늘렸을 때 과거 기록이 살아난다.
        let storageLimit = max(effectiveLimit, GotoCLIConfig.defaultRecentLimit)
        var recents = loadRecentProjects(availableProjects: availableProjects, limit: storageLimit)
        recents.removeAll { $0 == path }
        recents.insert(path, at: 0)
        let content = recents.prefix(storageLimit).joined(separator: "\n") + "\n"
        try? content.write(to: GotoSettings.recentProjectsURL, atomically: true, encoding: .utf8)
    }

    static func loadPinnedProjects(availableProjects: [String]) -> [String] {
        guard let content = try? String(contentsOf: GotoSettings.pinnedProjectsURL, encoding: .utf8) else {
            return []
        }

        let available = Set(availableProjects)
        var seen = Set<String>()
        var pins: [String] = []

        for line in content.components(separatedBy: .newlines) {
            let path = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty, available.contains(path), !seen.contains(path) else {
                continue
            }
            seen.insert(path)
            pins.append(path)
        }

        return pins
    }

    static func isPinned(_ path: String, pinned: [String]? = nil) -> Bool {
        let list = pinned ?? loadPinnedProjects(availableProjects: [path])
        return list.contains(path)
    }

    @discardableResult
    static func setPinned(_ path: String, pinned: Bool, availableProjects: [String]) -> Bool {
        var current = loadPinnedProjects(availableProjects: availableProjects)
        let wasPinned = current.contains(path)
        if pinned {
            guard !wasPinned else { return false }
            current.insert(path, at: 0)
        } else {
            guard wasPinned else { return false }
            current.removeAll { $0 == path }
        }
        writePinned(current)
        return true
    }

    @discardableResult
    static func togglePinned(_ path: String, availableProjects: [String]) -> Bool {
        let current = loadPinnedProjects(availableProjects: availableProjects)
        let nextPinned = !current.contains(path)
        setPinned(path, pinned: nextPinned, availableProjects: availableProjects)
        return nextPinned
    }

    private static func writePinned(_ pins: [String]) {
        let content = pins.joined(separator: "\n") + (pins.isEmpty ? "" : "\n")
        try? content.write(to: GotoSettings.pinnedProjectsURL, atomically: true, encoding: .utf8)
    }

    static func sortedProjects(_ projects: [String], config: GotoCLIConfig) -> [String] {
        projects.sorted { compareProjects($0, $1, config: config, parentNameProvider: nil, projectNameProvider: nil) }
    }

    static func sortedProjects(
        _ projects: [String],
        config: GotoCLIConfig,
        parentNameProvider: @escaping (String) -> String,
        projectNameProvider: @escaping (String) -> String
    ) -> [String] {
        projects.sorted {
            compareProjects(
                $0, $1, config: config,
                parentNameProvider: parentNameProvider,
                projectNameProvider: projectNameProvider
            )
        }
    }

    static func sortedPinned(_ pins: [String], mode: GotoPinSortMode) -> [String] {
        switch mode {
        case .insertion:
            return pins
        case .nameAscending, .nameDescending:
            return pins.sorted {
                comparePinByName($0, $1, ascending: mode == .nameAscending)
            }
        case .createdAtAscending, .createdAtDescending:
            return pins.sorted {
                comparePinByDate($0, $1, ascending: mode == .createdAtAscending)
            }
        }
    }

    private static func comparePinByName(_ lhs: String, _ rhs: String, ascending: Bool) -> Bool {
        let a = displayItem(for: lhs).name
        let b = displayItem(for: rhs).name
        let result = a.localizedStandardCompare(b)
        if result == .orderedSame {
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        return (result == .orderedAscending) == ascending
    }

    private static func comparePinByDate(_ lhs: String, _ rhs: String, ascending: Bool) -> Bool {
        let a = creationDate(for: lhs)
        let b = creationDate(for: rhs)
        if a == b {
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        return (a < b) == ascending
    }

    static func orderedProjects(
        _ projects: [String],
        config: GotoCLIConfig
    ) -> (displayProjects: [String], pinnedCount: Int, recentCount: Int) {
        return orderedProjects(projects, config: config, parentNameProvider: nil, projectNameProvider: nil)
    }

    static func orderedProjects(
        _ projects: [String],
        config: GotoCLIConfig,
        parentNameProvider: ((String) -> String)?,
        projectNameProvider: ((String) -> String)?
    ) -> (displayProjects: [String], pinnedCount: Int, recentCount: Int) {
        let pins = sortedPinned(
            loadPinnedProjects(availableProjects: projects),
            mode: config.pinSortMode
        )
        let pinSet = Set(pins)
        let recents = loadRecentProjects(availableProjects: projects, limit: config.recentLimit)
            .filter { !pinSet.contains($0) }
        let recentSet = Set(recents)
        let remaining = projects
            .filter { !pinSet.contains($0) && !recentSet.contains($0) }
            .sorted {
                compareProjects(
                    $0, $1, config: config,
                    parentNameProvider: parentNameProvider,
                    projectNameProvider: projectNameProvider
                )
            }
        return (pins + recents + remaining, pins.count, recents.count)
    }

    private static func compareProjects(
        _ lhs: String,
        _ rhs: String,
        config: GotoCLIConfig,
        parentNameProvider: ((String) -> String)?,
        projectNameProvider: ((String) -> String)?
    ) -> Bool {
        let parent = parentComparison(lhs, rhs, config: config, parentNameProvider: parentNameProvider)
        if parent != .orderedSame {
            return parent == .orderedAscending
        }

        let project = projectComparison(lhs, rhs, config: config, projectNameProvider: projectNameProvider)
        if project != .orderedSame {
            return project == .orderedAscending
        }

        return lhs.localizedStandardCompare(rhs) == .orderedAscending
    }

    private static func parentComparison(
        _ lhs: String,
        _ rhs: String,
        config: GotoCLIConfig,
        parentNameProvider: ((String) -> String)?
    ) -> ComparisonResult {
        switch config.parentSortField {
        case .name:
            let leftName = parentNameProvider?(lhs) ?? displayItem(for: lhs).parent
            let rightName = parentNameProvider?(rhs) ?? displayItem(for: rhs).parent
            return compareStrings(leftName, rightName, direction: config.parentSortDirection)
        case .createdAt:
            return compareDates(
                creationDate(for: parentPath(for: lhs)),
                creationDate(for: parentPath(for: rhs)),
                direction: config.parentSortDirection
            )
        }
    }

    private static func projectComparison(
        _ lhs: String,
        _ rhs: String,
        config: GotoCLIConfig,
        projectNameProvider: ((String) -> String)?
    ) -> ComparisonResult {
        switch config.projectSortField {
        case .name:
            let leftName = projectNameProvider?(lhs) ?? displayItem(for: lhs).name
            let rightName = projectNameProvider?(rhs) ?? displayItem(for: rhs).name
            return compareStrings(leftName, rightName, direction: config.projectSortDirection)
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
    nonisolated(unsafe) static var pinnedProjectsURLOverride: URL?

    static var cliConfigURL: URL {
        cliConfigURLOverride ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".goto_config")
    }

    static var recentProjectsURL: URL {
        recentProjectsURLOverride ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".goto_recent")
    }

    static var pinnedProjectsURL: URL {
        pinnedProjectsURLOverride ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".goto_pinned")
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
