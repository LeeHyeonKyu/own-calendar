<!-- factory-lessons:v1 role=factory-builder max=12 -->
# Lessons — factory-builder

Read this file as a checklist before you start. Entries are appended by the retro job only
(`- [L-YYYY-MM-DD-NN] <check sentence> — 근거: <run links>`); integrity rejects other edits.
- [L-2026-09-27-01] When `files_expected` is defined in the plan handoff, run `git diff --name-only` against that list before declaring the implementation complete; any file in the diff that is not in `files_expected` and not covered by a `dissent_log` entry or an explicit in-diff 'Scope change' disclosure must be res…
  근거: runs/9.md, runs/31.md. 인용: 0회.
- [L-2026-09-27-02] When a `done_when` item claims a behavior for multiple sources or paths (e.g. 'both source files', 'either X or Y', 'any path in...'), write at least one test assertion that exercises each source/path independently and verify each one reaches the code under test; if all failure-injection evidence g…
  근거: runs/9.md, runs/31.md. 인용: 0회.
