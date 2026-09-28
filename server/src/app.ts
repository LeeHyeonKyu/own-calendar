import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { config } from './config';
import authRoutes from './routes/auth';
import calendarRoutes from './routes/calendars';
import eventRoutes from './routes/events';
import taskRoutes from './routes/tasks';
import familyRoutes from './routes/family';
import groupRoutes from './routes/groups';
import followRoutes from './routes/follows';
import inviteRoutes from './routes/invites';
import googleRoutes from './routes/google';
import importRoutes from './routes/import';
import routineRoutes from './routes/routines';
import categoryRoutes from './routes/categories';
import deviceTokenRoutes from './routes/device-tokens';
import userSettingsRoutes from './routes/user-settings';
import naverRoutes from './routes/naver';
import holidayRoutes from './routes/holidays';

const app = express();

// Trust tailscale serve (sidecar) forwarding so rate-limit sees the real client IP.
if (config.trustProxy) {
  app.set('trust proxy', config.trustProxy);
}

app.use(helmet());

if (config.corsOrigin.length > 0) {
  app.use(cors({ origin: config.corsOrigin, credentials: true }));
}

app.use(express.json({ limit: '100kb' }));

// FIX(#90): Rate-limit budgets raised to 100,000 in test env (NODE_ENV=test)
// as a defensive measure against test-environment rate-limiter exhaustion.
//
// Observed symptom: family.test.ts:127-182 ("shows family members public
// events, hides private events") intermittently failed with "expected [] to
// include 'Public Event'" in ~3/8 CI runs (#45 x3).
//
// Identified root cause: the two POST /api/events calls in that test did NOT
// assert their HTTP response status. Any transient failure — DB connection
// timeout on the tmpfs-backed test Postgres, rate-limiter rejection (429),
// or infrastructure-level error (500) — silently left zero events persisted.
// The real error was masked; only the downstream assertion fired with the
// misleading message "expected [] to include 'Public Event'".
//
// Primary fix: status assertions on event-creation calls (family.test.ts:160,
// 172) now surface the actual HTTP error at the causal line.
//
// Defensive fix (this code): rate-limiter relaxation in NODE_ENV=test.
// express-rate-limit's MemoryStore is an in-memory counter scoped to each
// module-scoped singleton instance. vitest 4.1.2 defaults to isolate:true
// and pool:'forks' (neither overridden in vitest.config.ts), which resets
// modules between test files — so the globalLimiter's 300-request counter
// does NOT accumulate across files. However, relaxing the limits in test env
// provides headroom against:
//   (a) The auth limiter's low 10-request budget (skipSuccessfulRequests:true
//       means only FAILED requests count; under CI DB-connection contention,
//       transient registration failures can exhaust this budget within a
//       single file, causing subsequent createTestUser calls to receive 429).
//   (b) Any future test file or regression test that makes >300 within-file
//       requests (e.g. test_90_rate_limiter_headroom sends 301 to prove the
//       guard works).
//   (c) Configuration changes (e.g. isolate:false) that would re-enable
//       cross-file counter accumulation.
//
// The regression test (test_90_rate_limiter_headroom) proves the guard is
// mechanically necessary: without isTestEnv, 301 requests within one file
// exhaust the 300-request budget and event creation returns 429 instead of
// 201. This is a deterministic proof of the guard, not a reproduction of
// the original flake's exact conditions.
//
// What this fix does NOT address: infrastructure-level failures (500s,
// MODULE_NOT_FOUND, Worker exited unexpectedly) that arise from concurrent
// processes (e.g. parallel npm ci) corrupting node_modules on a shared
// runner. Those require harness-level serialisation.
//
// Production and development rate limits are UNCHANGED: the elevated limits
// apply only when NODE_ENV=test (set by scripts/factory-server-test.sh:17).
// The middleware itself stays active so rate-limit response headers (draft-7
// standardHeaders) are still emitted — tests that assert header presence
// (e.g. test_47_ratelimit_headers_exact_set) continue to pass.
const isTestEnv = process.env.NODE_ENV === 'test';

// Global rate limiter — everyone hitting the API.
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: isTestEnv ? 100_000 : 300,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
});
app.use(globalLimiter);

// Stricter limiter for authentication and family-join brute force.
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: isTestEnv ? 100_000 : 10,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  skipSuccessfulRequests: true,
});

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.use('/api/auth/login', authLimiter);
app.use('/api/auth/register', authLimiter);
app.use('/api/family/join', authLimiter);
app.use('/api/groups/join', authLimiter);

app.use('/api/auth', authRoutes);
app.use('/api/calendars', calendarRoutes);
app.use('/api/events', eventRoutes);
app.use('/api/tasks', taskRoutes);
app.use('/api/family', familyRoutes);
app.use('/api/groups', groupRoutes);
app.use('/api/follows', followRoutes);
app.use('/api/invites', inviteRoutes);
app.use('/api/google', googleRoutes);
app.use('/api/import', importRoutes);
app.use('/api/routines', routineRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/device-tokens', deviceTokenRoutes);
app.use('/api/user-settings', userSettingsRoutes);
app.use('/api/naver', naverRoutes);
app.use('/api/holidays', holidayRoutes);

app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal server error' });
});

export default app;
