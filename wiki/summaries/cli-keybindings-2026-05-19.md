# CLI 키보드 정책 개편 (2026-05-19)

CLI 인터랙티브 리스트의 키 매핑을 단순화했다. 핵심은 **"검색이 디폴트"** — 단일 알파벳 단축키를 제거하고, 사용자가 글자를 입력하면 즉시 필터 모드로 진입한다.

## 변경 사항

### 키 매핑

| 기능 | 이전 | 이후 |
|---|---|---|
| 필터 진입 | `f` / `F` | 임의의 printable 글자 키 (해당 글자가 필터 첫 문자로 주입) |
| 핀 토글 | `p` / `P` | `Ctrl+P` (0x10) |
| 종료 | `q` / `Q` / `ESC` / `Ctrl+C` | `Ctrl+Q` (0x11) / `ESC` / `Ctrl+C` |

### 구현

- `Key` enum: `.filter` 제거, `.printable(UInt8)` 추가 — 필터로 흘려보낼 첫 바이트를 캐리.
- `readKey()`:
  - `0x10` → `.pin`
  - `0x11`, `0x03` → `.quit`
  - `0x20 ≤ byte < 0x7F` 의 나머지 printable → `.printable(byte)`
- 메인 루프에서 `.printable(let b)` 수신 시 `filterQuery = String(UnicodeScalar(b))` 로 필터 모드 즉시 진입.
- `key == .enter` 등 enum 등치 비교를 associated value 호환되도록 `if case .enter = key`로 교체 (settings 화면 `recentLimit` 분기).
- 헤더 안내 문구를 `Ctrl+P` / `Ctrl+Q` / "입력 시 필터" 로 갱신 (메인 리스트, 프로젝트 관리 화면 모두).
- `runSettings` / `runProjectManagement` 의 `.filter` 분기를 `.printable` 로 교체.

## 의도

- 단축키 충돌·암기 부담 제거 — `goto` 의 본질이 빠른 탐색이므로 키를 누르면 곧바로 검색이 가장 직관적.
- `p` / `q` 같은 일상 글자도 필터 쿼리로 자연스럽게 입력 가능. 핀/종료는 명시적인 modifier (`Ctrl+`) 가 있어야만 동작 — 실수 방지.
- macOS 터미널 raw 모드는 `Cmd+키`를 키스트로크로 전달하지 않기 때문에 `Ctrl+` 채택.

## 관련 변경

- `.claude/skills/ship-goto` → `.claude/skills/deploy` 리네이밍 (중간에 `release`를 거쳐 최종 `deploy`로 정착). 슬래시 호출은 `/deploy`, 부분 실행은 `/deploy {cleanup,docs,build,publish}`. SKILL.md 본문/headers 동기화 완료.
- Stage 0에서 `AskUserQuestion`으로 **자동/수동 모드**를 1회 선택받는다. 자동모드는 단계별 확인 없이 끝까지 진행하되 destructive 동작(`rm`, force push, hard reset)은 두 모드 모두 명시 승인 필수.
- `README.md` CLI 사용법 한 줄과 핀 설명을 새 정책에 맞춰 갱신.

## 회귀 점검

- 화살표(↑↓) 이동, Enter 선택 — 변경 없음.
- 필터 모드에서 backspace / ESC / 입력 추가 — 변경 없음.
- 핀 토글, 종료 단축키 — modifier 필수로 강화됨. 기존 `p`/`q` 사용 습관은 깨지지만 안내 문구로 즉시 학습 가능.
