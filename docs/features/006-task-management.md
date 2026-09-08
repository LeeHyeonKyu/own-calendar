---
feature: 006
title: Task 관리 (Event-Task N:1 관계)
priority: P0
depends_on: [001]
status: in-progress
gate:
  architect: pending
  designer: pending
  qa: pending
---

# 006. Task 관리

## 개요
Event와 독립적이면서도 연결 가능한 Task 시스템. Event는 "발생하는 것" (complete 없음), Task는 "해야 하는 것" (complete 있음). Task:Event = N:1 관계.

## 온톨로지

### Event (기존)
- complete 개념 없음
- 날짜+시간 존재 (필수)
- 반복 가능
- Task 없이 독립 존재

### Task (신규)
- complete 개념 존재 (TODO → DONE / CANCELLED)
- 날짜: optional, 시간: optional
- 반복 가능
- Event 없이 독립 존재 가능
- Event에 N:1로 related 가능 (다른 날짜 Task도 같은 Event에 연결 가능)

### 관계 예시
- Event "민수 결혼식" (10/15) → Tasks: "결혼식 참여"(10/15), "축의금 출금"(10/14), "선물 구매"(10/10)
- 독립 Task: "기상"(매일 6시), "일기 작성"(매일 11시), "명상"(시간 없음)

## 데이터 모델

### Task 테이블 (Prisma)
```prisma
model Task {
  id            String       @id @default(cuid())
  title         String
  description   String?
  status        TaskStatus   @default(TODO)
  priority      TaskPriority @default(NONE)
  
  // 시간 (모두 optional)
  dueDate       DateTime?    // 마감일
  scheduledDate DateTime?    // 예정일
  scheduledTime String?      // 예정 시간 (HH:mm)
  
  // 반복
  recurrenceType RecurrenceType @default(NONE)
  recurrenceEnd  DateTime?
  
  // 완료
  completedAt   DateTime?
  
  // 관계
  eventId       String?
  event         Event?       @relation(fields: [eventId], references: [id], onDelete: SetNull)
  calendarId    String
  calendar      Calendar     @relation(fields: [calendarId], references: [id], onDelete: Cascade)
  createdById   String
  createdBy     User         @relation("CreatedTasks", fields: [createdById], references: [id])
  
  // 정렬
  sortOrder     Int          @default(0)
  
  createdAt     DateTime     @default(now())
  updatedAt     DateTime     @updatedAt
}

enum TaskStatus {
  TODO
  DONE
  CANCELLED
}

enum TaskPriority {
  HIGH
  MEDIUM
  LOW
  NONE
}
```

### Event 모델 변경
- `tasks Task[]` relation 추가

## API 엔드포인트

### Task CRUD
- `GET /api/tasks` — 목록 (calendarId, status, eventId, start, end 필터)
- `POST /api/tasks` — 생성
- `PUT /api/tasks/:id` — 수정
- `DELETE /api/tasks/:id` — 삭제
- `PATCH /api/tasks/:id/complete` — 완료 토글
- `PATCH /api/tasks/:id/link/:eventId` — Event 연결/해제

### Event 확장
- `GET /api/events/:id` — include tasks 옵션 추가
- 기간 조회 시 관련 Task도 함께 반환

## UI 블록 시스템

### 시각 구분
- Event = 파란색 (#5B8DEF), 좌측 실선 바, 체크박스 없음
- Task = 주황색 (#F0A050), 좌측 실선/점선 바, 체크박스 있음
- Related = 보라색 (#A78BFA) 링크
- 완료 = 초록색 (#4ADE80), 취소선, 반투명
- 기한 초과 = 빨간색 (#EF6B6B)

### 블록 컴포넌트
- **Event Card**: 파란 좌측바 + 점 + 제목/시간. Related Tasks가 카드 안에 nested 체크리스트
- **Standalone Task**: 주황 좌측바 + 체크박스. 시간 없으면 점선 바
- **Timeline Grid**: 시간 눈금자가 먼저, 항목은 그 위에 얹힘
- **Now Line**: 빨간 가로선 + 시각 라벨
- **Unscheduled Zone**: 시간 미지정 Task 모음

### 뷰 매트릭스
| 뷰 | 서브탭 | 플랫폼 |
|----|--------|--------|
| Daily | Timeline / Task | App |
| Weekly | Timeline / Task | App |
| Monthly | Calendar | App |
| Daily Timeline | S/M/L | Widget |
| Daily Task | S/M/L | Widget |
| Weekly Timeline | M/L | Widget |
| Weekly Task | S/M/L | Widget |
| Monthly | M/L | Widget |

## 구현 순서

### Phase 1: Backend (Task CRUD)
1. Prisma schema에 Task 모델 추가 + migration
2. Task service (CRUD + complete toggle + event link)
3. Task routes + validation schemas
4. Event service 확장 (include tasks)

### Phase 2: Flutter Client (모델 + 기본 UI)
1. TaskModel + TaskProvider
2. Task 생성/편집 폼 (Event/Task 토글, Event 연결)
3. Monthly View에 Task 통합 (날짜 선택 시 하단 리스트)

### Phase 3: Daily/Weekly Views
1. Daily Timeline View (시간 눈금자 + Event Card Nested + Standalone Task)
2. Daily Task View (체크리스트 + 진행률)
3. Weekly Timeline View (7일 그리드)
4. Weekly Task View (요일별 그룹핑)

### Phase 4: Widgets
1. 기존 위젯 확장 (Task 점 표시)
2. Daily Task Widget (진행률 링)
3. Weekly Widget 확장

## Acceptance Criteria
- [ ] Task 생성/수정/삭제/완료 동작
- [ ] Task에 Event 연결/해제 동작
- [ ] Task 반복 동작 (매일/매주/매월/매년)
- [ ] Monthly View에서 Task 표시 (파란 점=Event, 주황 점=Task)
- [ ] Daily Timeline에서 Event Card 안에 Nested Task 표시
- [ ] Daily Task 뷰에서 체크리스트 + 진행률 표시
- [ ] 시간 없는 Task가 Unscheduled Zone에 표시
- [ ] 기한 초과 Task 빨간색 강조
- [ ] 위젯에서 Task 정보 표시
