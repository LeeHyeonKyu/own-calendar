# iOS Widget Extension — Xcode 설정 가이드

Widget Extension은 Xcode에서 수동으로 추가해야 합니다. 소스 파일은 이미 준비되어 있습니다.

## 1. Xcode에서 프로젝트 열기

```bash
open ios/Runner.xcworkspace
```

## 2. Widget Extension Target 추가

1. Xcode 메뉴: **File → New → Target...**
2. **Widget Extension** 선택 → Next
3. Product Name: `OwnCalendarWidget`
4. **Include Configuration App Intent** 체크 해제
5. **Finish** → "Activate" 선택

## 3. 자동 생성된 파일 교체

Xcode가 자동 생성한 `OwnCalendarWidget/` 안의 Swift 파일을 삭제하고,
이 디렉토리의 `OwnCalendarWidget.swift`를 Xcode 프로젝트에 추가합니다:

1. Xcode에서 자동 생성된 `.swift` 파일 삭제 (Move to Trash)
2. Finder에서 `ios/OwnCalendarWidget/OwnCalendarWidget.swift`를 Xcode의 OwnCalendarWidget 그룹으로 드래그
3. **Copy items if needed** 체크, Target: `OwnCalendarWidgetExtension` 선택

## 4. App Groups 설정

### Runner (메인 앱) Target:
1. Runner target 선택 → **Signing & Capabilities** 탭
2. **+ Capability** → **App Groups** 추가
3. `group.com.owncalendar.ownCalendar` 추가

### OwnCalendarWidgetExtension Target:
1. Widget extension target 선택 → **Signing & Capabilities** 탭
2. **+ Capability** → **App Groups** 추가
3. 같은 `group.com.owncalendar.ownCalendar` 추가

## 5. Bundle ID 확인

- Runner: `com.owncalendar.ownCalendar`
- Widget: `com.owncalendar.ownCalendar.OwnCalendarWidget`

## 6. 빌드 & 실행

```bash
flutter run --device-id <iphone-id>
```

위젯 추가: 홈 화면 길게 누르기 → + → "Own Calendar" 검색 → 위젯 추가

## 7. 디버깅

위젯이 데이터를 못 읽을 때:
- App Group ID가 양쪽 target에서 일치하는지 확인
- 앱을 한 번 실행하여 이벤트를 로드해야 위젯 데이터가 저장됨
- 위젯은 30분마다 자동 갱신 (타임라인 설정)
