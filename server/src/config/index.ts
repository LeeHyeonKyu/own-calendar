import dotenv from 'dotenv';
dotenv.config();

function requireEnv(key: string): string {
  const value = process.env[key];
  if (!value || value.trim() === '') {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
}

const nodeEnv = process.env.NODE_ENV || 'development';
const isProduction = nodeEnv === 'production';

// JWT_SECRET: required in production, with a minimum length check.
let jwtSecret: string;
if (isProduction) {
  jwtSecret = requireEnv('JWT_SECRET');
  if (jwtSecret.length < 32) {
    throw new Error('JWT_SECRET must be at least 32 characters in production');
  }
} else {
  jwtSecret = process.env.JWT_SECRET || 'dev-secret';
}

// DATABASE_URL: always required so Prisma can connect.
const databaseUrl = requireEnv('DATABASE_URL');

// CORS_ORIGIN: comma-separated list. Empty = no cors (native mobile only).
const corsOrigin = (process.env.CORS_ORIGIN || '')
  .split(',')
  .map((s) => s.trim())
  .filter((s) => s.length > 0);

// TRUST_PROXY: integer hop count for express `trust proxy` setting.
// 1 = trust first proxy (tailscale serve sidecar).
const trustProxyRaw = process.env.TRUST_PROXY;
const trustProxy = trustProxyRaw ? parseInt(trustProxyRaw, 10) : 0;

export const config = {
  nodeEnv,
  isProduction,
  port: parseInt(process.env.PORT || '3000', 10),
  databaseUrl,
  trustProxy,
  corsOrigin,
  jwt: {
    secret: jwtSecret,
    accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '15m',
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d',
  },
  google: {
    clientId: process.env.GOOGLE_CLIENT_ID || '',
    clientSecret: process.env.GOOGLE_CLIENT_SECRET || '',
    redirectUri: process.env.GOOGLE_REDIRECT_URI || 'http://localhost:3000/api/google/callback',
  },
};
