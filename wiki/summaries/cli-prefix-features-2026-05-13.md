---
tags: [cli, settings]
date: 2026-05-13
---

# CLI Prefix Color + `f` Filter + Pattern Prefix

CLI 인터랙티브 모드에 prefix 표현·검색 기능을 강화했다.

## 변경 요약

### 1. Prefix 배경색 (true color)

- 상위 폴더 또는 패턴 prefix 문자열을 **FNV-1a 64-bit 해시 → 8색 큐레이트 팔레트** 인덱스로 매핑해 배경 배지로 렌더링한다.
- 팔레트는 hue family 당 1개씩만 두고 인접 인덱스가 시각적으로 멀어지도록 재배치: red / emerald / violet / amber / cyan / pink / blue / slate.
- **충돌 회피(linear probing)**: 현재 표시 중인 unique prefix 들을 정렬해 슬롯 할당. 시작 슬롯이 차있으면 다음 빈 슬롯으로 이동 → unique prefix 수 ≤ 8 이면 충돌 0 보장.
- **자동 글자색 대비**: bg 휘도(`0.299R + 0.587G + 0.114B`) > 150 이면 검은 글자, 아니면 흰 글자. amber·cyan 같은 옅은 색에서도 가독성 유지.
- 동일 prefix 는 항상 동일 색(같은 표시 집합 안에서). 빈 prefix(최상위 경로) 는 색상 없음.
- 메인 리스트와 프로젝트 관리 화면 양쪽에 적용.

### 2. `f` 필터 모드

- 메인 리스트에서 `f` 또는 `F` 키로 진입. Claude Code 의 status 필터와 유사한 UX.
- 헤더가 `goto — 필터: <query>▌` 로 전환되고 입력 즉시 실시간 필터링.
- 매치 기준: `displayItem.parent`, `displayItem.name`, 전체 경로 모두 case-insensitive substring.
- 키:
  - 인쇄 가능 ASCII → 쿼리 누적
  - Backspace(0x7F/0x08) → 마지막 글자 제거
  - ↑↓ → 결과 내 이동
  - Enter → 선택
  - ESC → 쿼리 해제, 일반 모드 복귀
  - Ctrl-C → 종료
- 결과 0건이면 안내 문구 표시. 필터 중에는 separator/settings 행을 숨겨 플랫 결과 리스트만 노출.

### 3. `xxx-` 패턴 prefix

- 프로젝트 폴더명이 `xxx-yyy...` 형태이고, 동일 `xxx` 가 등록된 프로젝트 **2개 이상**에 등장할 때만 `xxx` 를 prefix 로 사용한다.
- 조건 미충족(단일 등장 또는 패턴 없음)이면 기존 동작인 상위 폴더명을 prefix 로 fallback.
- 첫 `-` 기준 분리. `oa-platform/oa-backend` 같은 중첩에서도 폴더명 자체가 `oa-backend` 이므로 `oa` 가 추출되어 다른 `oa-*` 와 묶인다.
- 표시·필터·**정렬** 모두 동일 prefix 기준으로 동작 → 동일 prefix 항목은 인접 배치.

### 4. 설정 2개 추가 (`~/.goto_config` 영속)

- `prefixColorEnabled` (기본 `true`) — 배경색 ON/OFF
- `prefixPatternEnabled` (기본 `true`) — 패턴 prefix 매칭 ON/OFF
- CLI Settings 화면에서 Enter/Space 로 토글. `prefix 색상`, `prefix 패턴 매칭` 행.
- 메뉴바 앱은 영향 없음. `displayItem(for:)` 본체는 그대로 유지하고 CLI 전용 `cliDisplayItem(for:sharedPrefixes:patternEnabled:)` 신규 함수를 사용.

### 5. 프로젝트 관리 "정리" 메뉴

- 프로젝트 관리 화면(`runProjectManagement`) "뒤로 가기" 바로 아래에 `정리 (N)` 메뉴 추가.
- N = 등록된 프로젝트 중 실제 디렉토리가 존재하지 않는(`FileManager.fileExists + isDirectory` 검사) 항목 개수.
- Enter/Space 누르면 missing path 전체를 store 에서 제거하고 pinned 상태도 함께 해제.
- 매 draw 마다 N 재계산 → 실시간 반영.
- 헬퍼: `missingProjectPaths([String]) -> [String]`

## 구현 노트

- `Shared/GotoCLISettings.swift`
  - `GotoProjectList.namePatternPrefix(for:)`, `patternPrefixSet(in:)`, `cliDisplayItem(...)` 추가
  - `orderedProjects` / `sortedProjects` 에 `parentNameProvider` / `projectNameProvider` 클로저 오버로드 추가. 기존 호출(메뉴바) 무영향
  - `GotoCLIConfig` 에 `prefixColorEnabled`, `prefixPatternEnabled` 코딩키·디코더 추가
- `GotoCLI/main.swift`
  - `Key.filter`, `FilterEvent`, `readFilterEvent()` 추가
  - `hashSeed`(FNV-1a), `prefixPalette`(8색), `assignPrefixColors`, `contrastFg`, `parentBadge(_:width:color:)`
  - `mainRows`/`projectManagementRows`/`drawMainList`/`drawProjectManagement` 가 `displayItem` 클로저와 `colored` 플래그 수신. draw 함수 내부에서 `assignPrefixColors` 호출해 colorMap 생성.
  - `SettingsRow.prefixColor`, `.prefixPattern` 케이스 추가
  - `ProjectManagementRow.cleanup` 추가, `missingProjectPaths` 헬퍼 추가
