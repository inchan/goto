import AppKit

@MainActor
final class WorktreeWindowController: NSWindowController {

    private let repoPath: String
    private let entries: [GotoWorktreeEntry]
    private let gitErrorMessage: String?

    var onWindowWillClose: ((WorktreeWindowController) -> Void)?

    private var tableView: NSTableView?

    init(repoPath: String,
         entries: [GotoWorktreeEntry],
         gitErrorMessage: String? = nil) {
        self.repoPath = repoPath
        self.entries = entries
        self.gitErrorMessage = gitErrorMessage

        let window = Self.makeWindow(repoPath: repoPath)
        super.init(window: window)

        buildContentView()
        registerWindowNotification()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private static func makeWindow(repoPath: String) -> NSWindow {
        let basename = URL(fileURLWithPath: repoPath).lastPathComponent
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 380),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Worktrees — \(basename)"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 380, height: 200)
        return window
    }

    private func buildContentView() {
        guard let contentView = window?.contentView else { return }

        if entries.isEmpty {
            buildMessageView(in: contentView)
        } else {
            buildTableView(in: contentView)
        }
    }

    private func buildMessageView(in contentView: NSView) {
        let message: String
        if let error = gitErrorMessage, !error.isEmpty {
            message = error
        } else {
            message = "워크트리가 없습니다."
        }

        let label = NSTextField(wrappingLabelWithString: message)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.textColor = .secondaryLabelColor
        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20)
        ])
    }

    private func buildTableView(in contentView: NSView) {
        let branchColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("branch"))
        branchColumn.title = "Branch"
        branchColumn.minWidth = 100
        branchColumn.width = 200
        branchColumn.maxWidth = 320

        let pathColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("path"))
        pathColumn.title = "Path"
        pathColumn.minWidth = 120
        pathColumn.width = 320
        pathColumn.maxWidth = 800

        let tv = NSTableView()
        tv.addTableColumn(branchColumn)
        tv.addTableColumn(pathColumn)
        tv.dataSource = self
        tv.delegate = self
        tv.usesAlternatingRowBackgroundColors = true
        tv.allowsMultipleSelection = false
        tv.rowHeight = 22
        tv.doubleAction = #selector(onRowDoubleClicked)
        tv.target = self
        tableView = tv

        let sv = NSScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.documentView = tv
        sv.hasVerticalScroller = true
        sv.hasHorizontalScroller = true
        sv.autohidesScrollers = true
        sv.borderType = .bezelBorder
        contentView.addSubview(sv)

        NSLayoutConstraint.activate([
            sv.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            sv.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            sv.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            sv.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])

        if !entries.isEmpty {
            tv.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }

        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(self?.tableView)
        }
    }

    private func registerWindowNotification() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillCloseHandler(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )
    }

    @objc private func windowWillCloseHandler(_ notification: Notification) {
        onWindowWillClose?(self)
    }

    @objc private func onRowDoubleClicked() {
        openSelectedRow()
    }

    private func openSelectedRow() {
        guard let tv = tableView else { return }
        let row = tv.selectedRow
        guard row >= 0, row < entries.count else { return }
        let entry = entries[row]
        _ = TerminalLauncher.open(
            preference: GotoSettings.defaultTerminalPreference(),
            path: entry.path
        )
        window?.close()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            window?.close()
        } else if event.keyCode == 36 || event.keyCode == 76 {
            openSelectedRow()
        } else {
            super.keyDown(with: event)
        }
    }
}

extension WorktreeWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        entries.count
    }
}

extension WorktreeWindowController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        guard row < entries.count else { return nil }
        let entry = entries[row]

        let identifier = tableColumn?.identifier
        let isPathColumn = identifier?.rawValue == "path"
        let cellID = NSUserInterfaceItemIdentifier("cell-\(identifier?.rawValue ?? "x")")

        let cellView: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView {
            cellView = reused
        } else {
            cellView = makeCellView(identifier: cellID, isPathColumn: isPathColumn)
        }

        guard let textField = cellView.textField else { return cellView }

        let text: String
        if isPathColumn {
            text = entry.path
        } else {
            let branchName = entry.branch ?? "(detached)"
            text = entry.isCurrent ? "▸ \(branchName)" : branchName
        }

        textField.stringValue = text

        let isDimmed = entry.isBare || entry.isPrunable
        textField.textColor = isDimmed ? .secondaryLabelColor : .labelColor

        return cellView
    }

    private func makeCellView(identifier: NSUserInterfaceItemIdentifier,
                               isPathColumn: Bool) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier

        let tf = NSTextField(labelWithString: "")
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.lineBreakMode = .byTruncatingMiddle

        if isPathColumn {
            tf.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize - 1, weight: .regular)
        } else {
            tf.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        }

        cell.addSubview(tf)
        cell.textField = tf

        NSLayoutConstraint.activate([
            tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        return cell
    }
}
