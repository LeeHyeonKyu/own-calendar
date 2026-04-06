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
      const user1 = await createTestUser(app, { email: 'user1@example.com' });
      const user2 = await createTestUser(app, { email: 'user2@example.com' });
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
});
