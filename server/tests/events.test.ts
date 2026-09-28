import request from 'supertest';
import app from '../src/app';
import { createTestUser } from './setup';

describe('Events API', () => {
  const eventData = {
    title: 'Test Event',
    startTime: '2026-04-10T09:00:00.000Z',
    endTime: '2026-04-10T10:00:00.000Z',
  };

  async function getUserCalendarId(accessToken: string): Promise<string> {
    const res = await request(app)
      .get('/api/calendars')
      .set('Authorization', `Bearer ${accessToken}`);
    const defaultCal = res.body.find((c: any) => c.isDefault === true);
    return defaultCal.id;
  }

  describe('POST /api/events', () => {
    it('creates event in own calendar', async () => {
      const user = await createTestUser(app);
      const calendarId = await getUserCalendarId(user.accessToken);

      const res = await request(app)
        .post('/api/events')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ ...eventData, calendarId });

      expect(res.status).toBe(201);
      expect(res.body.title).toBe('Test Event');
      expect(res.body.calendarId).toBe(calendarId);
    });

    it('cannot create event in other user calendar', async () => {
      const user1 = await createTestUser(app, { email: 'ev-owner@example.com' });
      const user2 = await createTestUser(app, { email: 'ev-other@example.com' });
      const calendarId = await getUserCalendarId(user1.accessToken);

      const res = await request(app)
        .post('/api/events')
        .set('Authorization', `Bearer ${user2.accessToken}`)
        .send({ ...eventData, calendarId });

      expect([403, 404]).toContain(res.status);
    });

    it('saves isPrivate: true correctly', async () => {
      const user = await createTestUser(app);
      const calendarId = await getUserCalendarId(user.accessToken);

      const res = await request(app)
        .post('/api/events')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ ...eventData, calendarId, isPrivate: true });

      expect(res.status).toBe(201);
      expect(res.body.isPrivate).toBe(true);
    });
  });

  describe('GET /api/events', () => {
    it('returns events and filters by date range', async () => {
      const user = await createTestUser(app);
      const calendarId = await getUserCalendarId(user.accessToken);

      // Create two events at different times
      await request(app)
        .post('/api/events')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({
          title: 'April Event',
          startTime: '2026-04-10T09:00:00.000Z',
          endTime: '2026-04-10T10:00:00.000Z',
          calendarId,
        });

      await request(app)
        .post('/api/events')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({
          title: 'May Event',
          startTime: '2026-05-10T09:00:00.000Z',
          endTime: '2026-05-10T10:00:00.000Z',
          calendarId,
        });

      // Fetch only April events
      const res = await request(app)
        .get('/api/events')
        .query({
          start: '2026-04-01T00:00:00.000Z',
          end: '2026-04-30T23:59:59.000Z',
        })
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBe(1);
      expect(res.body[0].title).toBe('April Event');
    });

    it('filters by calendarId', async () => {
      const user = await createTestUser(app);
      const defaultCalId = await getUserCalendarId(user.accessToken);

      // Create a second calendar
      const calRes = await request(app)
        .post('/api/calendars')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ name: 'Work' });
      const workCalId = calRes.body.id;

      // Create events in both calendars
      await request(app)
        .post('/api/events')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ ...eventData, title: 'Default Event', calendarId: defaultCalId });

      await request(app)
        .post('/api/events')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ ...eventData, title: 'Work Event', calendarId: workCalId });

      // Filter by work calendar
      const res = await request(app)
        .get('/api/events')
        .query({ calendarId: workCalId })
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.length).toBe(1);
      expect(res.body[0].title).toBe('Work Event');
    });
  });

  describe('PUT /api/events/:id', () => {
    it('updates own event', async () => {
      const user = await createTestUser(app);
      const calendarId = await getUserCalendarId(user.accessToken);

      const createRes = await request(app)
        .post('/api/events')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ ...eventData, calendarId });

      const res = await request(app)
        .put(`/api/events/${createRes.body.id}`)
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ title: 'Updated Event' });

      expect(res.status).toBe(200);
      expect(res.body.title).toBe('Updated Event');
    });
  });

  describe('DELETE /api/events/:id', () => {
    it('deletes own event', async () => {
      const user = await createTestUser(app);
      const calendarId = await getUserCalendarId(user.accessToken);

      const createRes = await request(app)
        .post('/api/events')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ ...eventData, calendarId });

      const res = await request(app)
        .delete(`/api/events/${createRes.body.id}`)
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(204);
    });
  });

  describe('cross-user authorization (issue #91)', () => {
    it('test_91_auth_403_verified', async () => {
      // Use unique emails to avoid collisions with family.test.ts / calendars.test.ts
      const user1 = await createTestUser(app, { email: 'ev91-owner@example.com' });
      const user2 = await createTestUser(app, { email: 'ev91-intruder@example.com' });

      // Diagnostic guards: setup must have produced valid tokens
      expect(user1.accessToken).toBeDefined();
      expect(typeof user1.accessToken).toBe('string');
      expect(user2.accessToken).toBeDefined();
      expect(typeof user2.accessToken).toBe('string');

      const calendarId = await getUserCalendarId(user1.accessToken);
      expect(calendarId).toBeDefined();

      // user2 attempts to create an event in user1's calendar
      const res = await request(app)
        .post('/api/events')
        .set('Authorization', `Bearer ${user2.accessToken}`)
        .send({ ...eventData, calendarId });

      // The authorization check (calendar.ownerId !== userId) must yield 403 Forbidden.
      // A 404, 429, 401, or other status indicates a test infrastructure failure.
      expect(res.status).toBe(403);
    });

    it('test_91_prod_ratelimit_preserved', async () => {
      // Verify that in test mode (current), the rate limit is raised for stability.
      const testRes = await request(app).get('/health');
      expect(testRes.headers['ratelimit-policy']).not.toBe('300;w=900');

      // Verify that in non-test mode, the production rate limit is preserved.
      const savedNodeEnv = process.env.NODE_ENV;
      try {
        vi.resetModules();
        process.env.NODE_ENV = 'development';
        const { default: devApp } = await import('../src/app');

        const prodRes = await request(devApp).get('/health');
        expect(prodRes.status).toBe(200);
        expect(prodRes.headers['ratelimit-policy']).toBe('300;w=900');
      } finally {
        process.env.NODE_ENV = savedNodeEnv;
        vi.resetModules();
      }
    });
  });
});
