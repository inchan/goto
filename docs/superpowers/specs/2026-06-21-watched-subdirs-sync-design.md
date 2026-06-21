# Watched Subdirs 자동 동기화 설계

## 목적
`--add-subdirs <parent>`로 등록한 parent 디렉터리를 "감시 대상(watched)"으로 기억해, 이후 그 하위의 git 프로젝트가 추가/삭제될 때 자동으로 `~/.goto` 목록을 동기화한다.

## 사용자 결정 사항
- `--add-subdirs`가 곧 watch 등록 (별도 watch 명령 없음). 해제는 `--unwatch`.
- **추가 기준**: parent 직속 자식 중 git 루트인 것 (기존 addSubdirs 규칙과 동일).
- **삭제 기준**: 디스크에서 **폴더가 물리적으로 사라진** 등록 항목만 제거. (`.git`만 사라져 git이 아니게 된 경우는 제거하지 않음.)
- **트리거**: 인터랙티브 모드 진입 시 `goto --sync`를 detached 백그라운드 프로세스로 분리 실행(비동기). 반영은 다음 실행 때 돼도 됨. + 수동 `goto --sync` 지원.
- 핀 보호 별도 처리 불필요 (폴더 삭제 기준이라 자연 해소).

## 데이터
- 신규 파일 `~/.goto_watched` — 감시 parent 경로를 normalize해 저장.
- 경로 규칙: `storeURL`의 형제로 둔다 → `storeURLOverride`로 테스트 격리가 자동 적용됨.
  - `watchedStoreURL = storeURL.deletingLastPathComponent().appendingPathComponent(storeURL.lastPathComponent + "_watched", isDirectory: false)`
  - 기본값: `~/.goto_watched`. override 시: `<override>_watched`.

## API 계약 (Shared/GotoProjectStore.swift) — Agent 1 담당
아래 시그니처를 **정확히** 따른다. CLI/테스트가 이 시그니처에 의존한다.

```swift
public static var watchedStoreURL: URL { get }

// normalized, deduped, sorted (load()와 동일 규약)
public static func loadWatched() -> [String]

// normalize 후 추가. 이미 있으면 false. (디렉터리 존재 검증은 하지 않음 — sync가 정리)
@discardableResult
public static func addWatched(_ path: String) -> Bool

// normalize 후 제거. 없으면 false.
@discardableResult
public static func removeWatched(_ path: String) -> Bool

// 모든 watched parent를 동기화. (추가 개수, 제거 개수) 반환.
@discardableResult
public static func syncWatched() -> (added: Int, removed: Int)
```

### syncWatched 동작 명세
각 watched parent `p`(normalized)에 대해:
- `p`가 디렉터리로 존재하지 않으면:
  - `p`의 **직속 자식**으로 등록된 항목을 모두 `remove` (removed 증가)
  - `p`를 watched 목록에서 제거
- `p`가 존재하면:
  - **추가**: `p`의 직속 자식 중 `isDirectory` && `isGitManagedDirectory`이고 아직 미등록인 것을 `add` (added 증가). `.`으로 시작하는 항목은 건너뜀 (기존 addSubdirs 규칙).
  - **제거**: 현재 등록 목록 중 `p`의 **직속 자식**인데 `isDirectory`가 false인 것을 `remove` (removed 증가).
- "직속 자식" 판정: 등록 경로가 `p + "/"`로 시작하고, 그 뒤 나머지에 `/`가 없음 (기존 `removeSubdirs` 패턴 재사용).
- watched 목록이 바뀌었으면 저장.

### addSubdirs 수정
기존 `addSubdirs(_ parent:)` 끝에서 `addWatched(normalize(parent))`를 호출해 parent를 watched로 등록한다. 반환값(추가된 프로젝트 수)은 그대로.

### 저장 헬퍼
`saveEntries`는 `~/.goto` 전용(tmp 파일명 하드코딩). watched용 별도 atomic 저장 헬퍼를 추가한다(tmp 파일명 충돌 회피). 기존 `rawLoad`/`saveEntries` 구조를 참고해 동일 방식(atomic write + replace/move)으로 구현.

**제약**: Agent 1은 `Shared/GotoProjectStore.swift`만 수정한다.

## CLI 계약 (GotoCLI/main.swift) — Agent 2 담당
현재 상태: 약어 매핑(`flagAliases`), `knownFlags`, `usageText`가 이미 존재한다.

- `flagAliases`에 추가: `"-U": "--unwatch"`, `"-S": "--sync"`. (기존 `-u`=unpin과 충돌 없음)
- `knownFlags`에 추가: `"--unwatch"`, `"--sync"`.
- `usageText`에 행 추가:
  - `goto --unwatch, -U <path>   감시 해제 (등록된 프로젝트는 유지)`
  - `goto --sync, -S             감시 중인 폴더 동기화`
- `--unwatch` 핸들러: 경로 인자 필요(없으면 기존 패턴대로 에러+usage+exit(2)). `GotoProjectStore.removeWatched(path)` → true면 `감시 해제: <path>`, false면 `감시 중이 아님: <path>`를 stderr로. exit(0).
- `--sync` 핸들러: 인자 없음. `let r = GotoProjectStore.syncWatched()` → `동기화 완료: 추가 \(r.added), 제거 \(r.removed)`를 stderr로. exit(0). **이 핸들러는 다른 플래그 핸들러들과 같은 위치(argArray firstIndex 분기)에 둔다.**
- **detached 백그라운드 sync**: 인터랙티브 모드로 진입하기 직전(runInteractive 호출 직전)에 `spawnBackgroundSync()`를 호출.
  - `spawnBackgroundSync()`: `GotoProjectStore.loadWatched()`가 비어있으면 즉시 return. 비어있지 않으면 자기 실행 파일(`CommandLine.arguments[0]`)을 `["--sync"]` 인자로 `Process`로 실행하되, `standardInput/Output/error`를 `FileHandle.nullDevice`로 두고 `try? run()`만 호출(`waitUntilExit` 안 함). 실행 파일 경로가 유효하지 않으면 조용히 skip(다음 실행 때 재시도).
  - `--sync` 모드에서는 이 spawn이 일어나지 않는다(핸들러가 먼저 exit하므로 자연히 보장). 무한 spawn 없음.

**제약**: Agent 2는 `GotoCLI/main.swift`만 수정한다. 전체 빌드 검증은 하지 말 것(코어가 동시 작업 중) — 자기 코드의 문법만 신경 쓴다.

## 테스트 (GotoTests/) — Agent 3 담당
- 신규 파일 `GotoTests/GotoWatchedSyncTests.swift` 추가 (기존 파일 수정 금지).
- 격리: 기존 `GotoProjectStoreTests`와 동일하게 `setUpWithError`에서 임시 디렉터리 + `GotoProjectStore.storeURLOverride = <tmp>/.goto` 설정, `tearDown`에서 nil + 정리. watched 경로는 override 형제라 자동 격리됨.
- git 루트는 실제 `git` 호출로 판정되므로, 테스트용 git 루트는 임시 디렉터리에 `git init`(또는 `.git` 디렉터리 생성으로는 부족 — `git -C ... rev-parse --show-toplevel`가 통과해야 함, 실제 `git init` 권장)으로 만든다.
- 커버 케이스:
  1. `addSubdirs` 호출 후 parent가 watched에 등록되는지 (`loadWatched`)
  2. watched parent 하위에 새 git 루트 생성 후 `syncWatched` → added 증가, 목록에 포함
  3. 등록된 직속 폴더를 디스크에서 삭제 후 `syncWatched` → removed 증가, 목록에서 빠짐
  4. `.git`만 제거(폴더는 존재) 후 `syncWatched` → 제거되지 **않음** (삭제 기준은 폴더 삭제)
  5. watched parent 자체를 삭제 후 `syncWatched` → 하위 등록 정리 + watched에서 제거
  6. `removeWatched` 후 `syncWatched`가 그 parent를 더 이상 동기화하지 않음
- 새 테스트 파일을 빌드 대상에 포함해야 할 수 있다(`project.yml`의 GotoTests sources가 디렉터리 글롭인지 확인; 글롭이면 자동 포함). 확인해 필요 시 메인에게 보고.

**제약**: Agent 3는 `GotoTests/` 아래만 수정. 테스트 실행(xcodebuild)은 환경상 불가할 수 있으니, 작성에 집중하고 컴파일/실행 가능 여부를 보고한다.

## 문서 (README.md) — Agent 4 담당
- CLI 사용 예시 코드블록에 `--unwatch, -U`, `--sync, -S` 행 추가.
- `--add-subdirs` 설명에 "이후 자동 동기화 대상으로 감시됨" 취지의 짧은 보충, 그리고 자동 동기화 동작(인터랙티브 진입 시 백그라운드 sync, 추가=git 기준 / 삭제=폴더 삭제 기준)을 1~2문장으로 README 적절한 위치에 추가.

**제약**: Agent 4는 `README.md`만 수정.

## 통합 검증 (메인이 수행)
- `swiftc -typecheck $(find GotoCLI Shared -name '*.swift')`로 코어+CLI 타입체크.
- 임시 바이너리 빌드 후 `--sync`, `--unwatch`, `--add-subdirs`(watched 등록) 실제 동작 확인.
- 파일이 겹치지 않으므로 머지 충돌 없음.
