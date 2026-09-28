<!-- factory-lessons:v1 role=factory-builder max=12 -->
# Lessons — factory-builder

Read this file as a checklist before you start. Entries are appended by the retro job only
(`- [L-YYYY-MM-DD-NN] <check sentence> — 근거: <run links>`); integrity rejects other edits.
- [L-2026-09-28-01] 핸드오프 전, diff 안의 모든 테스트 describe/it 블록이 plan의 done_when 항목 또는 이슈 시나리오에 1:1로 대응하는지 확인한다 — files_expected 안의 테스트 파일이라도 plan에 없는 동작(app.ts 글로벌 미들웨어, rate-limiter 헤더, CORS 설정 등)을 특성화하는 단언은 scope 위반이며, Scope change 주석 없이 추가하면 spec-conformance가 reject하고 rework 라운드를 소모한다.
  근거: runs/45.md, runs/48.md. 인용: 0회.
- [L-2026-09-28-02] 다중 조건 필터(예: isPrivate:false AND visibility:PUBLIC AND ownerId:followeeId)나 다중 소스 시스템(예: CHARTER.md + harness.toml)을 검증하는 테스트를 작성할 때, 각 개별 조건/소스가 제거되면 실패할 전용 픽스처(예: 팔로우 대상이 아닌 제3자의 공개 이벤트, 대체 소스 파일의 빈 경로)를 최소 하나씩 포함한다 — 단일 데이터 출처/사용자만 사용하면 개별 조건 삭제 회귀를 잡지 못하고 리뷰에서 rework가 발생한다.
  근거: runs/49.md, runs/31.md. 인용: 0회.
