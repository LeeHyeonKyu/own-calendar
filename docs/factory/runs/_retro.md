# Retro State

- last retro: 2026-09-28T14:04:50.119Z
- merges since last retro: 0
- current N: 2

## History (last 5)

| at | yield | n_before | n_after | needs_human_since |
| --- | --- | --- | --- | --- |
| 2026-09-27T06:16:18.892Z | 0 | 1 | 2 | 0 |
| 2026-09-27T13:58:42.189Z | 0 | 2 | 1 | 4 |
| 2026-09-27T19:26:40.682Z | 0 | 1 | 2 | 0 |
| 2026-09-28T12:24:12.049Z | 0 | 2 | 1 | 8 |
| 2026-09-28T14:04:50.119Z | 0 | 1 | 2 | 1 |

## Stats

| metric | this window | cumulative |
| --- | --- | --- |
| merged | 1 | 18 |
| review rounds avg | 1 | 1.61 |
| rounds/issue (plan/impl/review) | 1 / 1 / 1 | 1 / 2.5 / 1.61 |
| escaped defects | 0 | 11 |
| revert rate | 0.00 (0/1) | 0.00 (0/18) |
| needs-human | 1 | 38 |
| rejects by role | 없음 | correctness 2, architecture 1, spec-conformance 10, qa 3 |
| reviewer overlap | 없음 | 0.32 (6/19, runs 31) |
| unique findings by role | 없음 | correctness 4, architecture 1, spec-conformance 6, qa 2 |
| qa na ratio | 0.00 (0/5 claims, na-heavy 0/1 approvals) | 0.03 (4/149 claims, na-heavy 0/17 approvals) |
| cost (usd) | 20.49 | 562.14 |
| tokens | input 941491 / output 14429 | input 48426678 / output 674206 |
| retro cost (usd) | 2.11 | 14.69 |
| retro tokens | input 3 / output 1194 | input 26 / output 8601 |
| full retros | — | 9 |

### Rounds per issue (this window)

| issue | plan | implement | review | escaped |
| --- | --- | --- | --- | --- |
| #100 | 1 | 1 | 1 | 0 |

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
    "last_retro_at": "2026-09-28T14:04:50.119Z",
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
    },
    {
      "at": "2026-09-27T19:26:40.682Z",
      "yield": 0,
      "needs_human_since": 0,
      "applied": [
        {
          "step": "feedback-route",
          "issues": [
            48,
            47,
            46,
            45
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
              "issue": 48,
              "count": 2
            },
            {
              "kind": "product",
              "step": "feedback-route",
              "issue": 47,
              "count": 2
            },
            {
              "kind": "unverifiable-decision",
              "step": "feedback-route",
              "issue": 46,
              "author": "LeeHyeonKyu",
              "reason": "shared identity — author equals a factory login; cannot distinguish a person from an agent",
              "detail": "human-decision:v1 (skill=unstick) by @LeeHyeonKyu declares `cause: factory-defect` (ktb_fix: 1.4.26) — REFUSED as evidence: @LeeHyeonKyu is also a factory login"
            },
            {
              "kind": "product",
              "step": "feedback-route",
              "issue": 46,
              "count": 1
            },
            {
              "kind": "unverifiable-decision",
              "step": "feedback-route",
              "issue": 45,
              "author": "LeeHyeonKyu",
              "reason": "shared identity — author equals a factory login; cannot distinguish a person from an agent",
              "detail": "human-decision:v1 (skill=unstick) by @LeeHyeonKyu declares `cause: factory-defect` (ktb_fix: 1.4.27) — REFUSED as evidence: @LeeHyeonKyu is also a factory login"
            },
            {
              "kind": "ambiguous-note",
              "step": "feedback-route",
              "issue": 45,
              "fingerprint": "bc3f7c333e1ab367"
            },
            {
              "kind": "ambiguous-summary",
              "step": "feedback-route",
              "issue": 45,
              "count": 1
            },
            {
              "kind": "product",
              "step": "feedback-route",
              "issue": 45,
              "count": 3
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
          "step": "publish-lessons",
          "pr": 84,
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
      "at": "2026-09-28T12:24:12.049Z",
      "yield": 0,
      "needs_human_since": 8,
      "applied": [
        {
          "step": "feedback-route",
          "issues": [
            91,
            52,
            51,
            50,
            49
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
              "issue": 52,
              "author": "LeeHyeonKyu",
              "reason": "shared identity — author equals a factory login; cannot distinguish a person from an agent",
              "detail": "human-decision:v1 (skill=unstick) by @LeeHyeonKyu declares `cause: factory-defect` (ktb_fix: 1.4.29) — REFUSED as evidence: @LeeHyeonKyu is also a factory login"
            },
            {
              "kind": "unverifiable-decision",
              "step": "feedback-route",
              "issue": 52,
              "author": "LeeHyeonKyu",
              "reason": "shared identity — author equals a factory login; cannot distinguish a person from an agent",
              "detail": "human-decision:v1 (skill=unstick) by @LeeHyeonKyu declares `cause: factory-defect` (ktb_fix: 1.4.30) — REFUSED as evidence: @LeeHyeonKyu is also a factory login"
            },
            {
              "kind": "unverifiable-decision",
              "step": "feedback-route",
              "issue": 51,
              "author": "LeeHyeonKyu",
              "reason": "shared identity — author equals a factory login; cannot distinguish a person from an agent",
              "detail": "human-decision:v1 (skill=unstick) by @LeeHyeonKyu declares `cause: factory-defect` (ktb_fix: 1.4.29) — REFUSED as evidence: @LeeHyeonKyu is also a factory login"
            },
            {
              "kind": "unverifiable-decision",
              "step": "feedback-route",
              "issue": 51,
              "author": "LeeHyeonKyu",
              "reason": "shared identity — author equals a factory login; cannot distinguish a person from an agent",
              "detail": "human-decision:v1 (skill=unstick) by @LeeHyeonKyu declares `cause: factory-defect` (ktb_fix: 1.4.30) — REFUSED as evidence: @LeeHyeonKyu is also a factory login"
            },
            {
              "kind": "unverifiable-decision",
              "step": "feedback-route",
              "issue": 49,
              "author": "LeeHyeonKyu",
              "reason": "shared identity — author equals a factory login; cannot distinguish a person from an agent",
              "detail": "human-decision:v1 (skill=unstick) by @LeeHyeonKyu declares `cause: factory-defect` (ktb_fix: 1.4.29) — REFUSED as evidence: @LeeHyeonKyu is also a factory login"
            },
            {
              "kind": "product",
              "step": "feedback-route",
              "issue": 49,
              "count": 1
            }
          ]
        },
        {
          "step": "lessons:factory-builder",
          "added": [
            "L-2026-09-28-01",
            "L-2026-09-28-02"
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
              "text": "위치: implement handoff for #48 (files_expected includes server/tests/import.test.ts). 주장: import route의 happy-path 테스트 안에 authLimiter와 globalLimiter의 rate-limit 헤더(legacyHeaders, ratelimit-policy)를 검증하는 단언을 추가했다 — 파일 이름은 files_expected 안이므로 scope 위반이 아니라고 판단했다. 근거: rate-limit 동작은 plan의 done_when에도, …"
            }
          ],
          "skipped": [],
          "deferred": []
        },
        {
          "step": "publish-lessons",
          "pr": 99,
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
    },
    {
      "at": "2026-09-28T14:04:50.119Z",
      "yield": 0,
      "needs_human_since": 1,
      "applied": [
        {
          "step": "feedback-route",
          "issues": [
            100
          ],
          "actions": [
            {
              "kind": "warning",
              "step": "feedback-route",
              "login": "LeeHyeonKyu",
              "current": "bot-hk",
              "reason": "current factory identity: bot-hk (machine user/app, viewer); older runs in this window ran under a shared identity (LeeHyeonKyu) — their human decisions are unverifiable, nothing to register"
            }
          ]
        },
        {
          "step": "lessons:factory-builder",
          "added": [
            "L-2026-09-28-01",
            "L-2026-09-28-02"
          ],
          "rejected": [],
          "evicted": [],
          "cited": []
        },
        {
          "step": "role:factory-builder",
          "added": [
            {
              "section": "## Perspectives",
              "text": "**scope의 눈**: 내가 쓴 모든 assertion과 추가한 모든 파일을 done_when의 id와 files_expected에 1:1로 매핑할 수 있는가. 매핑할 수 없는 코드는 리뷰어가 보지 않기로 한 코드다 — 좋아 보여도 아무도 리뷰하지 않은 채 머지되는 것이다."
            }
          ],
          "skipped": [],
          "deferred": []
        },
        {
          "step": "publish-lessons",
          "pr": 102,
          "merged": false,
          "reason": "timeout",
          "files": [
            ".factory/lessons/factory-builder.md",
            ".claude/agents/factory-builder.md"
          ]
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
      },
      {
        "role": "spec-conformance",
        "text": "The diff smuggles extensive, undisclosed testing of unrelated server/src/app.ts global middleware (CORS credentials header, exact rate-limiter policy string, legacyHeaders/skipSuccessfulRequests booleans on the /api/auth/register path) into the device-tokens characterization file — none of this is in the issue's 6 enumerated scenarios, the plan's done_when (dw1-dw5) rubrics, files_expected substance, or non_goals, and it is not flagged in the diff as an approved scope change.",
        "runs": [
          45
        ],
        "source": "must_fix"
      },
      {
        "role": "spec-conformance",
        "text": "The diff adds rate-limit/mutation-guard assertions for app.ts's authLimiter/globalLimiter (legacyHeaders/ratelimit-policy headers) inside the required happy-path test for the ICS import route. This is content promised by nothing in plan.done_when, plan.non_goals, or the issue body, and it duplicates work that already has its own dedicated issue (#47) in this repo's own history — it is scope injected from an unrelated mutation-hunting activity, not characterization of the import route.",
        "runs": [
          48
        ],
        "source": "must_fix"
      },
      {
        "role": "spec-conformance",
        "text": "The issue's literal ask for the GET /holidays query schema — 'year: integer 1970–2100, month: optional integer 1–12, countryCode optional' — is a single three-field request. The countryCode third of it shipped as dead, misleading validation: it is accepted and schema-validated (malformed values correctly 400), but the handler never reads it (holidays.ts:50 destructures only `{ year, month } = parsed.data`) and holidayService.getHolidays(userId, year, month) has no countryCode parameter at all (holiday.service.ts:36). No done_when (dw1-dw5) exercises this field on the GET side — grep on server/tests/holidays.test.ts shows zero countryCode occurrences outside the POST /subscribe tests — so this literal piece of the issue's stated requirement was implemented, shipped, and never verified by anyone the plan authorized to verify it. This is Lens #6's plan-omission case: the issue asked for the field, the plan's done_when set never gated its behavior, and the diff followed that silence straight into an inert, contract-violating field (a client sending a valid countryCode filter gets zero filtering with no error, i.e., silently wrong data).",
        "runs": [
          46
        ],
        "source": "must_fix"
      },
      {
        "role": "qa",
        "text": "GET /holidays accepts and strictly validates an optional `countryCode` query parameter (2-letter upper-case regex) but the value is discarded — the handler destructures only `{ year, month }` from `parsed.data` and calls `holidayService.getHolidays(userId, year, month)`, which has no countryCode parameter at all and always returns holidays for every country the user is subscribed to. A caller who subscribes to both US and KR and requests `?year=2025&countryCode=US` gets a 200 with BOTH countries' holidays, silently unfiltered — no error, no indication the filter was ignored.",
        "runs": [
          46
        ],
        "source": "must_fix"
      },
      {
        "role": "spec-conformance",
        "text": "dw2's text says the endpoint 'returns B's public events from a PUBLIC-visibility calendar' -- i.e. the contract is that events are scoped to the specific followee (ownerId), not merely 'any PUBLIC calendar, any isPrivate:false event'. The test never creates this distinction: every fixture event in this block is created by userB, and no other user's PUBLIC-calendar event exists in the suite. `follow.service.ts` getFolloweePublicEvents filters on three predicates jointly -- `isPrivate:false`, `calendar.visibility:'PUBLIC'`, `calendar.ownerId:followeeId` -- but the test's assertions (`toContain`/`not.toContain` on titles) only exercise the first two. A regression that dropped or weakened the `calendar.ownerId: followeeId` clause (e.g. returning every PUBLIC calendar's events system-wide, leaking user C's events to A when A follows B) would still produce a response containing 'Visible Public Event' and omitting the two hidden-by-name events -- this test would keep passing while the authorization property the issue's own 'Why' section names as the point of this route ('which other users' events a person can see') silently breaks.",
        "runs": [
          49
        ],
        "source": "must_fix"
      },
      {
        "role": "qa",
        "text": "The new characterization suite calls POST /api/follows/:followId/accept exactly three times (follows.test.ts:27, 71, and inside followAndAccept reused by dw2/dw3), and in every call the bearer token belongs to the actual followee. No test in follows.test.ts, nor anywhere else in server/tests/ (repo-wide grep for `accept` confirms this), ever calls accept as an unrelated third party or as the original follower. The one authorization check that decides who may flip a PENDING follow into ACCEPTED -- and therefore who may unilaterally grant a requester visibility into someone else's events -- is completely unexercised by the shipped suite. Issue #49's own stated purpose is exactly this: 'follows.ts + follow.service.ts decide which other users' events a person can see and has no test file. It is a load-bearing path.' The accept step is the single gate that establishes every follow relationship the rest of the suite depends on, and it is the one branch of that gate nobody, including this new suite, has ever called with the wrong caller. The guard is not broken today (I confirmed it live, see evidence) -- this is a coverage gap on a security-relevant branch, not a live vulnerability -- but a future refactor could silently drop or invert this check and all 10 existing tests would stay green. Adding this case is additive to server/tests/follows.test.ts only and does not touch server/src/** or server/prisma/**, so it does not conflict with the issue's must_not constraint.",
        "runs": [
          49
        ],
        "source": "must_fix"
      },
      {
        "role": "spec-conformance",
        "text": "done_when dw1 (rubric: '5 consecutive full-suite runs are green; file-isolated runs alone do not suffice') is not established by any evidence in this PR's own record. Re-reading the qa reviewer's manifest, exit codes across their 12 documented runs are [1,0,0,0,1,1,0,0,1,0,0,0] (dw1-1..dw1-12). Every one of the 8 possible 5-run windows (1-5, 2-6, 3-7, 4-8, 5-9, 6-10, 7-11, 8-12) contains at least one failing run — there is no window of 5 consecutive clean runs anywhere in the 12 samples. qa's round-1 verified[] claims 'an unbroken final sequence of 5 (dw1-7,8,10,11,12, the intervening dw1-9 failure explained below)' — but dw1-9 sits between dw1-8 and dw1-10 in run order, so this is not an unbroken/consecutive sequence by any definition; it is 5 clean runs out of the last 6, with the 6th (dw1-9) explicitly excluded. That mischaracterization does not satisfy dw1's literal text.",
        "runs": [
          90
        ],
        "source": "must_fix"
      },
      {
        "role": "spec-conformance",
        "text": "The causal narrative in the diff (express-rate-limit MemoryStore exhaustion) does not account for the failure signature observed in the PR's own dw1 evidence. If it did, the residual failures should look like 429s (global limiter) or 401s tied specifically to auth-endpoint request volume — instead dw1-9.log shows 500s in family/events/tasks (not 429), a TypeError on an undefined calendar list in tasks.test.ts, and a 401 in holidays.test.ts paired with a trailing MODULE_NOT_FOUND/'Worker exited unexpectedly'. This is a materially different and more heterogeneous signature than 'two rate-limiter budgets get exhausted by cumulative cross-file requests.' Whatever is still causing dw1 to fail 5-in-a-row is not fully explained by, and is not demonstrably fixed by, the mechanism the comment names — so dw4's rubric ('the explanation must name the mechanism ... why the fix prevents recurrence') is not satisfiable as 'prevents recurrence' when recurrence (of some flakiness, in this same file) is still present in the PR's own evidence trail.",
        "runs": [
          90
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
      },
      {
        "issue": 52,
        "reason": "stage artifact missing or invalid: gates MISCONFIGURED: failing=none misconfigured=prove-test",
        "at": "2026-09-27T22:23:35Z"
      },
      {
        "issue": 51,
        "reason": "stage artifact missing or invalid: gates MISCONFIGURED: failing=none misconfigured=prove-test",
        "at": "2026-09-28T03:20:52Z"
      },
      {
        "issue": 49,
        "reason": "blocked (API quota/outage) — needs human",
        "at": "2026-09-28T10:51:44Z"
      },
      {
        "issue": 90,
        "reason": "lifetime cost $60.58 over 64 run(s) exceeds [budget].usd_per_issue $60 — a person raises the budget (`:proposal`), splits the issue, or closes it (wont-do); the counter spans re-queues and human retries on purpose",
        "at": "2026-09-28T12:44:06Z"
      },
      {
        "issue": 91,
        "reason": "blocked (job cancelled) — needs human",
        "at": "2026-09-28T04:52:36Z"
      }
    ]
  },
  "stats": {
    "merged": 1,
    "review_rounds_avg": 1,
    "plan_rounds_avg": 1,
    "implement_rounds_avg": 1,
    "rounds_per_issue": [
      {
        "issue": 100,
        "plan": 1,
        "implement": 1,
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
    "needs_human": 1,
    "qa_approvals": 1,
    "qa_claims_total": 5,
    "qa_na_total": 0,
    "qa_na_ratio": 0,
    "qa_na_heavy_approvals": 0,
    "usage": {
      "cost_usd": 20.485399,
      "tokens": {
        "input": 941491,
        "output": 14429
      }
    },
    "retro_usage": {
      "cost_usd": 2.111447,
      "tokens": {
        "input": 3,
        "output": 1194
      }
    }
  },
  "stats_total": {
    "merged": 18,
    "review_rounds_avg": 1.61,
    "plan_rounds_avg": 1,
    "implement_rounds_avg": 2.5,
    "escaped_defects": 11,
    "reverts": 0,
    "reverted_issues": [],
    "revert_rate": 0,
    "rejects_by_role": {
      "correctness": 2,
      "architecture": 1,
      "spec-conformance": 10,
      "qa": 3
    },
    "review_runs": 31,
    "findings_total": 19,
    "overlapping_findings": 6,
    "unique_findings_by_role": {
      "correctness": 4,
      "architecture": 1,
      "spec-conformance": 6,
      "qa": 2
    },
    "overlap_ratio": 0.32,
    "needs_human": 38,
    "qa_approvals": 17,
    "qa_claims_total": 145,
    "qa_na_total": 4,
    "qa_na_ratio": 0.03,
    "qa_na_heavy_approvals": 0,
    "usage": {
      "cost_usd": 562.138282,
      "tokens": {
        "input": 48426678,
        "output": 674206
      }
    },
    "retro_usage": {
      "cost_usd": 14.690959,
      "tokens": {
        "input": 26,
        "output": 8601
      }
    },
    "retros": 9
  },
  "deferred_proposals": [],
  "deletion_candidates": []
}
```
