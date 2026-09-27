<!-- factory-lessons:v1 role=factory-builder max=12 -->
# Lessons — factory-builder

Read this file as a checklist before you start. Entries are appended by the retro job only
(`- [L-YYYY-MM-DD-NN] <check sentence> — 근거: <run links>`); integrity rejects other edits.
- [L-2026-09-27-01] When the plan's files_expected lists specific paths, run `git diff --name-only` against the list before requesting verify -- if any path in the diff is not in files_expected and no dissent_log entry justifies the addition, remove the file or inline its logic into an authorized file.
  근거: runs/9.md, runs/31.md. 인용: 0회.
- [L-2026-09-27-02] After writing a test to prove a done_when criterion, remove or negate the artifact the criterion describes (e.g., delete the warning text, disable the endpoint) and re-run the test -- if the test still passes, it is vacuous and does not prove the done_when; rewrite it so it fails without the artifa…
  근거: runs/3.md, runs/9.md. 인용: 0회.
