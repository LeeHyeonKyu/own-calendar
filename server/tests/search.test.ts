import request from 'supertest';
import app from '../src/app';
import { createTestUser } from './setup';

describe('Event Search API', () => {
  async function getUserCalendarId(accessToken: string): Promise<string> {
    const res = await request(app)
      .get('/api/calendars')
      .set('Authorization', `Bearer ${accessToken}`);
    const defaultCal = res.body.find((c: any) => c.isDefault === true);
    return defaultCal.id;
  }

  async function createEvent(
    accessToken: string,
    calendarId: string,
    overrides: Partial<{
      title: string;
      description: string;
      startTime: string;
      endTime: string;
    }> = {},
  ) {
    return request(app)
      .post('/api/events')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        title: overrides.title || 'Test Event',
        description: overrides.description,
        startTime: overrides.startTime || '2026-04-10T09:00:00.000Z',
        endTime: overrides.endTime || '2026-04-10T10:00:00.000Z',
        calendarId,
      });
  }

  describe('GET /api/events/search', () => {
    it('finds events by title', async () => {
      const user = await createTestUser(app);
      const calendarId = await getUserCalendarId(user.accessToken);

      await createEvent(user.accessToken, calendarId, { title: '치과 예약' });
      await createEvent(user.accessToken, calendarId, { title: 'Team Lunch' });

      const res = await request(app)
        .get('/api/events/search')
        .query({ q: '치과' })
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.length).toBe(1);
      expect(res.body[0].title).toBe('치과 예약');
    });

    it('performs case-insensitive search', async () => {
      const user = await createTestUser(app);
      const calendarId = await getUserCalendarId(user.accessToken);

      await createEvent(user.accessToken, calendarId, { title: 'Team Meeting' });

      const res = await request(app)
        .get('/api/events/search')
        .query({ q: 'meeting' })
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.length).toBe(1);
      expect(res.body[0].title).toBe('Team Meeting');
    });

    it('finds events by description', async () => {
      const user = await createTestUser(app);
      const calendarId = await getUserCalendarId(user.accessToken);

      await createEvent(user.accessToken, calendarId, {
        title: 'Appointment',
        description: 'Visit the downtown clinic',
      });

      const res = await request(app)
        .get('/api/events/search')
        .query({ q: 'downtown clinic' })
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.length).toBe(1);
      expect(res.body[0].title).toBe('Appointment');
    });

    it('returns empty array for nonexistent query', async () => {
      const user = await createTestUser(app);
      const calendarId = await getUserCalendarId(user.accessToken);

      await createEvent(user.accessToken, calendarId, { title: 'Some Event' });

      const res = await request(app)
        .get('/api/events/search')
        .query({ q: 'nonexistent' })
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body).toEqual([]);
    });

    it('returns 400 without q parameter', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .get('/api/events/search')
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(400);
      expect(res.body.error).toBe('Validation failed');
    });

    it('filters by date range', async () => {
      const user = await createTestUser(app);
      const calendarId = await getUserCalendarId(user.accessToken);

      await createEvent(user.accessToken, calendarId, {
        title: '치과 4월',
        startTime: '2026-04-10T09:00:00.000Z',
        endTime: '2026-04-10T10:00:00.000Z',
      });
      await createEvent(user.accessToken, calendarId, {
        title: '치과 5월',
        startTime: '2026-05-10T09:00:00.000Z',
        endTime: '2026-05-10T10:00:00.000Z',
      });

      const res = await request(app)
        .get('/api/events/search')
        .query({
          q: '치과',
          start: '2026-04-01T00:00:00.000Z',
          end: '2026-04-30T23:59:59.000Z',
        })
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.length).toBe(1);
      expect(res.body[0].title).toBe('치과 4월');
    });

    it('includes calendar info in results', async () => {
      const user = await createTestUser(app);
      const calendarId = await getUserCalendarId(user.accessToken);

      await createEvent(user.accessToken, calendarId, { title: 'Search Me' });

      const res = await request(app)
        .get('/api/events/search')
        .query({ q: 'Search Me' })
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.length).toBe(1);
      expect(res.body[0].calendar).toBeDefined();
      expect(res.body[0].calendar.id).toBe(calendarId);
      expect(res.body[0].calendar.name).toBeDefined();
      expect(res.body[0].calendar.color).toBeDefined();
    });
  });
});
