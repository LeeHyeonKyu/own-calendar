import request from 'supertest';
import app from '../src/app';
import { createTestUser } from './setup';

describe('User Settings API', () => {
  describe('GET /api/user-settings', () => {
    it('test_44_get_defaults: returns default settings for a fresh user', async () => {
      const user = await createTestUser(app);
      // Precondition: verify the test helper created the user with the expected
      // default email — catches a mutation in setup.ts that silently replaces
      // the registration email with an arbitrary string.
      expect(user.user.email).toBe('test@example.com');

      const res = await request(app)
        .get('/api/user-settings')
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(200);
      // Prisma schema default is @default(10)
      expect(res.body).toEqual({ defaultReminderMinutes: 10 });
      // app.ts globalLimiter sets legacyHeaders: false — legacy rate-limit
      // headers must be absent; flipping that boolean to true adds them.
      expect(res.headers).not.toHaveProperty('x-ratelimit-limit');
      expect(res.headers).not.toHaveProperty('x-ratelimit-remaining');
      expect(res.headers).not.toHaveProperty('x-ratelimit-reset');
    });

    it('test_44_unauthenticated_get: returns 401 without auth', async () => {
      const res = await request(app).get('/api/user-settings');

      expect(res.status).toBe(401);
      expect(res.body).toHaveProperty('error');
      // app.ts globalLimiter legacyHeaders: false — no legacy headers
      expect(res.headers).not.toHaveProperty('x-ratelimit-limit');
    });
  });

  describe('PUT /api/user-settings', () => {
    it('test_44_put_valid: updates settings with a valid body', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .put('/api/user-settings')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ defaultReminderMinutes: 30 });

      expect(res.status).toBe(200);
      expect(res.body).toEqual({ defaultReminderMinutes: 30 });
      // app.ts globalLimiter legacyHeaders: false — no legacy headers
      expect(res.headers).not.toHaveProperty('x-ratelimit-limit');
    });

    it('test_44_get_after_put: GET reflects the previously PUT value', async () => {
      const user = await createTestUser(app);

      // PUT a new value
      await request(app)
        .put('/api/user-settings')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ defaultReminderMinutes: 45 });

      // GET should reflect the updated value
      const res = await request(app)
        .get('/api/user-settings')
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body).toEqual({ defaultReminderMinutes: 45 });
    });

    it('test_44_validate_400_shape: PUT with invalid field type returns 400 with validate.ts shape', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .put('/api/user-settings')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ defaultReminderMinutes: 'not-a-number' });

      expect(res.status).toBe(400);
      // validate.ts line 7: { error: 'Validation failed', details: result.error.flatten() }
      expect(res.body).toHaveProperty('error');
      expect(res.body.error).toBe('Validation failed');
      expect(res.body).toHaveProperty('details');
      // Zod flatten() produces { formErrors: string[], fieldErrors: Record<string, string[]> }
      expect(res.body.details).toHaveProperty('formErrors');
      expect(res.body.details).toHaveProperty('fieldErrors');
      expect(Array.isArray(res.body.details.formErrors)).toBe(true);
      expect(res.body.details.fieldErrors).toHaveProperty('defaultReminderMinutes');
      expect(Array.isArray(res.body.details.fieldErrors.defaultReminderMinutes)).toBe(true);
    });
  });
});
