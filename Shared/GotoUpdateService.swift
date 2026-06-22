import Foundation

public enum GotoUpdateError: Error, Equatable {
    case offline
    case network(String)
    case noAsset
    case downloadFailed
    case mountFailed
    case installFailed(Int32)
}

public struct GotoLatestRelease: Equatable {
    public let tag: String
    public let dmgURL: URL
    public init(tag: String, dmgURL: URL) { self.tag = tag; self.dmgURL = dmgURL }
}

public struct GotoUpdateCache: Codable, Equatable {
    public var lastCheckedAt: Date
    public var latestTag: String
    public init(lastCheckedAt: Date, latestTag: String) {
        self.lastCheckedAt = lastCheckedAt
        self.latestTag = latestTag
    }
}

public enum GotoUpdateService {
    static let repoSlug = "inchan/goto"
    public static let checkTTL: TimeInterval = 24 * 60 * 60

    // MARK: - Pure logic

    public static func currentVersion() -> String? {
        guard let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              !v.isEmpty else { return nil }
        return v
    }

    public static func compareSemVer(_ a: String, _ b: String) -> ComparisonResult {
        func parts(_ s: String) -> [Int] {
            let trimmed = s.hasPrefix("v") ? String(s.dropFirst()) : s
            return trimmed.split(separator: ".").map { Int($0) ?? 0 }
        }
        let pa = parts(a), pb = parts(b)
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x < y ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }

    public static func isUpdateAvailable(current: String, latest: String) -> Bool {
        if current == "0.0.0" { return false }
        return compareSemVer(current, latest) == .orderedAscending
    }

    public static var cacheStoreURL: URL {
        let base = GotoProjectStore.storeURL
        return base.deletingLastPathComponent()
            .appendingPathComponent(base.lastPathComponent + "_update_check", isDirectory: false)
    }

    public static func loadCache() -> GotoUpdateCache? {
        guard let data = try? Data(contentsOf: cacheStoreURL) else { return nil }
        return try? JSONDecoder().decode(GotoUpdateCache.self, from: data)
    }

    public static func saveCache(_ cache: GotoUpdateCache) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: cacheStoreURL, options: .atomic)
    }

    public static func shouldCheck(now: Date, cache: GotoUpdateCache?, ttl: TimeInterval = checkTTL) -> Bool {
        guard let cache else { return true }
        return now.timeIntervalSince(cache.lastCheckedAt) >= ttl
    }

    public static func pendingNotice() -> String? {
        guard let current = currentVersion(), current != "0.0.0",
              let cache = loadCache(),
              isUpdateAvailable(current: current, latest: cache.latestTag) else { return nil }
        return "⬆ 새 버전 \(cache.latestTag) 사용 가능 — goto --upgrade"
    }

    // MARK: - Side effects

    private static func runProcess(
        _ launchPath: String,
        _ args: [String],
        inheritIO: Bool = false
    ) -> (status: Int32, stdout: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launchPath)
        p.arguments = args
        let outPipe = Pipe()
        if inheritIO {
            p.standardInput = FileHandle.standardInput
            p.standardOutput = FileHandle.standardOutput
            p.standardError = FileHandle.standardError
        } else {
            p.standardOutput = outPipe
            p.standardError = Pipe()
        }
        do { try p.run() } catch { return (-1, "") }
        var out = ""
        if !inheritIO {
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            out = String(data: data, encoding: .utf8) ?? ""
        }
        p.waitUntilExit()
        return (p.terminationStatus, out)
    }

    public static func fetchLatest() -> Result<GotoLatestRelease, GotoUpdateError> {
        let url = URL(string: "https://api.github.com/repos/\(repoSlug)/releases/latest")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("goto-cli", forHTTPHeaderField: "User-Agent")

        let sem = DispatchSemaphore(value: 0)
        var result: Result<GotoLatestRelease, GotoUpdateError> = .failure(.offline)
        URLSession.shared.dataTask(with: request) { data, _, error in
            defer { sem.signal() }
            if error != nil { result = .failure(.offline); return }
            guard let data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = obj["tag_name"] as? String,
                  let assets = obj["assets"] as? [[String: Any]] else {
                result = .failure(.network("invalid response")); return
            }
            let dmg = assets.first { ($0["name"] as? String)?.hasSuffix(".dmg") == true }
            guard let dmg, let s = dmg["browser_download_url"] as? String, let dmgURL = URL(string: s) else {
                result = .failure(.noAsset); return
            }
            result = .success(GotoLatestRelease(tag: tag, dmgURL: dmgURL))
        }.resume()
        sem.wait()
        return result
    }

    public static func refreshCache(now: Date = Date()) {
        guard let current = currentVersion(), current != "0.0.0" else { return }
        if !shouldCheck(now: now, cache: loadCache()) { return }
        if case .success(let release) = fetchLatest() {
            saveCache(GotoUpdateCache(lastCheckedAt: now, latestTag: release.tag))
        }
    }

    @discardableResult
    public static func performUpgrade(log: (String) -> Void) -> Result<String, GotoUpdateError> {
        let latest: GotoLatestRelease
        switch fetchLatest() {
        case .success(let r): latest = r
        case .failure(let e): return .failure(e)
        }

        if let current = currentVersion(), current != "0.0.0",
           !isUpdateAvailable(current: current, latest: latest.tag) {
            log("이미 최신 버전입니다 (\(current))")
            return .success(current)
        }

        log("다운로드 중: \(latest.tag) …")
        let tmpDMG = FileManager.default.temporaryDirectory
            .appendingPathComponent("Goto-\(latest.tag).dmg")
        try? FileManager.default.removeItem(at: tmpDMG)

        let dlSem = DispatchSemaphore(value: 0)
        var dlOK = false
        URLSession.shared.downloadTask(with: latest.dmgURL) { url, _, error in
            defer { dlSem.signal() }
            guard let url, error == nil else { return }
            do { try FileManager.default.moveItem(at: url, to: tmpDMG); dlOK = true } catch { dlOK = false }
        }.resume()
        dlSem.wait()
        guard dlOK else { return .failure(.downloadFailed) }
        defer { try? FileManager.default.removeItem(at: tmpDMG) }

        let mountDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("goto-mnt-\(latest.tag)")
        try? FileManager.default.removeItem(at: mountDir)
        try? FileManager.default.createDirectory(at: mountDir, withIntermediateDirectories: true)

        log("디스크 이미지 마운트 중 …")
        let attach = runProcess("/usr/bin/hdiutil",
            ["attach", tmpDMG.path, "-nobrowse", "-quiet", "-mountpoint", mountDir.path])
        guard attach.status == 0 else { return .failure(.mountFailed) }
        defer { _ = runProcess("/usr/bin/hdiutil", ["detach", mountDir.path, "-quiet"]) }

        let pkg = mountDir.appendingPathComponent("Install Goto.pkg")
        guard FileManager.default.fileExists(atPath: pkg.path) else { return .failure(.noAsset) }

        log("설치 중 (sudo 비밀번호가 필요할 수 있습니다) …")
        let install = runProcess("/usr/bin/sudo",
            ["installer", "-pkg", pkg.path, "-target", "/"], inheritIO: true)
        guard install.status == 0 else { return .failure(.installFailed(install.status)) }

        return .success(latest.tag)
    }
}
