# Event/Task 디자인 결정 기록

**Date:** 2026-09-07

## 온톨로지 정의 (확정)

### Event
- complete 개념 없음
- 날짜+시간 존재
- 반복 가능
- Task 없이 독립 존재 가능

### Task
- complete 개념 존재
- 날짜/시간 optional (있을 수도 없을 수도)
- 반복 가능
- Event 없이 독립 존재 가능

### 관계
- Task:Event = N:1
- Task는 Event에 related 될 수 있음
- 다른 날짜의 Task도 같은 Event에 연결 가능

### 예시
- Event "X의 결혼식" (10/15) → Related Tasks: "결혼식 참여"(10/15), "축의금 출금"(10/14), "결혼 선물 구매"(10/10)
- 독립 Task: "기상"(매일 6시), "일기작성"(매일 11시), "명상"(시간없음)

### 방법론
- RFC 5545 VEVENT + VTODO + RELATED-TO 모델과 일치
- Apple Calendar + Reminders 구조와 가장 유사

## 뷰 매트릭스 (확정)

|              | App (풀스크린)        | Widget (컴팩트)      |
|--------------|----------------------|---------------------|
| Daily Timeline | 24h 타임라인         | 다음 일정 미리보기    |
| Daily Task   | Task 체크리스트       | Task 진행률          |
| Weekly Timeline | 7일 컬럼 그리드     | 주간 분포 바          |
| Weekly Task  | 요일별 Task 그룹      | 주간 Task 진행       |
| Monthly      | 달력 그리드 + 리스트  | 미니 달력 + 점        |

## 시각 구분 (확정)
- Event = 파란색, 체크박스 없음
- Task = 주황색, 체크박스 있음
- Related = 보라색 링크

## 미결정
- UI 컴포넌트의 최소 단위(블록) 설계
- Obsidian/파일시스템 연동 (API pull 방식 확정, 포맷 미정)
- 생성/편집 폼 플로우
