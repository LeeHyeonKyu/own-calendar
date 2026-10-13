---
id: 11
title: Daily Routine (습관/루틴) — DEPRECATED
status: deprecated
priority: P1
class: Architectural
depends_on: [1, 10]
persona: 현규
gate:
  worktree: null
  architect: fail
  designer: fail
  qa: skipped
deprecated_reason: "루틴 = 반복 Task. 별도 엔티티(Routine/RoutineGroup/RoutineCompletion) 불필요. Feature 012에 흡수."
superseded_by: 12
date: 2026-09-08
generatedBy: know-thy-build-feature
---

# Daily Routine (습관/루틴) — DEPRECATED

> **이 Feature는 폐기되었습니다.** Feature 012 (반복 규칙 엔진)에 흡수됨.

## 폐기 사유

Gate Review (2026-09-10)에서 Architect FAIL + Designer FAIL 판정.

근본 원인: **루틴은 반복 Task와 동일한 개념**이다.

| 루틴 개념 | Task로 표현 |
|-----------|------------|
| 이름 | `title` |
| 시간 | `scheduledTime` |
| 반복 요일 | `rrule` (FREQ=WEEKLY;BYDAY=MO,WE,FR 등) |
| 완료 체크 | `RecurrenceException` (status=DONE) |
| 그룹 | `Category` (Feature 017) |

별도 엔티티(Routine, RoutineGroup, RoutineCompletion)를 만든 것은 불필요한 중복이었다.

## 제거 대상

### Server
- `server/src/services/routine.service.ts`
- `server/src/routes/routines.ts`
- `server/src/schemas/routine.schema.ts`
- `server/prisma/migrations/20260908010000_add_routines/`
- `server/prisma/schema.prisma` — Routine, RoutineGroup, RoutineCompletion 모델
- `server/src/app.ts` — routines 라우트 등록

### Client
- `client/lib/screens/routine_screen.dart`
- `client/lib/screens/routine_form_screen.dart`
- `client/lib/providers/routine_provider.dart`
- `client/lib/models/routine.dart`
- `client/lib/router.dart` — /routines, /routine/new, /routine/:id/edit 라우트
- `client/lib/main.dart` — RoutineProvider 등록

## 대체 구현

Feature 012의 확장 스코프로 흡수:
- 반복 Task 생성 = 루틴 생성 (rrule 설정)
- Daily Task View에서 반복 인스턴스 완료 체크 = 루틴 완료
- Daily Timeline에서 scheduledTime에 따라 표시

---

*Deprecated: 2026-09-10 | Superseded by Feature 012*
