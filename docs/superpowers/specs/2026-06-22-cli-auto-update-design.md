# goto CLI 자동 업데이트 설계 (알림 + self-update)

## 목적
goto CLI 사용자가 새 릴리스를 자동으로 인지하고(알림), 한 명령(`goto --upgrade`)으로 최신 버전을 설치할 수 있게 한다. 설치 단위는 기존 릴리스 자산인 DMG 내부 `Install Goto.pkg` 전체(앱+CLI+wrapper)다.

## 사용자 결정 사항
- **대상/수준**: CLI 중심. 알림 + self-update 모두. 앱(메뉴바)에는 별도 자동 업데이트를 넣지 않는다.
- **설치 방식**: `goto --upgrade`는 릴리스 DMG를 받아 내부 `Install Goto.pkg`를 `sudo installer`로 전체 설치한다(앱+CLI+wrapper 모두 갱신).
- **백그라운드 체크**: 별도 `--check-update` 플래그를 만들지 않고 기존 백그라운드 `goto --sync` 경로에 업데이트 체크를 통합한다.

## 버전 출처
- **현재 버전**: `Bundle.main.infoDictionary?["CFBundleShortVersionString"]`. `release.yml`이 빌드 시 `MARKETING_VERSION`을 주입하므로 릴리스 바이너리에는 실제 버전이 박힌다.
  - 로컬 dev 빌드는 `0.0.0`이 박히므로, 현재 버전이 `0.0.0`이거나 읽기 실패면 **업데이트 체크/알림을 전부 skip**한다(오탐 방지).
- **최신 버전**: GitHub Releases API `GET https://api.github.com/repos/inchan/goto/releases/latest`의 `tag_name`(예: `v0.0.28`)과 DMG asset(`Goto-vX.Y.Z.dmg`)의 `browser_download_url`.

## 컴포넌트

### `Shared/GotoUpdateService.swift` (신규)
순수 로직과 부수효과를 함수 경계로 분리한다.

순수(테스트 대상):
- `currentVersion() -> String?` — `Bundle.main` infoDictionary에서 읽음. `0.0.0`/nil 처리.
- `compareSemVer(_ a: String, _ b: String) -> ComparisonResult` — `v` 접두사 허용, `MAJOR.MINOR.PATCH` 숫자 비교.
- `isUpdateAvailable(current: String, latest: String) -> Bool` — dev(0.0.0) 가드 포함.
- 캐시 입출력: `cacheStoreURL`(= `storeURL` 형제 `~/.goto_update_check`), `loadCache() -> UpdateCache?`, `saveCache(_:)`. `UpdateCache`는 `lastCheckedAt: Date`, `latestTag: String`.
- `shouldCheck(now:cache:ttl:) -> Bool` — 마지막 체크가 TTL(기본 24h) 이내면 false.

부수효과(테스트 제외, 함수로 격리):
- `fetchLatest() -> Result<LatestRelease, UpdateError>` — URLSession 동기 호출(CLI 단발 프로세스), HTTPS, 타임아웃 짧게(예: 5s). `LatestRelease { tag: String, dmgURL: URL }`.
- `refreshCache()` — 백그라운드 경로에서 호출. `shouldCheck`면 `fetchLatest` 후 `saveCache`.
- `performUpgrade() -> Result<Void, UpdateError>` — 아래 self-update 흐름.

`UpdateError`: `network`, `noAsset`, `downloadFailed`, `mountFailed`, `installFailed(status)`, `offline` 등.

### 캐시 파일
- 경로: `storeURL.deletingLastPathComponent()/(storeURL.lastPathComponent + "_update_check")` → 기본 `~/.goto_update_check`, override 시 형제 경로라 테스트 격리 자동(기존 watched 패턴과 동일).
- 포맷: JSON `{ "lastCheckedAt": <epoch>, "latestTag": "v0.0.28" }`. atomic write.

## 알림 흐름 (백그라운드)
1. 인터랙티브 진입 직전, 기존 `spawnBackgroundSync()`가 띄우는 `goto --sync` 프로세스가 sync 완료 후 `GotoUpdateService.refreshCache()`도 호출한다(spawn 1회로 sync + update 체크).
   - `refreshCache()`는 `shouldCheck`(24h TTL)일 때만 네트워크 호출. 아니면 즉시 반환.
   - dev 버전(0.0.0)이면 호출 자체를 skip.
2. 인터랙티브 리스트 렌더링 시 `loadCache()`를 읽어 `isUpdateAvailable(current, cache.latestTag)`이면 리스트 상단에 한 줄 안내를 표시한다: `⬆ 새 버전 <tag> 사용 가능 — goto --upgrade`.
   - 캐시 기반이므로 반영은 다음 실행 때(첫 실행은 캐시가 없어 미표시 — sync 철학과 동일).
   - 표시는 비-TTY(파이프) 출력에는 넣지 않는다(stdout 오염 방지).

## self-update 흐름 (`goto --upgrade`, 포그라운드)
1. `fetchLatest()` 호출. 실패면 에러 출력 후 exit(비0).
2. `isUpdateAvailable`이 false면 `이미 최신 버전입니다 (<current>)` 출력 후 exit(0).
3. DMG를 `/tmp`(또는 `FileManager.temporaryDirectory`)로 다운로드. 진행 메시지 출력.
4. `hdiutil attach -nobrowse -quiet <dmg>` → 마운트 포인트 파싱.
5. 마운트 볼륨에서 `Install Goto.pkg` 경로 확인.
6. `sudo installer -pkg "<mount>/Install Goto.pkg" -target /` 실행. sudo 비밀번호 프롬프트는 포그라운드 터미널에서 자연 발생(stdin/stdout/stderr 상속).
7. 성공/실패와 무관하게 `hdiutil detach <mount>` 및 임시 DMG 삭제(정리).
8. 성공 시: `업데이트 완료: <tag>. 새 셸을 열거나 'source ~/.zshrc' 후 사용하세요.` 출력.

## 신규 플래그 (`GotoCLI/main.swift`)
- `goto --upgrade` (공개, usageText 노출): `GotoUpdateService.performUpgrade()` 호출.
  - 단축 별칭은 부여하지 않는다(파괴적/드문 동작이라 명시적 장형만).
- 별도 `--check-update` 플래그는 만들지 않는다. 백그라운드 체크는 `--sync` 핸들러 끝에서 `refreshCache()`를 호출해 처리한다.

## 보안 / 엣지 케이스
- HTTPS만 사용. GitHub 신뢰(현 ad-hoc 서명 수준과 일관 — 별도 EdDSA/notarization 검증은 범위 밖).
- 오프라인/네트워크 실패: 알림 경로는 조용히 skip(에러 출력 없음), `--upgrade`는 명확한 에러 메시지 + 비0 종료.
- GitHub API rate limit(미인증 60/h/IP): 24h TTL 캐시로 빈도 제한. 토큰 불필요.
- DMG mount/detach 실패, pkg 설치 실패: 각각 에러로 처리하고 임시 파일·마운트를 정리.
- `release.yml`·DMG 자산 구조는 **변경하지 않는다**(기존 DMG 그대로 사용).

## 테스트
- 단위 테스트 (`GotoTests/`, 격리는 기존 `storeURLOverride` 패턴):
  - `compareSemVer`: `v0.0.28` vs `0.0.28`, 자리수/패치/마이너/메이저 경계, 동일 버전.
  - `isUpdateAvailable`: dev(0.0.0) 가드, 최신/구버전/동일.
  - 캐시 round-trip: `saveCache`→`loadCache` 일치, 손상 파일이면 nil.
  - `shouldCheck`: TTL 경계(직전 체크 후 23h59m vs 24h01m). `now`를 주입 가능한 시그니처로 설계.
- 부수효과(`fetchLatest`/`performUpgrade`)는 네트워크·`hdiutil`·`installer`·sudo 의존이라 자동 테스트에서 제외. 함수 경계로 분리해 수동 검증.

## 파일 변경 요약
- 신규: `Shared/GotoUpdateService.swift`, `GotoTests/GotoUpdateServiceTests.swift`
- 수정: `GotoCLI/main.swift`(--upgrade 핸들러, --sync에 refreshCache 통합, 인터랙티브 리스트 알림 줄, usageText)
- 문서: `README.md`(업데이트 방법에 자동 알림/`--upgrade` 추가), `wiki/log.md`, `wiki/SCHEMA.md`(필요 시 태그)

## 비목표 (YAGNI)
- 앱(Goto.app/메뉴바) 내 자동 업데이트, Sparkle 통합.
- CLI 바이너리 단독 자산 추가(전체 pkg 설치로 충분).
- 서명/notarization 검증, 델타 업데이트, 롤백, 채널(beta/stable) 분리.
- `--upgrade` 단축 플래그.
