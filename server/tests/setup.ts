import dotenv from 'dotenv';
dotenv.config();

import { PrismaClient } from '../src/generated/prisma/client';
import request from 'supertest';

const prisma = new PrismaClient();

beforeEach(async () => {
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
