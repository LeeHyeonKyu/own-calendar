#!/usr/bin/env bash
# Factory gate helper: run the server integration test suite against a throwaway Postgres.
# Accepts optional vitest file/filter args (e.g. server/tests/auth.test.ts).
# Exit code is the verdict — non-zero means at least one test failed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/server"

# Deterministic dependency install (dw5): ensure server/node_modules is provisioned
# before prisma or vitest are invoked, so a fresh checkout without pre-existing
# node_modules does not rely on npx downloading packages on the fly.
npm ci --ignore-scripts

export DATABASE_URL="postgresql://postgres:testpass@127.0.0.1:5433/own_calendar_test?schema=public"
export JWT_SECRET="factory-test-secret"
export NODE_ENV="test"
# Dummy Google OAuth credentials so the /api/google/auth endpoint returns a URL
# instead of 503. These are not real credentials — they let googleapis construct
# a structurally valid OAuth URL without hitting any external service.
export GOOGLE_CLIENT_ID="factory-test-client-id"
export GOOGLE_CLIENT_SECRET="factory-test-client-secret"

npx prisma generate
npx prisma db push --skip-generate --accept-data-loss

# Strip the server/ prefix from any paths the factory passes (they arrive repo-root-relative).
args=()
for a in "$@"; do args+=("${a#server/}"); done

# Full-suite runs also write a JSON report for the factory's integration gate ([test].integration_report):
# without it the gate cannot name failing tests, so a flaky existing test (tests/family.test.ts, #45) can
# neither be classified nor excluded and every retry goes RED. File-scoped runs (test_files) skip it.
mkdir -p "$ROOT/.factory/out"
if [ ${#args[@]} -eq 0 ]; then
  exec npx vitest run --reporter=default --reporter=json --outputFile="$ROOT/.factory/out/integration.json"
else
  exec npx vitest run "${args[@]}"
fi
