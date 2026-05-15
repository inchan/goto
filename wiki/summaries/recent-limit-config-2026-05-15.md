---
tags: [cli, menubar, settings]
date: 2026-05-15
---

# 최근 항목 개수 설정화

`recent` 표시 개수를 하드코딩 상수에서 사용자 설정으로 승격했다. 기본값 또한 3 → 5 로 상향.

## 변경 요약

### 1. `GotoCLIConfig.recentLimit`

- `Shared/GotoCLISettings.swift`
- `recentLimit: Int` 필드 추가 (`Codable`). 디코딩 시 `0...50` 클램프.
- `defaultRecentLimit = 5`, `recentLimitOptions = [0, 1, 3, 5, 10]`.
- 헬퍼: `sanitizedRecentLimit(_:)`, `nextRecentLimit(after:)` (CLI 순환용).
- 기존 사용자 `.goto_config` 에 키가 없으면 자동으로 `5` 가 적용된다.

### 2. `GotoProjectList` API 확장

- `static let recentLimit = 3` 상수 제거.
- `loadRecentProjects(availableProjects:limit:)` — `limit:` 옵셔널. 미지정 시 현재 `cliConfig().recentLimit` 사용. `0` 이면 빈 배열.
- `recordRecentProject(_:availableProjects:limit:)` — 저장 한도는 `max(effectiveLimit, defaultRecentLimit)`. 사용자가 한도를 다시 늘렸을 때 과거 기록이 살아나도록 의도적으로 더 보수적으로 저장.
- `orderedProjects(...)` 가 `config.recentLimit` 을 그대로 전달 → 메뉴바·CLI 모두 자동 반영.

### 3. CLI 설정 화면

- `GotoCLI/main.swift`
- `SettingsRow.recentLimit` 케이스 추가. `프로젝트 정렬` 과 `prefix 색상` 사이에 배치.
- 표시: `최근 항목 개수    꺼짐 | 1개 | 3개 | 5개 | 10개`.
- Enter/Space 로 `nextRecentLimit(after:)` 순환 후 즉시 `saveCLIConfig`.

### 4. macOS 앱 설정창

- `GotoApp/AppDelegate.swift`
- "CLI project list sorting" 섹션 하단에 `최근 개수` `NSPopUpButton` 추가.
- 옵션: `표시 안 함 / 1개 / 3개 / 5개 / 10개` (representedObject = `Int`).
- 핸들러 `recentLimitDidChange(_:)` 가 저장 후 `menuBarController?.update()` 호출 → 메뉴바 드롭다운 즉시 갱신.
- 헬퍼 `configureRecentLimitPopup(_:)` 추가, 레이아웃 제약(라벨 90pt, popup 180pt) 추가.

## 호환성

- 옛 `.goto_config` (recentLimit 키 누락) → 디코더가 `defaultRecentLimit` 적용.
- 옛 `.goto_recent` 파일에 N개가 있어도, `recordRecentProject` 가 storage 한도를 `max(설정, 5)` 로 유지하므로 한도를 잠시 낮췄다가 다시 올려도 잃지 않는다.
- 메뉴바 그리기 로직(`MenuBarController.buildMenu`)은 이미 `ordered.recentCount` 기반이라 본문 변경 없이 자동 반영.

## 동기

- recent가 3개로 고정돼 있어 자주 쓰는 5~10개 워크플로우에서 부족하다는 피드백.
- CLI/메뉴바 양쪽 진입점에서 동일 설정을 변경 가능해야 도구를 어떤 경로로 켜든 일관된 경험.
