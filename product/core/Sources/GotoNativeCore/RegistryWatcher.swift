import Foundation

public final class RegistryWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var directorySource: DispatchSourceFileSystemObject?
    private let url: URL
    private let onChange: () -> Void
    private let queue: DispatchQueue
    private var debounceWork: DispatchWorkItem?

    public init(
        registryURL: URL,
        queue: DispatchQueue = .init(label: "dev.goto.registry-watcher"),
        onChange: @escaping () -> Void
    ) {
        self.url = registryURL
        self.queue = queue
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    public func start() {
        // Try file directly — watchFile falls back to watchDirectory if file doesn't exist
        watchFile()
    }

    public func stop() {
        source?.cancel()
        source = nil
        directorySource?.cancel()
        directorySource = nil
        debounceWork?.cancel()
        debounceWork = nil
    }

    private func watchFile() {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            watchDirectory()
            return
        }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: queue
        )

        src.setEventHandler { [weak self] in
            self?.scheduleCallback()

            if let flags = self?.source?.data, flags.contains(.delete) || flags.contains(.rename) {
                self?.source?.cancel()
                self?.source = nil
                self?.watchDirectory()
            }
        }

        src.setCancelHandler {
            close(fd)
        }

        source = src
        src.resume()
    }

    private func watchDirectory() {
        let dirURL = url.deletingLastPathComponent()
        let fd = open(dirURL.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: queue
        )

        src.setEventHandler { [weak self] in
            guard let self else { return }
            if FileManager.default.fileExists(atPath: self.url.path) {
                self.directorySource?.cancel()
                self.directorySource = nil
                self.watchFile()
                self.scheduleCallback()
            }
        }

        src.setCancelHandler {
            close(fd)
        }

        directorySource = src
        src.resume()
    }

    private func scheduleCallback() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onChange()
        }
        debounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }
}
