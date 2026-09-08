# Event vs Task 온톨로지: 캘린더 항목 분류 프레임워크

캘린더/일정 관리에서 Event와 Task를 어떻게 구분하는가에 대한 primary source 기반 리서치.

**Date:** 2026-09-02
**핵심 질문:** "월급날"은 Event, "코드 리뷰"는 Task, "누군가와의 만남/식사"는 뭔가?

---

## 1. iCalendar 표준 (RFC 5545) — 공식 정의

RFC 5545는 캘린더 컴포넌트를 세 가지로 구분한다:

| 컴포넌트 | 정의 | 핵심 속성 | 고유 속성 |
|----------|------|----------|----------|
| **VEVENT** | 특정 시작/종료 시간에 고정된 예정된 발생(scheduled occurrence) | DTSTART (필수), DTEND, LOCATION, ATTENDEE | — |
| **VTODO** | 완료 상태를 추적하는 행동 항목(action item) | DUE (DTEND 대신), STATUS | PERCENT-COMPLETE, COMPLETED |
| **VJOURNAL** | 시간이나 행동에 묶이지 않는 기술적 문서(descriptive documentation) | — | — |

**핵심 구분 기준:**
- **VEVENT**: "시간에 고정된 것" — 언제 발생하는가가 본질
- **VTODO**: "완료해야 하는 것" — 완료 여부가 본질. 시간은 부차적(DUE는 선택 속성)
- **VJOURNAL**: 시간도 완료도 아닌 "기록" — 메모, 일기, 참고 정보

VTODO는 `RELATED-TO` 속성으로 VEVENT에 연결할 수 있다 (예: "이 회의를 위해 준비할 것").

**Source:** [RFC 5545, Sections 3.6.1-3.6.3](https://www.rfc-editor.org/rfc/rfc5545)

---

## 2. GTD (Getting Things Done) — David Allen의 프레임워크

Allen은 캘린더를 **"hard landscape"** (단단한 지형)로 정의한다. 캘린더에는 반드시 그 시간/날짜에 해야 하는 것만 들어간다.

### 캘린더에 넣는 3가지 유형

| 유형 | 설명 | 예시 |
|------|------|------|
| **Time-specific actions** | 특정 시간에 고정된 약속/이벤트 | 14시 회의, 치과 예약 |
| **Day-specific actions** | 특정 날짜에 해야 하지만 시간은 유동적 | 보고서 제출 마감, 월급날 확인 |
| **Day-specific information** | 특정 날짜에 알아야 할 정보 | 약속 장소 안내, 동료 출장 일정 |

### Next Actions 리스트 (캘린더 밖)

"할 일"은 캘린더가 아니라 **Next Actions 리스트**에 넣는다. 컨텍스트별로 분류 (@컴퓨터, @집, @전화 등). 캘린더에 task를 넣으면 "신성한 공간"이 희석되어 캘린더의 신뢰도가 떨어진다.

**핵심 원칙:** 캘린더는 "sacrosanct" (신성불가침) — 그 날/시간에 반드시 해야 하거나 영영 못 하는 것만 넣는다.

**Source:** David Allen, *Getting Things Done* (2001, 2015 revised). 요약: [GTD in 15 minutes](https://hamberg.no/gtd), [Rufus Pollock 요약](https://rufuspollock.com/post/getting-things-done)

---

## 3. Cal Newport — Time Block Planning

Newport은 GTD와 다른 접근을 취한다:

- **Task 리스트** (Trello 등)에 구체적 행동 항목을 관리
- **캘린더**에는 회의/약속 같은 외부 고정 일정
- **Time Block** — 매일 아침, task 리스트와 캘린더를 보고 하루의 모든 시간을 블록으로 배분

Newport의 핵심 통찰: **중요한 프로젝트는 task 리스트에 넣으면 영원히 안 한다.** 캘린더에 시간 블록을 잡아야 실제로 진행된다. 즉, task가 캘린더에 "올라탈" 수 있다 — 하지만 그것은 "이 시간에 이 작업을 한다"는 event 형태로 변환된 것이지, task 자체가 캘린더에 들어간 것은 아니다.

**Source:** [Cal Newport — Projects vs. Tasks](https://calnewport.com/projects-vs-tasks-a-critical-distinction-in-productive-scheduling/), [Deep Habits: Planning Every Minute](https://calnewport.com/deep-habits-the-importance-of-planning-every-minute-of-your-work-day/), [Text File Time Blocking](https://calnewport.com/text-file-time-blocking/)

---

## 4. 주요 앱들의 실제 구분

### 4.1 Google Calendar + Google Tasks

| | Event | Task |
|--|-------|------|
| **본질** | 시간을 예약(reserve)한다 | 완료해야 할 것을 추적한다 |
| **시간** | 시작+종료 시간 필수 | 날짜/시간 선택적 |
| **협업** | 참석자 초대, RSVP, 화상회의 링크 | 없음 (개인용) |
| **속성** | 위치, 첨부파일, 반복, Busy/Free 상태 | 제목, 설명, 날짜뿐 |
| **완료** | 없음 (지나가면 끝) | 체크박스로 완료 표시 |

Google은 둘을 **완전히 별개 시스템**으로 분리한다. CalDAV에서도 VTODO를 지원하지 않는다.

**Source:** [ClickUp 비교](https://clickup.com/blog/tasks-vs-events-google-calendar/), [TechRepublic 비교](https://www.techrepublic.com/article/google-calendar-tasks-and-events-which-should-you-use/)

### 4.2 Apple Calendar + Reminders

| | Calendar | Reminders |
|--|----------|-----------|
| **설계 철학** | "시간 중심" — 시간에 고정된 약속 추적 | "작업 중심" — 해야 할 일 추적 |
| **시간** | 날짜+시간 필수 | 선택적. 날짜 없이도 존재 가능 |
| **고유 기능** | 참석자, 위치, travel time | 우선순위, 리스트/카테고리, 완료 체크, 위치 기반 알림 |
| **통합** | iOS 18+에서 Calendar 안에 Reminders 표시 | — |

Apple도 둘을 별개 앱으로 분리하되, iOS 18부터 캘린더 뷰 안에서 리마인더를 함께 볼 수 있게 통합했다.

**Source:** [MacMost 비교](https://macmost.com/which-app-to-use-calendar-vs-reminders.html), [Apple Community 토론](https://discussions.apple.com/thread/6509942)

### 4.3 Fantastical — 통합 접근

Fantastical은 event와 task(reminder)를 **하나의 뷰**에서 보여주되, 생성 시 구분한다:

- **기본값은 Event** — 타이핑하면 자동으로 이벤트 생성
- **Task 전환** — "reminder", "todo", "task", "√" 키워드로 시작하면 task
- **Event 속성**: 시간, 위치 (`at`), 참석자 (`with`)
- **Task 속성**: 우선순위 (느낌표 개수), 마감일, 리스트 배정

**핵심 설계:** "reminder는 속성 수준에서 event와 비슷하므로, 같은 계층 구조에 넣고 같은 뷰에서 보여주는 것이 합리적"

**Source:** [Fantastical Help — Adding Events and Tasks](https://flexibits.com/fantastical/help/adding-events-and-tasks), [MacStories Review](https://www.macstories.net/reviews/the-new-fantastical-review/)

### 4.4 TickTick — Task-first 통합

TickTick은 task 관리자가 캘린더를 흡수한 형태:

- 모든 task에 날짜를 부여하면 캘린더에 자동 표시
- 외부 캘린더(Google/Outlook/Apple)의 event를 import하여 task와 나란히 표시
- 캘린더 뷰에서 task를 시간 슬롯에 drag & drop → time blocking
- **양방향 동기화**: "시간 속성이 있는 모든 task"가 외부 캘린더에 event로 표시됨

**핵심 설계:** Task에 시간을 부여하면 그것이 곧 event가 된다. 경계가 유동적.

**Source:** [TickTick Calendar Quickstart](https://blog.ticktick.com/2020/11/30/ticktick-calendar-quickstart/), [TickTick Google Calendar Help](https://help.ticktick.com/articles/7055781593733922816)

### 4.5 Todoist — 의도적 분리

Todoist는 task 관리자이면서 캘린더 event를 **참조만** 한다:

- 외부 캘린더 event를 Today/Upcoming 뷰에서 task 옆에 보여줌
- 그러나 event를 Todoist DB에 저장하지 않음 — "참조(reference)만 저장"
- Task에 시간을 부여하면 외부 캘린더에 event로 sync됨

**핵심 원칙:** Event는 남의 데이터. Task만이 우리의 데이터.

**Source:** [Todoist Calendar Integration](https://www.todoist.com/help/articles/use-the-calendar-integration-rCqwLCt3G), [Todoist Google Calendar Integration](https://www.todoist.com/integrations/apps/google-calendar-integration)

### 4.6 Notion — 유연한 단일 모델

Notion은 Event/Task를 구분하지 않는다:

- 하나의 Database에 Date, Status, Category, Assignee 등 property 부여
- **Status property가 있으면 task**, 없으면 event처럼 동작
- Calendar View에서 모든 항목을 날짜 기준으로 표시
- 사용자가 property를 자유롭게 정의하므로 구분은 사용자 몫

**Source:** [Notion Calendar 가이드](https://noteforms.com/resources/how-to-use-notion-calendar), [Notion Database Templates](https://aiproductivity.ai/guides/notion-database-templates-guide/)

---

## 5. Carl Pullein의 명확한 정의

생산성 코치 Carl Pullein은 가장 간결한 구분을 제시한다:

> **Event** = "다른 사람과의 약속. 특정 장소에 특정 시간에 있겠다는 commitment."
>
> **Task** = "내가 해야 한다고 결정한 것. 언제든 할 수 있는 것."

Task를 캘린더에 넣으면 생기는 3가지 문제:
1. **유연성 상실** — 회의가 늦어지면 뒤의 task 블록이 다 밀림
2. **효과 감소** — 우선순위가 바뀌면 예정된 task를 무시하게 됨, 캘린더 신뢰도 하락
3. **심리적 부담** — 모든 분이 빼곡하면 압도감

**Source:** [Carl Pullein — Calendar Events v Tasks](https://www.carlpullein.com/podcast/calendar-events-v-tasks-and-why-tasks-do-not-belong-on-your-calendar/11/9/2023)

---

## 6. 학술 연구 — 실제 사용자 행동

### Payne (2008) — An Exploratory Study of Calendar Use

실제 사용자 연구에서 발견한 것: 사용자들은 **엄격한 구분을 하지 않는다.**

- 캘린더를 단순한 일정 도구가 아니라 **개인 정보 관리(PIM) 도구**로 사용
- Event, task, reminder, memo, 연락처 정보까지 캘린더에 섞어 넣음
- 캘린더를 **"기억 보조 도구"** 및 **"보고 도구"**로도 활용
- 결론: 실제 사용 패턴은 표준 캘린더 설계가 수용하는 것보다 훨씬 복잡하고 다양

**Source:** [Payne, "An Exploratory Study of Calendar Use" (2008)](https://arxiv.org/pdf/0809.3447)

### Graus et al. (2016) — Analyzing and Predicting Task Reminders

Cortana의 6개월 리마인더 로그를 분석:
- 사용자가 설정하는 리마인더의 일반적 카테고리 분류 체계(taxonomy) 도출
- "진행 중인 활동(ongoing)"과 "계획된 활동(planned)"의 구분 발견
- 리마인더 텍스트, 설정 시점, 알림 시점 간의 관계 분석

**Source:** [Graus et al., UMAP 2016](https://dl.acm.org/doi/10.1145/2930238.2930239)

---

## 7. 종합 프레임워크: 2축 분류

모든 소스를 종합하면, 캘린더 항목은 **두 개의 독립적 축**으로 분류할 수 있다:

### 축 1: 시간 고정성 (Time Binding)

| 등급 | 설명 | 예시 |
|------|------|------|
| **Fixed** | 특정 시간에 고정. 옮기면 의미가 변함 | 14시 회의, 치과 예약 |
| **Bounded** | 특정 날짜/기간 안에. 시간은 유동적 | 오늘 중 보고서 제출, 이번 주 코드 리뷰 |
| **Floating** | 시간 제약 없음. 언젠가 하면 됨 | 책 읽기, 정리 |

### 축 2: 완료 추적 (Completion Tracking)

| 등급 | 설명 | 예시 |
|------|------|------|
| **Completable** | 완료/미완료 상태가 있음 | 코드 리뷰, 장보기, 보고서 작성 |
| **Occurrence** | 발생하면 끝. 완료 개념 없음 | 월급날, 생일, 일몰 |
| **Participatory** | 참여하면 됨. 완료보다 출석이 본질 | 회의, 식사 약속, 콘서트 |

### 경계 사례 매핑

| 항목 | 시간 고정성 | 완료 추적 | Event? Task? |
|------|-----------|----------|-------------|
| 월급날 | Fixed | Occurrence | **Event** — 발생하는 것. 할 일이 아님 |
| 코드 리뷰 | Bounded | Completable | **Task** — 완료해야 하는 것. 특정 시간에 고정 불필요 |
| 식사 약속 | Fixed | Participatory | **Event** — 시간+장소에 고정, 참여가 본질 |
| 회의 | Fixed | Participatory | **Event** — 시간 고정 + 참여 |
| 회의 준비 | Bounded | Completable | **Task** — 회의 전까지 완료해야 하는 것 (Event에 종속) |
| 보고서 마감 | Bounded | Completable | **Task** — 완료가 본질. 마감일은 DUE |
| 생일 | Fixed | Occurrence | **Event** — 발생하는 것 |
| 선물 사기 | Bounded | Completable | **Task** — 생일 전까지 완료해야 하는 것 (Event에 종속 가능) |
| 출장 | Fixed (기간) | Participatory | **Event** — 기간에 고정, 참여 |
| 출장 준비 | Bounded | Completable | **Task** — 출장 전까지 완료. Event에 종속 |
| 운동 | Floating/Fixed | Completable | **양쪽 다 가능** — 헬스장 예약이면 Event, "오늘 운동하기"이면 Task |

### 판별 규칙 (우선순위 순)

```
1. "다른 사람과의 시간 약속인가?" → YES → Event
2. "완료/미완료 상태가 있는가?" → YES → Task
3. "특정 시간에 고정되어야 하는가?" → YES → Event
4. 그 외 → 용도에 따라 (기록 = Journal, 알림 = Reminder)
```

이 규칙으로 "누군가와의 만남/식사"는 명확히 **Event**다 — 규칙 1에 의해.

---

## 8. 앱별 설계 철학 스펙트럼

```
분리 ←─────────────────────────────────────→ 통합

Google          Apple         Fantastical    TickTick       Notion
(완전 분리)     (분리+뷰 통합)  (통합 뷰)     (Task-first    (단일 모델)
Event≠Task     Calendar≠     하나의 UI에     통합)          Property로
별개 API       Reminders     Event+Task     Task에 시간    구분
               iOS18 뷰통합   키워드 전환    = Event        사용자 정의
```

---

## Sources

### Standards
- [RFC 5545 — iCalendar](https://www.rfc-editor.org/rfc/rfc5545) — VEVENT, VTODO, VJOURNAL 정의

### Productivity Frameworks
- David Allen, *Getting Things Done* (2001, 2015) — [GTD in 15 minutes](https://hamberg.no/gtd), [Rufus Pollock 요약](https://rufuspollock.com/post/getting-things-done)
- [Cal Newport — Projects vs. Tasks](https://calnewport.com/projects-vs-tasks-a-critical-distinction-in-productive-scheduling/)
- [Cal Newport — Deep Habits: Planning Every Minute](https://calnewport.com/deep-habits-the-importance-of-planning-every-minute-of-your-work-day/)
- [Carl Pullein — Calendar Events v Tasks](https://www.carlpullein.com/podcast/calendar-events-v-tasks-and-why-tasks-do-not-belong-on-your-calendar/11/9/2023)

### App Documentation
- [Google Calendar Tasks vs Events](https://clickup.com/blog/tasks-vs-events-google-calendar/)
- [MacMost — Calendar vs Reminders](https://macmost.com/which-app-to-use-calendar-vs-reminders.html)
- [Fantastical — Adding Events and Tasks](https://flexibits.com/fantastical/help/adding-events-and-tasks)
- [TickTick Calendar Quickstart](https://blog.ticktick.com/2020/11/30/ticktick-calendar-quickstart/)
- [Todoist Calendar Integration](https://www.todoist.com/help/articles/use-the-calendar-integration-rCqwLCt3G)
- [Notion Calendar 가이드](https://noteforms.com/resources/how-to-use-notion-calendar)

### Research
- [Payne, "An Exploratory Study of Calendar Use" (2008)](https://arxiv.org/pdf/0809.3447)
- [Graus et al., "Analyzing and Predicting Task Reminders", UMAP 2016](https://dl.acm.org/doi/10.1145/2930238.2930239)
