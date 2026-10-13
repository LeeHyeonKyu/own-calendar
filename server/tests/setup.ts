import dotenv from 'dotenv';
dotenv.config();

// --- Test DB isolation guard ---
// 2026-09-09 incident: vitest inside Docker deleted all prod data.
// Auto-redirect to _test DB if DATABASE_URL does not contain "test".
const dbUrl = process.env.DATABASE_URL || '';
if (!dbUrl.includes('_test') && !dbUrl.includes('test') && !process.env.ALLOW_TEST_ON_PROD) {
  const testDbUrl = dbUrl.replace(/\/([^/?]+)(\?|$)/, '/$1_test$2');
  process.env.DATABASE_URL = testDbUrl;
  console.warn(`[TEST SAFETY] Redirected to test DB: ${testDbUrl.replace(/:[^:@]+@/, ':***@')}`);
}

import { PrismaClient } from '../src/generated/prisma/client';
import request from 'supertest';

const prisma = new PrismaClient();

beforeEach(async () => {
  // Double-check: abort if we're about to wipe a non-test DB
  const url = process.env.DATABASE_URL || '';
  if (!url.includes('_test')) {
    throw new Error(`FATAL: beforeEach would run deleteMany() against non-test DB: ${url.replace(/:[^:@]+@/, ':***@')}. Aborting.`);
  }

  await prisma.eventInvite.deleteMany();
  await prisma.follow.deleteMany();
  await prisma.event.deleteMany();
  await prisma.externalCalendarConnection.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.familyMembership.deleteMany();
  await prisma.groupMembership.deleteMany();
  await prisma.calendar.deleteMany();
  await prisma.familyGroup.deleteMany();
  await prisma.group.deleteMany();
  await prisma.user.deleteMany();
});

afterAll(async () => {
  await prisma.$disconnect();
});

export async function createTestUser(
  app: any,
  overrides?: Partial<{ email: string; name: string; password: string }>,
) {
  const userData = {
    email: overrides?.email || 'test@example.com',
    name: overrides?.name || 'Test User',
    password: overrides?.password || 'password123',
  };
  const res = await request(app).post('/api/auth/register').send(userData);
  if (res.status !== 201) {
    throw new Error(
      `createTestUser failed for ${userData.email}: expected 201, got ${res.status} — ${JSON.stringify(res.body)}`,
    );
  }
  return { ...res.body, password: userData.password };
}

export { prisma };
