import request from 'supertest';
import app from '../src/app';
import { createTestUser } from './setup';

describe('Auth API', () => {
  describe('POST /api/auth/register', () => {
    it('creates user with default calendar and returns tokens', async () => {
      const res = await request(app).post('/api/auth/register').send({
        email: 'new@example.com',
        name: 'New User',
        password: 'password123',
      });

      expect(res.status).toBe(201);
      expect(res.body.user).toBeDefined();
      expect(res.body.user.email).toBe('new@example.com');
      expect(res.body.user.name).toBe('New User');
      expect(res.body.accessToken).toBeDefined();
      expect(res.body.refreshToken).toBeDefined();
      // password should not be in response
      expect(res.body.user.passwordHash).toBeUndefined();
    });

    it('returns 409 for duplicate email', async () => {
      await createTestUser(app, { email: 'dup@example.com' });

      const res = await request(app).post('/api/auth/register').send({
        email: 'dup@example.com',
        name: 'Another User',
        password: 'password123',
      });

      expect(res.status).toBe(409);
      expect(res.body.error).toBeDefined();
    });

    it('returns 400 for invalid data', async () => {
      const res = await request(app).post('/api/auth/register').send({
        email: 'not-an-email',
        name: '',
        password: '12',
      });

      expect(res.status).toBe(400);
    });
  });

  describe('POST /api/auth/login', () => {
    it('returns tokens for correct credentials', async () => {
      await createTestUser(app);

      const res = await request(app).post('/api/auth/login').send({
        email: 'test@example.com',
        password: 'password123',
      });

      expect(res.status).toBe(200);
      expect(res.body.user).toBeDefined();
      expect(res.body.user.email).toBe('test@example.com');
      expect(res.body.accessToken).toBeDefined();
      expect(res.body.refreshToken).toBeDefined();
    });

    it('returns 401 for wrong password', async () => {
      await createTestUser(app);

      const res = await request(app).post('/api/auth/login').send({
        email: 'test@example.com',
        password: 'wrongpassword',
      });

      expect(res.status).toBe(401);
      expect(res.body.error).toBeDefined();
    });
  });

  describe('POST /api/auth/refresh', () => {
    it('returns new token pair for valid refresh token', async () => {
      const user = await createTestUser(app);

      const res = await request(app).post('/api/auth/refresh').send({
        refreshToken: user.refreshToken,
      });

      expect(res.status).toBe(200);
      expect(res.body.accessToken).toBeDefined();
      expect(res.body.refreshToken).toBeDefined();
      // New refresh token should be different (rotation)
      expect(res.body.refreshToken).not.toBe(user.refreshToken);
    });

    it('returns 401 when using already-rotated token', async () => {
      const user = await createTestUser(app);

      // Use the refresh token once (rotation)
      await request(app).post('/api/auth/refresh').send({
        refreshToken: user.refreshToken,
      });

      // Try using the old token again
      const res = await request(app).post('/api/auth/refresh').send({
        refreshToken: user.refreshToken,
      });

      expect(res.status).toBe(401);
    });
  });

  describe('POST /api/auth/logout', () => {
    it('invalidates the refresh token', async () => {
      const user = await createTestUser(app);

      const logoutRes = await request(app).post('/api/auth/logout').send({
        refreshToken: user.refreshToken,
      });

      expect(logoutRes.status).toBe(204);

      // Try using the token after logout
      const refreshRes = await request(app).post('/api/auth/refresh').send({
        refreshToken: user.refreshToken,
      });

      expect(refreshRes.status).toBe(401);
    });
  });

  describe('GET /api/auth/me', () => {
    it('returns current user for a valid access token', async () => {
      const created = await createTestUser(app, {
        email: 'me@example.com',
        name: 'Me User',
      });

      const res = await request(app)
        .get('/api/auth/me')
        .set('Authorization', `Bearer ${created.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.user).toBeDefined();
      expect(res.body.user.id).toBe(created.user.id);
      expect(res.body.user.email).toBe('me@example.com');
      expect(res.body.user.name).toBe('Me User');
      expect(res.body.user.passwordHash).toBeUndefined();
    });

    it('returns 401 when Authorization header is missing', async () => {
      const res = await request(app).get('/api/auth/me');
      expect(res.status).toBe(401);
      expect(res.body.error).toBeDefined();
    });

    it('returns 401 for an invalid access token', async () => {
      const res = await request(app)
        .get('/api/auth/me')
        .set('Authorization', 'Bearer not.a.real.token');
      expect(res.status).toBe(401);
    });
  });
});
