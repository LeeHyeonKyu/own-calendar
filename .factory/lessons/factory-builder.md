<!-- factory-lessons:v1 role=factory-builder max=12 -->
# Lessons — factory-builder

Read this file as a checklist before you start. Entries are appended by the retro job only
(`- [L-YYYY-MM-DD-NN] <check sentence> — 근거: <run links>`); integrity rejects other edits.
- [L-2026-10-02-01] commit 전 체크: git diff --name-only의 모든 변경 파일을 files_expected와 대조하고, 모든 새 assertion의 대상을 done_when id에 매핑한다 — files_expected 안의 테스트 파일이라도 done_when에 없는 기능(rate-limiter, 무관한 미들웨어)의 assertion을 추가하면 scope 위반이다
  근거: runs/9.md, runs/31.md, runs/45.md, runs/48.md. 인용: 0회.
