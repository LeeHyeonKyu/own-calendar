<!-- factory-lessons:v1 role=factory-builder max=12 -->
# Lessons — factory-builder

Read this file as a checklist before you start. Entries are appended by the retro job only
(`- [L-YYYY-MM-DD-NN] <check sentence> — 근거: <run links>`); integrity rejects other edits.
- [L-2026-09-27-01] 핸드오프 전에 `git diff --name-only`의 모든 경로가 plan handoff의 `files_expected`에 있는지 한 줄씩 대조한다 — 없는 경로가 있으면 PR 본문 Scope change 섹션에 경로와 사유를 적거나 그 파일 없이 구현을 리팩터링한다. 사유 없이 범위를 벗어난 diff는 spec-conformance에서 reject되어 rework 라운드를 추가한다.
  근거: runs/9.md, runs/31.md. 인용: 0회.
- [L-2026-09-27-02] done_when의 rubric 문구와 테스트 단언을 한 줄씩 대조한다 — rubric이 '앞에 나온다(before)'고 했으면 순서(order)를 단언하고 근접성(proximity)으로 대체하지 않는다, rubric이 특정 실패 모드를 지목했으면 그 모드를 정확히 재현한다. rubric 문구와 단언 사이에 간격이 있으면 spec-conformance가 reject한다.
  근거: runs/3.md, runs/9.md. 인용: 0회.
