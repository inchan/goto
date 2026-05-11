---
title: Icon glyph fix — menu bar & Finder Sync white square
date: 2026-05-11
tags: [menubar, refactor]
---

# Icon glyph fix — menu bar & Finder Sync white square

## 증상

`Goto.app` 설치 후 메뉴바와 Finder Sync 도구막대 버튼이 portal/jump 아이콘 대신 단색의 흰 네모로 보였다.

## 원인

`scripts/generate-icons.swift`의 mono 분기에서 `ctx.clear(rect)`를 호출했다. 비트맵 컨텍스트에서는 알파를 비우는 동작이지만, `CGPDFContext`에는 알파 클리어 연산이 없어 현재 그리기 색(검정)으로 페이지 전체를 fill한다. PDF content stream 디코드 결과 다음 명령이 박혀 있었다.

```
0 0 64 64 re f    # 페이지 전체를 검정으로 fill
```

이후 portal과 화살표를 같은 검정 stroke로 덧그려도 가려져 보이지 않고, 결과적으로 64×64 검정 사각형만 남았다. `NSImage.isTemplate = true` 상태에서 macOS는 검정 픽셀을 메뉴바 전경색으로 매핑하므로 다크 모드 메뉴바에서는 흰색 사각형으로 렌더링된다.

## 수정

- `scripts/generate-icons.swift`
  - mono 분기에서 `ctx.clear(rect)` 호출 제거. PDF context는 빈 상태로 시작하므로 별도 초기화가 필요 없다.
  - 스크립트 끝에 `iconutil -c icns tmp/AppIcon.iconset -o Resources/applet.icns` 호출 추가. PNG와 `.icns`가 항상 함께 갱신되도록 만든다.
- `Resources/goto-glyph.pdf`
  - 재생성. content stream에서 전체 fill 명령이 사라지고 portal 2개 + 화살표 stroke만 남는 것을 확인했다.

## 검증

- PDF content stream 재디코드 → `0 0 64 64 re f` 사라짐.
- PDF 시각 렌더 → portal 2개 + 화살표.
- `./install.sh` 빌드/설치 후 `/Applications/Goto.app/Contents/Resources/goto-glyph.pdf`와 `/Applications/Goto.app/Contents/PlugIns/GotoFinderSync.appex/Contents/Resources/goto-glyph.pdf` MD5가 새 글리프와 일치.
- 기존 Goto 프로세스 종료, `lsregister -f`, `pluginkit -e ignore`→`-e use` 토글, Finder 재시작 후 메뉴바·Finder Sync 툴바 아이콘 정상.

## 회귀 방지

다음 사람이 같은 함정에 빠지지 않도록 mono 분기에 주석을 남겼다. PDF로 렌더할 때는 배경을 따로 채우지 않는 것이 정답이다.
