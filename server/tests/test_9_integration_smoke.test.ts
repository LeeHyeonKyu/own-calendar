/**
 * Smoke test for the server integration gate (issue #9, M2 promotion).
 *
 * Proves the integration infrastructure works end-to-end:
 * - test-compose Postgres is reachable
 * - Prisma client can query the DB
 * - Express app boots and responds to HTTP
 * - A full create → read cycle through the HTTP surface succeeds
 */
import request from 'supertest';
import app from '../src/app';
import { prisma, createTestUser } from './setup';

describe('test_9_integration_smoke', () => {
  it('health endpoint responds with status ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });

  it('database is reachable via Prisma', async () => {
    // A raw query that returns a result proves the DB connection is live
    const result = await prisma.$queryRaw<Array<{ v: number }>>`SELECT 1 AS v`;
    expect(result[0].v).toBe(1);
  });

  it('full HTTP create-read cycle succeeds', async () => {
    // Register a user (creates user + default calendar in DB)
    const user = await createTestUser(app, {
      email: 'smoke@integration.test',
      name: 'Smoke Test',
    });
    expect(user.accessToken).toBeDefined();

    // Read back via authenticated endpoint
    const meRes = await request(app)
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${user.accessToken}`);
    expect(meRes.status).toBe(200);
    expect(meRes.body.user.email).toBe('smoke@integration.test');
  });
});
