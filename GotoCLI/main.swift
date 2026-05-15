import Darwin
import Foundation

private let ansiHideCursor  = "\u{1B}[?25l"
private let ansiShowCursor  = "\u{1B}[?25h"
private let ansiClear       = "\u{1B}[H\u{1B}[2J"
private let ansiInvertOn    = "\u{1B}[7m"
private let ansiBold        = "\u{1B}[1m"
private let ansiBoldOff     = "\u{1B}[22m"
private let ansiGray        = "\u{1B}[90m"
private let ansiReset       = "\u{1B}[0m"

private func enterRawMode() -> termios {
    var original = termios()
    tcgetattr(STDIN_FILENO, &original)
    var raw = original
    raw.c_lflag &= ~tcflag_t(ECHO | ICANON | ISIG)
    raw.c_cc.16 = 1   // VMIN
    raw.c_cc.17 = 0   // VTIME
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
    return original
}

private func restoreMode(_ original: inout termios) {
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &original)
}

private enum Key {
    case up, down, left, right, enter, space, pin, filter, esc, quit, other
}

private enum FilterEvent {
    case up, down, enter, escape, backspace, append(UInt8), quit
}

private func readPendingByte() -> UInt8? {
    let flags = fcntl(STDIN_FILENO, F_GETFL)
    guard flags >= 0 else { return nil }

    _ = fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK)
    defer { _ = fcntl(STDIN_FILENO, F_SETFL, flags) }

    var byte: UInt8 = 0
    guard read(STDIN_FILENO, &byte, 1) == 1 else {
        return nil
    }
    return byte
}

private func readKey() -> Key {
    var byte: UInt8 = 0
    let n = read(STDIN_FILENO, &byte, 1)
    guard n > 0 else { return .other }

    switch byte {
    case 0x0A, 0x0D:
        return .enter
    case 0x20:
        return .space
    case UInt8(ascii: "p"), UInt8(ascii: "P"):
        return .pin
    case UInt8(ascii: "f"), UInt8(ascii: "F"):
        return .filter
    case UInt8(ascii: "q"), UInt8(ascii: "Q"):
        return .quit
    case 3:
        return .quit
    case 0x1B:
        guard let next = readPendingByte() else { return .esc }
        guard next == UInt8(ascii: "[") else { return .esc }

        guard let direction = readPendingByte() else { return .esc }
        switch direction {
        case UInt8(ascii: "A"): return .up
        case UInt8(ascii: "B"): return .down
        case UInt8(ascii: "D"): return .left
        case UInt8(ascii: "C"): return .right
        default: return .other
        }
    default:
        return .other
    }
}

private func readFilterEvent() -> FilterEvent {
    var byte: UInt8 = 0
    guard read(STDIN_FILENO, &byte, 1) == 1 else { return .escape }
    switch byte {
    case 0x1B:
        guard let next = readPendingByte() else { return .escape }
        guard next == UInt8(ascii: "[") else { return .escape }
        guard let dir = readPendingByte() else { return .escape }
        switch dir {
        case UInt8(ascii: "A"): return .up
        case UInt8(ascii: "B"): return .down
        default: return .escape
        }
    case 0x0A, 0x0D:
        return .enter
    case 0x7F, 0x08:
        return .backspace
    case 3:
        return .quit
    default:
        if byte >= 0x20 { return .append(byte) }
        return .escape
    }
}

private func hashSeed(_ text: String) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in text.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x100000001b3
    }
    return hash
}

// One color per hue family. Every pair has a hue gap of at least ~80°
// so neither hash collisions nor probing land on a visually similar color.
// Indices are arranged so that linear probing (idx → idx+1) also crosses
// a large hue distance.
private let prefixPalette: [(Int, Int, Int)] = [
    (0xef, 0x44, 0x44),  // red       hue   0°
    (0x10, 0xb9, 0x81),  // emerald   hue 160°
    (0x8b, 0x5c, 0xf6),  // violet    hue 260°
    (0xf5, 0x9e, 0x0b),  // amber     hue  38°
    (0x06, 0xb6, 0xd4),  // cyan      hue 188°
    (0xec, 0x48, 0x99),  // pink      hue 330°
    (0x3b, 0x82, 0xf6),  // blue      hue 215°
    (0x64, 0x74, 0x8b),  // slate     neutral
]

// Linear-probed assignment: same prefix always gets the same start slot,
// but if a slot collides with an already-assigned prefix in the current
// list, the next free slot is used. Guarantees zero color collisions
// when the unique prefix count is <= palette size.
private func assignPrefixColors(_ prefixes: [String]) -> [String: (Int, Int, Int)] {
    let n = prefixPalette.count
    var slots: [Int: String] = [:]
    var assignment: [String: Int] = [:]
    // deterministic order: hash-stable to keep colors stable across draws
    for prefix in prefixes.sorted() {
        let start = Int(hashSeed(prefix) % UInt64(n))
        var idx = start
        var placed = false
        for _ in 0..<n {
            if slots[idx] == nil {
                slots[idx] = prefix
                assignment[prefix] = idx
                placed = true
                break
            }
            idx = (idx + 1) % n
        }
        if !placed {
            assignment[prefix] = start
        }
    }
    return assignment.mapValues { prefixPalette[$0] }
}

private func contrastFg(for rgb: (Int, Int, Int)) -> String {
    let lum = 0.299 * Double(rgb.0) + 0.587 * Double(rgb.1) + 0.114 * Double(rgb.2)
    return lum > 150 ? "\u{1B}[38;2;0;0;0m" : "\u{1B}[97m"
}

private func parentBadge(_ parent: String, width: Int, color: (Int, Int, Int)?) -> String {
    let padding = String(repeating: " ", count: max(0, width - parent.count))
    if parent.isEmpty {
        return String(repeating: " ", count: width + 2)
    }
    guard let rgb = color else {
        return " \(parent)\(padding) "
    }
    let bg = "\u{1B}[48;2;\(rgb.0);\(rgb.1);\(rgb.2)m"
    let fg = contrastFg(for: rgb)
    return "\(bg)\(fg) \(parent)\(padding) \u{1B}[49m\u{1B}[39m"
}

private enum MainRow {
    case project(String)
    case separator
    case settings

    var isSelectable: Bool {
        switch self {
        case .project, .settings: return true
        case .separator: return false
        }
    }
}

private enum SettingsRow: CaseIterable {
    case back
    case pinSort
    case prefixSort
    case projectSort
    case recentLimit
    case prefixColor
    case prefixPattern
    case projectManagement
}

private enum ProjectManagementRow {
    case back
    case cleanup
    case removeSelected
    case separator
    case project(String)

    var isSelectable: Bool {
        switch self {
        case .back, .cleanup, .removeSelected, .project:
            return true
        case .separator:
            return false
        }
    }
}

private func missingProjectPaths(_ projects: [String]) -> [String] {
    let fm = FileManager.default
    var missing: [String] = []
    for path in projects {
        var isDir: ObjCBool = false
        let exists = fm.fileExists(atPath: path, isDirectory: &isDir)
        if !exists || !isDir.boolValue {
            missing.append(path)
        }
    }
    return missing
}

private enum InteractiveResult {
    case chosen(String)
    case cancelled
}

private struct ProjectColumns {
    let parentWidth: Int
    let nameWidth: Int
}

private func projectColumns(
    for paths: [String],
    displayItem: (String) -> GotoProjectDisplayItem
) -> ProjectColumns {
    let displayItems = paths.map(displayItem)
    return ProjectColumns(
        parentWidth: displayItems.map(\.parent.count).max() ?? 0,
        nameWidth: displayItems.map(\.name.count).max() ?? 0
    )
}

private func drawMainList(
    rows: [MainRow],
    pinnedSet: Set<String>,
    selected: Int,
    filterQuery: String?,
    displayItem: (String) -> GotoProjectDisplayItem,
    colored: Bool,
    tty: UnsafeMutablePointer<FILE>
) {
    fputs(ansiClear, tty)
    if let query = filterQuery {
        fputs(
            "goto — 필터: \(ansiBold)\(query)\(ansiBoldOff)\(ansiGray)▌\(ansiReset)  (↑↓ 이동, Enter 선택, ESC 필터 해제)\n\n",
            tty
        )
    } else {
        fputs(
            "goto — 프로젝트 선택 (↑↓ 이동, Enter 선택, p 핀 토글, f 필터, ESC/q 취소)\n\n",
            tty
        )
    }
    let projectPaths = rows.compactMap { row -> String? in
        if case .project(let path) = row { return path }
        return nil
    }
    let columns = projectColumns(for: projectPaths, displayItem: displayItem)

    let uniqueParents = Array(Set(projectPaths.map { displayItem($0).parent }.filter { !$0.isEmpty }))
    let colorMap: [String: (Int, Int, Int)] = colored ? assignPrefixColors(uniqueParents) : [:]

    if filterQuery != nil && projectPaths.isEmpty {
        fputs("  \(ansiGray)일치하는 프로젝트가 없습니다.\(ansiReset)\n", tty)
    }

    for (i, row) in rows.enumerated() {
        switch row {
        case .separator:
            fputs("\n\(separatorLine(for: tty))\n\n", tty)
        case .project(let path):
            let item = displayItem(path)
            fputs(
                displayLine(
                    item: item,
                    path: path,
                    parentWidth: columns.parentWidth,
                    nameWidth: columns.nameWidth,
                    isPinned: pinnedSet.contains(path),
                    isSelected: i == selected,
                    color: colored ? colorMap[item.parent] : nil
                ),
                tty
            )
        case .settings:
            fputs(menuLine("settings", isSelected: i == selected), tty)
        }
    }
}

private func terminalColumnCount(for tty: UnsafeMutablePointer<FILE>) -> Int {
    var size = winsize()
    if ioctl(fileno(tty), TIOCGWINSZ, &size) == 0 && size.ws_col > 0 {
        return Int(size.ws_col)
    }
    return 80
}

private func separatorLine(for tty: UnsafeMutablePointer<FILE>) -> String {
    let width = max(1, terminalColumnCount(for: tty) - 1)
    return "\(ansiGray)\(String(repeating: "─", count: width))\(ansiReset)"
}

private func padded(_ text: String, to width: Int) -> String {
    text + String(repeating: " ", count: max(0, width - text.count))
}

private func displayLine(
    item: GotoProjectDisplayItem,
    path: String,
    parentWidth: Int,
    nameWidth: Int,
    isPinned: Bool,
    isSelected: Bool,
    color: (Int, Int, Int)?
) -> String {
    let badge = parentBadge(item.parent, width: parentWidth, color: color)
    let name = padded(item.name, to: nameWidth)
    let marker = isPinned ? "📌 " : "   "
    let text = "\(marker)\(badge)  \(ansiBold)\(name)\(ansiBoldOff)  \(ansiGray)\(GotoProjectList.displayPath(for: path))"
    if isSelected {
        return "\(ansiInvertOn)  \(text)  \(ansiReset)\n"
    }
    return "  \(text)\(ansiReset)\n"
}

private func menuLine(_ title: String, isSelected: Bool) -> String {
    let text = "\(ansiBold)\(title)\(ansiBoldOff)"
    if isSelected {
        return "\(ansiInvertOn)  \(text)  \(ansiReset)\n"
    }
    return "  \(text)\(ansiReset)\n"
}

private func optionLine(_ title: String, value: String, isSelected: Bool) -> String {
    let text = "\(title)  \(ansiGray)\(value)"
    if isSelected {
        return "\(ansiInvertOn)  \(text)  \(ansiReset)\n"
    }
    return "  \(text)\(ansiReset)\n"
}

private func settingsOptionLine(
    _ title: String,
    value: String,
    titleWidth: Int,
    isSelected: Bool
) -> String {
    optionLine(padded(title, to: titleWidth), value: value, isSelected: isSelected)
}

private func mainRows(
    projects: [String],
    config: GotoCLIConfig,
    displayItem: @escaping (String) -> GotoProjectDisplayItem
) -> [MainRow] {
    let ordered = GotoProjectList.orderedProjects(
        projects,
        config: config,
        parentNameProvider: { displayItem($0).parent },
        projectNameProvider: { displayItem($0).name }
    )
    var rows: [MainRow] = []

    let pinEnd = ordered.pinnedCount
    let recentEnd = ordered.pinnedCount + ordered.recentCount
    let total = ordered.displayProjects.count

    for (index, path) in ordered.displayProjects.enumerated() {
        if pinEnd > 0 && index == pinEnd && index < total {
            rows.append(.separator)
        } else if ordered.recentCount > 0 && index == recentEnd && index < total {
            rows.append(.separator)
        }
        rows.append(.project(path))
    }

    if !rows.isEmpty {
        rows.append(.separator)
    }
    rows.append(.settings)
    return rows
}

private func firstSelectableIndex<T>(in rows: [T], isSelectable: (T) -> Bool) -> Int {
    rows.firstIndex(where: isSelectable) ?? 0
}

private func lastSelectableIndex<T>(in rows: [T], isSelectable: (T) -> Bool) -> Int {
    rows.lastIndex(where: isSelectable) ?? 0
}

private func previousIndex(_ selected: Int) -> Int {
    max(0, selected - 1)
}

private func nextIndex<T>(_ selected: Int, in rows: [T]) -> Int {
    min(rows.count - 1, selected + 1)
}

private func nextSelectableIndex<T>(
    from selected: Int,
    delta: Int,
    rows: [T],
    isSelectable: (T) -> Bool
) -> Int {
    guard !rows.isEmpty else { return selected }
    var index = selected
    while true {
        let next = index + delta
        if next < 0 || next >= rows.count {
            return selected
        }
        index = next
        if isSelectable(rows[index]) {
            return index
        }
    }
}

private func promptIntegerValue(
    title: String,
    initial: Int,
    range: ClosedRange<Int>,
    tty: UnsafeMutablePointer<FILE>
) -> Int? {
    var buffer = "\(initial)"
    func draw(error: String? = nil) {
        fputs(ansiClear, tty)
        fputs("goto — \(title)\n\n", tty)
        fputs("값: \(ansiBold)\(buffer)\(ansiBoldOff)\(ansiGray)▌\(ansiReset)\n\n", tty)
        fputs("\(ansiGray)(숫자 \(range.lowerBound)~\(range.upperBound) 입력, Enter 저장, ESC 취소)\(ansiReset)\n", tty)
        if let error {
            fputs("\n\(ansiBold)\(error)\(ansiBoldOff)\n", tty)
        }
    }
    draw()
    while true {
        let evt = readFilterEvent()
        switch evt {
        case .append(let b):
            let scalar = UnicodeScalar(b)
            if scalar >= "0" && scalar <= "9", buffer.count < 3 {
                if buffer == "0" { buffer.removeAll() }
                buffer.append(Character(scalar))
                draw()
            }
        case .backspace:
            if !buffer.isEmpty {
                buffer.removeLast()
                draw()
            }
        case .enter:
            if let n = Int(buffer), range.contains(n) {
                return n
            }
            draw(error: "범위를 벗어났습니다: \(range.lowerBound)~\(range.upperBound)")
        case .escape, .quit:
            return nil
        case .up, .down:
            break
        }
    }
}

private func drawSettings(config: GotoCLIConfig, selected: Int, tty: UnsafeMutablePointer<FILE>) {
    fputs(ansiClear, tty)
    fputs("goto — settings (↑↓ 이동, Space 순환/토글, Enter 변경, ESC 뒤로)\n\n", tty)
    let rows = SettingsRow.allCases
    let titleWidth = "prefix 패턴 매칭".count
    for (index, row) in rows.enumerated() {
        let isSelected = index == selected
        switch row {
        case .back:
            fputs(menuLine("뒤로 가기", isSelected: isSelected), tty)
            fputs("\n\(separatorLine(for: tty))\n\n", tty)
        case .pinSort:
            fputs(settingsOptionLine("핀 정렬", value: config.pinSortMode.title, titleWidth: titleWidth, isSelected: isSelected), tty)
        case .prefixSort:
            let option = GotoSettings.sortOption(field: config.parentSortField, direction: config.parentSortDirection)
            fputs(settingsOptionLine("상위 폴더 정렬", value: option.title, titleWidth: titleWidth, isSelected: isSelected), tty)
        case .projectSort:
            let option = GotoSettings.sortOption(field: config.projectSortField, direction: config.projectSortDirection)
            fputs(settingsOptionLine("프로젝트 정렬", value: option.title, titleWidth: titleWidth, isSelected: isSelected), tty)
            fputs("\n\(separatorLine(for: tty))\n\n", tty)
        case .recentLimit:
            let base = config.recentLimit == 0 ? "꺼짐" : "\(config.recentLimit)개"
            let value = "\(base)  (Enter: 직접 입력, Space: 순환)"
            fputs(settingsOptionLine("최근 항목 개수", value: value, titleWidth: titleWidth, isSelected: isSelected), tty)
        case .prefixColor:
            fputs(settingsOptionLine("prefix 색상", value: config.prefixColorEnabled ? "켜짐" : "꺼짐", titleWidth: titleWidth, isSelected: isSelected), tty)
        case .prefixPattern:
            fputs(settingsOptionLine("prefix 패턴 매칭", value: config.prefixPatternEnabled ? "켜짐" : "꺼짐", titleWidth: titleWidth, isSelected: isSelected), tty)
            fputs("\n\(separatorLine(for: tty))\n\n", tty)
        case .projectManagement:
            fputs(menuLine("프로젝트 관리", isSelected: isSelected), tty)
        }
    }
}

private enum SettingsAction {
    case back
    case openProjectManagement
    case cancelled
}

private func runSettings(config: inout GotoCLIConfig, tty: UnsafeMutablePointer<FILE>) -> SettingsAction {
    let rows = SettingsRow.allCases
    var selected = 0
    drawSettings(config: config, selected: selected, tty: tty)

    while true {
        let key = readKey()
        switch key {
        case .up:
            selected = previousIndex(selected)
        case .down:
            selected = nextIndex(selected, in: rows)
        case .left:
            selected = 0
        case .right:
            selected = rows.count - 1
        case .enter, .space:
            switch rows[selected] {
            case .back:
                return .back
            case .pinSort:
                config.pinSortMode = config.pinSortMode.next
                GotoSettings.saveCLIConfig(config)
            case .prefixSort:
                let current = GotoSettings.sortOption(field: config.parentSortField, direction: config.parentSortDirection)
                let next = current.next
                config.parentSortField = next.field
                config.parentSortDirection = next.direction
                GotoSettings.saveCLIConfig(config)
            case .projectSort:
                let current = GotoSettings.sortOption(field: config.projectSortField, direction: config.projectSortDirection)
                let next = current.next
                config.projectSortField = next.field
                config.projectSortDirection = next.direction
                GotoSettings.saveCLIConfig(config)
            case .recentLimit:
                if key == .enter {
                    if let v = promptIntegerValue(
                        title: "최근 항목 개수 직접 입력",
                        initial: config.recentLimit,
                        range: 0...50,
                        tty: tty
                    ) {
                        config.recentLimit = GotoCLIConfig.sanitizedRecentLimit(v)
                        GotoSettings.saveCLIConfig(config)
                    }
                } else {
                    config.recentLimit = GotoCLIConfig.nextRecentLimit(after: config.recentLimit)
                    GotoSettings.saveCLIConfig(config)
                }
            case .prefixColor:
                config.prefixColorEnabled.toggle()
                GotoSettings.saveCLIConfig(config)
            case .prefixPattern:
                config.prefixPatternEnabled.toggle()
                GotoSettings.saveCLIConfig(config)
            case .projectManagement:
                return .openProjectManagement
            }
        case .pin, .filter:
            break
        case .esc:
            return .back
        case .quit:
            return .cancelled
        case .other:
            break
        }
        drawSettings(config: config, selected: selected, tty: tty)
    }
}

private func projectManagementRows(
    projects: [String],
    config: GotoCLIConfig,
    displayItem: @escaping (String) -> GotoProjectDisplayItem
) -> [ProjectManagementRow] {
    let sorted = GotoProjectList.sortedProjects(
        projects,
        config: config,
        parentNameProvider: { displayItem($0).parent },
        projectNameProvider: { displayItem($0).name }
    )
    let projectRows = sorted.map { ProjectManagementRow.project($0) }
    return [.back, .cleanup] + projectRows + [.separator, .removeSelected]
}

private func drawProjectManagement(
    rows: [ProjectManagementRow],
    marked: Set<String>,
    pinnedSet: Set<String>,
    selected: Int,
    displayItem: (String) -> GotoProjectDisplayItem,
    colored: Bool,
    tty: UnsafeMutablePointer<FILE>
) {
    fputs(ansiClear, tty)
    fputs("goto — 프로젝트 관리 (↑↓ 이동, Space/Enter 체크, p 핀, ESC 뒤로)\n\n", tty)

    let projectPaths = rows.compactMap { row -> String? in
        if case .project(let path) = row { return path }
        return nil
    }
    let columns = projectColumns(for: projectPaths, displayItem: displayItem)

    let uniqueParents = Array(Set(projectPaths.map { displayItem($0).parent }.filter { !$0.isEmpty }))
    let colorMap: [String: (Int, Int, Int)] = colored ? assignPrefixColors(uniqueParents) : [:]

    for (index, row) in rows.enumerated() {
        let isSelected = index == selected
        switch row {
        case .back:
            fputs(menuLine("뒤로 가기", isSelected: isSelected), tty)
        case .cleanup:
            let missingCount = missingProjectPaths(rows.compactMap {
                if case .project(let p) = $0 { return p } else { return nil }
            }).count
            fputs(menuLine("정리 (\(missingCount))", isSelected: isSelected), tty)
            fputs("\n\(separatorLine(for: tty))\n\n", tty)
        case .removeSelected:
            fputs(menuLine("선택한 프로젝트 제거 (\(marked.count))", isSelected: isSelected), tty)
        case .separator:
            fputs("\n\(separatorLine(for: tty))\n\n", tty)
        case .project(let path):
            let mark = marked.contains(path) ? "[x]" : "[ ]"
            let pin = pinnedSet.contains(path) ? "📌" : "  "
            let item = displayItem(path)
            let badge = parentBadge(item.parent, width: columns.parentWidth, color: colored ? colorMap[item.parent] : nil)
            let name = padded(item.name, to: columns.nameWidth)
            let text = "\(mark) \(pin) \(badge)  \(ansiBold)\(name)\(ansiBoldOff)  \(ansiGray)\(GotoProjectList.displayPath(for: path))"
            if isSelected {
                fputs("\(ansiInvertOn)  \(text)  \(ansiReset)\n", tty)
            } else {
                fputs("  \(text)\(ansiReset)\n", tty)
            }
        }
    }
}

private func runProjectManagement(
    projects: inout [String],
    config: GotoCLIConfig,
    tty: UnsafeMutablePointer<FILE>
) {
    func makeDisplayItem() -> (String) -> GotoProjectDisplayItem {
        let set = config.prefixPatternEnabled ? GotoProjectList.patternPrefixSet(in: projects) : []
        let enabled = config.prefixPatternEnabled
        return { path in
            GotoProjectList.cliDisplayItem(for: path, sharedPrefixes: set, patternEnabled: enabled)
        }
    }
    var displayItem = makeDisplayItem()
    let colored = config.prefixColorEnabled

    var rows = projectManagementRows(projects: projects, config: config, displayItem: displayItem)
    var selected = firstSelectableIndex(in: rows) { $0.isSelectable }
    var marked = Set<String>()
    var pinnedSet = Set(GotoProjectList.loadPinnedProjects(availableProjects: projects))

    drawProjectManagement(rows: rows, marked: marked, pinnedSet: pinnedSet, selected: selected, displayItem: displayItem, colored: colored, tty: tty)

    while true {
        switch readKey() {
        case .up:
            selected = nextSelectableIndex(from: selected, delta: -1, rows: rows) { $0.isSelectable }
        case .down:
            selected = nextSelectableIndex(from: selected, delta: 1, rows: rows) { $0.isSelectable }
        case .left:
            selected = firstSelectableIndex(in: rows) { $0.isSelectable }
        case .right:
            selected = lastSelectableIndex(in: rows) { $0.isSelectable }
        case .pin:
            if case .project(let path) = rows[selected] {
                GotoProjectList.togglePinned(path, availableProjects: projects)
                pinnedSet = Set(GotoProjectList.loadPinnedProjects(availableProjects: projects))
            }
        case .enter, .space:
            switch rows[selected] {
            case .back:
                return
            case .cleanup:
                let missing = missingProjectPaths(projects)
                for path in missing {
                    _ = try? GotoProjectStore.remove(path)
                    GotoProjectList.setPinned(path, pinned: false, availableProjects: GotoProjectStore.load())
                    marked.remove(path)
                }
                projects = GotoProjectStore.load()
                displayItem = makeDisplayItem()
                rows = projectManagementRows(projects: projects, config: config, displayItem: displayItem)
                pinnedSet = Set(GotoProjectList.loadPinnedProjects(availableProjects: projects))
                selected = firstSelectableIndex(in: rows) { $0.isSelectable }
            case .removeSelected:
                for path in marked {
                    _ = try? GotoProjectStore.remove(path)
                    GotoProjectList.setPinned(path, pinned: false, availableProjects: GotoProjectStore.load())
                }
                projects = GotoProjectStore.load()
                displayItem = makeDisplayItem()
                rows = projectManagementRows(projects: projects, config: config, displayItem: displayItem)
                marked.removeAll()
                pinnedSet = Set(GotoProjectList.loadPinnedProjects(availableProjects: projects))
                selected = lastSelectableIndex(in: rows) { $0.isSelectable }
            case .separator:
                break
            case .project(let path):
                if marked.contains(path) {
                    marked.remove(path)
                } else {
                    marked.insert(path)
                }
            }
        case .esc, .quit:
            return
        case .filter, .other:
            break
        }
        drawProjectManagement(rows: rows, marked: marked, pinnedSet: pinnedSet, selected: selected, displayItem: displayItem, colored: colored, tty: tty)
    }
}

private func runInteractive(projects initialProjects: [String]) -> InteractiveResult {
    guard let tty = fopen("/dev/tty", "w") else {
        fputs("error: /dev/tty 열기 실패\n", stderr)
        return .cancelled
    }
    defer { fclose(tty) }

    var original = enterRawMode()
    defer { restoreMode(&original) }

    fputs(ansiHideCursor, tty)
    defer { fputs(ansiShowCursor, tty) }

    var projects = initialProjects
    var config = GotoSettings.cliConfig()
    var pinnedSet = Set(GotoProjectList.loadPinnedProjects(availableProjects: projects))
    var filterQuery: String? = nil

    func makeDisplayItem() -> (String) -> GotoProjectDisplayItem {
        let set = config.prefixPatternEnabled ? GotoProjectList.patternPrefixSet(in: projects) : []
        let enabled = config.prefixPatternEnabled
        return { path in
            GotoProjectList.cliDisplayItem(for: path, sharedPrefixes: set, patternEnabled: enabled)
        }
    }
    var displayItem = makeDisplayItem()

    func makeRows() -> [MainRow] {
        if let q = filterQuery {
            let needle = q.lowercased()
            let sorted = GotoProjectList.sortedProjects(
                projects,
                config: config,
                parentNameProvider: { displayItem($0).parent },
                projectNameProvider: { displayItem($0).name }
            )
            let filtered: [String]
            if needle.isEmpty {
                filtered = sorted
            } else {
                filtered = sorted.filter { path in
                    let item = displayItem(path)
                    return item.parent.lowercased().contains(needle)
                        || item.name.lowercased().contains(needle)
                        || path.lowercased().contains(needle)
                }
            }
            return filtered.map { .project($0) }
        }
        return mainRows(projects: projects, config: config, displayItem: displayItem)
    }

    var rows = makeRows()
    var selected = firstSelectableIndex(in: rows) { $0.isSelectable }
    drawMainList(rows: rows, pinnedSet: pinnedSet, selected: selected, filterQuery: filterQuery, displayItem: displayItem, colored: config.prefixColorEnabled, tty: tty)

    while true {
        if filterQuery != nil {
            let evt = readFilterEvent()
            switch evt {
            case .append(let byte):
                filterQuery = (filterQuery ?? "") + String(UnicodeScalar(byte))
                rows = makeRows()
                selected = firstSelectableIndex(in: rows) { $0.isSelectable }
            case .backspace:
                if var q = filterQuery, !q.isEmpty {
                    q.removeLast()
                    filterQuery = q
                    rows = makeRows()
                    selected = firstSelectableIndex(in: rows) { $0.isSelectable }
                }
            case .up:
                selected = nextSelectableIndex(from: selected, delta: -1, rows: rows) { $0.isSelectable }
            case .down:
                selected = nextSelectableIndex(from: selected, delta: 1, rows: rows) { $0.isSelectable }
            case .enter:
                if !rows.isEmpty, rows.indices.contains(selected),
                   case .project(let chosen) = rows[selected] {
                    GotoProjectList.recordRecentProject(chosen, availableProjects: projects)
                    fputs(ansiClear, tty)
                    return .chosen(chosen)
                }
            case .escape:
                filterQuery = nil
                rows = makeRows()
                selected = firstSelectableIndex(in: rows) { $0.isSelectable }
            case .quit:
                fputs(ansiClear, tty)
                return .cancelled
            }
            drawMainList(rows: rows, pinnedSet: pinnedSet, selected: selected, filterQuery: filterQuery, displayItem: displayItem, colored: config.prefixColorEnabled, tty: tty)
            continue
        }

        let key = readKey()
        switch key {
        case .up:
            selected = nextSelectableIndex(from: selected, delta: -1, rows: rows) { $0.isSelectable }
        case .down:
            selected = nextSelectableIndex(from: selected, delta: 1, rows: rows) { $0.isSelectable }
        case .left:
            selected = firstSelectableIndex(in: rows) { $0.isSelectable }
        case .right:
            selected = lastSelectableIndex(in: rows) { $0.isSelectable }
        case .filter:
            filterQuery = ""
            rows = makeRows()
            selected = firstSelectableIndex(in: rows) { $0.isSelectable }
        case .pin:
            if case .project(let path) = rows[selected] {
                GotoProjectList.togglePinned(path, availableProjects: projects)
                rows = makeRows()
                pinnedSet = Set(GotoProjectList.loadPinnedProjects(availableProjects: projects))
                if let idx = rows.firstIndex(where: { row in
                    if case .project(let p) = row { return p == path }
                    return false
                }) {
                    selected = idx
                } else {
                    selected = firstSelectableIndex(in: rows) { $0.isSelectable }
                }
            }
        case .enter, .space:
            switch rows[selected] {
            case .project(let chosen):
                GotoProjectList.recordRecentProject(chosen, availableProjects: projects)
                fputs(ansiClear, tty)
                return .chosen(chosen)
            case .settings:
                switch runSettings(config: &config, tty: tty) {
                case .back:
                    break
                case .openProjectManagement:
                    runProjectManagement(projects: &projects, config: config, tty: tty)
                case .cancelled:
                    fputs(ansiClear, tty)
                    return .cancelled
                }
                config = GotoSettings.cliConfig()
                displayItem = makeDisplayItem()
                rows = makeRows()
                pinnedSet = Set(GotoProjectList.loadPinnedProjects(availableProjects: projects))
                selected = firstSelectableIndex(in: rows) { $0.isSelectable }
            case .separator:
                break
            }
        case .esc, .quit:
            fputs(ansiClear, tty)
            return .cancelled
        case .other:
            break
        }
        drawMainList(rows: rows, pinnedSet: pinnedSet, selected: selected, filterQuery: filterQuery, displayItem: displayItem, colored: config.prefixColorEnabled, tty: tty)
    }
}

private let usageText = """
사용법:
  goto                           인터랙티브 프로젝트 선택
  goto --add <path>              경로 등록
  goto --remove <path>           경로 제거
  goto --add-subdirs <path>      1단계 하위 git 디렉터리 모두 등록
  goto --remove-subdirs <path>   1단계 하위 디렉터리 모두 제거
  goto --pin <path>              프로젝트 핀 고정 (최상단)
  goto --unpin <path>            프로젝트 핀 해제
  goto --help                    이 도움말 출력
"""

private func handleStoreError(_ error: Error, path: String) -> Never {
    switch error {
    case GotoProjectStoreError.pathNotDirectory(let p):
        fputs("error: 디렉터리가 아닙니다: \(p)\n", stderr)
    case GotoProjectStoreError.parentNotReadable(let p):
        fputs("error: 디렉터리를 읽을 수 없습니다: \(p)\n", stderr)
    default:
        fputs("error: \(error.localizedDescription)\n", stderr)
    }
    exit(2)
}

let args = CommandLine.arguments.dropFirst()

if args.contains("--help") {
    print(usageText)
    exit(0)
}

let knownFlags: Set<String> = ["--add", "--remove", "--add-subdirs", "--remove-subdirs", "--pin", "--unpin", "--help"]
for arg in args where arg.hasPrefix("-") {
    if !knownFlags.contains(arg) {
        fputs("error: 알 수 없는 인자: \(arg)\n\(usageText)\n", stderr)
        exit(2)
    }
}

let argArray = Array(args)

if let idx = argArray.firstIndex(of: "--add") {
    guard idx + 1 < argArray.count else {
        fputs("error: --add 에 경로가 필요합니다\n\(usageText)\n", stderr)
        exit(2)
    }
    let path = argArray[idx + 1]
    do {
        let added = try GotoProjectStore.add(path)
        fputs(added ? "추가됨: \(path)\n" : "이미 등록됨: \(path)\n", stderr)
        exit(0)
    } catch {
        handleStoreError(error, path: path)
    }
}

if let idx = argArray.firstIndex(of: "--remove") {
    guard idx + 1 < argArray.count else {
        fputs("error: --remove 에 경로가 필요합니다\n\(usageText)\n", stderr)
        exit(2)
    }
    let path = argArray[idx + 1]
    do {
        let removed = try GotoProjectStore.remove(path)
        fputs(removed ? "제거됨: \(path)\n" : "등록되어 있지 않음: \(path)\n", stderr)
        exit(0)
    } catch {
        handleStoreError(error, path: path)
    }
}

if let idx = argArray.firstIndex(of: "--add-subdirs") {
    guard idx + 1 < argArray.count else {
        fputs("error: --add-subdirs 에 경로가 필요합니다\n\(usageText)\n", stderr)
        exit(2)
    }
    let path = argArray[idx + 1]
    do {
        let count = try GotoProjectStore.addSubdirs(path)
        fputs("추가됨 \(count)개\n", stderr)
        exit(0)
    } catch {
        handleStoreError(error, path: path)
    }
}

if let idx = argArray.firstIndex(of: "--remove-subdirs") {
    guard idx + 1 < argArray.count else {
        fputs("error: --remove-subdirs 에 경로가 필요합니다\n\(usageText)\n", stderr)
        exit(2)
    }
    let path = argArray[idx + 1]
    do {
        let count = try GotoProjectStore.removeSubdirs(path)
        fputs("제거됨 \(count)개\n", stderr)
        exit(0)
    } catch {
        handleStoreError(error, path: path)
    }
}

if let idx = argArray.firstIndex(of: "--pin") {
    guard idx + 1 < argArray.count else {
        fputs("error: --pin 에 경로가 필요합니다\n\(usageText)\n", stderr)
        exit(2)
    }
    let norm = GotoProjectStore.normalize(argArray[idx + 1])
    let projects = GotoProjectStore.load()
    guard projects.contains(norm) else {
        fputs("error: 등록되지 않은 경로입니다. 먼저 --add 로 등록하세요: \(norm)\n", stderr)
        exit(2)
    }
    let changed = GotoProjectList.setPinned(norm, pinned: true, availableProjects: projects)
    fputs(changed ? "핀 고정: \(norm)\n" : "이미 핀 고정됨: \(norm)\n", stderr)
    exit(0)
}

if let idx = argArray.firstIndex(of: "--unpin") {
    guard idx + 1 < argArray.count else {
        fputs("error: --unpin 에 경로가 필요합니다\n\(usageText)\n", stderr)
        exit(2)
    }
    let norm = GotoProjectStore.normalize(argArray[idx + 1])
    let projects = GotoProjectStore.load()
    let changed = GotoProjectList.setPinned(norm, pinned: false, availableProjects: projects)
    fputs(changed ? "핀 해제: \(norm)\n" : "핀 고정되어 있지 않음: \(norm)\n", stderr)
    exit(0)
}

if !argArray.isEmpty {
    fputs("error: 알 수 없는 인자: \(argArray.joined(separator: " "))\n\(usageText)\n", stderr)
    exit(2)
}

let projects = GotoProjectStore.load()

if isatty(STDIN_FILENO) == 0 {
    for path in projects {
        print(path)
    }
    exit(0)
}

switch runInteractive(projects: projects) {
case .chosen(let chosen):
    print(chosen)
    exit(0)
case .cancelled:
    exit(1)
}
