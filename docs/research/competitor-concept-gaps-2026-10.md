# Research: own-calendar — 다른 캘린더에는 있는데 여기 없는 것

Date: 2026-10-02
Question: 다른 주요 캘린더 서비스(Google Calendar, Apple Calendar, TimeTree, Fantastical, Notion Calendar, Cozi, Samsung Calendar)가 가진 UX 개념/컨벤션 중 own-calendar에는 없는 것은 무엇이고, "단순함"(primary value) · "데이터 조작의 자유"(NON-NEGOTIABLE) · "데이터 소유권"(NON-NEGOTIABLE) 원칙에 부합하면서 가족 가치가 높은 것부터 우선순위를 매기면 다음에 무엇을 만들어야 하는가.

## Findings

### 1. 인벤토리 — own-calendar가 오늘 가진 것 (코드 근거)

| 기능 | 구현 위치 | 비고 |
|---|---|---|
| 월/주/일/연 뷰 | `client/lib/screens/{monthly,weekly,daily,yearly}_view_screen.dart` | 4가지 뷰 모두 존재. Agenda/리스트 뷰는 없음 |
| 오늘로 이동 | `weekly_view_screen.dart:151`, `daily_view_screen.dart:104` "오늘" 버튼, `monthly_view_screen.dart:318-325` 월 라벨 탭 | 연 뷰에는 미확인(코드상 버튼 없음) |
| 카테고리 필터 | `monthly_view_screen.dart:284-291` `showCategoryFilterDialog` | 월 뷰 AppBar 아이콘 |
| 가족 일정 표시 토글 | `calendar_provider.dart:22,40,46 showFamilyEvents` | **전체 on/off만**, 구성원별 아님 |
| 키워드 검색 | `screens/search_screen.dart`, `calendar_provider.searchEvents`, `routes/events.ts:28 GET /search` | 제목/본문 텍스트 매치만, 필터 없음 |
| 일정 CRUD | `screens/event_form_screen.dart`, `routes/events.ts` (GET/POST/PUT/DELETE) | 복제·다른 캘린더로 복사 엔드포인트 없음 |
| 반복 규칙(RRULE) 엔진 | `widgets/recurrence_picker.dart`, `utils/rrule_utils.dart`, `server/src/services/recurrence.service.ts` (feature 012) | 프리셋 + 커스텀 RRULE, 단일/전체 인스턴스 편집 분기 지원 |
| 알림(리마인더) | `event_form_screen.dart:476-512`, `prisma schema.prisma:94 reminderMinutes Int?`, `server/src/services/alarm.service.ts` | **이벤트당 값 1개**(끄기/정시/5~60분 전 중 택1), 스누즈 없음 |
| 공휴일 구독 | `screens/holiday_settings_screen.dart`, `server/src/services/holiday.service.ts`, `routes/holidays.ts` (feature 013) | 국가별 공휴일 라벨만. 개인 음력 생일/기념일 입력은 없음 |
| 커스텀 카테고리(색상+이모지) | `screens/category_settings_screen.dart`, `models/category.dart`, `prisma Category{color, emoji}` | 카테고리 CRUD는 있으나 **`event_form_screen.dart`에 categoryId 선택 UI가 없음**(값은 들고 있지만 편집 불가 — feature 017 노출 공백) |
| 캘린더별 색상 | `models/calendar.dart`, `prisma Calendar.color` | 색상은 캘린더/카테고리 단위. 이벤트 단위 색상 필드 없음 |
| 외부 캘린더 가져오기 | Google follow(`google-sync.service.ts`), Naver pull(`naver-sync.service.ts`), 범용 ICS import(`ics-import.service.ts`, `routes/import.ts: POST /ics`) | **전부 단방향 import.** export 라우트 전무 |
| 가족 그룹 + 초대 코드 | `family.service.ts`, `routes/family.ts`, `screens/family_screen.dart` | |
| 그룹/팔로우 | `group.service.ts`, `follow.service.ts`, `routes/groups.ts`,`follows.ts` | |
| 이벤트 초대/RSVP | `invite.service.ts`, `routes/invites.ts`(`/accept`,`/decline`), `models/event_invite.dart` | PENDING/ACCEPTED/DECLINED 상태 머신 — TimeTree식 댓글/채팅은 없음 |
| Task 관리 | `task.service.ts`, `screens/task_form_screen.dart`, `models/task.dart` | Event와 N:1. **서브태스크/체크리스트 배열 없음**(flat) |
| Daily Routine | `routine.service.ts`, `screens/routine_screen.dart` | |
| 다크모드 + 컬러 테마 | `providers/theme_provider.dart`, `screens/theme_settings_screen.dart` | 라이트/시스템/다크 + 4개 프리셋 |
| 하단 네비 커스터마이징 | `screens/tab_settings_screen.dart`, `widgets/navigation_shell.dart`(feature 015) | |
| iOS 홈 화면 위젯 | `client/ios/OwnCalendarWidget`, 디자인은 docs/features/005 | 인터랙티브(날짜 선택/페이지네비/가족·카테고리 토글). 잠금화면 위젯은 미확인 |
| 푸시 알림(FCM) | `fcm_service.dart`, `routes/device-tokens.ts`, `fcm.service.ts` | |
| 메타데이터(장소/메모/참여자) | `event_form_screen.dart` `_showMetadata` 섹션 | 장소는 **일반 텍스트 필드**(지도/지오코딩/이동시간 없음), 참여자는 이름/이메일 텍스트 칩 |
| 비공개 일정 | `models/event.dart isPrivate`, `event_form_screen.dart` | |
| 네이티브 패키징 | feature 019 | iOS/macOS + CI/CD |

**확인된 부재(그렙으로 전수 확인, 0건)**
- 드래그 이동/리사이즈: `client/lib/screens`에 `Draggable`/`DragTarget`/`onPanUpdate` 0건. `GestureDetector`는 전부 `onTap`(월 라벨, 날짜 셀 등)만 사용
- 되돌리기(Undo): `undo`/`SnackBarAction` 0건
- 스와이프 제스처: `Dismissible` 0건(설정화면 리오더 드래그만 존재 — `category_settings_screen.dart`, `tab_settings_screen.dart`)
- 키보드 단축키: `Shortcuts`/`LogicalKeySet`/`HardwareKeyboard` 0건 — macOS/Web 빌드 타겟인데도 없음
- 자연어 Quick Add: `nlp`/`quickAdd`/`natural` 0건
- 이벤트 복제: `events.ts`는 GET/POST/PUT/DELETE뿐, `/duplicate`·`/copy` 없음
- ICS Export: `routes/import.ts`에 `POST /ics`만 있고 export 라우트 전무
- 다중 알림: `reminderMinutes Int?` 단일 nullable int (DB 스키마 레벨에서부터 1개)
- 스누즈: `alarm.service.ts`에 `snooze` 0건
- 체크리스트/서브태스크: `task.dart`에 하위 항목 배열 없음, `checklist` 매치는 Task 아이콘(`Icons.checklist`) 오탐
- 첨부파일: `attachment` 0건
- 장소 지도/지오코딩/이동시간: `MapView`/`google_maps`/`geocod` 0건
- 음력 날짜 입력/표시: `lunar`/`음력` 0건(공휴일 데이터는 음력 기반 공휴일을 양력으로 변환해 받아오지만, 사용자가 자기 일정을 음력으로 입력하는 기능은 없음)
- 날씨: `weather`/`날씨` 0건
- 검색 필터(사람/카테고리/날짜범위): `search_screen.dart` 97줄 전체가 텍스트 입력 + 검색 버튼뿐
- 구성원별 색상 + 구성원 단위 필터: `showFamilyEvents`는 불린 1개(전체 on/off)
- 주 시작 요일 설정: `weekly_view_screen.dart:43` `now.subtract(Duration(days: now.weekday % 7))`로 **일요일 하드코딩**, 설정 UI 없음
- 시간대(timezone) 설정: `timezone`/`시간대` 0건
- 접근성/큰 글씨 설정: 전무

### 2. 경쟁 서비스 비교표 (주요 후보 개념)

| 개념 | 경쟁 서비스가 하는 것 (출처) | own-calendar 상태 | Gap? |
|---|---|---|---|
| 자연어 Quick Add | Fantastical은 "Thursday at 5pm", "with John" 같은 문장을 날짜·장소·참석자·반복으로 파싱 [14]. Google Calendar는 과거 Quick Add를 웹 UI에서 제거했고 현재는 모바일 입력창의 제안 수준만 지원(2차 출처로만 확인, 공식 문서 미확인) | 없음. 폼 입력만 | Y |
| 드래그로 이동/리사이즈 | Apple Calendar(Mac): "drag the event to another day or time", "drag the top or bottom edge... to change its start or end time" [7] | 없음(GestureDetector는 onTap뿐) | Y |
| 다중 뷰(월/주/일/Agenda) | Google Calendar: Day/Week/Month/Year/Schedule/4일, Schedule(Agenda) 뷰는 스크린리더 권장 리스트 뷰, 단축키 `a`/`5` [1] | 월/주/일/연 O, Agenda/리스트 뷰 X | Y(부분) |
| 오늘 점프 & 미니먼스 | Google Calendar Schedule/Month 전환 자체가 공식 문서화[1]; 미니먼스는 Fantastical/Apple 보편 패턴(2차 확인) | 월 라벨 탭·"오늘" 버튼으로 존재 | N(이미 있음) |
| 주 시작 요일 설정 | 캘린더 앱 보편 설정(Google/Apple 설정 메뉴, 1차 소스로 개별 확인은 생략) | 없음, 일요일 고정 | Y |
| 이벤트 색상: 캘린더 단위 vs 이벤트 단위 | Google Calendar는 캘린더 기본 색 + 이벤트별 색 오버라이드 지원(보편적 기능, 1차 소스 상세 미확인 — 미확인) | 캘린더/카테고리 단위만, 이벤트 단위 없음 | Y(미확인 등급) |
| 복제 | 보편 기능(Google/Apple "Duplicate event", 1차 소스 상세 페이지 미확인) | 없음, 엔드포인트도 없음 | Y |
| 다른 캘린더로 복사/이동 | 보편 기능(미확인) | 없음 | Y |
| 삭제 후 되돌리기(Undo/Trash) | Google Workspace 공식 블로그: Calendar에 Trash 도입 — "quickly reverse any event mishaps" [5], 2008년 undo 기능 공지 [6] | 없음 | Y |
| 스와이프 삭제 | Apple 공식 삭제 가이드는 스와이프를 언급하지 않고 "tap the event, tap Delete Event, tap Delete Event again"만 기술 [10] | 없음(탭+확인 다이얼로그 1회) | N/미확인(경쟁사도 공식 문서상 스와이프 보장 안 함) |
| 다중/반복 알림 | Google Calendar: 이벤트당 알림 1개 이상 추가 가능, 캘린더 기본값을 이벤트별로 오버라이드 [2][3]. Apple Mac: iCloud 캘린더는 "Add" 버튼으로 알림 추가, Exchange는 1개 제한 [9] | DB·UI 모두 **단일 값**(`reminderMinutes Int?`) | Y |
| 스누즈 | 보편 기능(미확인, 1차 소스 상세 미확인) | 없음 | Y(미확인 등급) |
| 가족/구성원별 색상 | Cozi 공식 FAQ: 최대 12명, "each family member... has a color dot", 설정에서 색상 변경 가능 [16] | 없음(카테고리 색만) | Y |
| 구성원 단위 필터 | Cozi는 이벤트에 참여자 전원/일부를 배정해 색점으로 구분 [16] | `showFamilyEvents` 전체 on/off뿐 | Y |
| 이벤트 댓글/채팅 | TimeTree: 이벤트 상세에서 댓글+이미지 첨부(최대 10장) [12], 2022년 Calendar Chat 출시 [13] | 없음(초대 수락/거절만) | Y |
| 체크리스트/서브태스크 | TimeTree Premium은 파일 첨부 지원(무료는 열람만) [12]; 다른 비교군은 1차 소스 미확인 | Task가 flat, 하위 항목 배열 없음 | Y |
| 첨부파일/링크 | TimeTree는 이미지·(프리미엄)파일 첨부 지원 [12] | 없음 | Y |
| 위치+지도+이동시간 | Apple: 위치 추가 시 지도·날씨 정보 자동 추가, "time to leave" 알림(이동시간 기반) [8] | 장소는 순수 텍스트 필드 | Y |
| 날씨 표시 | Apple 위치 추가 시 날씨 정보 동반 표시(위 [8]과 동일 출처) | 없음 | Y |
| 음력 생일/기념일 | 삼성 서비스 공식 안내: 일정 등록 시 "음력,양력을 선택"할 수 있고 반복 설정과 결합해 매년 자동 반복 가능 [17] | 없음 | Y |
| D-day 카운터 | 한국 캘린더/다이어리 앱의 보편 관행(공식 1차 소스로 삼성 캘린더에서는 확인 못함 — **미확인**) | 없음 | Y(가치는 높으나 경쟁사 공식 근거는 미확인) |
| ICS Export | Google Calendar 공식: 전체 캘린더는 zip, 개별 캘린더는 .ics로 "Export" 가능 [4] | **없음**. import만 존재 | Y — PROJECT.md의 "데이터 소유권(NON-NEGOTIABLE)" 원칙과 정면 충돌 |
| 키보드 단축키(웹/맥) | Notion Calendar: `?`로 전체 단축키 열람, `T`=오늘, `J`/`K`=다음/이전, `D`/`W`/`M`=뷰 전환, `C`=새 이벤트, `Cmd+K`=커맨드 팔레트 [15] | 없음(macOS/Web 빌드 대상인데도) | Y |
| 다크모드 | 보편 기능 | 있음(`theme_provider.dart`) | N |
| 반복 규칙 엔진 | 보편 기능 | RRULE 기반 정교한 구현 있음(012) | N |
| 공휴일 자동 반영 | 보편 기능 | 있음(013) | N |
| 가족 초대/RSVP | 보편 기능 | 있음(`invites.ts`) | N |

### 3. Gap 목록 (상위 선정 항목만 — a~e)

**G1. ICS Export**
a) Google Calendar는 전체/개별 캘린더를 `.ics`/zip으로 내보내는 공식 메뉴 제공 [4]. b) own-calendar는 `routes/import.ts`에 import만 있고 export 라우트 전무. c) 현규(이전 앱으로 이동/백업), 가족(탈퇴 시 자기 일정 보존) 둘 다 수혜, 특히 현규. d) M(서버: 새 라우트+ICS 직렬화 서비스, 클라: 다운로드/공유 트리거). e) **원칙 적합**—오히려 "데이터 소유권(NON-NEGOTIABLE)"이 요구하는 최소 기능이 지금 빠져 있음.

**G2. 드래그 이동/리사이즈**
a) Apple Calendar Mac 공식 가이드가 드래그 이동/엣지 드래그 리사이즈를 명시 [7]. b) own-calendar 뷰는 탭으로만 상세 진입, 시간 변경은 폼의 날짜/시간 피커뿐. c) 둘 다 수혜(마찰 감소는 "데이터 조작의 자유"에 직결, 특히 가족 구성원이 빠르게 일정 옮길 때). d) M(주/일 뷰 그리드 좌표→시간 매핑, 서버는 기존 PUT 재사용). e) 적합—"최소 동작으로 조작"이라는 primary value에 정확히 부합.

**G3. 삭제/변경 되돌리기(Undo)**
a) Google은 2008년부터 Undo, 2015년부터 Trash/복구 기능을 공식 발표 [5][6]. b) own-calendar는 삭제 confirm 다이얼로그만 있고 실행 취소 수단 없음. c) 가족(비개발자일수록 실수 삭제 공포가 큼) 최우선 수혜, 현규도 수혜. d) S(클라이언트에서 삭제를 지연 커밋 + SnackBar 액션으로 구현 가능, 서버 변경 불필요). e) 매우 적합—"데이터 조작의 자유(NON-NEGOTIABLE)"가 요구하는 "마찰 없는 실수 복구"를 가장 싸게 채움.

**G4. 이벤트 복제**
a) 보편적으로 제공되는 기능(1차 소스 상세 페이지는 미확인이나 Google/Apple 양쪽 다 UI에 존재하는 것으로 업계에서 널리 알려짐). b) own-calendar `events.ts`에 복제 엔드포인트 없음. c) 둘 다 수혜(반복 유사 일정—가족 행사 변형—등록 마찰 감소). d) S(클라이언트에서 기존 이벤트 데이터를 새 폼에 프리필 후 `createEvent` 재사용, 서버 변경 불필요). e) 적합—단순함.

**G5. 가족 구성원별 색상 + 구성원 필터**
a) Cozi 공식 FAQ: 최대 12명까지 각자 색상 점 배정, 이벤트가 담당자 색으로 표시 [16]. b) own-calendar는 `showFamilyEvents` 전체 on/off뿐, 이벤트 카드 색은 카테고리색. c) 가족 전원 수혜("이게 누구 일정이지"는 own-calendar의 Problem 선언문에 나온 핵심 pain point). d) M(서버: User/Membership에 color 필드 추가, 클라: 설정 UI+필터+카드 렌더). e) 적합—가족 공유가 핵심 가치축.

**G6. 검색 필터(사람/카테고리/날짜범위)**
a) Google/Apple/TimeTree 모두 리스트/검색 화면에서 날짜·캘린더 단위 필터를 제공(보편 패턴, 개별 1차 소스 미확인). b) `search_screen.dart`는 키워드 텍스트 하나뿐. c) 현규(과거 일정 회고가 PROJECT.md의 핵심 Output) 우선 수혜. d) S~M(서버 `GET /search`에 쿼리 파라미터 추가, 클라 필터 칩 UI). e) 적합—"과거 일정 검색 및 회고"는 PROJECT.md Output에 이미 명시된 약속.

**G7. 다중 알림(이벤트당 2개 이상)**
a) Google Calendar는 이벤트당 알림 1개 이상 추가가 공식 지원되고, 캘린더 기본값을 이벤트 단위로 오버라이드 가능 [2][3]. Apple Mac은 iCloud 캘린더에 한해 다중 알림 지원 [9]. b) own-calendar는 `reminderMinutes Int?` 단일 값(DB 스키마 레벨 제약). c) 둘 다 수혜하나 가족(중요 일정 전날+당일 이중 알림) 쪽 체감이 큼. d) M(Prisma 마이그레이션으로 `Int?`→배열/JSON, `alarm.service.ts` 다중 스케줄링, 폼 UI를 다중 선택으로). e) 대체로 적합하나 폼 복잡도가 늘어나는 트레이드오프—"끄기/정시/N분 전" 단일 선택 UI보다 UI 설계에 신경 써야 단순함을 안 깨뜨림.

**G8. 음력 생일/기념일**
a) 삼성 공식 고객지원 문서: 일정 등록 시 "음력,양력을 선택"하며 반복 설정과 결합해 매년 자동 반복되는 음력 기념일을 만들 수 있음 [17]. b) own-calendar는 양력 고정, 음력 입력/변환 기능 없음. c) 가족 압도적 수혜(한국 가족 맥락의 조부모/부모 생신). d) M(양음력 변환 라이브러리 도입, `recurrence.service.ts`에 음력 반복 규칙 추가, 폼에 토글). e) 적합하나 반복 규칙 엔진(012)에 손을 대야 해서 리스크는 중간.

**G9. D-day 카운터**
a) 한국 캘린더/다이어리 앱 전반의 관행이나 비교군 7개 중 공식 1차 소스로 확인된 곳은 없음(**미확인**). b) own-calendar에 없음. c) 가족 수혜(아이 생일/여행 기대감 등 정서적 가치, PROJECT.md가 말하는 "가족이 쓰기 쉬운" 재미 요소). d) S(클라이언트 전용 — 이벤트 날짜와 오늘 날짜 차이 계산해 배지 렌더). e) 매우 적합, 서버 변경 없이 단순함을 해치지 않음.

**G10. 키보드 단축키(Web/macOS)**
a) Notion Calendar 공식: `?`로 전체 단축키 패널, `T`/`J`/`K`/`D`/`W`/`M`/`C`/`Cmd+K` 등 [15]. b) own-calendar는 Flutter `Shortcuts`/`LogicalKeySet` 사용 0건 — macOS/Web 타겟 앱인데도 전무. c) 현규 전용 수혜(가족은 거의 모바일만 사용 — PROJECT.md 페르소나 표에 명시). d) S(뷰 전환/오늘 이동 등 소수 단축키만이면 1일 내 가능). e) 적합하나 가족 가치가 0이라 랭킹에서 밀림.

### 4. 랭킹 — Top 10 (가족가치 × 원칙적합도 / 사이즈)

가족가치(1~3)·원칙적합도(0~3, 원칙 위반 방향이면 1 이하)·사이즈(S=1, M=2, L=3)로 거칠게 점수화. ICS Export는 점수상 중위권이지만 **NON-NEGOTIABLE 원칙 위반 상태를 지금 방치하고 있다는 사실** 때문에 수동으로 상위에 올렸다(아래 표의 `*` 표시, §5에서 설명).

| 순위 | 항목 | 가족가치 | 원칙적합도 | 사이즈 | 점수 |
|---|---|---|---|---|---|
| 1 | G3 삭제 되돌리기(Undo) | 3 | 3 | S(1) | 9.0 |
| 2 | G4 이벤트 복제 | 2 | 3 | S(1) | 6.0 |
| 2 | G9 D-day 카운터 | 2 | 3 | S(1) | 6.0 |
| 4 | G2 드래그 이동/리사이즈 | 3 | 3 | M(2) | 4.5 |
| 4 | G5 구성원별 색상+필터 | 3 | 3 | M(2) | 4.5 |
| 6 | G6 검색 필터 | 2 | 3 | S~M(1.5) | 4.0 |
| 7* | G1 ICS Export | 2 | 3(NON-NEGOTIABLE) | M(2) | 3.0 (우선순위 수동 상향) |
| 7 | G8 음력 생일/기념일 | 3 | 2 | M(2) | 3.0 |
| 7 | G10 키보드 단축키 | 1(현규만) | 2 | S(1) | 3.0 |
| 10 | G7 다중 알림 | 2 | 2 | M(2) | 2.5 |

순위 밖(사이즈 L이거나 원칙 리스크로 배제): 자연어 Quick Add(한국어 NLP 난이도 L, 잘못 파싱되면 "최소 마찰" 원칙을 거꾸로 깨뜨릴 위험), 지도/이동시간/날씨(외부 지도 API 종속 — 셀프호스팅·단순함과 충돌), 체크리스트/서브태스크(M이지만 Task 모델을 건드려야 해서 리스크 중간, 이번 라운드에서는 보류), 이벤트 댓글/채팅(TimeTree 수준 채팅 스레드는 own-calendar의 "가족이 직접 캘린더만 보면 됨"이라는 단순함 지향과 거리가 있어 보류).

### 5. 다음에 만들 Top 5 — 독립적으로 머지 가능한 이슈 초안

**이슈 1 — 일정 삭제·수정에 실행 취소(Undo) 추가**
What: 일정을 삭제하거나 반복 인스턴스를 수정할 때, 서버에 즉시 확정 커밋하지 않고 짧은 유예(예: 5초) 동안 "실행 취소" 스낵바를 띄운 뒤에만 실제 DELETE/PUT을 호출한다. 유예 중 화면에서는 낙관적으로(optimistic) 즉시 사라지되, "실행 취소"를 누르면 로컬 상태를 원복하고 서버 호출을 취소한다. Why: PROJECT.md의 "데이터 조작의 자유(NON-NEGOTIABLE)"는 "CRUD에 불필요한 단계나 확인 과정을 넣지 않는다"고 못박는데, 지금은 되돌릴 방법이 없어 사실상 삭제 전 확인 다이얼로그(마찰)에 의존하고 있다. Undo가 생기면 오히려 확인 다이얼로그를 없애거나 가볍게 만들 수 있어 마찰이 줄어든다. 가족 페르소나(비개발자)의 실수 공포를 가장 싸게(서버 변경 없이) 없앤다. Impact paths: `client/lib/providers/calendar_provider.dart`(지연 삭제/복원 로직 추가), `client/lib/screens/event_form_screen.dart`(`_delete()` 흐름을 지연 커밋+SnackBarAction으로 교체).

**이슈 2 — 일정 복제(Duplicate) 버튼**
What: `event_form_screen.dart`의 수정 모드 AppBar에 "복제" 아이콘을 추가한다. 누르면 현재 폼의 모든 필드값(제목/시간/카테고리/반복/알림/메타데이터)을 가진 새 일정 생성 폼으로 전환하고(제목 뒤에 "(사본)" 등은 붙이지 않고 그대로), 저장 시 기존 `createEvent` 플로우를 그대로 탄다. Why: 가족 행사의 변형("이번엔 시간만 다르게 한 번 더")을 등록할 때 처음부터 모든 필드를 다시 입력하는 마찰이 크다. 서버 엔드포인트 추가 없이 클라이언트 로직만으로 구현 가능해 비용 대비 가치가 가장 높은 항목 중 하나다. Impact paths: `client/lib/screens/event_form_screen.dart`(복제 액션 추가, 기존 `_save()`/필드 바인딩 재사용).

**이슈 3 — D-day 카운터 배지**
What: `EventCard`와 홈 화면에 다가오는 일정까지 남은 일수를 "D-3", "D-DAY", "D+1" 형태로 표시하는 배지를 추가한다. 순수 클라이언트 계산(`event.startTime`과 `DateTime.now()`의 날짜 차이)이며 서버/DB 변경이 없다. Why: 가족 구성원(특히 아이들, 비개발자)에게 "앞으로 며칠 남았는지"는 날짜/시간 텍스트보다 직관적이다. PROJECT.md가 말하는 "가족이 쓰기 쉬운" 가치에 부합하고, 한국 캘린더/다이어리 앱의 보편 관행이다(경쟁사 공식 문서로는 미확인이지만 구현 리스크와 비용이 거의 0에 가까워 포함). Impact paths: `client/lib/widgets/event_card.dart`(배지 렌더링 추가), `client/lib/screens/home_screen.dart`(오늘 다가오는 일정 목록에 배지 노출).

**이슈 4 — 가족 구성원별 색상 지정 + 캘린더에서 구성원 필터**
What: 가족 구성원마다 색상을 지정할 수 있게 하고(가족 설정 화면), 월/주/일 뷰에서 "전체 on/off"뿐인 현재 가족 토글을 "구성원별 체크박스 필터"로 확장한다. 이벤트 카드는 작성자/참여자 구성원 색을 함께 표시한다. Why: own-calendar의 Problem 선언문 자체가 "누군가의 일정을 알려면 직접 물어봐야 한다"인데, 지금은 가족 일정을 보되 "누구 건지"를 색으로 구분할 수 없다. Cozi가 핵심 기능으로 제공하는 패턴이며[16], 가족 페르소나에게 가장 직접적인 가치를 준다. Impact paths: `server/prisma/schema.prisma`(User 또는 FamilyMembership에 `color` 필드 추가 + 마이그레이션), `server/src/services/family.service.ts` / `server/src/routes/family.ts`(구성원 색상 CRUD 노출), `client/lib/screens/family_screen.dart`(색상 선택 UI), `client/lib/providers/calendar_provider.dart`(`showFamilyEvents` 불린을 구성원 ID 집합 필터로 확장), `client/lib/widgets/event_card.dart`(구성원 색 렌더).

**이슈 5 — ICS 캘린더 내보내기(Export)**
What: 설정 화면에 "캘린더 내보내기"를 추가해 내 캘린더(또는 선택한 캘린더)의 모든 일정을 RFC5545 `.ics` 파일로 생성해 다운로드(웹/맥)하거나 공유 시트(모바일)로 내보낸다. 서버에 `ics-import.service.ts`와 대칭을 이루는 `ics-export.service.ts`와 새 라우트를 추가한다. Why: PROJECT.md의 "데이터 소유권(NON-NEGOTIABLE)"은 "언제든 데이터를 내보내거나 이동할 수 있어야 한다"고 명시하는데, 현재 own-calendar는 **import만 있고 export가 전혀 없어 이 NON-NEGOTIABLE 원칙을 어기고 있다.** Google Calendar조차 전체/개별 캘린더 export를 공식 지원하는 기본기다[4]. 가족가치는 낮지만(가족은 거의 안 씀) 현규(1인 개발자, 플랫폼 lock-in 탈피가 프로젝트 존재 이유)에게는 최우선이며, 무엇보다 **제품 선언문과의 모순을 없애는** 작업이라 사이즈 대비 순위보다 먼저 처리해야 한다. Impact paths: `server/src/services/ics-export.service.ts`(신규, `ics-import.service.ts`의 역함수 구조 참고), `server/src/routes/export.ts`(신규) 또는 `server/src/routes/calendars.ts`에 엔드포인트 추가, `client/lib/screens/settings_screen.dart`(내보내기 진입점), `client/lib/services/api_service.dart`(다운로드/공유 호출).

## Sources

1. Google Calendar Help — View your day, week, or month (Desktop): https://support.google.com/calendar/answer/6110849?hl=en&co=GENIE.Platform%3DDesktop
2. Google Calendar Help — Change Google Calendar notifications: https://support.google.com/calendar/answer/37242
3. Google Workspace Developers — Reminders and notifications (Calendar API concepts): https://developers.google.com/workspace/calendar/api/concepts/reminders
4. Google Calendar Help — Export events from your Google Calendar: https://support.google.com/calendar/answer/37111
5. Google Workspace Updates (official blog) — Restore deleted events in Google Calendar web: https://workspaceupdates.googleblog.com/2015/11/restore-deleted-events-in-google.html
6. Google Workspace Updates (official blog) — Google Calendar adds 'undo', event reminder options and more (2008): https://workspaceupdates.googleblog.com/2008/12/google-calendar-adds-event-reminder.html
7. Apple Support — Add, modify, or delete events in Calendar on Mac: https://support.apple.com/guide/calendar/add-modify-or-delete-events-icalwr13-events/mac
8. Apple Support — Add location and travel time to events in Calendar on Mac: https://support.apple.com/guide/calendar/add-locations-and-travel-info-icl43600/mac
9. Apple Support — Set alerts for an event in Calendar on Mac: https://support.apple.com/guide/calendar/icl1012/mac
10. Apple Support — Delete calendars and events on iPhone: https://support.apple.com/en-hk/102444
11. Apple Support — Create and edit events in Calendar on iPhone: https://support.apple.com/guide/iphone/create-and-edit-events-in-calendar-iph3d110f84/ios
12. TimeTree Help Center — How to attach images and comment events after creating an event: https://support.timetreeapp.com/hc/en-us/articles/203005559-How-to-attach-images-and-comment-events-after-creating-an-event
13. TimeTree Newsroom — New TimeTree Calendar Chat (2022-09-21): https://timetreeapp.com/intl/en/newsroom/2022-09-21/calendar-chat
14. Flexibits (Fantastical official help) — Adding events and tasks: https://flexibits.com/fantastical/help/adding-events-and-tasks
15. Notion (official help) — Notion Calendar keyboard shortcuts: https://www.notion.com/help/notion-calendar-keyboard-shortcuts
16. Cozi (official FAQ) — Cozi Family Organizer FAQs: Calendars, Lists, & More: https://www.cozi.com/faq/
17. Samsung 공식 고객지원 — [삼성 스마트폰] 갤럭시, 일정 등록 및 관리 방법이 궁금합니다: https://www.samsungsvc.co.kr/solution/40757

**미확인(1차 소스로 확정하지 못한 주장, 본문에 별도 표기)**: Apple/Samsung Calendar의 스와이프 삭제 제스처 공식 문서화 여부, 이벤트 단위 색상 오버라이드의 1차 소스, 스누즈 기능의 경쟁사별 1차 소스, D-day 카운터의 삼성/타임트리 공식 문서 근거, Google Calendar 모바일 Quick Add 현황.
