import request from 'supertest';
import app from '../src/app';
import { createTestUser } from './setup';

describe('Calendars API', () => {
  describe('GET /api/calendars', () => {
    it('returns user calendars including default', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .get('/api/calendars')
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBeGreaterThanOrEqual(1);

      const defaultCal = res.body.find((c: any) => c.isDefault === true);
      expect(defaultCal).toBeDefined();
    });

    it('returns 401 without auth', async () => {
      const res = await request(app).get('/api/calendars');

      expect(res.status).toBe(401);
    });
  });

  describe('POST /api/calendars', () => {
    it('creates a new calendar', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .post('/api/calendars')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ name: 'Work Calendar', color: '#FF5733' });

      expect(res.status).toBe(201);
      expect(res.body.name).toBe('Work Calendar');
      expect(res.body.color).toBe('#FF5733');
      expect(res.body.isDefault).toBe(false);
    });
  });

  describe('PUT /api/calendars/:id', () => {
    it('updates own calendar', async () => {
      const user = await createTestUser(app);

      // Create a calendar to update
      const createRes = await request(app)
        .post('/api/calendars')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ name: 'Old Name' });

      const res = await request(app)
        .put(`/api/calendars/${createRes.body.id}`)
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ name: 'New Name' });

      expect(res.status).toBe(200);
      expect(res.body.name).toBe('New Name');
    });

    it('cannot update other user calendar (403 or 404)', async () => {
      const user1 = await createTestUser(app, { email: 'user1@example.com' });
      const user2 = await createTestUser(app, { email: 'user2@example.com' });

      // Create a calendar as user1
      const createRes = await request(app)
        .post('/api/calendars')
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({ name: 'User1 Cal' });

      // Try to update as user2
      const res = await request(app)
        .put(`/api/calendars/${createRes.body.id}`)
        .set('Authorization', `Bearer ${user2.accessToken}`)
        .send({ name: 'Hacked' });

      expect([403, 404]).toContain(res.status);
    });
  });

  describe('DELETE /api/calendars/:id', () => {
    it('deletes own calendar', async () => {
      const user = await createTestUser(app);

      const createRes = await request(app)
        .post('/api/calendars')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ name: 'To Delete' });

      const res = await request(app)
        .delete(`/api/calendars/${createRes.body.id}`)
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(204);
    });

    it('cannot delete default calendar (400)', async () => {
      const user = await createTestUser(app);

      // Get the default calendar
      const listRes = await request(app)
        .get('/api/calendars')
        .set('Authorization', `Bearer ${user.accessToken}`);

      const defaultCal = listRes.body.find((c: any) => c.isDefault === true);

      const res = await request(app)
        .delete(`/api/calendars/${defaultCal.id}`)
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(400);
    });
  });
});
