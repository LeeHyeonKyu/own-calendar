import request from 'supertest';
import app from '../src/app';
import { createTestUser, prisma } from './setup';

describe('Device Tokens API', () => {
  describe('test_45_register_token', () => {
    it('POST with valid body returns 201 and persists the token', async () => {
      // Register two users directly so we can inspect auth-path rate-limit headers.
      // /api/auth/register passes through both the globalLimiter AND the authLimiter
      // (app.ts lines 39-44 and 48-54). Guard both legacyHeaders: false booleans
      // and the skipSuccessfulRequests: true boolean.
      const authRes1 = await request(app)
        .post('/api/auth/register')
        .send({ email: 'dt-guard1@example.com', name: 'DT Guard1', password: 'password123' });
      expect(authRes1.status).toBe(201);

      const authRes2 = await request(app)
        .post('/api/auth/register')
        .send({ email: 'dt-guard2@example.com', name: 'DT Guard2', password: 'password123' });
      expect(authRes2.status).toBe(201);

      // Guard: authLimiter's legacyHeaders must be false (app.ts line 52).
      // If mutated to true, the auth path response includes X-RateLimit-* legacy headers.
      // authLimiter runs AFTER globalLimiter, so its headers overwrite — we see authLimiter's config.
      expect(authRes2.headers).not.toHaveProperty('x-ratelimit-limit');
      expect(authRes2.headers).not.toHaveProperty('x-ratelimit-remaining');
      expect(authRes2.headers).not.toHaveProperty('x-ratelimit-reset');

      // Guard: authLimiter's skipSuccessfulRequests must be true (app.ts line 53).
      // With true, successful register requests are uncounted after the response finishes,
      // so the ratelimit remaining value stays the same between consecutive registrations.
      // If mutated to false, each successful request decrements remaining.
      const remaining1 = authRes1.headers['ratelimit']?.match(/remaining=(\d+)/)?.[1];
      const remaining2 = authRes2.headers['ratelimit']?.match(/remaining=(\d+)/)?.[1];
      expect(remaining1).toBeDefined();
      expect(remaining2).toBeDefined();
      expect(remaining2).toBe(remaining1);

      const user = { ...authRes2.body, password: 'password123' };

      const res = await request(app)
        .post('/api/device-tokens')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ token: 'fcm-token-abc123', platform: 'IOS' });

      expect(res.status).toBe(201);
      expect(res.body).toHaveProperty('token', 'fcm-token-abc123');
      expect(res.body).toHaveProperty('platform', 'IOS');
      expect(res.body).toHaveProperty('userId');
      // Guard: global rate limiter's legacyHeaders must be false (app.ts line 43).
      // If the boolean is mutated to true, legacy X-RateLimit-* headers appear.
      expect(res.headers).not.toHaveProperty('x-ratelimit-limit');
      // Positive guard: draft-7 standard headers must be present.
      // If standardHeaders config is removed, these disappear.
      expect(res.headers).toHaveProperty('ratelimit-policy');
      expect(res.headers).toHaveProperty('ratelimit');
    });

    it('second identical POST also returns 201 (upsert idempotency)', async () => {
      const user = await createTestUser(app);

      const first = await request(app)
        .post('/api/device-tokens')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ token: 'fcm-token-dup', platform: 'ANDROID' });

      expect(first.status).toBe(201);

      const second = await request(app)
        .post('/api/device-tokens')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ token: 'fcm-token-dup', platform: 'ANDROID' });

      expect(second.status).toBe(201);
      expect(second.body).toHaveProperty('token', 'fcm-token-dup');
    });
  });

  describe('test_45_invalid_body_400', () => {
    it('POST with missing token returns 400 with error and details keys', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .post('/api/device-tokens')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ platform: 'IOS' });

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error');
      expect(res.body).toHaveProperty('details');
    });

    it('POST with invalid platform returns 400 with error and details keys', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .post('/api/device-tokens')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ token: 'fcm-token-xyz', platform: 'INVALID_PLATFORM' });

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error');
      expect(res.body).toHaveProperty('details');
    });

    it('POST with empty body returns 400 with error and details keys', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .post('/api/device-tokens')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({});

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error');
      expect(res.body).toHaveProperty('details');
    });
  });

  describe('test_45_idempotent_delete', () => {
    it('DELETE of own registered token returns 204', async () => {
      const user = await createTestUser(app);

      // Register the token first
      await request(app)
        .post('/api/device-tokens')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ token: 'fcm-token-del', platform: 'WEB' });

      const res = await request(app)
        .delete('/api/device-tokens/fcm-token-del')
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(204);
      // Guard: legacyHeaders: false in app.ts globalLimiter — same check on DELETE path
      expect(res.headers).not.toHaveProperty('x-ratelimit-limit');
      // Positive guard: draft-7 standard headers present on DELETE path too
      expect(res.headers).toHaveProperty('ratelimit-policy');
      expect(res.headers).toHaveProperty('ratelimit');
    });

    it('repeated DELETE of the same token returns 204', async () => {
      const user = await createTestUser(app);

      // Register the token first
      await request(app)
        .post('/api/device-tokens')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ token: 'fcm-token-repeat', platform: 'IOS' });

      // First delete
      const first = await request(app)
        .delete('/api/device-tokens/fcm-token-repeat')
        .set('Authorization', `Bearer ${user.accessToken}`);
      expect(first.status).toBe(204);

      // Second delete (already gone)
      const second = await request(app)
        .delete('/api/device-tokens/fcm-token-repeat')
        .set('Authorization', `Bearer ${user.accessToken}`);
      expect(second.status).toBe(204);
    });

    it('DELETE of a token that never existed returns 204', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .delete('/api/device-tokens/fcm-token-never-existed')
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(204);
    });
  });

  describe('test_45_scoped_delete', () => {
    it('DELETE by another user returns 204 but does not remove the original user row', async () => {
      const userA = await createTestUser(app, { email: 'usera-dt@example.com' });
      const userB = await createTestUser(app, { email: 'userb-dt@example.com' });

      // User A registers token T
      const registerRes = await request(app)
        .post('/api/device-tokens')
        .set('Authorization', `Bearer ${userA.accessToken}`)
        .send({ token: 'fcm-token-scoped', platform: 'ANDROID' });
      expect(registerRes.status).toBe(201);

      // User B tries to delete token T — gets 204 (idempotent)
      // but the deleteMany is scoped to userB's userId, so user A's row survives
      const deleteByB = await request(app)
        .delete('/api/device-tokens/fcm-token-scoped')
        .set('Authorization', `Bearer ${userB.accessToken}`);
      expect(deleteByB.status).toBe(204);

      // Prove user A's row still exists by querying the database directly
      const row = await prisma.deviceToken.findUnique({
        where: { token: 'fcm-token-scoped' },
      });
      expect(row).not.toBeNull();
      expect(row!.token).toBe('fcm-token-scoped');

      // Now user A's own delete should actually remove the row
      const deleteByA = await request(app)
        .delete('/api/device-tokens/fcm-token-scoped')
        .set('Authorization', `Bearer ${userA.accessToken}`);
      expect(deleteByA.status).toBe(204);

      // Verify the row is now truly gone
      const gone = await prisma.deviceToken.findUnique({
        where: { token: 'fcm-token-scoped' },
      });
      expect(gone).toBeNull();
    });
  });

  describe('test_45_unauth_401', () => {
    it('POST without Authorization header returns 401', async () => {
      const res = await request(app)
        .post('/api/device-tokens')
        .send({ token: 'fcm-token-unauth', platform: 'IOS' });

      expect(res.status).toBe(401);
      expect(res.body).toHaveProperty('error');
      expect(typeof res.body.error).toBe('string');
    });

    it('DELETE without Authorization header returns 401', async () => {
      const res = await request(app)
        .delete('/api/device-tokens/fcm-token-unauth');

      expect(res.status).toBe(401);
      expect(res.body).toHaveProperty('error');
      expect(typeof res.body.error).toBe('string');
    });
  });
});
