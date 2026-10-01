# Research: 다음 개선 이슈 선정 — 삼각토론 (2026-10-02)

Date: 2026-10-02
Question: `competitor-concept-gaps-2026-10.md`의 Top 5(Undo → 복제 → D-day → 구성원 색상+필터 → ICS export)를 그 순서대로 공장에 넣는 것이 맞는가.
1라운드, 에이전트 3(PRO/NEUTRAL/CON, 읽기 전용, 웹 검색 없음).

## Findings

| 쟁점 | PRO | NEUTRAL | CON | 생존 | 결정 |
|---|---|---|---|---|---|
| 이미 깨진 약속이 있다 | — | — | **카테고리 드롭다운이 legacy enum(`_category`)에 묶여 있고 `_categoryId`는 UI에서 바꿀 수 없다**(`event_form_screen.dart:328-356`, `:45,115,231`). feature 017이 약속한 "Event 생성 시 카테고리 선택(칩)"·"미선택 시 default"가 미구현. 카드 색도 `calendarColor`만 쓰고 `categoryColor`는 죽은 필드(`event_card.dart:24`, `event.dart:25,82`) | ✅ (코드로 확인) | **1번으로 올린다.** 새 개념이 아니라 판 기능의 완성 |
| Undo의 범위 | 비반복 단일 삭제에만, 반복 인스턴스는 기존 경로 유지 | done_when을 "삭제만"으로 좁혀야 K=2 안에서 통과; 인스턴스 편집 롤백까지 넣으면 M | 5초 유예 중 가족 뷰가 잠깐 어긋난다; 정직한 설계는 서버 trash(M, 스키마 = protected) | ✅ PRO·NEUTRAL | **비반복 단일 삭제만**, 클라이언트 지연 커밋 + 스낵바. 그 경로의 확인 다이얼로그는 없앤다(원칙: CRUD에 불필요한 확인 없음). 5초 어긋남은 수용(서버 trash는 스키마 → 사람 머지라 이번 라운드 밖) |
| 복제 | 클라이언트만, `createEvent` 재사용(`calendar_provider.dart:282`) | 리스크 최소 | (반대 없음) | ✅ | 그대로 |
| D-day | 서버 0건, 비용 0 | done_when을 수치 문자열로 못박아야(#105 선례) | 근거가 연구 스스로 "미확인"; 카드가 이미 빽빽(`event_card.dart:84,136`) — 단순함 위반에 가깝다 | ✅ CON | **이번 라운드에서 뺀다** |
| 구성원 색상+필터 | 핵심 Problem을 푸는 유일한 항목 | **`server/prisma/schema.prisma`가 `[protected]`+`[load_bearing]` 이중 적중** → 사람 머지 강제, 공장 직렬 전제와 충돌; 스키마/API와 클라 UI로 분리 | 캘린더색·죽은 카테고리색·구성원색 3중 체계 — 구성원색이 1차 색이 되어야 | ✅ NEUTRAL·CON | **뒤로.** 색 체계를 먼저 하나로 정리한 뒤(1번 이슈가 카테고리색을 살린다) 스키마(사람 머지)/UI로 쪼개 제출 |
| ICS export | NON-NEGOTIABLE(데이터 소유권) 위반 상태 | 신규 파일만이라 protected 밖 — 구조적으로 4보다 쉬움 | 현규 1인용 기능의 원칙 포장 | ✅ NEUTRAL(구조), CON 부분 | 2차 배치 4번. 가족가치는 낮지만 선언문과의 모순은 닫는다 |
| 검색 필터 | — | — | PROJECT.md Output "과거 회고"가 이미 약속 | ✅ | 2차 배치 5번 |

## 결정
- **1차 배치(지금, 직렬)**: ① 카테고리 선택 완성(017 약속) ② 비반복 단일 삭제 Undo ③ 일정 복제. 셋 다 클라이언트만, protected/load_bearing 밖, standard 티어.
- **2차 배치(1차 뒤)**: ④ ICS export ⑤ 검색 필터(날짜 범위·카테고리) ⑥ 구성원 색상 — 스키마·API(사람 머지)와 클라 UI로 분리.
- **제외**: D-day(근거 미확인·단순함 위험), 자연어 입력·지도·날씨·댓글(L 또는 원칙 충돌).

## Rounds
- Round 1만. CON의 두 코드 사실(카테고리 피커 미바인딩, 카드 색 = 캘린더색)과 NEUTRAL의 harness 사실(schema.prisma 보호)이 결정적이라 추가 라운드 없음.
