<!-- factory-lessons:v1 role=reviewer-correctness max=12 -->
# Lessons — reviewer-correctness

Read this file as a checklist before you start. Entries are appended by the retro job only
(`- [L-YYYY-MM-DD-NN] <check sentence> — 근거: <run links>`); integrity rejects other edits.
- [L-2026-10-02-01] 새 테스트가 필터·권한·분기를 검증한다고 주장하면, fixture에 그 필터에 걸려야 하는 레코드(다른 사용자의 데이터, 다른 소스의 실패)가 있는지 확인한다 — 양성 케이스만 있는 fixture에서는 필터를 지워도 테스트가 통과한다
  근거: runs/31.md, runs/49.md. 인용: 0회.
