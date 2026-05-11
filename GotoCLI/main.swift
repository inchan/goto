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
    case up, down, left, right, enter, space, pin, esc, quit, other
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
    case projectManagement
}

private enum ProjectManagementRow {
    case back
    case removeSelected
    case separator
    case project(String)

    var isSelectable: Bool {
        switch self {
        case .back, .removeSelected, .project:
            return true
        case .separator:
            return false
        }
    }
}

private enum InteractiveResult {
    case chosen(String)
    case cancelled
}

private struct ProjectColumns {
    let parentWidth: Int
    let nameWidth: Int
}

private func projectColumns(for paths: [String]) -> ProjectColumns {
    let displayItems = paths.map { GotoProjectList.displayItem(for: $0) }
    return ProjectColumns(
        parentWidth: displayItems.map(\.parent.count).max() ?? 0,
        nameWidth: displayItems.map(\.name.count).max() ?? 0
    )
}

private func drawMainList(
    rows: [MainRow],
    pinnedSet: Set<String>,
    selected: Int,
    tty: UnsafeMutablePointer<FILE>
) {
    fputs(ansiClear, tty)
    fputs("goto — 프로젝트 선택 (↑↓ 이동, Enter 선택, p 핀 토글, ESC/q 취소)\n\n", tty)
    let projectPaths = rows.compactMap { row -> String? in
        if case .project(let path) = row { return path }
        return nil
    }
    let columns = projectColumns(for: projectPaths)

    for (i, row) in rows.enumerated() {
        switch row {
        case .separator:
            fputs("\n\(separatorLine(for: tty))\n\n", tty)
        case .project(let path):
            fputs(
                displayLine(
                    item: GotoProjectList.displayItem(for: path),
                    path: path,
                    parentWidth: columns.parentWidth,
                    nameWidth: columns.nameWidth,
                    isPinned: pinnedSet.contains(path),
                    isSelected: i == selected
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
    isSelected: Bool
) -> String {
    let parent = padded(item.parent, to: parentWidth)
    let name = padded(item.name, to: nameWidth)
    let marker = isPinned ? "📌 " : "   "
    let text = "\(marker)\(parent)  \(ansiBold)\(name)\(ansiBoldOff)  \(ansiGray)\(GotoProjectList.displayPath(for: path))"
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

private func mainRows(projects: [String], config: GotoCLIConfig) -> [MainRow] {
    let ordered = GotoProjectList.orderedProjects(projects, config: config)
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

private func drawSettings(config: GotoCLIConfig, selected: Int, tty: UnsafeMutablePointer<FILE>) {
    fputs(ansiClear, tty)
    fputs("goto — settings (↑↓ 이동, Enter/Space 변경, ESC 뒤로)\n\n", tty)
    let rows = SettingsRow.allCases
    let titleWidth = "상위 폴더 정렬".count
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
        switch readKey() {
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
            case .projectManagement:
                return .openProjectManagement
            }
        case .pin:
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

private func projectManagementRows(projects: [String], config: GotoCLIConfig) -> [ProjectManagementRow] {
    let projectRows = GotoProjectList.sortedProjects(projects, config: config).map { ProjectManagementRow.project($0) }
    return [.back] + projectRows + [.separator, .removeSelected]
}

private func drawProjectManagement(
    rows: [ProjectManagementRow],
    marked: Set<String>,
    pinnedSet: Set<String>,
    selected: Int,
    tty: UnsafeMutablePointer<FILE>
) {
    fputs(ansiClear, tty)
    fputs("goto — 프로젝트 관리 (↑↓ 이동, Space/Enter 체크, p 핀, ESC 뒤로)\n\n", tty)

    let projectPaths = rows.compactMap { row -> String? in
        if case .project(let path) = row { return path }
        return nil
    }
    let columns = projectColumns(for: projectPaths)

    for (index, row) in rows.enumerated() {
        let isSelected = index == selected
        switch row {
        case .back:
            fputs(menuLine("뒤로 가기", isSelected: isSelected), tty)
            fputs("\n\(separatorLine(for: tty))\n\n", tty)
        case .removeSelected:
            fputs(menuLine("선택한 프로젝트 제거 (\(marked.count))", isSelected: isSelected), tty)
        case .separator:
            fputs("\n\(separatorLine(for: tty))\n\n", tty)
        case .project(let path):
            let mark = marked.contains(path) ? "[x]" : "[ ]"
            let pin = pinnedSet.contains(path) ? "📌" : "  "
            let item = GotoProjectList.displayItem(for: path)
            let parent = padded(item.parent, to: columns.parentWidth)
            let name = padded(item.name, to: columns.nameWidth)
            let text = "\(mark) \(pin) \(parent)  \(ansiBold)\(name)\(ansiBoldOff)  \(ansiGray)\(GotoProjectList.displayPath(for: path))"
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
    var rows = projectManagementRows(projects: projects, config: config)
    var selected = firstSelectableIndex(in: rows) { $0.isSelectable }
    var marked = Set<String>()
    var pinnedSet = Set(GotoProjectList.loadPinnedProjects(availableProjects: projects))
    drawProjectManagement(rows: rows, marked: marked, pinnedSet: pinnedSet, selected: selected, tty: tty)

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
            case .removeSelected:
                for path in marked {
                    _ = try? GotoProjectStore.remove(path)
                    GotoProjectList.setPinned(path, pinned: false, availableProjects: GotoProjectStore.load())
                }
                projects = GotoProjectStore.load()
                rows = projectManagementRows(projects: projects, config: config)
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
        case .other:
            break
        }
        drawProjectManagement(rows: rows, marked: marked, pinnedSet: pinnedSet, selected: selected, tty: tty)
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
    var rows = mainRows(projects: projects, config: config)
    var pinnedSet = Set(GotoProjectList.loadPinnedProjects(availableProjects: projects))
    var selected = firstSelectableIndex(in: rows) { $0.isSelectable }
    drawMainList(rows: rows, pinnedSet: pinnedSet, selected: selected, tty: tty)

    while true {
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
        case .pin:
            if case .project(let path) = rows[selected] {
                GotoProjectList.togglePinned(path, availableProjects: projects)
                rows = mainRows(projects: projects, config: config)
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
                rows = mainRows(projects: projects, config: config)
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
        drawMainList(rows: rows, pinnedSet: pinnedSet, selected: selected, tty: tty)
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
