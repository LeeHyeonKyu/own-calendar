---
id: 22
title: 습관 추적 (Habit Tracking)
status: spec
priority: P1
class: Architectural
depends_on: [1, 6, 12]
persona: 현규
gate:
  worktree: null
  architect: pending
  designer: pending
  qa: pending
assumptions:
  - "습관 항목 수가 수십 개 이내로 유지될 것"
  - "추적 데이터는 RecurrenceException에서 파생 가능 (별도 집계 테이블 불필요)"
date: 2026-09-12
generatedBy: know-thy-build-feature
---

# 습관 추적 (Habit Tracking)

매일 반복되는 습관을 별도 탭에서 관리하고, 달성 여부를 추적한다.

## Problem

"양치하기", "영양제 섭취", "스트레칭" 같은 일상 습관은 캘린더 일정/태스크와 성격이 다르다.
월별 뷰에 매일 반복되면 노이즈가 되고, "했는지/안 했는지"를 추적하는 것이 핵심이다.
현재 반복 Task로 생성할 수 있지만, 월별 뷰에 노출되고 습관 추적(streak, 달성률)이 없다.

TickTick, Todoist 등 상용 앱에서도 "습관"은 태스크와 분리된 별도 탭으로 관리한다.

## Value

- 습관과 일정/태스크가 같은 앱에서 관리되되, 캘린더 뷰를 어지럽히지 않음
- 일별/주별 뷰에서는 함께 보여 "오늘 할 일" 전체를 파악 가능
- streak/달성률로 습관 이행을 시각적으로 추적 → 동기부여

## Solution

### 핵심 설계: Task + isHabit 플래그

별도 엔티티를 만들지 않는다. 기존 Task에 `isHabit: Boolean` 플래그를 추가한다.

```
Task {
  ...기존 필드
  isHabit    Boolean  @default(false)
}
```

- `isHabit = true` → 습관. 월별/연별 뷰에서 숨김. 습관 탭에서 표시. 추적 대상.
- `isHabit = false` → 기존 Task. 동작 변경 없음.

습관 Task는 반드시 `rrule`을 가진다 (매일, 평일, 특정 요일 등).
완료 체크는 기존 RecurrenceException(status: DONE) 메커니즘을 그대로 사용.

### 뷰별 표시 정책

| 뷰 | isHabit=false (일반 Task) | isHabit=true (습관) |
|---|---|---|
| 월별 | 표시 | **숨김** |
| 연별 | 표시 | **숨김** |
| 일별 | 표시 | **표시** |
| 주별 | 표시 | **표시** |
| 습관 탭 | 숨김 | **표시** |

### 습관 탭 구성

하단 네비게이션 `allTabs`에 "습관" 탭 추가.

#### 오늘의 습관 체크리스트 (메인)
- 오늘 해야 할 습관 목록 (rrule 기반 요일 필터링은 서버의 가상 확장이 처리)
- 각 항목: 체크박스 + 이름 + 시간(있으면)
- 체크하면 RecurrenceException(status: DONE) 생성
- 진행률 바: "3/5 완료"
- 습관에 checklist(서브항목)이 있으면 펼쳐서 개별 체크 가능

#### Streak 표시
- 각 습관 옆에 연속 달성일 수 표시: "🔥 7일"
- streak 계산: 오늘부터 역순으로 연속 완료된 날 수
  - 해당 요일이 아닌 날은 건너뜀 (매주 월수금 습관이면 화목은 무시)
  - 오늘 아직 미완료면 어제까지 기준으로 계산 (오늘 포함하면 하루 내내 0)

#### 주간 요약
- 이번 주 월~일 동그라미 표시: ●(완료) ○(미완료) -(해당 없음)
- 습관별로 한 줄

#### 월간 히트맵
- GitHub contributions 스타일 달력 격자
- 색상 강도: 미완료(빈칸) → 부분 완료(연한) → 전부 완료(진한)
- 전체 습관 합산 or 개별 습관 선택 가능

### 습관 생성/편집

- 습관 탭에서 + 버튼 → 습관 생성 폼
- 기존 Task 생성 폼과 유사하되, `isHabit: true`가 자동 설정
- 필수: 이름, 반복 규칙 (rrule)
- 선택: 시간, 카테고리, checklist(서브항목)
- "매일/평일/주말" 프리셋 제공

또는: 기존 Task 생성 폼에 "습관으로 만들기" 토글 추가.

### 습관 편집 시 히스토리 정책

| 변경 | 과거 기록 | 미래 인스턴스 |
|---|---|---|
| 이름 변경 | 유지 (RecurrenceException에 기록된 title 보존) | 새 이름 적용 |
| 시간 변경 | 유지 | 새 시간 적용 |
| 반복 규칙 변경 | 유지 (기존 exception 보존) | 새 규칙 적용 (updateWithMode 'thisAndFuture') |
| checklist 항목 추가 | 영향 없음 | 새 템플릿 적용 |
| checklist 항목 삭제 | 기존 exception의 checklist에는 남아있음 | 제거됨 |
| 습관 삭제 | **master Task + 모든 RecurrenceException 삭제** | 삭제됨 |
| 습관 일시 중지 | 별도 구현 필요 (isActive 플래그 or rrule UNTIL 설정) | 표시 안 됨 |

**원칙**: 과거 완료 기록(RecurrenceException)은 편집으로 소실되지 않는다. 이름 변경해도 과거 "비타민D 체크" 기록은 남는다.

### 추적 데이터 소스

별도 집계 테이블을 만들지 않는다. RecurrenceException에서 실시간 계산:

```
streak 계산:
  1. master Task의 rrule로 오늘부터 역순으로 인스턴스 날짜 생성
  2. 각 날짜에 RecurrenceException(status: DONE)이 있는지 확인
  3. 연속 완료된 날 수 = streak

주간 요약:
  해당 주의 7일 × 각 날짜에 exception 존재 여부

월간 히트맵:
  해당 월의 모든 날 × 전체 습관 중 완료 비율
```

습관 수가 수십 개 이내이므로 실시간 계산으로 충분.
성능이 문제되면 일별 집계 캐시 테이블로 전환 (P2).

## Scope

**Includes:**
- Task에 `isHabit` 필드 추가
- 습관 전용 탭 (하단 네비바 등록)
- 오늘의 습관 체크리스트 + 체크
- streak 계산 및 표시
- 주간 동그라미 요약
- 월간 히트맵
- 습관 CRUD (생성/편집/삭제)
- 월별/연별 뷰에서 습관 필터링
- 일별/주별 뷰에서 습관 표시

**Excludes:**
- 습관 일시 중지 (isActive) — P2
- 달성 목표 설정 (예: 주 5회) — P2
- 습관 알림 (010 알람 연동) — P2
- 가족/그룹 공유 습관 — P2
- 습관 통계 내보내기 — P2

## User Stories & Acceptance Criteria

### Story 1: 습관 생성

**As a** 현규, **I want** "영양제 섭취 — 매일 10시" 같은 습관을 만드는 것 **so that** 매일 할 일을 체계적으로 관리한다.

**Acceptance Criteria:**
- [ ] 습관 탭에서 + 버튼으로 습관 생성 가능
- [ ] 이름, 반복 규칙(매일/평일/특정 요일), 시간(선택) 설정 가능
- [ ] 반복 규칙 없이 생성 시도 시 안내 (습관은 반복 필수)
- [ ] 생성된 습관이 습관 탭에 표시됨
- [ ] 생성된 습관이 해당 요일의 일별/주별 뷰에도 표시됨
- [ ] 월별/연별 뷰에는 표시되지 않음

### Story 2: 습관 체크

**As a** 현규, **I want** 오늘 습관을 체크하는 것 **so that** 이행 여부를 기록한다.

**Acceptance Criteria:**
- [ ] 습관 탭에서 항목 탭으로 완료 체크/해제
- [ ] 일별 Task View에서도 동일하게 체크 가능
- [ ] 체크 시 즉시 UI 반영 (optimistic update)
- [ ] 오늘 완료해도 내일은 미완료로 표시
- [ ] checklist(서브항목) 있으면 개별 체크 가능

### Story 3: streak 추적

**As a** 현규, **I want** 연속 달성일을 보는 것 **so that** 동기부여를 받는다.

**Acceptance Criteria:**
- [ ] 각 습관 옆에 streak 일수 표시
- [ ] streak은 해당 요일만 기준으로 계산 (월수금 습관이면 화목 무시)
- [ ] 오늘 미완료 상태에서는 어제까지 기준 streak 표시

### Story 4: 주간/월간 추적

**As a** 현규, **I want** 이번 주/이번 달 습관 달성 현황을 한눈에 보는 것 **so that** 패턴을 파악한다.

**Acceptance Criteria:**
- [ ] 주간: 월~일 동그라미 표시 (●완료 ○미완료 -해당없음)
- [ ] 월간: GitHub 스타일 히트맵 (색상 강도로 완료율 표현)
- [ ] 전체 습관 합산 뷰 + 개별 습관 선택 가능

### Story 5: 습관 편집

**As a** 현규, **I want** 습관을 편집하는 것 **so that** 변경된 루틴에 맞춘다.

**Acceptance Criteria:**
- [ ] 이름, 시간, 반복 규칙, checklist 편집 가능
- [ ] 편집해도 과거 완료 기록은 유지됨
- [ ] 반복 규칙 변경 시 "이후 전부" 적용 (기존 메커니즘 활용)

## Approach

### DB 변경
- Task에 `isHabit Boolean @default(false)` 추가
- Migration: `ALTER TABLE "Task" ADD COLUMN "isHabit" BOOLEAN NOT NULL DEFAULT false;`

### Server 변경
- Task 조회 API: 기존 그대로 (isHabit 필드만 추가로 반환)
- streak/주간/월간 API: `GET /api/tasks/:id/stats?range=week|month`
  - RecurrenceException 기반 실시간 계산
  - 또는 클라이언트에서 계산 (RecurrenceException 목록 + rrule 확장)
- Task 생성/편집: `isHabit` 필드 통과

### Client 변경
- 습관 탭: `allTabs`에 추가, 라우터에 `/habits` 등록
- 습관 화면: 오늘 체크리스트 + streak + 주간 요약 + 월간 히트맵
- 월별/연별 뷰: `isHabit == true` 필터링
- 일별/주별 뷰: 기존대로 표시 (TaskCard가 이미 처리)
- 습관 생성 폼: Task 생성 폼 기반 + isHabit 자동 설정

---

*Generated by know-thy-build-feature | 2026-09-12*
