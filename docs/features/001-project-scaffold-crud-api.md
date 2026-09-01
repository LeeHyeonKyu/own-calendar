# Feature 001: 프로젝트 스캐폴딩 및 기본 일정 CRUD API

## Summary
Node.js(TypeScript) + Prisma + PostgreSQL 백엔드 프로젝트를 초기 세팅하고, 사용자/캘린더/일정의 기본 CRUD REST API를 구현한다.

## Problem
프로젝트 코드베이스가 비어있다. MVP의 모든 기능(통합 뷰, 동기화, 가족 공유, 검색)은 기본 데이터 모델과 API 위에 구축되므로, 이 기초가 먼저 필요하다.

## What We Build

### 백엔드 프로젝트 세팅
- Node.js + TypeScript 프로젝트 초기화
- Express.js REST API 서버
- Prisma ORM + PostgreSQL 연결
- Docker Compose (PostgreSQL + API 서버)

### 데이터 모델
- **User**: id, email, name, password(hashed), createdAt, updatedAt
- **Calendar**: id, name, color, isDefault, visibility(public/private), ownerId, type(personal/family/external), createdAt, updatedAt
- **Event**: id, title, description, startTime, endTime, isAllDay, isPrivate, calendarId, createdBy, createdAt, updatedAt

### REST API Endpoints
- `POST /api/auth/register` — 회원가입
- `POST /api/auth/login` — 로그인 (JWT)
- `GET /api/calendars` — 내 캘린더 목록
- `POST /api/calendars` — 캘린더 생성
- `PUT /api/calendars/:id` — 캘린더 수정
- `DELETE /api/calendars/:id` — 캘린더 삭제
- `GET /api/events?calendarId=&start=&end=` — 일정 조회 (기간 필터)
- `POST /api/events` — 일정 생성
- `PUT /api/events/:id` — 일정 수정
- `DELETE /api/events/:id` — 일정 삭제

## Acceptance Criteria
- [ ] `docker compose up`으로 PostgreSQL + API 서버가 기동된다
- [ ] 회원가입/로그인 후 JWT 토큰을 받을 수 있다
- [ ] 캘린더 CRUD가 동작한다
- [ ] 일정 CRUD가 동작한다 (기간 필터 포함)
- [ ] 일정의 공개/비공개 설정이 동작한다
- [ ] 본인의 캘린더/일정만 접근 가능하다 (인증 체크)

## Out of Scope
- 가족 공유 기능
- 외부 캘린더 동기화
- 과거 일정 검색 (Full-text search)
- Flutter 클라이언트
- 푸시 알림
