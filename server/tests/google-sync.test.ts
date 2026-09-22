import request from 'supertest';
import app from '../src/app';
import { createTestUser } from './setup';

describe('Google Sync API', () => {
  describe('GET /api/google/auth', () => {
    it('returns auth URL containing accounts.google.com', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .get('/api/google/auth')
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.url).toBeDefined();
      expect(res.body.url).toContain('accounts.google.com');
    });

    it('returns 401 without auth', async () => {
      const res = await request(app).get('/api/google/auth');

      expect(res.status).toBe(401);
    });
  });

  describe('GET /api/google/connections', () => {
    it('returns empty array when no connections', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .get('/api/google/connections')
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBe(0);
    });
  });

  describe('GET /api/google/callback', () => {
    it('returns 400 without code', async () => {
      const res = await request(app).get('/api/google/callback');

      expect(res.status).toBe(400);
      // The callback is where the user's BROWSER lands after Google consent — the contract is an HTML page, not JSON.
      expect(res.headers['content-type']).toMatch(/text\/html/);
      expect(res.text).toContain('인증 정보가 누락되었습니다');
    });

    it('returns 400 without state', async () => {
      const res = await request(app)
        .get('/api/google/callback')
        .query({ code: 'test-code' });

      expect(res.status).toBe(400);
      expect(res.headers['content-type']).toMatch(/text\/html/);
      expect(res.text).toContain('인증 정보가 누락되었습니다');
    });
  });
});
