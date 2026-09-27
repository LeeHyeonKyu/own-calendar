# Retro State

- last retro: 2026-09-27T13:58:42.189Z
- merges since last retro: 0
- current N: 1

## History (last 5)

| at | yield | n_before | n_after | needs_human_since |
| --- | --- | --- | --- | --- |
| 2026-09-27T02:14:34.266Z | 0 | 1 | 1 | 17 |
| 2026-09-27T02:35:11.352Z | 0 | 1 | 2 | 0 |
| 2026-09-27T06:00:22.254Z | 0 | 2 | 1 | 3 |
| 2026-09-27T06:16:18.892Z | 0 | 1 | 2 | 0 |
| 2026-09-27T13:58:42.189Z | 0 | 2 | 1 | 4 |

## Stats

| metric | this window | cumulative |
| --- | --- | --- |
| merged | 2 | 8 |
| review rounds avg | 1 | 1.75 |
| rounds/issue (plan/impl/review) | 1 / 3 / 1 | 1 / 2.75 / 1.75 |
| escaped defects | 0 | 6 |
| revert rate | 0.00 (0/2) | 0.00 (0/8) |
| needs-human | 4 | 29 |
| rejects by role | 없음 | correctness 2, architecture 1, spec-conformance 6, qa 1 |
| reviewer overlap | 없음 | 0.38 (5/13, runs 15) |
| unique findings by role | 없음 | correctness 4, architecture 1, spec-conformance 3 |
| qa na ratio | 0.00 (0/12 claims, na-heavy 0/2 approvals) | 0.00 (0/47 claims, na-heavy 0/6 approvals) |
| cost (usd) | 67.65 | 311.82 |
| tokens | input 6229893 / output 52762 | input 30563628 / output 452674 |
| retro cost (usd) | 1.86 | 8.82 |
| retro tokens | input 3 / output 1014 | input 17 / output 5383 |
| full retros | — | 6 |

### Rounds per issue (this window)

| issue | plan | implement | review | escaped |
| --- | --- | --- | --- | --- |
| #44 | 1 | 3 | 1 | 0 |
| #43 | 1 | 3 | 1 | 0 |

### Phase-2 gate baseline (this session)

- baseline: KTB #18 = $143 / 12 stage-runs; own-cal #3 = 4 review rounds
- frozen thresholds: escaped_defects ≤ 0, revert_rate ≤ 0.00
- rounds-per-issue exemplar: own-cal #3 = 4 review rounds (reject-heavy; caught in review, escaped_defects=0)
- must-not-recur escaped defects: KTB #18 R3 finish() regression (approve→reject flip — a post-approval escaped defect)
- gate (ADR-026): Phase 2 (plan Tasks 6, 7) starts only when, over ≥5 post-Phase-1 issues, escaped-defect rate AND revert rate are ≤ baseline while rounds-per-issue fell.

<!-- factory-retro-state:v1 -->
```json
{
  "cursor": {
    "last_retro_at": "2026-09-27T13:58:42.189Z",
    "last_record_offsets": {}
  },
  "merges_since": 0,
  "n": 1,
  "history": [
    {
      "at": "2026-09-14T16:34:23.746Z",
      "yield": 1,
      "needs_human_since": 5,
      "applied": [
        {
          "step": "harness",
          "title": "harness: promote to M2 — HTTP route surface present (express/fastify/hono/koa/next dependency, or routes-style files) but harness maturity is M1 or below",
          "issue": 9
        }
      ],
      "n_before": 1,
      "n_after": 1
    },
    {
      "at": "2026-09-27T02:14:34.266Z",
      "yield": 0,
      "needs_human_since": 17,
      "applied": [
        {
          "step": "feedback-route",
          "issues": [
            30
          ],
          "actions": [
            {
              "kind": "warning",
              "step": "feedback-route",
              "login": "LeeHyeonKyu",
              "current": "bot-hk",
              "reason": "current factory identity: bot-hk (machine user/app, viewer); older runs in this window ran under a shared identity (LeeHyeonKyu) — their human decisions are unverifiable, nothing to register"
            },
            {
              "kind": "unverifiable-decision",
              "step": "feedback-route",
              "issue": 30,
              "author": "LeeHyeonKyu",
              "reason": "shared identity — author equals a factory login; cannot distinguish a person from an agent",
              "detail": "human-decision:v1 (skill=unstick) by @LeeHyeonKyu declares `cause: factory-defect` (ktb_fix: 1.4.9) — REFUSED as evidence: @LeeHyeonKyu is also a factory login"
            },
            {
              "kind": "unverifiable-decision",
              "step": "feedback-route",
              "issue": 30,
              "author": "LeeHyeonKyu",
              "reason": "shared identity — author equals a factory login; cannot distinguish a person from an agent",
              "detail": "human-decision:v1 (skill=unstick) by @LeeHyeonKyu declares `cause: factory-defect` (ktb_fix: 1.4.11) — REFUSED as evidence: @LeeHyeonKyu is also a factory login"
            },
            {
              "kind": "unverifiable-decision",
              "step": "feedback-route",
              "issue": 30,
              "author": "LeeHyeonKyu",
              "reason": "shared identity — author equals a factory login; cannot distinguish a person from an agent",
              "detail": "human-decision:v1 (skill=unstick) by @LeeHyeonKyu declares `cause: factory-defect` (ktb_fix: 1.4.12) — REFUSED as evidence: @LeeHyeonKyu is also a factory login"
            }
          ]
        },
        {
          "step": "lessons:factory-builder",
          "added": [
            "L-2026-09-27-01",
            "L-2026-09-27-02"
          ],
          "rejected": [],
          "evicted": [],
          "cited": []
        },
        {
          "step": "publish-lessons",
          "pr": 61,
          "merged": false,
          "reason": "timeout",
          "files": [
            ".factory/lessons/factory-builder.md"
          ]
        },
        {
          "step": "harness",
          "title": "harness: promote to M2 — HTTP route surface present (express/fastify/hono/koa/next dependency, or routes-style files) but harness maturity is M1 or below",
          "skipped": "duplicate"
        }
      ],
      "n_before": 1,
      "n_after": 1
    },
    {
      "at": "2026-09-27T02:35:11.352Z",
      "yield": 0,
      "needs_human_since": 0,
      "applied": [
        {
          "step": "feedback-route",
          "issues": [
            29
          ],
          "actions": [
            {
              "kind": "warning",
              "step": "feedback-route",
              "login": "LeeHyeonKyu",
              "current": "bot-hk",
              "reason": "current factory identity: bot-hk (machine user/app, viewer); older runs in this window ran under a shared identity (LeeHyeonKyu) — their human decisions are unverifiable, nothing to register"
            },
            {
              "kind": "unverifiable-decision",
              "step": "feedback-route",
              "issue": 29,
              "author": "LeeHyeonKyu",
              "reason": "shared identity — author equals a factory login; cannot distinguish a person from an agent",
              "detail": "human-decision:v1 (skill=unstick) by @LeeHyeonKyu declares `cause: factory-defect` (ktb_fix: 1.4.9) — REFUSED as evidence: @LeeHyeonKyu is also a factory login"
            },
            {
              "kind": "unverifiable-decision",
              "step": "feedback-route",
              "issue": 29,
              "author": "LeeHyeonKyu",
              "reason": "shared identity — author equals a factory login; cannot distinguish a person from an agent",
              "detail": "human-decision:v1 (skill=unstick) by @LeeHyeonKyu declares `cause: factory-defect` (ktb_fix: 1.4.12) — REFUSED as evidence: @LeeHyeonKyu is also a factory login"
            }
          ]
        },
        {
          "step": "lessons:factory-builder",
          "added": [
            "L-2026-09-27-01",
            "L-2026-09-27-02"
          ],
          "rejected": [],
          "evicted": [],
          "cited": []
        },
        {
          "step": "publish-lessons",
          "pr": 63,
          "merged": false,
          "reason": "timeout",
          "files": [
            ".factory/lessons/factory-builder.md"
          ]
        },
        {
          "step": "harness",
          "title": "harness: promote to M2 — HTTP route surface present (express/fastify/hono/koa/next dependency, or routes-style files) but harness maturity is M1 or below",
          "skipped": "duplicate"
        }
      ],
      "n_before": 1,
      "n_after": 2
    },
    {
      "at": "2026-09-27T06:00:22.254Z",
      "yield": 0,
      "needs_human_since": 3,
      "applied": [
        {
          "step": "feedback-route",
          "issues": [
            31,
            28
          ],
          "actions": [
            {
              "kind": "warning",
              "step": "feedback-route",
              "login": "LeeHyeonKyu",
              "current": "bot-hk",
              "reason": "current factory identity: bot-hk (machine user/app, viewer); older runs in this window ran under a shared identity (LeeHyeonKyu) — their human decisions are unverifiable, nothing to register"
            },
            {
              "kind": "unverifiable-decision",
              "step": "feedback-route",
              "issue": 31,
              "author": "LeeHyeonKyu",
              "reason": "shared identity — author equals a factory login; cannot distinguish a person from an agent",
              "detail": "human-decision:v1 (skill=unstick) by @LeeHyeonKyu declares `cause: factory-defect` (ktb_fix: 1.4.14) — REFUSED as evidence: @LeeHyeonKyu is also a factory login"
            },
            {
              "kind": "unverifiable-decision",
              "step": "feedback-route",
              "issue": 31,
              "author": "LeeHyeonKyu",
              "reason": "shared identity — author equals a factory login; cannot distinguish a person from an agent",
              "detail": "human-decision:v1 (skill=unstick) by @LeeHyeonKyu declares `cause: factory-defect` (ktb_fix: 1.4.21) — REFUSED as evidence: @LeeHyeonKyu is also a factory login"
            },
            {
              "kind": "unverifiable-decision",
              "step": "feedback-route",
              "issue": 31,
              "author": "LeeHyeonKyu",
              "reason": "shared identity — author equals a factory login; cannot distinguish a person from an agent",
              "detail": "human-decision:v1 (skill=unstick) by @LeeHyeonKyu declares `cause: factory-defect` (ktb_fix: 1.4.22) — REFUSED as evidence: @LeeHyeonKyu is also a factory login"
            },
            {
              "kind": "product",
              "step": "feedback-route",
              "issue": 31,
              "count": 1
            },
            {
              "kind": "unverifiable-decision",
              "step": "feedback-route",
              "issue": 28,
              "author": "LeeHyeonKyu",
              "reason": "shared identity — author equals a factory login; cannot distinguish a person from an agent",
              "detail": "human-decision:v1 (skill=unstick) by @LeeHyeonKyu declares `cause: factory-defect` (ktb_fix: 1.4.9) — REFUSED as evidence: @LeeHyeonKyu is also a factory login"
            },
            {
              "kind": "unverifiable-decision",
              "step": "feedback-route",
              "issue": 28,
              "author": "LeeHyeonKyu",
              "reason": "shared identity — author equals a factory login; cannot distinguish a person from an agent",
              "detail": "human-decision:v1 (skill=unstick) by @LeeHyeonKyu declares `cause: factory-defect` (ktb_fix: 1.4.12) — REFUSED as evidence: @LeeHyeonKyu is also a factory login"
            },
            {
              "kind": "unverifiable-decision",
              "step": "feedback-route",
              "issue": 28,
              "author": "LeeHyeonKyu",
              "reason": "shared identity — author equals a factory login; cannot distinguish a person from an agent",
              "detail": "human-decision:v1 (skill=unstick) by @LeeHyeonKyu declares `cause: factory-defect` (ktb_fix: 1.4.21) — REFUSED as evidence: @LeeHyeonKyu is also a factory login"
            }
          ]
        },
        {
          "step": "lessons:factory-builder",
          "added": [
            "L-2026-09-27-01",
            "L-2026-09-27-02"
          ],
          "rejected": [],
          "evicted": [],
          "cited": []
        },
        {
          "step": "publish-lessons",
          "pr": 65,
          "merged": false,
          "reason": "timeout",
          "files": [
            ".factory/lessons/factory-builder.md"
          ]
        },
        {
          "step": "harness",
          "title": "harness: promote to M2 — HTTP route surface present (express/fastify/hono/koa/next dependency, or routes-style files) but harness maturity is M1 or below",
          "skipped": "duplicate"
        }
      ],
      "n_before": 2,
      "n_after": 1
    },
    {
      "at": "2026-09-27T06:16:18.892Z",
      "yield": 0,
      "needs_human_since": 0,
      "applied": [
        {
          "step": "feedback-route",
          "issues": [
            9
          ],
          "actions": [
            {
              "kind": "warning",
              "step": "feedback-route",
              "login": "LeeHyeonKyu",
              "current": "bot-hk",
              "reason": "current factory identity: bot-hk (machine user/app, viewer); older runs in this window ran under a shared identity (LeeHyeonKyu) — their human decisions are unverifiable, nothing to register"
            },
            {
              "kind": "unverifiable-decision",
              "step": "feedback-route",
              "issue": 9,
              "author": "LeeHyeonKyu",
              "reason": "shared identity — author equals a factory login; cannot distinguish a person from an agent",
              "detail": "human-decision:v1 (skill=unstick) by @LeeHyeonKyu declares `cause: factory-defect` — REFUSED as evidence: @LeeHyeonKyu is also a factory login"
            },
            {
              "kind": "unverifiable-decision",
              "step": "feedback-route",
              "issue": 9,
              "author": "LeeHyeonKyu",
              "reason": "shared identity — author equals a factory login; cannot distinguish a person from an agent",
              "detail": "human-decision:v1 (skill=unstick) by @LeeHyeonKyu declares `cause: factory-defect` (ktb_fix: 1.4.12) — REFUSED as evidence: @LeeHyeonKyu is also a factory login"
            },
            {
              "kind": "unverifiable-decision",
              "step": "feedback-route",
              "issue": 9,
              "author": "LeeHyeonKyu",
              "reason": "shared identity — author equals a factory login; cannot distinguish a person from an agent",
              "detail": "human-decision:v1 (skill=unstick) by @LeeHyeonKyu declares `cause: factory-defect` (ktb_fix: 1.4.21) — REFUSED as evidence: @LeeHyeonKyu is also a factory login"
            },
            {
              "kind": "unverifiable-decision",
              "step": "feedback-route",
              "issue": 9,
              "author": "LeeHyeonKyu",
              "reason": "shared identity — author equals a factory login; cannot distinguish a person from an agent",
              "detail": "human-decision:v1 (skill=unstick) by @LeeHyeonKyu declares `cause: factory-defect` (ktb_fix: 1.4.22) — REFUSED as evidence: @LeeHyeonKyu is also a factory login"
            },
            {
              "kind": "harness-issue",
              "step": "feedback-route",
              "issue": 9,
              "harness_issue": 66,
              "created": true,
              "appended": 0,
              "findings": 3
            },
            {
              "kind": "product",
              "step": "feedback-route",
              "issue": 9,
              "count": 2
            }
          ]
        },
        {
          "step": "lessons:factory-builder",
          "added": [
            "L-2026-09-27-01",
            "L-2026-09-27-02"
          ],
          "rejected": [],
          "evicted": [],
          "cited": []
        },
        {
          "step": "publish-lessons",
          "pr": 67,
          "merged": false,
          "reason": "timeout",
          "files": [
            ".factory/lessons/factory-builder.md"
          ]
        }
      ],
      "n_before": 1,
      "n_after": 2
    },
    {
      "at": "2026-09-27T13:58:42.189Z",
      "yield": 0,
      "needs_human_since": 4,
      "applied": [
        {
          "step": "feedback-route",
          "issues": [
            44,
            43
          ],
          "actions": [
            {
              "kind": "warning",
              "step": "feedback-route",
              "login": "LeeHyeonKyu",
              "current": "bot-hk",
              "reason": "current factory identity: bot-hk (machine user/app, viewer); older runs in this window ran under a shared identity (LeeHyeonKyu) — their human decisions are unverifiable, nothing to register"
            },
            {
              "kind": "product",
              "step": "feedback-route",
              "issue": 44,
              "count": 2
            },
            {
              "kind": "product",
              "step": "feedback-route",
              "issue": 43,
              "count": 2
            }
          ]
        },
        {
          "step": "lessons:factory-builder",
          "added": [
            "L-2026-09-27-01"
          ],
          "rejected": [],
          "evicted": [],
          "cited": []
        },
        {
          "step": "role:factory-builder",
          "added": [
            {
              "section": "### 나쁜 발견",
              "text": "위치: implement handoff (`files_expected = [\"client/test/charter_paths_guard_test.dart\"]`). 주장: 테스트에 공용 헬퍼가 필요해서 `files_expected` 밖의 `client/lib/testing/charter_paths.dart`를 scope-change 사유 없이 추가했다. 근거: plan이 승인하지 않은 파일은 리뷰 범위 밖이다 — spec-conformance가 reject하고 rework 라운드를 소모한다. 필요하면 handoff notes에 'Sc…"
            }
          ],
          "skipped": [],
          "deferred": []
        },
        {
          "step": "publish-lessons",
          "pr": 82,
          "merged": false,
          "reason": "timeout",
          "files": [
            ".factory/lessons/factory-builder.md",
            ".claude/agents/factory-builder.md"
          ]
        }
      ],
      "n_before": 2,
      "n_after": 1
    }
  ],
  "candidates": {
    "lessons": [
      {
        "role": "correctness",
        "text": "dw4의 파괴 경고 가드가 fail-closed가 아니다 — README에서 경고를 통째로 지우고 무해한 셋업 문장으로 바꿔도 5개 테스트가 전부 통과한다. 이 변경에서 유일하게 데이터 안전과 직결된 단언이 아무것도 지키지 못한다.",
        "runs": [
          3
        ],
        "source": "must_fix"
      },
      {
        "role": "correctness",
        "text": "`## Run`의 prerequisite가 가리키는 docs/TECHNICAL.md에는 환경변수가 한 글자도 없다 — 실제 목록이 담긴 server/.env.example이 바로 옆에 있는데도 README가 언급하지 않아, 독자는 README를 따라가서 서버를 띄울 수 없다. 라운드1에서 나는 이를 '스펙이 그렇게 지정했으므로 비차단'으로 낮춰 잡았으나, 가드를 건드리지 않고 README 한 줄만으로 고칠 수 있음을 실측해 판단을 바꾼다.",
        "runs": [
          3
        ],
        "source": "must_fix"
      },
      {
        "role": "correctness",
        "text": "The published client run command connects to the maintainer's live production API, not to the local server that the same section (README.md:33-37) just told the reader to start. Following `## Run` literally makes a new contributor register accounts and write calendar rows into the production database, while their freshly started local server sits idle.",
        "runs": [
          3
        ],
        "source": "must_fix"
      },
      {
        "role": "correctness",
        "text": "`cd server && npm ci && npm run dev` cannot bring the server up on a fresh clone: it omits the Prisma migration (and, empirically here, the Prisma client generation) that both of the repo's own working recipes run. With no `prisma migrate deploy`/`npm run db:migrate` the tables never exist, so every request fails and `cd server && npm test` — the command the new destructive warning guards — cannot even reach the deleteMany() it warns about.",
        "runs": [
          3
        ],
        "source": "must_fix"
      },
      {
        "role": "architecture",
        "text": "`## Run`'s client command `cd client && flutter pub get && flutter run` points a new contributor's build at the LIVE production API, and contradicts the server command three lines below it. The repository's build-config mechanism for this is `client/config/{dev,prod}.json` + `--dart-define-from-file`; the README is now the only place in the repo that publishes the bare form, so the entry-point document teaches the one usage that bypasses the config files and mutates the family's real calendar.",
        "runs": [
          3
        ],
        "source": "must_fix"
      },
      {
        "role": "spec-conformance",
        "text": "dw4's own sentence requires the warning to appear 'Before a reader can act on the server test command,' but the guard test only checks symmetric adjacency (`(i - commandIndex).abs() <= proximity`, proximity=6), and the merged README actually places the destructive warning *after* the fenced `cd server && npm test` block, not before it. The test is green despite the artifact violating the literal ordering the done_when text promises — a direct text-vs-test-vs-artifact mismatch, not a stylistic quibble.",
        "runs": [
          3
        ],
        "source": "must_fix"
      },
      {
        "role": "spec-conformance",
        "text": "File outside handoffs.plan.files_expected was added with no in-diff Scope change justification.",
        "runs": [
          9
        ],
        "source": "must_fix"
      },
      {
        "role": "spec-conformance",
        "text": "dw3 requires 'The changeset adds only client/test/charter_paths_guard_test.dart; no other file is created or modified' (rubric: 'git diff --name-only against main shows exactly one path'), and files_expected = [\"client/test/charter_paths_guard_test.dart\"] exactly. The issue body's own Done-when #3 says the same thing verbatim. The diff adds a second file, client/lib/testing/charter_paths.dart (120 lines), which is outside files_expected and outside any dissent_log/open_risk carve-out — the plan's open_risks discuss regex/vacuous-pass and TOML-parsing risk, never a prove-test implementation-counterpart need. The builder's own implement handoff self-reports this as a violation ('accepted-with-reservations') rather than claiming it is in scope, and qa's round-1 must_fix (qa1) independently reached the identical finding from a live git diff run. Three independent readings (plan text, builder's own admission, qa's live command) converge on the same fact: this is not an ambiguous scope call, it is a stated single-file constraint that the diff violates.",
        "runs": [
          31
        ],
        "source": "must_fix"
      },
      {
        "role": "qa",
        "text": "The changeset touches two files, not one. Issue #31's own Done-when #3 says \"Diff touches only client/test/charter_paths_guard_test.dart\" and the issue body's What section says \"New client/test/charter_paths_guard_test.dart only\". done_when dw3's rubric is explicit: \"git diff --name-only against main shows exactly one path: client/test/charter_paths_guard_test.dart.\" That is not what the repo shows.",
        "runs": [
          31
        ],
        "source": "must_fix"
      },
      {
        "role": "spec-conformance",
        "text": "dw2's persisted evidence exercises a different failure mode than dw2's own text/rubric require, and the plan's named check mechanism for dw2 structurally cannot produce the proof dw2 describes -- the done_when is unproven by any tracked artifact across two review rounds.",
        "runs": [
          9
        ],
        "source": "must_fix"
      },
      {
        "role": "spec-conformance",
        "text": "dw2's text ('When any path listed in either source file is renamed or removed...') and dw4's text ('The test exits non-zero if either source file (CHARTER.md NEVER_AUTOMATE or harness.toml [load_bearing].paths) yields zero extractable paths') both make a universal claim about BOTH source files, but every piece of failure-injection evidence collected for both ids exercises the CHARTER.md-side code path only. The harness.toml-side failure machinery has never been triggered and observed to fail correctly by anyone.",
        "runs": [
          31
        ],
        "source": "must_fix"
      },
      {
        "role": "spec-conformance",
        "text": "This diff adds a file outside files_expected (files_expected = [server/docker-compose.test.yml, scripts/factory-server-test.sh, .factory/harness.toml]) with no in-diff 'Scope change' disclosure, unlike the other two out-of-scope files in this same commit which each carry one. Lens 2 requires reject for silently-widened diffs, and re-verification this round confirms the asymmetry is real and unchanged.",
        "runs": [
          9
        ],
        "source": "must_fix"
      }
    ],
    "examples": [],
    "flaky": [],
    "needs_human": [
      {
        "issue": 3,
        "reason": "review verification failed — review round 4 > K=3",
        "at": "2026-09-14T16:31:40Z"
      },
      {
        "issue": 9,
        "reason": "review rounds exhausted (K=3): 1 must_fix remain",
        "at": "2026-09-27T04:55:14Z"
      },
      {
        "issue": 21,
        "reason": "stage artifact missing or invalid: gates RED: failing=prove-test",
        "at": "2026-09-22T07:59:40Z"
      },
      {
        "issue": 30,
        "reason": "stalled restart limit (2) reached",
        "at": "2026-09-26T19:19:49Z"
      },
      {
        "issue": 29,
        "reason": "stalled restart limit (2) reached",
        "at": "2026-09-26T19:40:22Z"
      },
      {
        "issue": 28,
        "reason": "worktree dirty after review (no-write stage): client/.factory/out/qa/28/manifest.json",
        "at": "2026-09-27T01:18:02Z"
      },
      {
        "issue": 31,
        "reason": "stage artifact missing or invalid: gates RED: failing=prove-test",
        "at": "2026-09-27T04:10:39Z"
      },
      {
        "issue": 45,
        "reason": "self-gate: not converging after 4 retries",
        "at": "2026-09-27T12:26:27Z"
      },
      {
        "issue": 44,
        "reason": "worktree dirty after review (no-write stage): node_modules/.vite/vitest/da39a3ee5e6b4b0d3255bfef95601890afd80709/results.json",
        "at": "2026-09-27T11:01:41Z"
      },
      {
        "issue": 46,
        "reason": "stage artifact missing or invalid: dissent without done_when: d1, d2",
        "at": "2026-09-27T11:46:58Z"
      }
    ]
  },
  "stats": {
    "merged": 2,
    "review_rounds_avg": 1,
    "plan_rounds_avg": 1,
    "implement_rounds_avg": 3,
    "rounds_per_issue": [
      {
        "issue": 44,
        "plan": 1,
        "implement": 3,
        "review": 1
      },
      {
        "issue": 43,
        "plan": 1,
        "implement": 3,
        "review": 1
      }
    ],
    "escaped_defects": 0,
    "escaped_defects_detail": [],
    "reverts": 0,
    "reverted_issues": [],
    "revert_rate": 0,
    "rejects_by_role": {},
    "review_runs": 2,
    "findings_total": 0,
    "overlapping_findings": 0,
    "unique_findings_by_role": {},
    "overlap_ratio": 0,
    "needs_human": 4,
    "qa_approvals": 2,
    "qa_claims_total": 12,
    "qa_na_total": 0,
    "qa_na_ratio": 0,
    "qa_na_heavy_approvals": 0,
    "usage": {
      "cost_usd": 67.646699,
      "tokens": {
        "input": 6229893,
        "output": 52762
      }
    },
    "retro_usage": {
      "cost_usd": 1.862013,
      "tokens": {
        "input": 3,
        "output": 1014
      }
    }
  },
  "stats_total": {
    "merged": 8,
    "review_rounds_avg": 1.75,
    "plan_rounds_avg": 1,
    "implement_rounds_avg": 2.75,
    "escaped_defects": 6,
    "reverts": 0,
    "reverted_issues": [],
    "revert_rate": 0,
    "rejects_by_role": {
      "correctness": 2,
      "architecture": 1,
      "spec-conformance": 6,
      "qa": 1
    },
    "review_runs": 15,
    "findings_total": 13,
    "overlapping_findings": 5,
    "unique_findings_by_role": {
      "correctness": 4,
      "architecture": 1,
      "spec-conformance": 3
    },
    "overlap_ratio": 0.38,
    "needs_human": 29,
    "qa_approvals": 6,
    "qa_claims_total": 47,
    "qa_na_total": 0,
    "qa_na_ratio": 0,
    "qa_na_heavy_approvals": 0,
    "usage": {
      "cost_usd": 311.821281,
      "tokens": {
        "input": 30563628,
        "output": 452674
      }
    },
    "retro_usage": {
      "cost_usd": 8.821845,
      "tokens": {
        "input": 17,
        "output": 5383
      }
    },
    "retros": 6
  },
  "deferred_proposals": [],
  "deletion_candidates": []
}
```
