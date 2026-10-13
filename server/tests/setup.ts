import dotenv from 'dotenv';
dotenv.config();

// SAFETY: Never run tests against production database.
// Tests use deleteMany() which wipes all data.
const dbUrl = process.env.DATABASE_URL || '';
if (!dbUrl.includes('_test') && !dbUrl.includes('test') && !process.env.ALLOW_TEST_ON_PROD) {
  // Override to test database by appending _test suffix
  const testDbUrl = dbUrl.replace(/\/([^/?]+)(\?|$)/, '/$1_test$2');
  process.env.DATABASE_URL = testDbUrl;
  console.warn(`[TEST SAFETY] Redirected to test DB: ${testDbUrl.replace(/:[^:@]+@/, ':***@')}`);
}

import { PrismaClient } from '../src/generated/prisma/client';
import request from 'supertest';

const prisma = new PrismaClient();

beforeEach(async () => {
  // Double-check: abort if connected to production DB
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
  return { ...res.body, password: userData.password };
}

export { prisma };
