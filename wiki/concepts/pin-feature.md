---
title: Pin feature
date: 2026-05-11
tags: [cli, menubar, settings]
---

# Pin feature

핀(pin)은 자주 쓰는 프로젝트를 리스트 최상단에 고정하는 기능이다. recents보다 위에 위치하며, CLI · 메뉴바 양쪽에서 동일 데이터(`~/.goto_pinned`)를 공유한다.

## 데이터

- 파일: `~/.goto_pinned`
- 형식: 한 줄에 하나의 절대 경로(`~/.goto`와 동일 normalize).
- 순서: 추가순(앞이 가장 최근 추가). 정렬 옵션이 다른 값이면 표시 시 매번 정렬.
- 무효 경로: `~/.goto`에 등록되지 않은 경로는 표시 시 자동 무시(파일은 그대로 두어 사용자가 다시 등록하면 핀이 살아남음).

## 정렬 옵션

`GotoCLIConfig.pinSortMode: GotoPinSortMode` (`~/.goto_config` 안에 저장).

| 값 | 설명 |
|---|---|
| `insertion` (default) | 추가 순서대로. 가장 최근에 핀한 항목이 가장 위. |
| `nameAscending` / `nameDescending` | 프로젝트 이름 기준. |
| `createdAtAscending` / `createdAtDescending` | 디렉터리 생성일 기준. |

`pinSortMode`가 `insertion`이 아니면 표시 시 매번 정렬한다(저장 순서는 그대로 유지).

## UI 표시

### CLI (`goto`)
- 메인 리스트 순서: 핀 → 최근 → 그 외(상위 폴더 정렬 + 프로젝트 정렬).
- 핀 영역 항목 앞에 📌 마커.
- 키바인딩: `p` 누르면 현재 선택된 행 토글. 토글 후 해당 path가 새 위치(핀 추가 시 핀 영역 최상단, 핀 해제 시 일반 영역)로 이동하고 선택 커서가 따라간다.

### Settings → 핀 정렬
- Settings 화면에서 `핀 정렬` 행을 Enter/Space로 다음 옵션으로 회전.

### 프로젝트 관리 화면
- 각 행에 `[x]/[ ] 📌` 형식의 마커: 체크박스(제거 후보) + 핀 마커.
- `p` 키로 현재 행 토글.

### 메뉴바 (`Goto.app`)
- 메뉴 순서: 핀(📌 prefix) → 최근 → 일반/그룹.
- 모든 프로젝트 항목에 `NSMenuItem.isAlternate = true` + `.option` modifier로 alternate 항목 짝지음. ⌥ 키를 누른 채 호버하면 "📌 name (핀 고정)" 또는 "(핀 해제)" 항목이 보이고, 클릭하면 토글된다.
- `~/.goto_pinned` 변경은 `~/.goto`와 마찬가지로 `DispatchSourceFileSystemObject`로 감시해서 메뉴를 자동 갱신.

## CLI 플래그

- `goto --pin <path>` — `~/.goto`에 등록된 경로만 받음. 미등록이면 에러.
- `goto --unpin <path>` — 안전하게 멱등.

핀과 add는 분리. `--pin`은 add를 자동 수행하지 않으며, 사용자가 의도적으로 add → pin 순서로 호출해야 한다. add가 빠진 핀은 표시 시 필터링된다.

## 회귀 방지

- `GotoCLIConfig.pinSortMode`는 구버전 `~/.goto_config`(필드 없음)에서도 정상 로드되도록 `init(from:)`에 `decodeIfPresent`로 기본값 처리.
- `orderedProjects`는 `(displayProjects, pinnedCount, recentCount)` 튜플을 반환. 호출부(`mainRows`, `MenuBarController.buildMenu`)가 두 카운트로 분리선을 결정.
- 핀과 recents가 겹치면 핀 영역에만 표시(중복 제거).
