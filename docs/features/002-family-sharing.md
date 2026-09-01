# Feature 002: 가족 그룹 및 일정 공유

## Summary
가족 그룹 생성, 가족 코드 초대, 가족 공통 캘린더, 가족 구성원 간 일정 열람 기능을 구현한다.

## What We Build

### 데이터 모델 추가
- **FamilyGroup**: id, name, code(unique, 8자리), createdById, createdAt, updatedAt
- **FamilyMembership**: id, userId, familyGroupId, role(OWNER/MEMBER), joinedAt

### REST API Endpoints
- `POST /api/family` — 가족 그룹 생성 (코드 자동 발급)
- `GET /api/family` — 내 가족 그룹 정보
- `POST /api/family/join` — 가족 코드로 합류
- `GET /api/family/members` — 가족 구성원 목록
- `DELETE /api/family/members/:userId` — 구성원 내보내기 (owner만)
- `GET /api/family/calendars` — 가족 구성원들의 공개 캘린더 + 일정 열람
- `POST /api/family/events` — 가족 공통 캘린더에 일정 등록 (전원 자동 반영)

### 핵심 동작
- 가족 그룹 생성 시 8자리 랜덤 코드 발급 + 가족 공통 캘린더(type: FAMILY) 자동 생성
- 가족 코드로 합류하면 FamilyMembership 생성 + 가족 공통 캘린더 접근 가능
- 가족 구성원의 PUBLIC 캘린더/일정을 열람 가능 (PRIVATE 일정 제외)
- 가족 공통 캘린더의 일정은 모든 구성원이 조회 가능

## Acceptance Criteria
- [ ] 가족 그룹 생성 시 코드가 발급되고 가족 공통 캘린더가 생성된다
- [ ] 가족 코드로 그룹에 합류할 수 있다
- [ ] 가족 구성원의 공개 일정을 열람할 수 있다
- [ ] 비공개 일정은 다른 구성원에게 보이지 않는다
- [ ] 가족 공통 캘린더에 일정을 등록하면 모든 구성원이 볼 수 있다
- [ ] 통합 테스트 통과
