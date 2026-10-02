<!-- factory-lessons:v1 role=factory-builder max=12 -->
# Lessons — factory-builder

Read this file as a checklist before you start. Entries are appended by the retro job only
(`- [L-YYYY-MM-DD-NN] <check sentence> — 근거: <run links>`); integrity rejects other edits.
- [L-2026-10-02-01] prove-test나 플레이크 조사 이슈에서 테스트가 재현하는 실패 서명(상태 코드, 에러 타입, 에러 메시지)이 이슈 본문에 보고된 서명과 일치하는지 확인한다 — 이슈가 '200 {}'를 말하는데 테스트가 429를 재현하면, 또는 이슈가 500/TypeError를 보이는데 설명이 429를 예측하면, 테스트는 다른 버그를 증명하고 있는 것이고 done_when의 'reproduces the exact condition' 류 rubric을 충족할 수 없다
  근거: runs/90.md, runs/124.md. 인용: 0회.
- [L-2026-10-02-02] 테스트 파일이 files_expected 안에 있더라도 테스트 안의 모든 assertion이 done_when의 특정 id에 매핑되는지 확인한다 — done_when에 없는 동작(rate-limit 헤더, CORS 정책, 다른 이슈의 미들웨어)을 같은 파일 안에서 검증하면 그 assertion은 리뷰 범위 밖이므로 spec-conformance가 reject하거나, 아무도 보지 않은 채 머지된다
  근거: runs/45.md, runs/48.md. 인용: 0회.
