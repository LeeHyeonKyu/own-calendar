import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit, { MemoryStore } from 'express-rate-limit';
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

// Explicit stores so tests can reset accumulated counters between files (#124).
const globalStore = new MemoryStore();
const authStore = new MemoryStore();

// Global rate limiter — everyone hitting the API.
// In test mode the limit is raised so the ~350 supertest requests across the full
// suite do not cross the threshold and cause 429s (root cause of #91 flakiness).
// Production/development keep the original 300-request budget.
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: config.nodeEnv === 'test' ? 10000 : 300,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  store: globalStore,
});
app.use(globalLimiter);

// Stricter limiter for authentication and family-join brute force.
// In test mode the limit is raised (matching globalLimiter above) so the
// ~110 createTestUser calls across the full integration suite do not trigger
// rate-limiting between test files.  The in-memory MemoryStore is never
// reset between vitest files (setup.ts only clears DB tables), so without
// this override the counter accumulates and later files get blocked (#124).
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: config.nodeEnv === 'test' ? 10000 : 10,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  skipSuccessfulRequests: true,
  store: authStore,
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

// Reset in-memory rate limiter state.  Called from tests/setup.ts beforeEach
// so counters accumulated during a prior test file do not leak into the next (#124).
export function resetRateLimitState(): void {
  globalStore.resetAll();
  authStore.resetAll();
}

export default app;
