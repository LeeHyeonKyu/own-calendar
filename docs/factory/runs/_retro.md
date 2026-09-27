# Retro State

- last retro: 2026-09-27T02:35:11.352Z
- merges since last retro: 0
- current N: 2

## History (last 5)

| at | yield | n_before | n_after | needs_human_since |
| --- | --- | --- | --- | --- |
| 2026-09-14T16:34:23.746Z | 1 | 1 | 1 | 5 |
| 2026-09-27T02:14:34.266Z | 0 | 1 | 1 | 17 |
| 2026-09-27T02:35:11.352Z | 0 | 1 | 2 | 0 |

## Stats

| metric | this window | cumulative |
| --- | --- | --- |
| merged | 1 | 3 |
| review rounds avg | 1 | 2 |
| rounds/issue (plan/impl/review) | 1 / 4 / 1 | 0.67 / 1.67 / 2 |
| escaped defects | 0 | 0 |
| revert rate | 0.00 (0/1) | 0.00 (0/3) |
| needs-human | 0 | 22 |
| rejects by role | 없음 | correctness 2, architecture 1, spec-conformance 1 |
| reviewer overlap | 없음 | 0.00 (0/6, runs 6) |
| unique findings by role | 없음 | correctness 4, architecture 1, spec-conformance 1 |
| qa na ratio | 없음 | 0.00 (0/19 claims, na-heavy 0/2 approvals) |
| cost (usd) | 0.00 | 204.09 |
| tokens | input 0 / output 0 | input 20380640 / output 342065 |
| retro cost (usd) | 1.28 | 3.92 |
| retro tokens | input 3 / output 621 | input 8 / output 2950 |
| full retros | — | 3 |

### Rounds per issue (this window)

| issue | plan | implement | review | escaped |
| --- | --- | --- | --- | --- |
| #29 | 1 | 4 | 1 | 0 |

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
    "last_retro_at": "2026-09-27T02:35:11.352Z",
    "last_record_offsets": {}
  },
  "merges_since": 0,
  "n": 2,
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
        "reason": "worktree dirty after review (no-write stage): .factory/harness.toml",
        "at": "2026-09-27T02:13:03Z"
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
        "reason": "stage artifact missing or invalid: dissent without done_when: d3, d4",
        "at": "2026-09-27T01:56:59Z"
      }
    ]
  },
  "stats": {
    "merged": 1,
    "review_rounds_avg": 1,
    "plan_rounds_avg": 1,
    "implement_rounds_avg": 4,
    "rounds_per_issue": [
      {
        "issue": 29,
        "plan": 1,
        "implement": 4,
        "review": 1
      }
    ],
    "escaped_defects": 0,
    "escaped_defects_detail": [],
    "reverts": 0,
    "reverted_issues": [],
    "revert_rate": 0,
    "rejects_by_role": {},
    "review_runs": 1,
    "findings_total": 0,
    "overlapping_findings": 0,
    "unique_findings_by_role": {},
    "overlap_ratio": 0,
    "needs_human": 0,
    "qa_approvals": 0,
    "qa_claims_total": 0,
    "qa_na_total": 0,
    "qa_na_ratio": 0,
    "qa_na_heavy_approvals": 0,
    "usage": {
      "cost_usd": 0,
      "tokens": {
        "input": 0,
        "output": 0
      }
    },
    "retro_usage": {
      "cost_usd": 1.281896,
      "tokens": {
        "input": 3,
        "output": 621
      }
    }
  },
  "stats_total": {
    "merged": 3,
    "review_rounds_avg": 2,
    "plan_rounds_avg": 0.67,
    "implement_rounds_avg": 1.67,
    "escaped_defects": 0,
    "reverts": 0,
    "reverted_issues": [],
    "revert_rate": 0,
    "rejects_by_role": {
      "correctness": 2,
      "architecture": 1,
      "spec-conformance": 1
    },
    "review_runs": 6,
    "findings_total": 6,
    "overlapping_findings": 0,
    "unique_findings_by_role": {
      "correctness": 4,
      "architecture": 1,
      "spec-conformance": 1
    },
    "overlap_ratio": 0,
    "needs_human": 22,
    "qa_approvals": 2,
    "qa_claims_total": 19,
    "qa_na_total": 0,
    "qa_na_ratio": 0,
    "qa_na_heavy_approvals": 0,
    "usage": {
      "cost_usd": 204.092257,
      "tokens": {
        "input": 20380640,
        "output": 342065
      }
    },
    "retro_usage": {
      "cost_usd": 3.923179,
      "tokens": {
        "input": 8,
        "output": 2950
      }
    },
    "retros": 3
  },
  "deferred_proposals": [],
  "deletion_candidates": []
}
```
