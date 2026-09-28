<!-- factory-lessons:v1 role=factory-builder max=12 -->
# Lessons — factory-builder

Read this file as a checklist before you start. Entries are appended by the retro job only
(`- [L-YYYY-MM-DD-NN] <check sentence> — 근거: <run links>`); integrity rejects other edits.
- [L-2026-09-28-01] implement handoff를 제출하기 전에 (1) git diff --name-only의 모든 경로가 plan.files_expected에 있는지, (2) 테스트 파일 안의 모든 assertion이 plan.done_when의 어느 id에 대응하는지 확인한다 — 파일이 files_expected 안이더라도 done_when이 요구하지 않는 동작(다른 이슈의 rate-limit 헤더, 관련 없는 미들웨어 CORS 설정, 다른 route의 인가 정책 등)에 대한 assertion은 scope injection이므로 handoff…
  근거: runs/9.md, runs/31.md, runs/45.md, runs/48.md. 인용: 0회.
- [L-2026-09-28-02] 필터링(ownerId, countryCode)이나 인가(누가 accept를 호출할 수 있는지)를 검증하는 테스트를 작성할 때 반드시 해당 조건이 없을 때 결과가 달라지는 부정적 데이터(다른 사용자의 PUBLIC 이벤트, 권한 없는 호출자, 다른 필터 값을 가진 행)를 포함한다 — 긍정 데이터만으로 테스트가 통과하면 해당 조건을 삭제해도 GREEN이 유지되어 regression을 잡지 못한다
  근거: runs/46.md, runs/49.md. 인용: 0회.
