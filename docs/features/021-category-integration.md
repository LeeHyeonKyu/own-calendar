---
id: 21
title: 카테고리 시스템 통합 완성
status: complete
priority: P0
class: Bounded
depends_on: [17]
persona: 현규
gate:
  worktree: null
  architect: pending
  designer: pending
  qa: pending
assumptions:
  - "기존 EventCategory enum을 완전히 제거하고 DB Category로 대체"
date: 2026-09-10
generatedBy: manual
---

# 카테고리 시스템 통합 완성

Feature 017에서 Category 모델/API/설정 UI를 만들었지만, 캘린더 뷰의 필터와 색상 표시가 여전히 하드코딩된 EventCategory enum을 사용한다. DB Category 기반으로 완전히 전환한다.

## Problem

현재 두 개의 카테고리 시스템이 공존:

1. **EventCategory enum** (WORK, PERSONAL, FAMILY, HEALTH, SOCIAL, FINANCE, OTHER) — Prisma schema에 하드코딩. `event.category` 필드. 월별 뷰 필터 다이얼로그에서 사용.
2. **Category 모델** (📜Daily TODO, 💼Work 등) — DB 테이블. `event.categoryId` 필드. 설정 화면에서 관리 가능.

사용자가 설정에서 카테고리를 만들어도 캘린더 필터에 반영되지 않고, 필터에 보이는 건 하드코딩된 7개 enum 뿐이다.

## Value

카테고리 = 캘린더에서 일정을 색으로 구분하는 유일한 도구. 이것이 제대로 동작해야 "한눈에 오늘이 어떤 날인지" 파악할 수 있다.

## Solution

### 제거할 것
- `EventModel.categoryLabels` 하드코딩 맵 (업무/개인/가족 등 7개)
- `EventModel.categoryColors` 하드코딩 맵
- `CalendarProvider._selectedCategories` Set<String> (enum 기반)
- `CalendarProvider.toggleCategory()`, `selectAllCategories()` (enum 기반)
- `showCategoryFilterDialog()` — enum 리스트 기반 체크박스
- Prisma `EventCategory` enum (장기적으로 — 이번에는 deprecated 처리)

### 추가/변경할 것
- `CalendarProvider`에 `_categories: List<CategoryModel>` 추가
- `CalendarProvider`에 `_hiddenCategoryIds: Set<String>` 추가 (SharedPreferences 저장)
- `allVisibleEvents` — `_hiddenCategoryIds`로 필터링 (`event.categoryId`가 숨김 목록에 있으면 제외)
- `tasks` getter — 동일 필터 적용
- 카테고리 필터 다이얼로그 — DB Category 목록 기반 (색상 원 + 이모지 + 이름 + 체크박스)
- 월별 뷰 색상 바 — `event.categoryColor` 사용 (없으면 기본 색상)
- Event/Task 생성/편집 폼 — Category 선택 드롭다운을 DB 카테고리 목록으로
- categoryId 없는 이벤트 — "미분류"로 표시 (필터에서 토글 가능)

### 마이그레이션
- `event.category` (enum)와 `event.categoryId` (FK)가 모두 있는 경우 `categoryId` 우선
- `categoryId`가 없는 이벤트 — 기존 `category` enum 값에 매칭되는 Category가 있으면 자동 연결, 없으면 "미분류"

## Scope

**Includes:**
- CalendarProvider 카테고리 필터를 DB Category 기반으로 전환
- 월별/일별/주별 뷰에서 카테고리 색상 반영
- 카테고리 필터 다이얼로그 개편
- Event/Task 폼의 카테고리 선택 개편
- "미분류" 이벤트 처리

**Excludes:**
- EventCategory enum 제거 (DB 마이그레이션 필요, 다음 단계)
- 카테고리 자동 추천/AI 분류

## Acceptance Criteria

- [ ] 카테고리 필터가 DB Category 목록을 보여줌 (하드코딩 7개 아닌 사용자 커스텀 카테고리)
- [ ] 카테고리별 색상 원 + 이모지 + 이름 표시
- [ ] 카테고리 토글 시 해당 이벤트/태스크 월별 뷰에서 숨김/표시
- [ ] 필터 상태가 앱 재시작 후에도 유지 (SharedPreferences)
- [ ] 월별 뷰 이벤트 색상 바가 카테고리 색상 사용
- [ ] Event/Task 생성 시 DB 카테고리 목록에서 선택
- [ ] categoryId 없는 이벤트도 "미분류"로 필터 가능
- [ ] Google Calendar에서 가져온 이벤트는 "미분류" (사용자가 수동으로 카테고리 부여 가능)

---

*Created 2026-09-10*
