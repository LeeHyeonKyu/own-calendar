import request from 'supertest';
import app from '../src/app';
import { createTestUser } from './setup';

describe('Family API', () => {
  let user1: any;
  let user2: any;

  beforeEach(async () => {
    user1 = await createTestUser(app, { email: 'user1@example.com', name: 'User One' });
    user2 = await createTestUser(app, { email: 'user2@example.com', name: 'User Two' });
  });

  describe('POST /api/family', () => {
    it('creates group with code + family calendar + owner membership', async () => {
      const res = await request(app)
        .post('/api/family')
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({ name: '우리 가족' });

      expect(res.status).toBe(201);
      expect(res.body.name).toBe('우리 가족');
      expect(res.body.code).toHaveLength(8);
      expect(res.body.members).toHaveLength(1);
      expect(res.body.members[0].role).toBe('OWNER');
      expect(res.body.calendar).toBeDefined();
      expect(res.body.calendar.type).toBe('FAMILY');
      expect(res.body.calendar.name).toBe('우리 가족 가족 캘린더');
    });
  });

  describe('POST /api/family/join', () => {
    let familyCode: string;

    beforeEach(async () => {
      const res = await request(app)
        .post('/api/family')
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({ name: '우리 가족' });
      familyCode = res.body.code;
    });

    it('joins the group with valid code', async () => {
      const res = await request(app)
        .post('/api/family/join')
        .set('Authorization', `Bearer ${user2.accessToken}`)
        .send({ code: familyCode });

      expect(res.status).toBe(200);
      expect(res.body.name).toBe('우리 가족');
    });

    it('returns 404 for invalid code', async () => {
      const res = await request(app)
        .post('/api/family/join')
        .set('Authorization', `Bearer ${user2.accessToken}`)
        .send({ code: 'abcd1234' });

      expect(res.status).toBe(404);
    });

    it('returns 409 if already a member', async () => {
      await request(app)
        .post('/api/family/join')
        .set('Authorization', `Bearer ${user2.accessToken}`)
        .send({ code: familyCode });

      const res = await request(app)
        .post('/api/family/join')
        .set('Authorization', `Bearer ${user2.accessToken}`)
        .send({ code: familyCode });

      expect(res.status).toBe(409);
    });
  });

  describe('GET /api/family', () => {
    it('returns group info', async () => {
      await request(app)
        .post('/api/family')
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({ name: '우리 가족' });

      const res = await request(app)
        .get('/api/family')
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.name).toBe('우리 가족');
      expect(res.body.role).toBe('OWNER');
    });

    it('returns null when not in a group', async () => {
      const res = await request(app)
        .get('/api/family')
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body).toBeNull();
    });
  });

  describe('GET /api/family/members', () => {
    it('returns all members', async () => {
      const createRes = await request(app)
        .post('/api/family')
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({ name: '우리 가족' });

      await request(app)
        .post('/api/family/join')
        .set('Authorization', `Bearer ${user2.accessToken}`)
        .send({ code: createRes.body.code });

      const res = await request(app)
        .get('/api/family/members')
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body).toHaveLength(2);
      expect(res.body.map((m: any) => m.email)).toContain('user1@example.com');
      expect(res.body.map((m: any) => m.email)).toContain('user2@example.com');
    });
  });

  describe('GET /api/family/calendars', () => {
    // Root cause (#100): intermediate HTTP calls (family create, join, calendar
    // list, event POST x2) were not status-checked; a silent non-2xx (e.g. 429
    // from authLimiter on /api/family/join, or a transient error) left zero
    // events in the DB, producing the misleading "expected [] to include
    // 'Public Event'" failure.  Additionally, calendar selection used the
    // fragile body[0].id array index instead of the deterministic
    // find-by-isDefault pattern established in events.test.ts.
    // Fix: assert status on every intermediate call, select calendar by
    // isDefault, and move dates to 2099 to future-proof against any later
    // date-window filtering.
    it('shows family members public events, hides private events', async () => {
      const createRes = await request(app)
        .post('/api/family')
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({ name: '우리 가족' });
      expect(createRes.status).toBe(201);

      const joinRes = await request(app)
        .post('/api/family/join')
        .set('Authorization', `Bearer ${user2.accessToken}`)
        .send({ code: createRes.body.code });
      expect(joinRes.status).toBe(200);

      // User2 creates a public event on their default calendar
      const calRes = await request(app)
        .get('/api/calendars')
        .set('Authorization', `Bearer ${user2.accessToken}`);
      expect(calRes.status).toBe(200);
      const defaultCal = calRes.body.find((c: any) => c.isDefault === true);
      expect(defaultCal).toBeDefined();
      const user2CalendarId = defaultCal.id;

      const publicEventRes = await request(app)
        .post('/api/events')
        .set('Authorization', `Bearer ${user2.accessToken}`)
        .send({
          title: 'Public Event',
          startTime: '2099-04-10T10:00:00.000Z',
          endTime: '2099-04-10T11:00:00.000Z',
          calendarId: user2CalendarId,
          isPrivate: false,
        });
      expect(publicEventRes.status).toBe(201);

      const privateEventRes = await request(app)
        .post('/api/events')
        .set('Authorization', `Bearer ${user2.accessToken}`)
        .send({
          title: 'Private Event',
          startTime: '2099-04-10T14:00:00.000Z',
          endTime: '2099-04-10T15:00:00.000Z',
          calendarId: user2CalendarId,
          isPrivate: true,
        });
      expect(privateEventRes.status).toBe(201);

      // User1 views family calendars
      const res = await request(app)
        .get('/api/family/calendars')
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(res.status).toBe(200);

      // Find user2's calendar entry in the result
      const user2Entry = res.body.find((e: any) => e.member.id === user2.user.id);
      expect(user2Entry).toBeDefined();

      // Should only see the public event from user2's calendars
      const allUser2Events = user2Entry.calendars.flatMap((c: any) => c.events);
      const titles = allUser2Events.map((e: any) => e.title);
      expect(titles).toContain('Public Event');
      expect(titles).not.toContain('Private Event');
    });
  });

  describe('POST /api/family/events', () => {
    it('creates event in family calendar', async () => {
      await request(app)
        .post('/api/family')
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({ name: '우리 가족' });

      const res = await request(app)
        .post('/api/family/events')
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({
          title: 'Family Dinner',
          startTime: '2026-04-12T18:00:00.000Z',
          endTime: '2026-04-12T20:00:00.000Z',
        });

      expect(res.status).toBe(201);
      expect(res.body.title).toBe('Family Dinner');
    });
  });

  describe('DELETE /api/family/members/:userId', () => {
    let familyCode: string;

    beforeEach(async () => {
      const res = await request(app)
        .post('/api/family')
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({ name: '우리 가족' });
      familyCode = res.body.code;

      await request(app)
        .post('/api/family/join')
        .set('Authorization', `Bearer ${user2.accessToken}`)
        .send({ code: familyCode });
    });

    it('owner can remove member', async () => {
      const res = await request(app)
        .delete(`/api/family/members/${user2.user.id}`)
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(res.status).toBe(204);

      // Verify user2 is no longer in the group
      const membersRes = await request(app)
        .get('/api/family/members')
        .set('Authorization', `Bearer ${user1.accessToken}`);
      expect(membersRes.body).toHaveLength(1);
    });

    it('non-owner cannot remove member', async () => {
      const res = await request(app)
        .delete(`/api/family/members/${user1.user.id}`)
        .set('Authorization', `Bearer ${user2.accessToken}`);

      expect(res.status).toBe(403);
    });
  });
});
