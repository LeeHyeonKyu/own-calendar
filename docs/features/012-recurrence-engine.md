---
id: 12
title: 반복 규칙 엔진 (Event + Task)
status: complete
priority: P0
class: Architectural
depends_on: [1, 6]
persona: 현규
gate:
  worktree: null
  architect: pending
  designer: pending
  qa: pending
assumptions:
  - "가족 규모에서 반복 일정/태스크 수가 수백 개 이내로 유지될 것"
  - "iCalendar RRULE(RFC 5545) 호환이 외부 캘린더 동기화에 유리할 것"
date: 2026-09-08
generatedBy: know-thy-build-feature
---

# 반복 규칙 엔진 (Event + Task)

Event와 Task 모두에 적용 가능한 반복 규칙 시스템. 반복 패턴 정의, 인스턴스 생성, 개별 인스턴스 수정/삭제를 지원한다.

## Problem

현재 반복 관련 필드(`recurrenceType`, `recurrenceEnd`)가 Task 모델에 존재하지만, 실제 반복 로직이 없다. Event에는 반복 개념 자체가 없다. 결혼기념일(매년), 결제일(매월), 팀 미팅(매주) 같은 반복 일정과, 수영(월수금), 업무메일 확인(평일) 같은 반복 Task를 표현할 수 없다.

## Value

반복은 캘린더의 핵심 기능. 이게 없으면 매번 수동으로 같은 일정/태스크를 생성해야 한다. 특히 anniversary, 정기 결제일 같은 연/월 단위 반복과, 주 단위 루틴성 일정은 사용 빈도가 매우 높다. 외부 캘린더(GC)에서 가져오는 반복 일정도 이 엔진이 있어야 제대로 표현 가능.

## Solution

### 반복 규칙 모델

RFC 5545 RRULE과 호환되는 반복 규칙 시스템:

- **빈도**: 매일(DAILY), 매주(WEEKLY), 매월(MONTHLY), 매년(YEARLY)
- **간격**: N일/주/월/년마다 (예: 격주 = WEEKLY + interval 2)
- **요일 지정**: WEEKLY에서 특정 요일 선택 (예: 월수금)
- **월 내 지정**: MONTHLY에서 날짜(15일) 또는 순서(셋째 목요일)
- **종료 조건**: 무기한 / N회 후 종료 / 특정 날짜까지

### 인스턴스 생성 방식

가상 생성(virtual expansion):
- 반복 규칙 원본(master)만 DB에 저장
- 조회 시 규칙을 기반으로 해당 기간의 인스턴스를 동적 생성
- 개별 수정/삭제된 인스턴스만 별도 레코드로 저장 (exception)

### 개별 인스턴스 수정

- **이번만 수정**: 해당 날짜의 exception 레코드 생성 (시간 변경, 내용 변경 등)
- **이후 전부 수정**: master 규칙을 해당 날짜에서 종료하고, 새 master 생성 (체인 분리)
- **이번만 삭제(skip)**: 해당 날짜를 exception으로 제외
- **전체 삭제**: master + 모든 exception 삭제

## Scope

**Includes:**
- 반복 규칙 정의 (빈도, 간격, 요일, 종료 조건)
- Event + Task 모두 지원
- 가상 인스턴스 생성 (조회 시 동적 확장)
- 개별 인스턴스 수정 (이번만 / 이후 전부)
- 개별 인스턴스 삭제 (이번만 skip / 전체 삭제)
- 반복 규칙 편집 UI
- GC에서 가져온 반복 일정의 RRULE 파싱 및 표현

**Excludes:**
- 복잡한 RRULE 조합 (BYSETPOS, BYHOUR 등 고급 패턴)
- 반복 일정 간 충돌 감지
- 반복 일정 일괄 시간 변경 (드래그로 전체 이동)
- Daily Routine(011)과의 통합 — 011은 별도 엔티티로 독립

## User Stories & Acceptance Criteria

### Story 1: 반복 일정 생성

**As a** 현규, **I want** "결혼기념일 — 매년 5/20" 같은 반복 일정을 만드는 것 **so that** 매년 수동 등록하지 않아도 된다.

**Scenario:**
- Given: 일정 생성 화면
- When: 반복 옵션에서 "매년" 선택
- Then: 매년 해당 날짜에 일정이 자동으로 표시된다

**Acceptance Criteria:**
- [ ] Event 생성/편집 시 반복 옵션 설정 가능 (매일/매주/매월/매년) — verify: UI 확인
- [ ] 간격 설정 가능 (격주, 2개월마다 등) — verify: 간격 변경 후 표시 확인
- [ ] 매주 반복 시 특정 요일 다중 선택 가능 (월수금 등) — verify: 요일 선택 UI + 해당 요일에만 표시
- [ ] 매월 반복 시 날짜 또는 순서 선택 (15일 vs 셋째 목요일) — verify: 월별 표시 확인
- [ ] 종료 조건 설정 가능 (무기한/N회/특정 날짜) — verify: 종료 후 미표시 확인

**Edge Cases & Errors:**
- [ ] 2/29 매년 반복 (윤년) — verify: 비윤년 처리 정책 (2/28 또는 3/1로 대체, 또는 skip)
- [ ] 31일 매월 반복 (30일인 달) — verify: 해당 월 마지막 날로 표시 또는 skip
- [ ] 종료 날짜가 시작 날짜보다 이전 — verify: 유효성 검사 에러

### Story 2: 반복 Task 생성

**As a** 현규, **I want** "수영 — 매주 월수금토" 같은 반복 Task를 만드는 것 **so that** 매주 수동 생성하지 않아도 된다.

**Scenario:**
- Given: Task 생성 화면
- When: 반복 옵션에서 "매주" + 월수금토 선택
- Then: 해당 요일마다 Task가 표시되고 개별 완료 체크 가능

**Acceptance Criteria:**
- [ ] Task 생성/편집 시 반복 옵션 설정 가능 — verify: UI 확인
- [ ] 반복 Task의 각 인스턴스를 개별 완료 체크 가능 — verify: 월요일 완료 → 수요일은 미완료 유지
- [ ] 완료한 인스턴스와 미완료 인스턴스 구분 표시 — verify: UI 상태 확인

**Edge Cases & Errors:**
- [ ] 반복 Task 완료 시 다음 인스턴스에 영향 없음 — verify: 이번 주 완료해도 다음 주 미완료 상태
- [ ] 평일(월~금) 프리셋 제공 — verify: 프리셋 선택 시 5일 자동 선택

### Story 3: 개별 인스턴스 수정

**As a** 현규, **I want** "이번 주 수영만 목요일로 변경"하는 것 **so that** 예외 상황에 유연하게 대응한다.

**Scenario:**
- Given: 매주 수요일 반복 일정이 있는 상태
- When: 이번 주 수요일 인스턴스를 목요일로 변경하고 "이번만 수정" 선택
- Then: 이번 주만 목요일에 표시, 다음 주부터는 수요일 유지

**Acceptance Criteria:**
- [ ] 반복 인스턴스 수정 시 "이번만 / 이후 전부" 선택지 제공 — verify: 선택 다이얼로그 확인
- [ ] "이번만 수정": 해당 인스턴스만 변경, 나머지 유지 — verify: 전후 인스턴스 확인
- [ ] "이후 전부 수정": 해당 날짜부터 새 규칙 적용 — verify: 이전 인스턴스 유지, 이후 변경 확인
- [ ] "이번만 삭제(skip)": 해당 인스턴스만 제외 — verify: 해당 날짜 미표시, 전후 정상

**Edge Cases & Errors:**
- [ ] 반복 인스턴스 삭제 시 "이번만 / 이후 전부 / 전체 삭제" 선택지 — verify: 각 옵션 동작 확인
- [ ] exception이 많아져도 성능 저하 없음 — verify: 수십 개 exception 후 조회 속도

## Design Intent

| Step | User Action | Ideal Outcome | Design Decision | QA Verification |
|------|-------------|---------------|-----------------|-----------------|
| 1 | 일정/Task 생성 시 반복 필드 탭 | 반복 옵션 바텀시트 | 빈도 → 상세(요일/간격) → 종료 순서로 단계적 노출 | 반복 설정 플로우 확인 |
| 2 | 반복 일정 표시 | 캘린더에 반복 아이콘 표시 | 반복 일정은 작은 반복 아이콘으로 구분 | 아이콘 표시 확인 |
| 3 | 반복 인스턴스 수정 | "이번만 / 이후 전부" 다이얼로그 | 실수 방지 — 반드시 범위 확인 후 적용 | 다이얼로그 표시 + 각 옵션 동작 |
| 4 | 반복 인스턴스 삭제 | "이번만 / 이후 전부 / 전체" 다이얼로그 | 삭제는 3단계 — skip, 분리 삭제, 완전 삭제 | 각 옵션 동작 확인 |

**Key States:**

| State | Trigger | User Sees |
|-------|---------|-----------|
| Empty | 반복 미설정 | 반복 필드에 "반복 없음" 표시 |
| Error | 잘못된 규칙 (종료 < 시작) | 유효성 에러 메시지 |

## Approach

- 반복 규칙 저장: Event/Task에 `rrule` 필드 (RFC 5545 RRULE 문자열) 또는 구조화된 JSON
- 가상 확장: `rrule` 라이브러리 (JS: `rrule.js`) 사용하여 기간 내 인스턴스 동적 생성
- Exception 저장: `RecurrenceException` 모델 — masterEventId/masterTaskId + originalDate + 변경 내용 (또는 deleted flag)
- 006의 기존 `recurrenceType`/`recurrenceEnd` 필드를 `rrule` 기반으로 마이그레이션
- GC 동기화: Google의 RRULE → 그대로 저장, 조회 시 동일 엔진으로 확장

## Assumptions

- 가족 규모에서 반복 일정/태스크 수가 수백 개 이내로 유지될 것 — if wrong: 인스턴스 캐싱 또는 사전 생성(materialization)으로 전환
- iCalendar RRULE(RFC 5545) 호환이 외부 캘린더 동기화에 유리할 것 — if wrong: 내부 포맷으로 변환 레이어 추가

---

*Generated by know-thy-build-feature | 2026-09-08*
