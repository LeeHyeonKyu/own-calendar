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
import googleRoutes from './routes/google';

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
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 300,
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

app.use('/api/auth', authRoutes);
app.use('/api/calendars', calendarRoutes);
app.use('/api/events', eventRoutes);
app.use('/api/tasks', taskRoutes);
app.use('/api/family', familyRoutes);
app.use('/api/google', googleRoutes);

app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal server error' });
});

export default app;
