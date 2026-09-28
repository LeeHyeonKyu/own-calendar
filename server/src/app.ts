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

// FIX(#90): In test environment (NODE_ENV=test), rate-limit budgets are raised
// to effectively unlimited to eliminate one identified source of non-determinism.
//
// Mechanism addressed: express-rate-limit uses an in-memory MemoryStore that
// persists for the lifetime of each module-scoped singleton. Two separate
// limiters can cause silent failures in tests:
//
// (1) Global limiter (limit: 300, applied to ALL routes via app.use): In a
//     full-suite run (fileParallelism: false shares one Node process), if
//     vitest's module cache retains the app singleton across files, the
//     cumulative ~256 requests from 15 test files can exhaust this budget.
//     POST /api/events then receives 429 directly from globalLimiter. Because
//     the flaky test (family.test.ts:127-182) did not assert event-creation
//     HTTP status, the 429 propagated as the misleading downstream error
//     "expected [] to include 'Public Event'".
//
// (2) Auth limiter (limit: 10, skipSuccessfulRequests: true, applied only to
//     /api/auth/register, /api/auth/login, /api/family/join, /api/groups/join):
//     Under CI load (tmpfs-backed Postgres, connection-pool contention between
//     the two PrismaClient instances in tests/setup.ts vs src/lib/prisma.ts),
//     transient DB failures during user registration count against this low
//     budget. Once exhausted, createTestUser receives 429 on /api/auth/register
//     and returns no accessToken; subsequent requests with "Bearer undefined"
//     receive 401 from auth middleware, silently preventing event creation.
//
// Both pathways produce the same observed symptom: no events are persisted, and
// the downstream assertion fails with "expected [] to include 'Public Event'".
//
// Scope of this fix: this change eliminates the rate-limiter exhaustion pathway.
// It does NOT address infrastructure-level failures that produce a different
// signature (500s, MODULE_NOT_FOUND, Worker exited unexpectedly) — those arise
// from concurrent processes (e.g. parallel npm ci) corrupting node_modules on a
// shared runner, and require harness-level serialisation to fix.
// The deterministic regression test (test_90_rate_limiter_headroom) proves the
// rate-limiter mechanism by exhausting the base 300-request budget and asserting
// that event creation still returns 201, not 429.
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
