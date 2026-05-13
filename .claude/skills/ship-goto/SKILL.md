---
name: ship-goto
description: Goto 프로젝트의 출하 파이프라인. 사용자가 "/ship-goto", "출시", "릴리즈 해줘", "정리하고 배포", "ship it" 같은 표현으로 정리→문서→로컬 배포→커밋·PR 전체 흐름을 요청할 때 자동 로드한다. 단계별로 사용자 승인을 받으며 진행하고, 절대 사용자 승인 없이 destructive 동작(파일 삭제, push, PR 생성)을 수행하지 않는다.
---

# /ship-goto — Goto 출하 파이프라인

이 스킬은 Goto 프로젝트(`~/workspace/inchan/goto`)에 한정한 출하 절차를 안내한다.
브랜치 정책상 `develop` 이 작업 브랜치이며 `main` 푸시는 PR을 통해서만 일어난다.
`main` 으로 머지되면 GitHub Actions(`.github/workflows/release.yml`)가 자동으로 패치 버전 릴리즈를 만든다.

## 실행 원칙

- **4단계 순차**: 정리 → 문서 → 빌드/배포 → 커밋·푸시·PR
- **각 단계 시작 전 사용자 확인** (변경 범위 보고 + Y/N)
- **destructive 동작은 사용자 명시 승인 후에만**:
  - 파일 삭제, `git push`, `gh pr create`, `git reset --hard` 등
- 단계 도중 실패하면 다음 단계로 넘어가지 않고 보고 후 사용자 판단을 기다린다
- 브랜치는 항상 `develop` 위에서만 작업한다. `main` 직접 푸시 금지

## 사전 점검 (Stage 0)

다음을 병렬로 수집하고 보고한다:

```bash
git status
git rev-parse --abbrev-ref HEAD
git log --oneline origin/main..HEAD
git log --oneline origin/develop..HEAD 2>/dev/null
gh auth status 2>&1 | head -3
```

- 현재 브랜치가 `develop` 인지 확인. 아니라면 사용자에게 전환 여부 질문
- 작업트리 dirty 여부 보고
- `gh` 인증 상태 확인. 미인증 시 사용자에게 `gh auth login` 안내 후 중단
- **gh 활성 계정 점검** — `inchan` 이 아니면 이전 계정명을 변수에 저장 후 `gh auth switch -u inchan`. Stage 4 종료 시 반드시 이전 계정으로 복원
- `git config user.email` 가 `kangsazang@gmail.com` 인지 확인. 다르면 `git config user.email kangsazang@gmail.com` 로 로컬 설정

## Stage 1 — 정리

### 스캔 항목

병렬로 수행하고 결과를 군대식 보고서로 요약한다.

```bash
# Swift unused declarations / TODO / FIXME / 죽은 import
grep -rn "TODO\|FIXME\|XXX\|HACK" Shared GotoCLI GotoApp GotoFinderSync GotoLauncher 2>/dev/null
grep -rn "^import " Shared GotoCLI GotoApp 2>/dev/null

# 빌드 산출물·캐시·임시파일
ls -la build/ DerivedData/ .build/ 2>/dev/null
find . -name '*.bak.*' -not -path './build/*' -not -path './.git/*' 2>/dev/null
find . -name '.DS_Store' 2>/dev/null

# wiki/scripts 중 더 이상 참조되지 않는 파일
ls wiki/summaries/ scripts/ 2>/dev/null
```

### 정리 정책

- **빌드 산출물**(`build/`, `DerivedData/`)은 .gitignore 대상이면 그대로 둔다. 추적 중이면 사용자에게 제거 제안
- **`.bak.*` 백업 파일**: `~/.local/bin/goto.bak.*` 같은 사용자 환경 백업은 건드리지 않는다. 레포 내부의 `*.bak` 만 제거 후보로 보고
- **사용되지 않는 wiki/summaries/문서**: 본문에 링크되지 않은 항목을 후보로 제시. **자동 삭제 금지** — 사용자 승인 필수
- **죽은 코드**:
  - Swift `private` 심볼인데 참조 0개 → 후보 보고
  - 미사용 `import` → grep 으로 의심 후보 보고
  - 빈 함수, 빈 catch, `_ = ` 의미 없는 무시 패턴 보고
- **주석 정리**:
  - 코드와 어긋난 한글 주석, 자기설명적 주석, 옛 버전(`Goto3` 등) 잔재 보고
  - **WHY 가 적힌 주석은 보존**

### 출력 형식

```
## Stage 1 정리 후보

[자동 삭제 가능]
- <path> — <이유>

[사용자 확인 필요]
- <path> — <이유>

[보존]
- <path> — <이유>
```

사용자에게 `AskUserQuestion` 으로 삭제 범위 확정한 뒤 실행한다.

## Stage 2 — 문서 업데이트

### 점검 대상

- `README.md` — 현재 기능 설명이 최신인지
- `AGENTS.md` — 변경된 정책 반영 필요한지
- `wiki/index.md`, `wiki/SCHEMA.md` — 새 기능(prefix 색상, 패턴 매칭, `f` 필터 등) 반영 여부
- `wiki/summaries/` — 최근 PR 단위 요약 추가 여부
- `wiki/log.md` — 변경 로그 누적 정책 따르는지

### 작업 정책

- 발견된 누락만 보고하고, **추가/수정 패치를 보여준 뒤 적용 여부를 사용자에게 묻는다**
- 새 wiki summary 가 필요해 보이면 파일명·제목 후보를 제시
- 문서 톤은 기존 한국어 톤 + 군대식 요약을 유지

## Stage 3 — 빌드 / 로컬 배포

```bash
xcodebuild -project Goto.xcodeproj -scheme GotoCLI -configuration Release \
    -derivedDataPath ./build build 2>&1 | tail -5
```

BUILD SUCCEEDED 확인 후:

```bash
cp ~/.local/bin/goto ~/.local/bin/goto.bak.$(date +%Y%m%d%H%M%S) 2>/dev/null
cp ./build/Build/Products/Release/goto ~/.local/bin/goto
codesign --force --sign - ~/.local/bin/goto
~/.local/bin/goto --help | head -3
```

- 사용자에게 "전체 앱(`./install.sh`)도 함께 설치할지" 옵션 제공
  - 기본은 CLI 단독 배포만 수행
  - `./install.sh` 호출 시 sudo 권한과 `/Applications/Goto.app` 영향 사용자 명시 후 진행
- 빌드 실패 시 즉시 중단하고 에러 보고

## Stage 4 — 커밋 · 푸시 · PR

### 4-1 커밋

```bash
git status
git diff --stat
git log --oneline -5
```

- 변경 단위로 커밋 메시지 초안 작성 (Conventional Commits 권장: `feat`, `fix`, `chore`, `docs`, `refactor`, `ci`)
- **메시지에 Claude Code 서명을 임의로 추가하지 않는다** (사용자 레포 컨벤션 존중 — 최근 커밋 로그 패턴 따른다)
- 사용자 승인 후 커밋:

```bash
git add <specific files>   # NEVER use `git add -A`
git commit -m "$(cat <<'EOF'
<title>

<body>
EOF
)"
```

### 4-2 푸시 — 사용자 명시 승인 후

```bash
git push origin develop
```

### 4-3 PR develop → main

PR 본문은 변경 요약 + 테스트 플랜 형식.

```bash
gh pr create --base main --head develop --title "<title>" --body "$(cat <<'EOF'
## Summary
- <1-3 bullet>

## Changes
- <file/area> — <what>

## Test plan
- [ ] xcodebuild GotoCLI / Goto 빌드 통과 확인
- [ ] `~/.local/bin/goto` 인터랙티브 동작 확인
- [ ] 회귀 점검: 핀/필터/정렬

EOF
)"
```

- PR URL 을 사용자에게 출력
- main 보호 규칙은 `required_approving_review_count=0` 이므로 작성자(`inchan`) 가 직접 `gh pr merge <N> --squash --delete-branch=false` 로 머지 가능. 사용자에게 self-merge 진행 여부를 묻고 승인 시 수행
- 머지 후 CI `release.yml` 이 자동으로 패치 버전 릴리즈 생성

### 4-5 계정 복원 (필수)

Stage 0 에서 `inchan` 외 다른 계정에서 전환했다면 즉시 복원한다.

```bash
gh auth switch -u <previous-account>
```

복원 누락 금지 — 사용자의 다른 작업이 잘못된 계정으로 진행될 수 있다.

### 4-4 후속 안내

```
다음 단계:
1. PR 리뷰 후 main 머지
2. GitHub Actions release.yml 진행 상태 확인
3. `gh release view --web` 로 릴리즈 확인
```

## 금지 사항

- 사용자 미확인 상태 파일 삭제
- `git push --force`, `git reset --hard` (사용자가 명시 요청한 경우 제외)
- `main` 직접 푸시
- `--no-verify`, `--no-gpg-sign` 같은 훅/서명 우회
- `.env`, 키, 자격증명 파일 커밋
- PR 자동 머지

## 부분 실행

사용자가 특정 단계만 원하면 그 단계만 수행한다:
- `/ship-goto cleanup` → Stage 1 만
- `/ship-goto docs` → Stage 2 만
- `/ship-goto build` → Stage 3 만
- `/ship-goto release` → Stage 4 만
