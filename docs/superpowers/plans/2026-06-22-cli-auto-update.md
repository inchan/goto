# goto CLI 자동 업데이트 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** goto CLI가 새 릴리스를 백그라운드로 감지해 인터랙티브 화면에 알리고, `goto --upgrade`로 최신 DMG(pkg)를 받아 전체 설치한다.

**Architecture:** 순수 로직(버전 비교/캐시/판정)과 부수효과(네트워크/hdiutil/installer)를 `GotoUpdateService`로 분리한다. 백그라운드 체크는 기존 `goto --sync` detached 프로세스에 통합하고, 알림은 `~/.goto_update_check` 캐시를 인터랙티브 진입 시 읽어 표시한다(반영은 다음 실행). self-update는 DMG를 받아 `sudo installer`로 설치한다.

**Tech Stack:** Swift 6, Foundation(URLSession, JSONEncoder/Decoder), `hdiutil`/`installer` CLI, XCTest.

## Global Constraints

- Swift 버전 `6.0`, macOS 배포 타깃 `13.0` (project.yml).
- 새 파일은 디렉터리 글롭으로 자동 빌드 포함 — `project.yml` 수정 불필요(GotoCLI/GotoTests sources는 디렉터리).
- 캐시·데이터 파일은 `GotoProjectStore.storeURL` 형제 경로로 두어 `storeURLOverride` 격리를 따른다.
- `release.yml`·DMG 자산 구조는 변경하지 않는다.
- repo slug는 `inchan/goto` 고정.
- **테스트 실행**: 표준은 `xcodebuild test`. 이 개발 환경은 Xcode가 없어(CLT만) 실행 불가하므로, 순수 로직은 `swiftc`로 `GotoProjectStore.storeURLOverride`를 설정한 격리 하니스(`main.swift` 명명)로 동등 검증한다. 부수효과(네트워크/hdiutil/installer)는 자동 테스트에서 제외하고 수동 검증한다.
- 한글 사용자 메시지, 코드/식별자는 영문.

---

### Task 1: GotoUpdateService — 순수 로직 (버전 비교·캐시·판정)

**Files:**
- Create: `Shared/GotoUpdateService.swift`
- Test: `GotoTests/GotoUpdateServiceTests.swift`

**Interfaces:**
- Consumes: `GotoProjectStore.storeURL`, `GotoProjectStore.storeURLOverride` (기존).
- Produces:
  - `enum GotoUpdateError: Error, Equatable { case offline, network(String), noAsset, downloadFailed, mountFailed, installFailed(Int32) }`
  - `struct GotoLatestRelease: Equatable { let tag: String; let dmgURL: URL }`
  - `struct GotoUpdateCache: Codable, Equatable { var lastCheckedAt: Date; var latestTag: String }`
  - `GotoUpdateService.currentVersion() -> String?`
  - `GotoUpdateService.compareSemVer(_ a: String, _ b: String) -> ComparisonResult`
  - `GotoUpdateService.isUpdateAvailable(current: String, latest: String) -> Bool`
  - `GotoUpdateService.cacheStoreURL: URL`
  - `GotoUpdateService.loadCache() -> GotoUpdateCache?`
  - `GotoUpdateService.saveCache(_ cache: GotoUpdateCache)`
  - `GotoUpdateService.shouldCheck(now: Date, cache: GotoUpdateCache?, ttl: TimeInterval) -> Bool`
  - `GotoUpdateService.pendingNotice() -> String?`

- [ ] **Step 1: Write the failing test**

`GotoTests/GotoUpdateServiceTests.swift`:

```swift
import XCTest

final class GotoUpdateServiceTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("GotoUpdateServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        GotoProjectStore.storeURLOverride = tempRoot.appendingPathComponent(".goto")
    }

    override func tearDownWithError() throws {
        GotoProjectStore.storeURLOverride = nil
        if let tempRoot { try? FileManager.default.removeItem(at: tempRoot) }
        try super.tearDownWithError()
    }

    func testCompareSemVerHandlesVPrefixAndFields() {
        XCTAssertEqual(GotoUpdateService.compareSemVer("v0.0.28", "0.0.28"), .orderedSame)
        XCTAssertEqual(GotoUpdateService.compareSemVer("0.0.28", "0.0.29"), .orderedAscending)
        XCTAssertEqual(GotoUpdateService.compareSemVer("0.1.0", "0.0.99"), .orderedDescending)
        XCTAssertEqual(GotoUpdateService.compareSemVer("1.0.0", "0.9.9"), .orderedDescending)
        XCTAssertEqual(GotoUpdateService.compareSemVer("0.0.1", "0.0.1"), .orderedSame)
    }

    func testIsUpdateAvailableGuardsDevAndComparesCorrectly() {
        XCTAssertFalse(GotoUpdateService.isUpdateAvailable(current: "0.0.0", latest: "v9.9.9")) // dev guard
        XCTAssertTrue(GotoUpdateService.isUpdateAvailable(current: "0.0.28", latest: "v0.0.29"))
        XCTAssertFalse(GotoUpdateService.isUpdateAvailable(current: "0.0.29", latest: "v0.0.29"))
        XCTAssertFalse(GotoUpdateService.isUpdateAvailable(current: "0.0.30", latest: "v0.0.29"))
    }

    func testCacheRoundTripAndCorruptReturnsNil() throws {
        XCTAssertNil(GotoUpdateService.loadCache())
        let cache = GotoUpdateCache(lastCheckedAt: Date(timeIntervalSince1970: 1_000_000), latestTag: "v0.0.28")
        GotoUpdateService.saveCache(cache)
        XCTAssertEqual(GotoUpdateService.loadCache(), cache)
        try Data("not json".utf8).write(to: GotoUpdateService.cacheStoreURL, options: .atomic)
        XCTAssertNil(GotoUpdateService.loadCache())
    }

    func testShouldCheckRespectsTTL() {
        let base = Date(timeIntervalSince1970: 2_000_000)
        XCTAssertTrue(GotoUpdateService.shouldCheck(now: base, cache: nil, ttl: 86_400))
        let recent = GotoUpdateCache(lastCheckedAt: base, latestTag: "v0.0.28")
        XCTAssertFalse(GotoUpdateService.shouldCheck(now: base.addingTimeInterval(86_399), cache: recent, ttl: 86_400))
        XCTAssertTrue(GotoUpdateService.shouldCheck(now: base.addingTimeInterval(86_401), cache: recent, ttl: 86_400))
    }

    func testCacheStoreURLIsSiblingOfStore() {
        XCTAssertEqual(GotoUpdateService.cacheStoreURL.lastPathComponent, ".goto_update_check")
        XCTAssertEqual(
            GotoUpdateService.cacheStoreURL.deletingLastPathComponent().path,
            GotoProjectStore.storeURL.deletingLastPathComponent().path
        )
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (표준): `xcodebuild test -project Goto.xcodeproj -scheme Goto -only-testing:GotoTests/GotoUpdateServiceTests`
대체(Xcode 없음): 아래 Step 4의 하니스로 검증.
Expected: FAIL — `GotoUpdateService` 미정의.

- [ ] **Step 3: Write minimal implementation**

`Shared/GotoUpdateService.swift`:

```swift
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
    static let checkTTL: TimeInterval = 24 * 60 * 60

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
}
```

- [ ] **Step 4: Run test to verify it passes**

Run (표준): `xcodebuild test -project Goto.xcodeproj -scheme Goto -only-testing:GotoTests/GotoUpdateServiceTests`
대체(Xcode 없음) — 격리 하니스로 동등 검증:

```bash
cat > "$TMPDIR/main.swift" <<'SWIFT'
import Foundation
func check(_ l: String, _ c: Bool) { print((c ? "PASS" : "FAIL") + ": " + l) }
let root = FileManager.default.temporaryDirectory.appendingPathComponent("upd-\(UUID().uuidString)")
try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
GotoProjectStore.storeURLOverride = root.appendingPathComponent(".goto")
check("semver v-prefix", GotoUpdateService.compareSemVer("v0.0.28","0.0.28") == .orderedSame)
check("semver asc", GotoUpdateService.compareSemVer("0.0.28","0.0.29") == .orderedAscending)
check("semver minor>patch", GotoUpdateService.compareSemVer("0.1.0","0.0.99") == .orderedDescending)
check("dev guard", GotoUpdateService.isUpdateAvailable(current:"0.0.0",latest:"v9.9.9") == false)
check("update avail", GotoUpdateService.isUpdateAvailable(current:"0.0.28",latest:"v0.0.29"))
check("no cache nil", GotoUpdateService.loadCache() == nil)
let c = GotoUpdateCache(lastCheckedAt: Date(timeIntervalSince1970:1_000_000), latestTag:"v0.0.28")
GotoUpdateService.saveCache(c)
check("cache roundtrip", GotoUpdateService.loadCache() == c)
let base = Date(timeIntervalSince1970:2_000_000)
check("ttl nil->check", GotoUpdateService.shouldCheck(now: base, cache: nil, ttl: 86_400))
check("ttl recent->skip", GotoUpdateService.shouldCheck(now: base.addingTimeInterval(86_399), cache: GotoUpdateCache(lastCheckedAt: base, latestTag:"v0.0.28"), ttl: 86_400) == false)
check("ttl old->check", GotoUpdateService.shouldCheck(now: base.addingTimeInterval(86_401), cache: GotoUpdateCache(lastCheckedAt: base, latestTag:"v0.0.28"), ttl: 86_400))
check("cache sibling", GotoUpdateService.cacheStoreURL.lastPathComponent == ".goto_update_check")
try? FileManager.default.removeItem(at: root)
SWIFT
swiftc -o "$TMPDIR/updtest" Shared/GotoProjectStore.swift Shared/GotoUpdateService.swift "$TMPDIR/main.swift" 2>&1 | grep -i error
"$TMPDIR/updtest"
```
Expected: 모든 줄 PASS.

- [ ] **Step 5: Commit**

```bash
git add Shared/GotoUpdateService.swift GotoTests/GotoUpdateServiceTests.swift
git commit -m "feat: add GotoUpdateService version/cache logic"
```

---

### Task 2: GotoUpdateService — 부수효과 (네트워크·설치)

**Files:**
- Modify: `Shared/GotoUpdateService.swift` (Task 1에 함수 추가)

**Interfaces:**
- Consumes: Task 1의 타입들(`GotoLatestRelease`, `GotoUpdateError`, `GotoUpdateCache`, `currentVersion`, `shouldCheck`, `loadCache`, `saveCache`, `isUpdateAvailable`).
- Produces:
  - `GotoUpdateService.fetchLatest() -> Result<GotoLatestRelease, GotoUpdateError>`
  - `GotoUpdateService.refreshCache(now: Date)`
  - `GotoUpdateService.performUpgrade(log: (String) -> Void) -> Result<String, GotoUpdateError>` (성공 시 설치한 tag 반환)

- [ ] **Step 1: 구현 추가** (부수효과라 단위 테스트 없음 — 컴파일 + 수동 검증)

`Shared/GotoUpdateService.swift`의 `GotoUpdateService` 안에 추가:

```swift
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
            // sudo 프롬프트 등을 터미널과 공유
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
```

- [ ] **Step 2: 컴파일 검증**

Run:
```bash
swiftc -typecheck $(find GotoCLI Shared -name '*.swift') 2>&1 | grep -i "error:" | grep -v "main.swift.*ActorIsolatedCall"
```
Expected: 출력 없음(에러 0).

- [ ] **Step 3: Commit**

```bash
git add Shared/GotoUpdateService.swift
git commit -m "feat: add GotoUpdateService network/install side effects"
```

---

### Task 3: CLI 배선 — `--upgrade` 핸들러 + `--sync`에 refreshCache 통합

**Files:**
- Modify: `GotoCLI/main.swift` (knownFlags, usageText, --upgrade 핸들러, --sync 핸들러)

**Interfaces:**
- Consumes: `GotoUpdateService.performUpgrade(log:)`, `GotoUpdateService.refreshCache(now:)`.
- Produces: `goto --upgrade` 동작, `goto --sync`가 동기화 후 업데이트 캐시 갱신.

- [ ] **Step 1: usageText에 `--upgrade` 추가**

`GotoCLI/main.swift`의 `usageText` 안 `--help` 줄 바로 위에 추가:

```
  goto --upgrade                    최신 버전으로 업데이트 (앱+CLI)
```

- [ ] **Step 2: knownFlags에 `--upgrade` 추가**

`knownFlags` Set에 `"--upgrade"`를 추가한다(별칭 없음). 변경 후:

```swift
let knownFlags: Set<String> = ["--add", "--remove", "--add-subdirs", "--remove-subdirs", "--pin", "--unpin", "--unwatch", "--sync", "--upgrade", "--help"]
```

- [ ] **Step 3: `--sync` 핸들러에 refreshCache 통합**

기존 `--sync` 분기를 아래로 교체:

```swift
if argArray.firstIndex(of: "--sync") != nil {
    let r = GotoProjectStore.syncWatched()
    GotoUpdateService.refreshCache()
    fputs("동기화 완료: 추가 \(r.added), 제거 \(r.removed)\n", stderr)
    exit(0)
}
```

- [ ] **Step 4: `--upgrade` 핸들러 추가**

`--sync` 분기 바로 아래에 추가:

```swift
if argArray.firstIndex(of: "--upgrade") != nil {
    switch GotoUpdateService.performUpgrade(log: { fputs("\($0)\n", stderr) }) {
    case .success(let tag):
        fputs("업데이트 완료: \(tag). 새 셸을 열거나 'source ~/.zshrc' 후 사용하세요.\n", stderr)
        exit(0)
    case .failure(let error):
        fputs("error: 업데이트 실패 (\(error))\n", stderr)
        exit(2)
    }
}
```

- [ ] **Step 5: 컴파일 검증 + 동작 확인**

Run:
```bash
swiftc -typecheck $(find GotoCLI Shared -name '*.swift') 2>&1 | grep -i "error:" | grep -v "main.swift.*ActorIsolatedCall"
OUT="$TMPDIR/goto-upg"; swiftc -o "$OUT" $(find GotoCLI Shared -name '*.swift') 2>&1 | grep -i error
"$OUT" --help | grep -- "--upgrade"
```
Expected: typecheck 에러 0, `--help`에 `--upgrade` 줄 표시.

- [ ] **Step 6: Commit**

```bash
git add GotoCLI/main.swift
git commit -m "feat: wire goto --upgrade and update check into --sync"
```

---

### Task 4: 인터랙티브 알림 줄

**Files:**
- Modify: `GotoCLI/main.swift` (`drawMainList` 시그니처 + 본문, `runInteractive`에서 notice 계산·전달)

**Interfaces:**
- Consumes: `GotoUpdateService.pendingNotice() -> String?`.
- Produces: 인터랙티브 메인 리스트 헤더 아래에 업데이트 알림 한 줄(있을 때만).

- [ ] **Step 1: `drawMainList` 시그니처에 파라미터 추가**

`private func drawMainList(` 의 파라미터 목록 끝(`tty:` 앞)에 추가:

```swift
    updateNotice: String?,
    tty: UnsafeMutablePointer<FILE>
```

- [ ] **Step 2: 헤더 다음에 notice 출력**

`drawMainList` 본문에서 헤더 `} else { ... }` 블록(필터 안내) 직후, `let projectPaths` 줄 바로 위에 추가:

```swift
    if let updateNotice {
        fputs("\(ansiGray)\(updateNotice)\(ansiReset)\n\n", tty)
    }
```

- [ ] **Step 3: `runInteractive`에서 notice 계산 + 호출부 갱신**

`runInteractive` 함수 시작부(루프 진입 전)에서 한 번 계산:

```swift
    let updateNotice = GotoUpdateService.pendingNotice()
```

그리고 `runInteractive` 내 `drawMainList(...)` 호출 두 곳(초기 렌더 + 루프 내 갱신) 모두 `tty:` 인자 앞에 `updateNotice: updateNotice,` 를 추가한다. (호출부는 `drawMainList(rows: ..., colored: ..., tty: tty)` 형태 — `tty:` 앞에 삽입.)

- [ ] **Step 4: 컴파일 검증**

Run:
```bash
swiftc -typecheck $(find GotoCLI Shared -name '*.swift') 2>&1 | grep -i "error:" | grep -v "main.swift.*ActorIsolatedCall"
```
Expected: 에러 0. (drawMainList 호출 누락 시 "missing argument" 에러로 드러남 → 모두 갱신됐는지 보장)

- [ ] **Step 5: 알림 표시 수동 검증 (캐시 주입)**

Run (실제 ~/.goto_update_check를 건드리지 않도록 빌드 바이너리는 실제 HOME을 쓰므로, 로직은 Task 1 하니스에서 pendingNotice까지 확장해 검증):
```bash
cat > "$TMPDIR/main.swift" <<'SWIFT'
import Foundation
let root = FileManager.default.temporaryDirectory.appendingPathComponent("notice-\(UUID().uuidString)")
try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
GotoProjectStore.storeURLOverride = root.appendingPathComponent(".goto")
// 현재 버전 0.0.0(dev)면 nil 이어야 함
print("dev nil:", GotoUpdateService.pendingNotice() as Any)
try? FileManager.default.removeItem(at: root)
SWIFT
swiftc -o "$TMPDIR/notice" Shared/GotoProjectStore.swift Shared/GotoUpdateService.swift "$TMPDIR/main.swift" 2>&1 | grep -i error
"$TMPDIR/notice"
```
Expected: `dev nil: nil` (dev 빌드는 버전 0.0.0이라 알림 없음 — dev 가드 동작 확인).

- [ ] **Step 6: Commit**

```bash
git add GotoCLI/main.swift
git commit -m "feat: show update notice in interactive list"
```

---

### Task 5: 문서 갱신

**Files:**
- Modify: `README.md` (업데이트 방법 + CLI 표), `wiki/log.md`

**Interfaces:**
- Consumes: 위 기능. Produces: 없음(문서).

- [ ] **Step 1: README CLI 표에 `--upgrade` 추가**

README의 `## CLI` 코드블록 `goto --help, -h` 줄 위에 추가:

```
goto --upgrade                    # 최신 버전으로 업데이트 (앱+CLI)
```

- [ ] **Step 2: README 업데이트 섹션 보강**

`## 설치 (Release)` 또는 적절한 위치에 한 단락 추가:

```
인터랙티브 모드 진입 시 백그라운드로 새 버전을 확인하며(24시간마다, 결과는 다음 실행 때 상단 한 줄로 안내), `goto --upgrade`로 최신 릴리스 DMG를 받아 `Install Goto.pkg`를 설치합니다(sudo 필요, 앱+CLI 모두 갱신).
```

- [ ] **Step 3: wiki/log.md 항목 추가**

`# Goto Wiki Log` 다음에:

```
## 2026-06-22 feat | CLI 자동 업데이트 (알림 + self-update)

`GotoUpdateService`를 추가해 GitHub Releases `latest`의 tag를 비교한다. 인터랙티브 진입 시 기존 백그라운드 `goto --sync` 프로세스가 24h TTL로 `~/.goto_update_check` 캐시를 갱신하고, 메인 리스트는 캐시를 읽어 새 버전이면 상단에 `⬆ 새 버전 … — goto --upgrade` 한 줄을 표시한다(반영은 다음 실행). `goto --upgrade`는 최신 DMG를 받아 `hdiutil`로 마운트하고 `sudo installer`로 `Install Goto.pkg`를 전체 설치한다. dev 빌드(0.0.0)는 체크를 건너뛴다. 버전은 빌드 시 주입된 `CFBundleShortVersionString`을 사용. See `docs/superpowers/specs/2026-06-22-cli-auto-update-design.md`.
```

- [ ] **Step 4: Commit**

```bash
git add README.md wiki/log.md
git commit -m "docs: document goto auto-update"
```

---

## Self-Review

**1. Spec coverage:**
- 버전 출처(infoDictionary, dev 0.0.0 가드) → Task 1 `currentVersion`/`isUpdateAvailable`, Task 4 Step 5. ✓
- 캐시(~/.goto_update_check, 형제 경로, TTL) → Task 1 `cacheStoreURL`/`shouldCheck`/round-trip. ✓
- 알림(백그라운드 sync 통합, 캐시 기반, TTY 한정) → Task 3 Step 3, Task 4. ✓ (비-TTY 미표시: drawMainList는 인터랙티브 전용 함수라 자동 충족 — 비-TTY 경로는 별도 stdout 출력으로 drawMainList를 호출하지 않음.)
- self-update(DMG→hdiutil→sudo installer→detach, 정리) → Task 2 `performUpgrade`, Task 3 Step 4. ✓
- 신규 플래그(`--upgrade` 공개, 별칭 없음, `--check-update` 미생성) → Task 3. ✓
- 보안/엣지(HTTPS, 오프라인 skip, rate limit TTL, 정리) → Task 2 `fetchLatest`/`performUpgrade`(defer detach/remove), `refreshCache`(오프라인 시 캐시 미갱신). ✓
- 테스트(SemVer/캐시/TTL 단위, 부수효과 제외) → Task 1 테스트, Task 2 컴파일+수동. ✓
- release.yml 무변경 → 계획 어디에도 release.yml 수정 없음. ✓

**2. Placeholder scan:** 모든 코드 step에 완성 코드 포함. "TODO/적절히/등" 없음. ✓

**3. Type consistency:** `performUpgrade(log:)`는 Task 2 정의 = Task 3 호출 일치. `pendingNotice()`/`refreshCache(now:)`/`cacheStoreURL` 시그니처 Task 1·2 정의 = Task 3·4 사용 일치. `GotoUpdateCache(lastCheckedAt:latestTag:)` 일관. ✓
