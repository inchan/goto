---
tags: [cli, settings]
date: 2026-05-13
---

# CLI Prefix Color + `f` Filter + Pattern Prefix

CLI 인터랙티브 모드에 prefix 표현·검색 기능을 강화했다.

## 변경 요약

### 1. Prefix 배경색 (true color)

- 상위 폴더 또는 패턴 prefix 문자열을 **FNV-1a 64-bit 해시 → HSL 색공간** 으로 매핑해 배경 배지로 렌더링한다.
- hue 0~359 외에 채도 3 단계(0.50 / 0.62 / 0.74) · 명도 4 단계(0.26 / 0.32 / 0.38 / 0.44) 를 해시 상위 비트로 변주해 2160 톤 변형 공간을 확보. 인접 hue 충돌을 시각적으로 분리한다.
- 동일 prefix 는 항상 동일 색, 빈 prefix(최상위 경로) 는 색상 없음.
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

## 구현 노트

- `Shared/GotoCLISettings.swift`
  - `GotoProjectList.namePatternPrefix(for:)`, `patternPrefixSet(in:)`, `cliDisplayItem(...)` 추가
  - `orderedProjects` / `sortedProjects` 에 `parentNameProvider` / `projectNameProvider` 클로저 오버로드 추가. 기존 호출(메뉴바) 무영향
  - `GotoCLIConfig` 에 `prefixColorEnabled`, `prefixPatternEnabled` 코딩키·디코더 추가
- `GotoCLI/main.swift`
  - `Key.filter`, `FilterEvent`, `readFilterEvent()` 추가
  - `hashSeed`(FNV-1a), `hslToRgb`, `parentBgRgb`, `parentBadge(_:width:colored:)`
  - `mainRows`/`projectManagementRows`/`drawMainList`/`drawProjectManagement` 가 `displayItem` 클로저와 `colored` 플래그 수신
  - `SettingsRow.prefixColor`, `.prefixPattern` 케이스 추가
