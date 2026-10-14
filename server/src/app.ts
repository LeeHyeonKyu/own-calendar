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
import categoryRoutes from './routes/categories';
import deviceTokenRoutes from './routes/device-tokens';
import userSettingsRoutes from './routes/user-settings';
import naverRoutes from './routes/naver';
import holidayRoutes from './routes/holidays';
import versionRoutes from './routes/version';

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

// Global rate limiter — everyone hitting the API.
// In test mode the limit is raised so the ~350 supertest requests across the full
// suite do not cross the threshold and cause 429s (root cause of #91 flakiness).
// Production/development keep the original 300-request budget.
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: config.nodeEnv === 'test' ? 10000 : 300,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
});
app.use(globalLimiter);

// Stricter limiter for authentication and family-join brute force.
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
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
app.use('/api/categories', categoryRoutes);
app.use('/api/device-tokens', deviceTokenRoutes);
app.use('/api/user-settings', userSettingsRoutes);
app.use('/api/naver', naverRoutes);
app.use('/api/holidays', holidayRoutes);
app.use('/api/version', versionRoutes);

app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal server error' });
});

export default app;
