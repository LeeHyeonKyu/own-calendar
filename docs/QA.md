---
status: active
generatedBy: know-thy-build-qa
date: 2026-08-31
---

# QA

A feature is complete ONLY when its test cases here are all ✅.

## Test Environment

### Service

| | Command | Verified |
|---|---------|----------|
| **Start** | `cd server && docker compose up -d` | ✅ 2026-08-31 |
| **Stop** | `cd server && docker compose down` | ✅ 2026-08-31 |
| **Health check** | `curl https://own-calendar.tailb2886a.ts.net/health` | ✅ 2026-08-31 |
| **Seed data** | N/A (수동 테스트 데이터) | N/A |
| **Reset** | `docker exec server-postgres-1 psql -U postgres -d own_calendar -c 'TRUNCATE ...'` | N/A |

### Access Points

| Entry | Method | Address | Tool | Verified |
|-------|--------|---------|------|----------|
| Web UI | Browser | `https://own-calendar.tailb2886a.ts.net` | Playwright | ✅ 2026-08-31 |
| API | HTTP | `https://own-calendar.tailb2886a.ts.net/api/*` | curl | ✅ 2026-08-31 |

## Behavioral Testing Axes

### Persona: 현규 — 소프트웨어 엔지니어

| Axis | Primary | Secondary |
|------|---------|-----------|
| Mindset | Sequential | Divergent |
| Strategy | Core-feature | Input-focused |
| Habit | Short-valid | Invalid |
| Cooperation | Cooperative | Impatient |

### Persona: 가족 — 비개발자

| Axis | Primary | Secondary |
|------|---------|-----------|
| Mindset | Sequential | — |
| Strategy | Core-feature | Click-through |
| Habit | Short-valid | — |
| Cooperation | Cooperative | Incomplete |

### Test Profiles (risk-ordered)

| # | Axes | Risk | Description |
|---|------|------|-------------|
| P1 | Seq + Core + Short + Coop | Baseline | Happy path — 정상 흐름 |
| P2 | Div + Input + Invalid + Impatient | Critical | 가장 파괴적 조합 |
| P3 | Seq + Core + Short + Incomplete | Medium | 비개발자 가족 — 정보를 한번에 안 줌 |
| P4 | Div + Click + Long + Impatient | High | 빠르게 이것저것 누르는 유저 |
| P5 | Seq + Input + Invalid + Impossible | High | 시스템 한계 탐색 |

### Failure State Injection Methods

| Type | Method | Applicable Features |
|------|--------|---------------------|
| Network failure | 브라우저 DevTools throttle / API 서버 중단 | 모든 CRUD, 동기화 |
| Session expiry | secure storage 토큰 삭제 후 액션 시도 | 모든 인증 필요 기능 |
| Resource deletion | DB에서 이벤트/캘린더 직접 삭제 후 UI 접근 | 이벤트 수정, 캘린더 뷰 |
| Concurrent mutation | 다른 세션에서 데이터 변경 후 원래 세션에서 저장 | 가족 공유 |

## QA Quality Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Unique failures found (total) | 4 | — |
| Scenario diversity (profiles used) | P1, P2, P5 (3/5) | 100% |
| Turn instructions executed | 15+ | — |
| Failure injections performed | 0 | 2+ |

---

## Feature: Auth (인증)

**Access:** `https://own-calendar.tailb2886a.ts.net/#/login`
**Preconditions:** 서비스 실행 중
**Access verified:** ✅ 2026-08-31

### Test Cases

| # | Profile | Scenario | Expected | Status | Evidence |
|---|---------|----------|----------|--------|----------|
| A01 | P1 | 정상 회원가입 | 가입 성공, 홈으로 이동, "내 캘린더" 자동 생성 | ✅ | API 201 + calendar 반환 |
| A02 | P2 | 중복 이메일 가입 | 409 Conflict | ✅ | HTTP 409 |
| A05 | P1 | 정상 로그인 | 로그인 성공, 홈으로 이동 | ✅ | UI: 월별 뷰 진입 확인 |
| A06 | P2 | 잘못된 비밀번호 | 401 Unauthorized | ✅ | HTTP 401 |
| A07 | P2 | 존재하지 않는 이메일 | 401 Unauthorized | ✅ | HTTP 401 |
| A08 | P1 | 자동 로그인 (앱 새로고침) | 로그인 없이 홈 직행 | ✅ | 페이지 리로드 후 월별 뷰 진입 |
| A09 | — | 토큰 없이 API 접근 | 401 | ✅ | HTTP 401 |
| A10 | — | 잘못된 토큰으로 API 접근 | 401 | ✅ | HTTP 401 |
| A11 | — | Refresh 토큰 플로우 | 새 토큰 쌍 발급 | ✅ | 새 accessToken + refreshToken 반환 |
| A12 | P2 | Rate limit 초과 (15분 내 10회 실패) | 429 Too Many Requests | ⚠️ | 미테스트 |

### Results — 2026-08-31

**Summary:** 9/10 passed, 0 failed, 1 untested

---

## Feature: Event CRUD (일정 생성/조회/수정/삭제)

**Access:** 월별 뷰 FAB(+) → 생성 폼, EventCard 탭 → 수정 폼
**Preconditions:** 로그인 완료
**Access verified:** ✅ 2026-08-31

### Test Cases

| # | Profile | Scenario | Expected | Status | Evidence |
|---|---------|----------|----------|--------|----------|
| E01 | P1 | 최소 입력으로 이벤트 생성 (제목만) | 생성 성공, 캘린더에 반영 | ✅ | UI: "UI 테스트 이벤트" 월별 뷰 8/1에 표시 |
| E02 | P1 | 전체 필드 입력 생성 | 모든 필드 정확히 저장 | ✅ | API: 201 + 전 필드 반환 |
| E06 | P2 | 빈 제목으로 저장 시도 | 400 거부 | ✅ | API: 400 Validation failed |
| E07 | P1 | 생성 후 캘린더 뷰 복귀 | 새 이벤트 즉시 반영 | ✅ | UI: 생성 후 월별 뷰에 이벤트 표시 |
| E11 | P1 | EventCard 탭 → 수정 폼 | 기존 값 전체 로드 | ✅ | UI: 제목/시간/캘린더 정확히 로드 |
| E12 | P1 | 제목 변경 후 저장 | 변경 반영, 뷰 갱신 | ✅ | UI: "QA 수정된 이벤트"로 변경 확인 |
| E17 | P1 | 이벤트 삭제 | 삭제 성공, 뷰에서 제거 | ✅ | API: DELETE 후 목록에서 제거 확인 |
| E16 | P5 | 타인 이벤트 수정 시도 | 403 Forbidden | ✅ | API: 403 |
| E19 | P5 | 타인 이벤트 삭제 시도 | 403 Forbidden | ✅ | API: 403 |
| E05 | P5 | endTime < startTime 이벤트 생성 | 400 거부 | ✅ | API: 400 "endTime must be after startTime" (B3 수정 후) |
| E09 | P1 | FAB 클릭 시 기본 날짜 | 오늘 날짜가 기본값 | ✅ | B7 수정: `_currentMonth` → `DateTime.now()` |

### Issues

| # | Severity | Description | Status |
|---|----------|-------------|--------|
| B3 | P1 | endTime < startTime 검증 없음 — 역순 시간 이벤트 생성 가능 | **FIXED** |
| B7 | P2 | FAB 기본 날짜가 오늘이 아닌 현재 월의 1일 | **FIXED** |

### Results — 2026-08-31

**Summary:** 11/11 passed (B3, B7 수정 후)

---

## Feature: Calendar Views (캘린더 뷰)

**Access:** 하단 탭 (월별/일별/주별/연별)
**Preconditions:** 로그인 완료, 이벤트 존재
**Access verified:** ✅ 2026-08-31

### Test Cases

| # | Profile | Scenario | Expected | Status | Evidence |
|---|---------|----------|----------|--------|----------|
| V01 | P1 | 월별 뷰: 오늘 날짜 하이라이트 | 원형 배경으로 오늘 강조 | ✅ | Screenshot: qa-v01-monthly-view.png |
| V03 | P1 | 월별 뷰: 이벤트 색상 바 표시 | 캘린더 색상 바 표시 | ✅ | UI: "31 QA 수정된 이벤트" 표시 |
| V06 | P1 | 월별 → 날짜 탭 → 일별 뷰 | 해당 날짜 일별 뷰로 이동 | ✅ | UI: 8/31 탭 → "2026년 8월 31일" 일별 뷰 |
| V13 | P1 | 일별 뷰: 이벤트 리스트 | EventCard 표시 (시간/제목/캘린더) | ✅ | Screenshot: qa-v13-daily-view-events.png |
| V17 | P1 | 일별 뷰: EventCard 탭 → 수정 | 수정 폼으로 이동 | ✅ | UI: "일정 수정" heading 확인 |
| V19 | P1 | 주별 뷰: 이벤트 표시 | 요일별 이벤트 표시 | ✅ | UI: "월 31 QA 수정된 이벤트 10:00" |
| V21 | P1 | 주별 → 요일 탭 → 일별 뷰 | 해당 날짜 전달 | ✅ | UI: 8/31 탭 → "2026년 8월 31일" (B4 반증) |
| V24 | P1 | 하단 탭 뷰 전환 | 선택 탭 하이라이트, 뷰 즉시 전환 | ✅ | UI: 월별↔주별↔가족 전환 확인 |

### Results — 2026-08-31

**Summary:** 8/8 passed

---

## Feature: Search (검색)

**Access:** 월별 뷰 AppBar 검색 아이콘
**Preconditions:** 로그인 완료, 이벤트 존재
**Access verified:** ✅ 2026-08-31

### Test Cases

| # | Profile | Scenario | Expected | Status | Evidence |
|---|---------|----------|----------|--------|----------|
| S01 | P1 | 검색 화면 진입 | 검색 필드 autofocus, "검색어를 입력하세요" | ✅ | UI: 빈 상태 메시지 확인 |
| S02 | P1 | 키워드 "QA" 검색 | 해당 이벤트 결과 표시 | ✅ | UI: "QA 수정된 이벤트" 결과 |
| S05 | P1 | 대소문자 무시 검색 | 동일 결과 | ✅ | API: insensitive 검색 확인 |
| S06 | P1 | 한글 검색 ("수정") | 한글 검색 정상 | ✅ | API: URL-encoded 한글 검색 성공 |

### Results — 2026-08-31

**Summary:** 4/4 passed

---

## Feature: Family (가족 공유)

**Access:** 하단 탭 "가족"
**Preconditions:** 로그인 완료
**Access verified:** ✅ 2026-08-31

### Test Cases

| # | Profile | Scenario | Expected | Status | Evidence |
|---|---------|----------|----------|--------|----------|
| F01 | P1 | 가족 그룹 생성 | 그룹 생성 + 초대 코드 + 가족 캘린더 | ✅ | API: 201 + code + calendar 반환 |
| F04 | P1 | 유효한 코드로 합류 | 합류 성공, 멤버 추가 | ✅ | API: 200 (B1, B2 수정 후) |
| F05 | P2 | 잘못된 코드로 합류 | 404 거부 | ✅ | API: 404 |
| F08 | P1 | 가족 캘린더 이벤트 조회 | 전원 PUBLIC 일정 표시 | ✅ | API: 가족 이벤트 반환 |
| F09 | P1 | 비공개 이벤트 타 멤버에게 미노출 | isPrivate 이벤트 필터링 | ✅ | API: MEMBER 조회 시 비공개 미포함 |
| F10 | P1 | 가족 공통 캘린더 이벤트 생성 | 전원에게 반영 | ✅ | API: POST /family/events 성공 |
| F13 | P1 | OWNER가 MEMBER 제거 | 제거 성공 | ✅ | API: 204 |
| F14 | P5 | MEMBER가 멤버 제거 시도 | 403 | ✅ | API: 403 |
| F15 | P5 | OWNER 자기 제거 시도 | 400 | ✅ | API: 400 |
| F11 | P1 | 가족 탭 UI 표시 | 구성원 + 이벤트 리스트 표시 | ✅ | UI: "QA 가족" heading, 이벤트 리스트 |

### Issues

| # | Severity | Description | Status |
|---|----------|-------------|--------|
| B1 | P0 | 클라이언트 `inviteCode` 키 ↔ 서버 `code` 키 불일치 | **FIXED** |
| B2 | P0 | 초대 코드 생성 11자 ↔ 스키마 8자 제한 불일치 | **FIXED** |

### Results — 2026-08-31

**Summary:** 10/10 passed (B1, B2 수정 후)

---

## Bug Summary

| # | Severity | Description | Status |
|---|----------|-------------|--------|
| B1 | P0 | 가족 합류 API 키 불일치 (inviteCode ↔ code) | **FIXED** — `family_screen.dart` |
| B2 | P0 | 초대 코드 길이 불일치 (11자 생성, 8자 스키마) | **FIXED** — `family.schema.ts` |
| B3 | P1 | endTime < startTime 이벤트 생성 허용 | **FIXED** — `event.schema.ts` refine 추가 |
| B4 | P2 | 주별 → 일별 날짜 미전달 | **NOT REPRODUCED** — 실제 테스트에서 정상 동작 |
| B7 | P2 | FAB 기본 날짜가 월 1일 (오늘이어야 함) | **FIXED** — `monthly_view_screen.dart` |

## Discovered Patterns

- 가족 공유 기능에서 **서버-클라이언트 간 키/형식 불일치**가 집중 발생 (B1, B2). 새 API 추가 시 클라이언트-서버 계약 검증 필수.
- **입력 검증이 서버에 편중** — 클라이언트에서 시간 순서, 코드 형식 등을 사전 검증하지 않아 불필요한 API 호출 발생.
- 코드 분석에서 발견한 버그(B4)가 실제 테스트에서 재현되지 않는 경우 존재 — 코드 리뷰만으로 버그를 단정짓지 말 것.

---

*Generated by know-thy-build-qa | 2026-08-31*
