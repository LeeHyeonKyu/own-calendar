---
status: complete
areasExplored:
  problem: { depth: 3, decisions: 6 }
  persona: { depth: 2, decisions: 5 }
  competitive: { depth: 2, decisions: 3 }
  vision: { depth: 3, decisions: 7 }
  output: { depth: 2, decisions: 4 }
  journey: { depth: 2, decisions: 7 }
  boundaries: { depth: 1, decisions: 2 }
  success: { depth: 2, decisions: 4 }
  risks: { depth: 1, decisions: 3 }
  principles: { depth: 2, decisions: 2 }
  operations: { depth: 1, decisions: 4 }
assumptions:
  - "Naver Calendar의 CalDAV/ICS 경로가 계속 유지될 것"
  - "Google Calendar API 무료 쿼터가 소규모 그룹 트래픽에 충분할 것"
  - "그룹 구성원이 별도 앱을 설치할 의향이 있을 것"
  - "Tailscale Funnel이 외부 접근용으로 안정적일 것"
generatedBy: know-thy-build
version: 3.1.0
date: 2026-09-09
lastEvolve: 2026-09-09
---

# Own Calendar

내 모든 일정을 한 곳에서 소유하고 통합 관리하는 캘린더 허브. 그룹(가족, 동호회 등)과의 일정 공유까지.

## Problem

일정이 여러 곳에 흩어져 있다. Naver Calendar, Google Calendar, TickTick 등 각기 다른 플랫폼에 일정이 분산되어 있고, 이들을 한눈에 볼 수 없다. 과거 일정을 돌아보거나 검색하는 것도 어렵다. 특정 플랫폼에 lock-in 되어 있어 데이터를 자유롭게 옮길 수도 없다.

그룹 간 일정 공유도 불편하다. 가족이든 동호회든, 같은 그룹 구성원의 일정을 알려면 직접 물어봐야 하고, 들은 내용을 각자의 캘린더에 따로 등록해야 한다. 이 과정에서 일정이 누락되거나 충돌이 생긴다.

## Personas

| Persona | Role | Pain Point | Tech Level | Context |
|---------|------|------------|------------|---------|
| 현규 | 소프트웨어 엔지니어 | Naver/Google/TickTick에 일정 분산, 통합 뷰 부재, 플랫폼 lock-in | 개발자 | 여러 캘린더를 병행 사용. 그룹(가족, 동호회 등)과 일정 공유 필요 |
| 그룹 구성원 | 비개발자 (가족, 동호회 멤버 등) | 그룹 일정을 매번 물어봐야 함, 공유 일정 누락 | 스마트폰 기본 사용 가능, 복잡한 설정 어려움 | 일정 확인과 등록만 쉽게 할 수 있으면 됨 |

**Primary user values:** 단순함 — 열면 바로 오늘 일정이 보이고, 최소 동작으로 일정을 조작할 수 있는 것

## Competitive Landscape

11개 서비스를 세 축(캘린더 통합, 그룹 공유, 셀프호스팅)으로 조사한 결과, Own Calendar의 핵심 요구사항을 동시에 충족하는 서비스는 없다.

### 캘린더 통합 (Aggregator)

| Competitor | Approach | Gap |
|------------|----------|-----|
| CalendarBridge | Google↔Outlook↔iCloud 실시간 양방향 동기화. ICS 피드로 추가 캘린더 단방향 연결 | Naver/TickTick 미지원. 그룹 공유는 동기화 수준만 (전원 유료 필수, $4~40/월). SaaS 종속 |
| OneCal | Google↔Outlook↔iCloud 양방향 동기화 + 통합 뷰 | Naver/TickTick 미지원. 그룹 공유 개념 없음. SaaS 종속 ($3~25/월) |

### 그룹 캘린더

| Competitor | Approach | Gap |
|------------|----------|-----|
| Cozi | 가족 공유 캘린더 + 리스트/식단. 색상으로 구성원 구분 | 외부 캘린더 단방향만. 2024년 무료 30일 제한으로 전환 (Trustpilot 2.1/5). 권한 관리 없음. 가족 외 그룹 미지원 |
| TimeTree | 공유 캘린더 중심 모바일 앱. 이벤트별 댓글 | 외부 캘린더 단방향. 공식 export 불가 — 데이터 lock-in 심함. 무료 광고 과다 |
| Calendara | AI 사진 인식으로 일정 자동 추출. Google 양방향 동기화 | Early Access라 안정성 불확실. Naver/TickTick 미지원. 셀프호스팅 불가 |

### 셀프호스팅

| Competitor | Approach | Gap |
|------------|----------|-----|
| Nextcloud Calendar | CalDAV 기반 풀 스위트. 다중 사용자 캘린더 공유 | Google 양방향은 유료 브릿지 필요. 무겁고(2CPU, 4GB RAM) 모바일 앱 미성숙. 비개발자 진입장벽 높음 |
| Baikal/Radicale | 경량 CalDAV 서버 (~50MB) | 웹 UI/검색/그룹 공유 UX 전무. 모바일 앱 없음. 개발자 전용 |
| EteSync | E2E 암호화 CalDAV. 프라이버시 중심 | 외부 캘린더 양방향 불가. 그룹 공유 유료. 검색 없음 |
| Proton Calendar | 암호화 캘린더. 가족 플랜 지원 | Google 단방향 import만. 모바일에서 캘린더 공유 불가. Naver/TickTick 미지원 |

**Our Differentiation:** 세 축을 하나로 결합 — 외부 캘린더 양방향 통합(특히 한국 캘린더 생태계) + 비개발자 그룹 구성원이 쓸 수 있는 공유 + 셀프호스팅 데이터 소유권. 특히 Naver Calendar 양방향 동기화는 어떤 기존 서비스에서도 지원하지 않는다. "그룹" 개념으로 가족뿐 아니라 동호회 등 다양한 관계를 지원하는 점도 차별화.

## Vision

| Before | After |
|--------|-------|
| 일정이 여러 플랫폼에 흩어져 있음 | 모든 일정이 한 곳에 통합 |
| 특정 캘린더에 lock-in | 내 데이터를 내가 소유하고 자유롭게 이동 |
| 과거 일정을 돌아보기 어려움 | 과거 일정 검색 및 회고 가능 |
| 그룹 일정을 매번 물어봐야 함 | 그룹 캘린더를 열어 바로 확인 |

**Approach:** 외부 캘린더들과 양방향 동기화하는 중앙 허브. 기존 캘린더(특히 회사 캘린더)는 계속 사용하면서, 이 앱에서 모든 일정을 통합해서 보고 관리한다. 그룹 공유는 이 허브 위에 구축한다.
**Why:** 기존 캘린더를 대체하려 하면 채택 장벽이 높아진다. "통합 허브"로 포지셔닝하면 기존 습관을 유지하면서 점진적으로 전환할 수 있다.

**Core Value:** 통합 — 흩어진 일정을 하나로 모아 소유한다.

## What We Build

| | |
|---|---|
| **Deliverable** | 일정 통합 관리 + 그룹 공유 모바일 캘린더 앱 |
| **Form** | 크로스 플랫폼 모바일 앱 (iOS 우선, Android 지원). 1인 개발에서 네이티브 이중 유지보수가 불가하므로 Flutter 단일 코드베이스 |
| **Nature** | 개인 프로젝트 |

## Output

| Output | Description |
|--------|-------------|
| 통합 캘린더 뷰 | 여러 외부 캘린더(Naver, Google, TickTick 등)의 일정을 한 곳에서 확인 |
| 양방향 동기화 | 외부 캘린더와 실시간 동기화. 이 앱에서 추가/수정하면 원본에도 반영 |
| 개인 캘린더 | 외부 캘린더에 종속되지 않는 자체 일정 관리. 일정별 공개/비공개 설정 가능 |
| 과거 일정 검색 | 과거 일정을 검색하고 돌아볼 수 있는 기능 |
| 그룹 공통 캘린더 | 그룹 전체 공유 일정. 한 명이 등록하면 그룹 전원에게 자동 반영 |
| 그룹 일정 열람 | 같은 그룹 구성원의 캘린더를 자유롭게 열람 (제목, 내용, 시간 등 전부 확인 가능) |
| 일별/주별/월별 뷰 | 일별 뷰 — 오늘 전체 스케줄. 주별 뷰 — 한 주 일정. 월별 뷰(기본) — 한 달 전체 |
| 알림 | 설정 가능한 알림 (종류별 on/off) |
| 그룹 관리 | 초대 코드 발급으로 그룹 생성 및 참여. 가족, 동호회 등 다양한 그룹 지원 |

## User Journey

| Stage | Description |
|-------|-------------|
| **Trigger** | 일정을 확인하려는데 여러 앱을 오가야 하는 불편함. 그룹 일정을 물어봐야 하는 번거로움 |
| **Discovery** | 개인 프로젝트 — 직접 만듦 |
| **First Use** | 앱 설치 → 회원가입 → 기존 캘린더(Naver, Google, TickTick) 연결 → 통합 뷰에서 모든 일정 확인 |
| **Core Loop** | 매일 아침 앱을 열어 오늘 일정 확인. 새 일정 추가/수정. 과거 일정 검색. (매일) |
| **Aha Moment** | 흩어져 있던 모든 일정이 하나의 화면에 모여 보이는 순간 — "이제 여기만 보면 되네." |
| **After** | 일정 데이터가 이 앱에 축적됨. 과거 회고, 패턴 파악 가능 |
| **Return** | 초대 코드를 공유하고 그룹 형성 → 그룹 일정 열람이 일상 루틴에 편입 |

## Principles

### 데이터 조작의 자유 (NON-NEGOTIABLE)
일정의 추가, 편집, 삭제가 최소한의 마찰로 빠르고 자유롭게 이루어져야 한다. CRUD에 불필요한 단계나 확인 과정을 넣지 않는다.

### 데이터 소유권 (NON-NEGOTIABLE)
내 일정 데이터는 내가 소유한다. 특정 플랫폼에 lock-in 되지 않으며, 언제든 데이터를 내보내거나 이동할 수 있어야 한다.

## Boundaries

**This is NOT:**
- 업무용 협업 캘린더가 아니다
- 기존 캘린더의 대체제가 아니다 — 기존 캘린더들을 통합하는 허브다

## Success

**MVP:** 외부 캘린더 양방향 동기화 + 통합 뷰 + 과거 일정 검색 + 그룹 공유가 동작하는 모바일 앱
**Metric:** 개인 만족도 — 일정 확인을 위해 여러 앱을 오갈 필요가 없어지는가
**Leading Indicator:** 매일 아침 이 앱을 첫 번째로 여는가 — 다른 캘린더 앱을 먼저 열게 되면 통합이 부족하다는 신호

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Naver Calendar 공식 API 없음 — CalDAV/ICS 비공식 경로에 의존 | Naver가 경로를 막으면 동기화 불가 | 단방향 import(ICS export 파일)를 fallback으로 유지 |
| 1인 개발 — 유지보수 병목 | 기능 추가/버그 수정 속도 제한 | 스코프를 소규모 그룹으로 한정, 복잡한 기능 지양 |
| 그룹 구성원 채택 — 기존 앱 관성 | 구성원이 새 앱 설치를 거부하면 핵심 가치 반감 | 최소 마찰 온보딩(초대 코드만으로 합류), 기존 캘린더 계속 사용 가능 |

## Assumptions

- Naver Calendar의 CalDAV/ICS 경로가 계속 유지될 것 — if wrong: Naver 동기화 불가 → response: ICS 파일 수동 import fallback
- Google Calendar API 무료 쿼터가 소규모 그룹 트래픽에 충분할 것 — if wrong: 쿼터 초과 → response: 동기화 주기를 늘리거나 Webhook 중심으로 전환
- 그룹 구성원이 별도 앱을 설치할 의향이 있을 것 — if wrong: 채택 실패 → response: Web 버전으로 설치 없이 접근 가능하게
- Tailscale Funnel이 외부 접근용으로 안정적일 것 — if wrong: 외부 접속 불안정 → response: Fly.io나 VPS로 전환

## Key Decisions

| Decision | Alternatives Considered | Why This Path |
|----------|------------------------|---------------|
| Flutter (크로스 플랫폼 클라이언트) | React Native, Swift+Kotlin 네이티브 | iOS/Android/Mac/Web을 하나의 코드베이스로. 1인 개발에서 네이티브 이중 유지보수 불가 |
| Node.js + TypeScript (백엔드) | Go, Python | 외부 캘린더 API 연동(OAuth, SDK, Webhook) 생태계가 가장 풍부. 비동기 I/O로 동기화 처리에 자연스러움 |
| PostgreSQL + Prisma | SQLite, MongoDB | 관계형 데이터(일정, 그룹, 캘린더 구독) + Full-text search 내장. Prisma로 타입 안전한 쿼리 |
| Tailscale Funnel (배포) | Fly.io, VPS | 홈서버에서 직접 서빙. Fly.io 무료 티어 제약 회피. Docker 이미지 그대로 사용 |
| REST API | GraphQL | 1인 개발에서 단순함 우선. 엔드포인트 수가 적어 GraphQL의 유연성이 불필요 |
| 그룹 개념 (가족 확장) | 가족 전용 | 가족뿐 아니라 동호회 등 다양한 관계에서 일정 공유 수요 존재. 개념만 확장하면 코드 변경 최소 |

## Feature Registry

| # | Feature | Priority | Depends On | Status |
|---|---------|----------|------------|--------|
| 001 | [프로젝트 스캐폴딩 및 기본 일정 CRUD API](features/001-project-scaffold-crud-api.md) | P0 | — | complete |
| 002 | [가족 그룹 및 일정 공유](features/002-family-sharing.md) | P0 | 001 | complete |
| 003 | [자동 로그인 (세션 유지)](features/003-auto-login.md) | P1 | 001 | complete |
| 004 | [위젯 인증 상태 연동](features/004-widget-auth-state.md) | P1 | 003 | complete |
| 005 | [월별 캘린더 위젯](features/005-monthly-widget.md) | P0 | 004 | complete |
| 006 | [Task 관리 (Event-Task N:1 관계)](features/006-task-management.md) | P0 | 001 | complete |
| 007 | [Google Calendar Follow (단방향 동기화)](features/007-google-calendar-follow.md) | P0 | 001, 006 | complete |
| 008 | [범용 ICS Import](features/008-ics-import.md) | P0 | 001 | complete |
| 009 | [Naver Calendar 자동 Pull](features/009-naver-calendar-pull.md) | P1 | 001, 008 | complete |
| 010 | [일정 알람 (N분 전 / 정시 알림)](features/010-event-alarm.md) | P0 | 001 | complete |
| 011 | ~~[Daily Routine (습관/루틴)](features/011-daily-routine.md)~~ | P1 | 001, 010 | deprecated → 012 흡수 |
| 012 | [반복 규칙 엔진 (Event + Task + Routine)](features/012-recurrence-engine.md) | P0 | 001, 006 | in-progress |
| 013 | [공휴일 연동 (국가별 구독)](features/013-public-holidays.md) | P1 | 001 | complete |
| 014 | [DB 클라우드 이전 및 백업 체계](features/014-cloud-db-migration.md) | P1 | 001 | complete |
| 015 | [하단 네비게이션 통일 및 커스터마이징](features/015-navigation-customization.md) | P1 | 001 | complete |
| 016 | [그룹 및 Follow/Invite 시스템](features/016-group-and-follow.md) | P1 | 001 | complete |
| 017 | [Custom Category (색상/이모지)](features/017-custom-category.md) | P2 | 001, 006 | complete |
| 018 | [Event/Task 메타데이터 (참여자, 장소, 메모)](features/018-event-task-metadata.md) | P0 | 001, 006 | complete |
| 019 | [네이티브 앱 패키징 (iOS/macOS + CI/CD)](features/019-native-app-packaging.md) | P0 | 001 | complete |
| 020 | [디자인 대개편 (상용 캘린더 리서치 기반)](features/020-design-overhaul.md) | P0 | 001, 015, 017 | complete |
| 022 | [습관 추적 (Habit Tracking)](features/022-habit-tracking.md) | P1 | 001, 006, 012 | spec |

**Technical Foundation:** [TECHNICAL.md](TECHNICAL.md)

## Operations

### Merge Strategy

| Setting | Value |
|---------|-------|
| **Strategy** | squash merge |
| **Branch naming** | `feature/NNN-slug` (know-thy-build default) |
| **Commit format** | `feat(NNN): title` |

### Deploy

| Setting | Value |
|---------|-------|
| **Method** | `scripts/deploy.sh` — 자동화된 배포 파이프라인 |
| **Target** | 홈서버 (Docker Compose) + Tailscale Funnel (외부 접근) |
| **Trigger** | 수동 (`./scripts/deploy.sh --from <branch>` 또는 `./scripts/deploy.sh`) |

파이프라인 수행 단계: Pre-flight → Squash merge + push → 서버 빌드 (docker compose) → 서버 헬스체크 → DB Migration 확인 → 에러 로그 확인 → Flutter Web 빌드 + nginx 배포 → Web 검증 → Feature 브랜치 정리

### CI/CD

| Check | Command | Blocks merge? |
|-------|---------|---------------|
| **test** | **`cd server && npm test`** (vitest) | **yes (required)** |
| native build | GitHub Actions (`Build Native Apps`) | no (post-merge) |

### Additional Gates

| Gate | Required? | Who |
|------|-----------|-----|
| know-thy-build gates (architect/designer/qa) | yes | sub-agent reviews |

## Changelog

### v3.1.0 — 2026-09-09

**What changed:**
- 가족 → 그룹 개념 확장: "가족"은 그룹의 한 유형. 동호회 등 다양한 관계도 그룹으로 일정 공유 가능
- Operations 섹션 추가 (템플릿 갭 보완): Merge Strategy, Deploy, CI/CD, Additional Gates
- Vision에 "Why:" 라인 추가 (접근법의 이유 명시)
- What We Build의 Form에 "why this form" 추가
- Feature Registry 016 중복 제거 및 번호순 정렬
- Key Decisions에 "그룹 개념 확장" 의사결정 추가

**Why:**
- 가족 공유 기능은 이미 구현되어 있으나, "가족"이라는 제약을 벗어나 동호회 등으로 확장 가능한 범용 그룹 모델이 더 자연스러움
- 업데이트된 know-thy-build 템플릿에 Operations 섹션이 추가되었으나 기존 문서에 누락

**Principles:**
- kept: 데이터 조작의 자유 — 변함없이 핵심
- kept: 데이터 소유권 — 변함없이 핵심

### v3.0.0 — 2026-08-31

**What changed:**
- 새 know-thy-build 템플릿으로 전면 개선
- Personas 섹션 추가 — primary(현규), secondary(가족) 페르소나 정의
- Competitive Landscape 섹션 추가 — 11개 서비스 심층 조사 (Aggregator, 가족 캘린더, 셀프호스팅)
- User Journey를 단계별 테이블 형식으로 재구성
- Risks & Mitigations, Assumptions, Key Decisions 섹션 추가
- Feature Registry 추가 — 기존 specs/features/ 연결
- Success에 Leading Indicator 추가
- Vision에 Core Value 명시
- 월별 뷰(기본) 반영 (구현 완료 상태)
- 배포 전략: Fly.io → Tailscale Funnel로 변경 반영

**Why:**
- know-thy-build 스킬 업데이트로 프로젝트 정의 구조가 확장됨
- 경쟁 서비스 분석을 통해 프로젝트 존재 이유를 객관적으로 검증
- 기존 문서에 없던 리스크/가정/의사결정 근거를 명시화

### v2.0.0 — 2026-04-06

**What changed:**
- 프로젝트 정체성: 가족 공유 캘린더 → 일정 통합 관리 허브 + 가족 공유
- 외부 캘린더 양방향 동기화 추가 (Naver, Google, TickTick)
- 과거 일정 검색/회고 기능 추가
- 데이터 소유권 원칙 추가

**Why:**
- 가족 공유는 문제의 일부였을 뿐, 진짜 문제는 일정이 여러 플랫폼에 흩어져 있고 lock-in 되어 있는 것
- 기존 캘린더를 완전히 대체하는 것이 아니라, 계속 사용하면서 통합하는 허브가 필요

**Principles:**
- new: 데이터 소유권 — 플랫폼 lock-in에서 벗어나려는 핵심 동기 반영

---

*Generated by know-thy-build | 2026-09-09*
