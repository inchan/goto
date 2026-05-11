---
title: Settings window front-most fix
date: 2026-05-11
tags: [menubar, settings]
---

# Settings window front-most fix

## 증상

메뉴바 아이콘 → "Settings…" 클릭 시 설정 윈도우가 보이지 않거나 다른 앱 뒤에 가려진 채로 열렸다. 화면 위로 올라오지 않는 것처럼 보였다.

## 원인

1. **macOS 14+ 활성화 정책 변화** — `NSApp.activate(ignoringOtherApps: true)`만으로는 메뉴바에서 트리거된 백그라운드 앱이 항상 전면화되지 않는다. Sonoma 이후 권장 API는 인자 없는 `NSApp.activate()`이고, 그래도 안 되는 경우 윈도우 단위 `orderFrontRegardless()`가 필요하다.
2. **윈도우 캐시 미정리** — `AppDelegate.showSetupWindow()`는 한 번 생성한 윈도우 참조를 `self.window`에 보관한다. 사용자가 닫아도 캐시는 그대로 남고, `NSWindowDelegate` 미설정 상태라 close 후 상태를 추적할 수 없었다. 같은 인스턴스에 `makeKeyAndOrderFront`만 호출되어 종종 다른 앱 아래에 그려졌다.

## 수정

`GotoApp/AppDelegate.swift`

1. `bringToFront(_:)` 헬퍼 추가.
   - `NSApp.setActivationPolicy(.regular)`로 액티베이션 정책 보정.
   - macOS 14+에서는 `NSApp.activate()`, 그 이전 버전은 `NSApp.activate(ignoringOtherApps: true)` 분기.
   - `makeKeyAndOrderFront` 후 `orderFrontRegardless()`로 강제 전면화.
2. `showSetupWindow()`가 캐시 윈도우/신규 윈도우 모두 `bringToFront(_:)`를 거치도록 단순화.
3. `AppDelegate`에 `NSWindowDelegate` extension 추가. `windowWillClose`에서 self.window·terminalStatusLabel을 nil로 되돌려 다음 호출이 새 윈도우를 만들도록 한다.
4. 윈도우 생성 직후 `window.delegate = self`로 델리게이트 연결.

## 검증

- 빌드/설치 후 메뉴바 → Settings… 반복 클릭 시 설정창이 정상적으로 최상위로 올라오는지 확인.
- 설정창을 닫은 뒤 다시 Settings… 클릭 시 새 윈도우가 정상 표시되는지 확인.
