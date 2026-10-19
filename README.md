# own-calendar

## What

가족이 함께 쓰는 셀프호스팅 캘린더 허브. Flutter 클라이언트(iOS · Android · macOS · Web)와
Node.js(TypeScript) + PostgreSQL API 서버로 이루어져 있으며, 구글/네이버 등 외부 캘린더를
가져와 한 곳에서 보고 가족과 공유한다. 데이터는 외부 서비스가 아니라 우리가 운영하는 DB에
남는다. 제품 정의는 [docs/PROJECT.md](docs/PROJECT.md), 기술 결정은
[docs/TECHNICAL.md](docs/TECHNICAL.md)에 있다.

## Layout

| Path | What lives there |
|------|------------------|
| `client/` | Flutter 앱 (`lib/` 화면·프로바이더·서비스, `test/` 위젯/유닛 테스트) |
| `server/` | Node.js + TypeScript API 서버 (`src/` 라우트·서비스, `prisma/` 스키마와 마이그레이션, `tests/` vitest 스위트) |
| `altstore/` | AltStore 소스 매니페스트 (`apps.json`) — iOS 사이드로드 배포용 |
| `scripts/` | 운영 스크립트 — 배포(`deploy.sh`), DB 백업/복구, 클라우드 이전 |
| `docs/` | 프로젝트·기술 문서, 기능 스펙(`features/`), QA 체크리스트, factory 문서 |

## Run

Prerequisite: 서버는 직접 만들어야 하는 `server/.env` 설정 파일을 읽는다 — 채울 변수 이름은 [server/.env.example](server/.env.example)을 복사해서 쓰고, 배경은 [docs/TECHNICAL.md](docs/TECHNICAL.md)를 본다.

DB 접속 문자열은 `server/docker-compose.yml`이 컨테이너에 주입하므로 `server/.env.example`에는 없다 — 도커 없이 `npm run dev`로 띄우려면 같은 값을 직접 `server/.env`에 넣어야 한다.

Server (Node.js + TypeScript, PostgreSQL 필요):

```bash
cd server && npm ci && npm run db:generate && npm run db:migrate && npm run dev
```

`npm run db:generate`는 `server/src`가 import하는 Prisma 클라이언트를 만들고, `npm run db:migrate`는
`server/prisma/migrations/`의 스키마를 빈 DB에 적용한다. 둘 중 하나라도 건너뛰면 서버 프로세스는 뜨지만
첫 요청부터 "테이블이 없다"로 실패한다.

Client (Flutter) — 위에서 띄운 로컬 서버를 보게 하려면 `config/dev.json`을 넘긴다:

```bash
cd client && flutter pub get && flutter run --dart-define-from-file=config/dev.json
```

이 플래그를 빼면 클라이언트는 코드에 박힌 기본값, 즉 **운영 서버**에 붙는다 — 방금 띄운 로컬 서버는 놀고
가입·일정 추가가 실제 가족 데이터에 쓰인다. 운영 서버를 향하게 하려면 `config/prod.json`을 명시해서 쓴다.

배포는 직접 하지 말고 `scripts/deploy.sh` 파이프라인을 쓴다 (`CLAUDE.md` 참고).

## Test

Client:

```bash
cd client && flutter test
```

Server — 아래 명령을 복사하기 전에 이 두 문단을 먼저 읽는다.

스키마: 전용 테스트 DB도 빈 상태로는 스위트를 돌릴 수 없다 — `server/.env`를 그 DB로 맞춘 뒤
`cd server && npm run db:generate && npm run db:migrate`을 한 번 실행해 스키마를 만들고 나서
아래 명령을 돌린다.

주의: `cd server && npm test`는 `server/.env`가 가리키는 database의 모든 행을 **삭제**한다 —
`server/tests/setup.ts`가 전역 `beforeEach`에서 사용자·가족·캘린더·일정·토큰 테이블을 비우고,
실제 캘린더 데이터가 들어 있는 곳을 가리킨 채로 실행하면 되돌릴 수 없다.
실행 중인 PostgreSQL이 필요하며, 반드시 버려도 되는 전용 테스트 DB를 가리키게 한 뒤에 실행한다.

```bash
cd server && npm test
```

## iOS Build & Install (다른 장비에서)

다른 Mac에서 이 repo를 받아 iPhone에 앱 + 위젯을 설치하는 전체 과정.

### 0. 전제 조건

| 항목 | 요구 사양 |
|------|-----------|
| Mac | macOS 15.2+ (Intel) 또는 macOS 14+ (Apple Silicon) |
| Xcode | **16.4** — macOS 15에서는 App Store 최신(26+)이 안 됨. [developer.apple.com/download/all](https://developer.apple.com/download/all)에서 직접 다운로드 |
| Flutter SDK | 3.41+ — [flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install) |
| CocoaPods | `brew install cocoapods` |
| iPhone | iOS 16.0+, USB 케이블 |
| AltServer | [altstore.io](https://altstore.io) — Mac용 다운로드 |

### 1. Repo 클론 및 의존성

```bash
git clone git@github.com:LeeHyeonKyu/own-calendar.git
cd own-calendar/client
flutter pub get
```

### 2. Xcode 설정

```bash
# Xcode 경로 지정 (다운로드 위치에 맞게 수정)
sudo xcode-select -s "/path/to/Xcode.app/Contents/Developer"

# 라이선스 동의
sudo xcodebuild -license accept

# 확인
xcodebuild -version   # 16.4.x 인지 확인
```

### 3. CocoaPods 설치

```bash
cd client/ios
pod install
cd ..
```

> `flutter clean` 후에는 반드시 `pod install`을 다시 실행한다.

### 4. Xcode에서 Widget Extension 추가

Widget Extension은 **Xcode에서 수동 추가**가 필요하다. 소스 파일은 `client/ios/OwnCalendarWidget/`에 준비되어 있음.

```bash
open ios/Runner.xcworkspace
```

1. **File → New → Target → Widget Extension** → Product Name: `OwnCalendarWidget`
2. "Include Configuration App Intent" **체크 해제** → Finish → Activate
3. Xcode가 자동 생성한 Swift 파일 삭제 (Move to Trash)
4. Finder에서 `ios/OwnCalendarWidget/*.swift` 파일들을 Xcode OwnCalendarWidget 그룹으로 드래그
   - "Copy items if needed" 체크, Target: `OwnCalendarWidgetExtension`
5. **Signing & Capabilities** — Runner와 Widget 양쪽 모두:
   - `+ Capability` → `App Groups` → `group.com.owncalendar.ownCalendar` 추가
6. Bundle ID 확인:
   - Runner: `com.owncalendar.ownCalendar`
   - Widget: `com.owncalendar.ownCalendar.OwnCalendarWidget`
7. `project.pbxproj`에서 **"Thin Binary"를 마지막 빌드 페이즈로** 이동
   (안 하면 `Cycle inside Runner` 에러 발생)

상세 가이드: [`client/ios/OwnCalendarWidget/SETUP.md`](client/ios/OwnCalendarWidget/SETUP.md)

### 5. IPA 빌드 + AltStore 배포 (권장: 자동화)

```bash
# 한번에: IPA 빌드 → GitHub Release → AltStore 소스 업데이트
./scripts/deploy.sh --ios

# 서버+웹+iOS 전부 배포
./scripts/deploy.sh --ios
```

이 명령이 자동으로:
- `pubspec.yaml` build number 증가
- `flutter build ios --release`
- IPA 생성 + GitHub Release 업로드
- `altstore/apps.json` 버전 동기화 + 커밋/push

> **중요**: `altstore/apps.json`의 version은 IPA의 CFBundleShortVersionString과 반드시 일치해야 합니다.
> `--ios` 플래그가 이를 자동 처리하므로, **수동으로 apps.json을 수정하지 마세요.**

### 5-B. IPA 수동 빌드 (자동화 불가 시)

```bash
cd client
flutter build ios --release
```

> **반드시 `--release`**. Debug 빌드는 홈 화면에서 직접 실행 불가.

### 6-A. USB로 직접 설치 (개발용)

```bash
flutter install --release
```

iPhone 설정:
- **설정 → 개인정보 보호 및 보안 → 개발자 모드 → 켜기** (재부팅 필요)
- **설정 → 일반 → VPN 및 기기 관리 → 개발자 앱 → 신뢰**

> USB 직접 설치 앱은 **7일 후 만료**. AltStore 사용을 권장.

### 6-B. AltStore로 설치 (권장 — 자동 갱신)

#### IPA 파일 생성

```bash
cd client
mkdir -p build/ios/ipa/Payload
cp -r build/ios/iphoneos/Runner.app build/ios/ipa/Payload/
cd build/ios/ipa
zip -r OwnCalendar.ipa Payload/
```

#### AltServer 설정 (Mac)

1. [altstore.io](https://altstore.io)에서 AltServer 다운로드 → 설치 → 실행
2. 메뉴바 AltServer 아이콘 → Install AltStore → 연결된 iPhone 선택
3. Apple ID 입력 (무료 계정 OK)

#### AltStore에서 IPA 설치

**방법 1 — AltStore 소스 추가 (자동 업데이트)**

AltStore 앱 → Sources → `+` 버튼 → 아래 URL 입력:
```
https://raw.githubusercontent.com/LeeHyeonKyu/own-calendar/main/altstore/apps.json
```
→ Own Calendar 탭 → Install

**방법 2 — IPA 직접 사이드로드**

1. 생성된 `OwnCalendar.ipa`를 iPhone으로 AirDrop
2. iPhone에서 AltStore 앱 열기 → My Apps → `+` → IPA 선택

#### 자동 갱신 조건

- Mac에서 AltServer 실행 중
- iPhone과 **같은 Wi-Fi** 연결
- 7일 내에 자동으로 갱신됨

### 7. 위젯 추가

앱 설치 후 첫 실행 → 로그인 → 일정 로드 완료 후:

1. iPhone 홈 화면 길게 누르기
2. 좌측 상단 `+` 버튼
3. "Own Calendar" 검색
4. 원하는 위젯 크기 선택 → 추가

> 위젯은 앱 실행 후 데이터가 App Group 저장소에 기록되어야 표시됨.
> 위젯 데이터는 30분마다 자동 갱신.

### 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| `Cycle inside Runner` | Thin Binary 빌드 페이즈 순서 | pbxproj에서 Thin Binary를 맨 마지막으로 이동 |
| `The sandbox is not in sync with the Podfile.lock` | pod install 누락 | `cd ios && pod install` |
| `higher minimum iOS deployment version` | iOS target 불일치 | Podfile과 pbxproj 모두 `16.0`으로 통일 |
| 앱 아이콘 탭해도 실행 안 됨 | Debug 빌드 | `flutter build ios --release` 후 재설치 |
| "Untrusted Developer" | 개발자 신뢰 미설정 | 설정 → 일반 → VPN 및 기기 관리 → 신뢰 |
| 위젯에 데이터 안 나옴 | 앱 미실행 / App Group 불일치 | 앱 한 번 실행 후 확인. App Group ID 양쪽 동일한지 확인 |
| 7일 후 앱 만료 | AltServer 미실행 또는 Wi-Fi 다름 | AltServer 실행 + 같은 Wi-Fi 확인 |

### 요약 체크리스트

```
[ ] Xcode 16.4 설치 + xcode-select 경로 지정
[ ] sudo xcodebuild -license accept
[ ] brew install cocoapods
[ ] git clone → cd client → flutter pub get
[ ] cd ios && pod install
[ ] Xcode에서 Widget Extension 추가 (SETUP.md 참조)
[ ] Signing: App Groups 양쪽 설정
[ ] pbxproj: Thin Binary → 마지막 빌드 페이즈
[ ] flutter build ios --release
[ ] AltServer 설치 + AltStore 설치
[ ] IPA 생성 → AltStore에서 사이드로드
[ ] iPhone: 개발자 모드 ON + 개발자 앱 신뢰
[ ] 앱 실행 → 로그인 → 위젯 추가
```

## Docs

- [docs/PROJECT.md](docs/PROJECT.md) — 제품 정의, 원칙, 기능 레지스트리
- [docs/TECHNICAL.md](docs/TECHNICAL.md) — 스택, 아키텍처, 데이터, 제약
- [docs/features/](docs/features/) — 기능별 스펙 (`NNN.md`)
- [docs/factory/CHARTER.md](docs/factory/CHARTER.md) — 자동화 에이전트 운영 헌장
