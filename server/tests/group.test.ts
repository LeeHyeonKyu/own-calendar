import request from 'supertest';
import app from '../src/app';
import { createTestUser } from './setup';

describe('Group API', () => {
  let user1: any;
  let user2: any;
  let user3: any;

  beforeEach(async () => {
    user1 = await createTestUser(app, { email: 'user1@example.com', name: 'User One' });
    user2 = await createTestUser(app, { email: 'user2@example.com', name: 'User Two' });
    user3 = await createTestUser(app, { email: 'user3@example.com', name: 'User Three' });
  });

  // ─── Helper ────────────────────────────────────────────────────────
  async function createGroup(token: string, name = '테스트 그룹', type?: string) {
    const body: any = { name };
    if (type) body.type = type;
    return request(app)
      .post('/api/groups')
      .set('Authorization', `Bearer ${token}`)
      .send(body);
  }

  async function joinGroup(token: string, code: string) {
    return request(app)
      .post('/api/groups/join')
      .set('Authorization', `Bearer ${token}`)
      .send({ code });
  }

  // ─── 1. Group CRUD ─────────────────────────────────────────────────

  describe('POST /api/groups', () => {
    it('creates a group with code, calendar, and owner membership', async () => {
      const res = await createGroup(user1.accessToken, '친구 모임', '친구');

      expect(res.status).toBe(201);
      expect(res.body.name).toBe('친구 모임');
      expect(res.body.type).toBe('친구');
      expect(res.body.code).toBeDefined();
      expect(res.body.code.length).toBeGreaterThanOrEqual(6);
      expect(res.body.members).toHaveLength(1);
      expect(res.body.members[0].role).toBe('OWNER');
      expect(res.body.calendar).toBeDefined();
      expect(res.body.calendar.type).toBe('FAMILY');
    });

    it('defaults type to 가족 when not specified', async () => {
      const res = await createGroup(user1.accessToken, '우리 가족');

      expect(res.status).toBe(201);
      expect(res.body.type).toBe('가족');
    });

    it('returns 400 when name is missing', async () => {
      const res = await request(app)
        .post('/api/groups')
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({});

      expect(res.status).toBe(400);
    });

    it('returns 400 when name is empty string', async () => {
      const res = await request(app)
        .post('/api/groups')
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({ name: '' });

      expect(res.status).toBe(400);
    });

    it('returns 401 without auth', async () => {
      const res = await request(app)
        .post('/api/groups')
        .send({ name: 'Unauthorized Group' });

      expect(res.status).toBe(401);
    });
  });

  describe('GET /api/groups', () => {
    it('returns empty array when user has no groups', async () => {
      const res = await request(app)
        .get('/api/groups')
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body).toEqual([]);
    });

    it('returns all groups the user belongs to', async () => {
      const g1 = await createGroup(user1.accessToken, '그룹 A');
      await createGroup(user1.accessToken, '그룹 B');

      // user1 also joins user2's group
      const g3 = await createGroup(user2.accessToken, '그룹 C');
      await joinGroup(user1.accessToken, g3.body.code);

      const res = await request(app)
        .get('/api/groups')
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body).toHaveLength(3);
      const names = res.body.map((g: any) => g.name);
      expect(names).toContain('그룹 A');
      expect(names).toContain('그룹 B');
      expect(names).toContain('그룹 C');
    });

    it('includes role info (OWNER vs MEMBER)', async () => {
      const g = await createGroup(user1.accessToken, '소유자 그룹');
      await joinGroup(user2.accessToken, g.body.code);

      const ownerRes = await request(app)
        .get('/api/groups')
        .set('Authorization', `Bearer ${user1.accessToken}`);
      expect(ownerRes.body[0].role).toBe('OWNER');

      const memberRes = await request(app)
        .get('/api/groups')
        .set('Authorization', `Bearer ${user2.accessToken}`);
      expect(memberRes.body[0].role).toBe('MEMBER');
    });
  });

  describe('GET /api/groups/:id', () => {
    it('returns group detail with members', async () => {
      const g = await createGroup(user1.accessToken, '상세 그룹');
      await joinGroup(user2.accessToken, g.body.code);

      const res = await request(app)
        .get(`/api/groups/${g.body.id}`)
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.name).toBe('상세 그룹');
      expect(res.body.members).toHaveLength(2);
      const emails = res.body.members.map((m: any) => m.email);
      expect(emails).toContain('user1@example.com');
      expect(emails).toContain('user2@example.com');
    });

    it('returns 403 for non-member', async () => {
      const g = await createGroup(user1.accessToken, '비공개 그룹');

      const res = await request(app)
        .get(`/api/groups/${g.body.id}`)
        .set('Authorization', `Bearer ${user2.accessToken}`);

      expect(res.status).toBe(403);
    });
  });

  describe('DELETE /api/groups/:id', () => {
    it('owner can delete group', async () => {
      const g = await createGroup(user1.accessToken, '삭제 대상');

      const res = await request(app)
        .delete(`/api/groups/${g.body.id}`)
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(res.status).toBe(204);

      // Verify group is gone
      const listRes = await request(app)
        .get('/api/groups')
        .set('Authorization', `Bearer ${user1.accessToken}`);
      expect(listRes.body).toHaveLength(0);
    });

    it('non-owner cannot delete group', async () => {
      const g = await createGroup(user1.accessToken, '보호된 그룹');
      await joinGroup(user2.accessToken, g.body.code);

      const res = await request(app)
        .delete(`/api/groups/${g.body.id}`)
        .set('Authorization', `Bearer ${user2.accessToken}`);

      expect(res.status).toBe(403);
    });

    it('non-member cannot delete group', async () => {
      const g = await createGroup(user1.accessToken, '외부인 삭제시도');

      const res = await request(app)
        .delete(`/api/groups/${g.body.id}`)
        .set('Authorization', `Bearer ${user2.accessToken}`);

      expect(res.status).toBe(403);
    });
  });

  // ─── 2. Join / Leave ───────────────────────────────────────────────

  describe('POST /api/groups/join', () => {
    it('joins group with valid code', async () => {
      const g = await createGroup(user1.accessToken, '합류 테스트');

      const res = await joinGroup(user2.accessToken, g.body.code);

      expect(res.status).toBe(200);
      expect(res.body.name).toBe('합류 테스트');
    });

    it('returns 404 for invalid code', async () => {
      const res = await joinGroup(user2.accessToken, 'INVALID_CODE_XYZ');

      expect(res.status).toBe(404);
    });

    it('returns 409 if already a member', async () => {
      const g = await createGroup(user1.accessToken, '중복 합류');
      await joinGroup(user2.accessToken, g.body.code);

      const res = await joinGroup(user2.accessToken, g.body.code);

      expect(res.status).toBe(409);
    });

    it('returns 400 when code is empty', async () => {
      const res = await request(app)
        .post('/api/groups/join')
        .set('Authorization', `Bearer ${user2.accessToken}`)
        .send({ code: '' });

      expect(res.status).toBe(400);
    });
  });

  describe('POST /api/groups/:id/leave', () => {
    it('member can leave', async () => {
      const g = await createGroup(user1.accessToken, '탈퇴 그룹');
      await joinGroup(user2.accessToken, g.body.code);

      const res = await request(app)
        .post(`/api/groups/${g.body.id}/leave`)
        .set('Authorization', `Bearer ${user2.accessToken}`);

      expect(res.status).toBe(204);

      // Verify user2 no longer in group
      const detailRes = await request(app)
        .get(`/api/groups/${g.body.id}`)
        .set('Authorization', `Bearer ${user1.accessToken}`);
      expect(detailRes.body.members).toHaveLength(1);
    });

    it('owner cannot leave', async () => {
      const g = await createGroup(user1.accessToken, '소유자 탈퇴시도');

      const res = await request(app)
        .post(`/api/groups/${g.body.id}/leave`)
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(res.status).toBe(400);
    });

    it('non-member gets 404', async () => {
      const g = await createGroup(user1.accessToken, '외부인 탈퇴');

      const res = await request(app)
        .post(`/api/groups/${g.body.id}/leave`)
        .set('Authorization', `Bearer ${user2.accessToken}`);

      expect(res.status).toBe(404);
    });
  });

  describe('DELETE /api/groups/:id/members/:userId', () => {
    let groupId: string;
    let groupCode: string;

    beforeEach(async () => {
      const g = await createGroup(user1.accessToken, '멤버 관리');
      groupId = g.body.id;
      groupCode = g.body.code;
      await joinGroup(user2.accessToken, groupCode);
      await joinGroup(user3.accessToken, groupCode);
    });

    it('owner can remove a member', async () => {
      const res = await request(app)
        .delete(`/api/groups/${groupId}/members/${user2.user.id}`)
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(res.status).toBe(204);

      const detail = await request(app)
        .get(`/api/groups/${groupId}`)
        .set('Authorization', `Bearer ${user1.accessToken}`);
      expect(detail.body.members).toHaveLength(2);
      expect(detail.body.members.map((m: any) => m.email)).not.toContain('user2@example.com');
    });

    it('non-owner cannot remove a member', async () => {
      const res = await request(app)
        .delete(`/api/groups/${groupId}/members/${user3.user.id}`)
        .set('Authorization', `Bearer ${user2.accessToken}`);

      expect(res.status).toBe(403);
    });

    it('owner cannot remove self', async () => {
      const res = await request(app)
        .delete(`/api/groups/${groupId}/members/${user1.user.id}`)
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(res.status).toBe(400);
    });
  });

  // ─── 3. Group Calendars (NEW endpoint) ─────────────────────────────

  describe('GET /api/groups/calendars', () => {
    it('returns empty array when user has no groups', async () => {
      const res = await request(app)
        .get('/api/groups/calendars')
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body).toEqual([]);
    });

    it('returns combined calendars from all groups', async () => {
      const g1 = await createGroup(user1.accessToken, '그룹 A');
      const g2 = await createGroup(user1.accessToken, '그룹 B');
      await joinGroup(user2.accessToken, g1.body.code);
      await joinGroup(user2.accessToken, g2.body.code);

      const res = await request(app)
        .get('/api/groups/calendars')
        .set('Authorization', `Bearer ${user2.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.length).toBeGreaterThanOrEqual(2);
    });

    it('shows public events but hides private events from other members', async () => {
      const g = await createGroup(user1.accessToken, '가시성 테스트');
      await joinGroup(user2.accessToken, g.body.code);

      // Get user2's personal calendar
      const calRes = await request(app)
        .get('/api/calendars')
        .set('Authorization', `Bearer ${user2.accessToken}`);
      const user2CalId = calRes.body[0].id;

      // User2 creates public + private events
      await request(app)
        .post('/api/events')
        .set('Authorization', `Bearer ${user2.accessToken}`)
        .send({
          title: 'Public Meeting',
          startTime: '2026-10-01T10:00:00.000Z',
          endTime: '2026-10-01T11:00:00.000Z',
          calendarId: user2CalId,
          isPrivate: false,
        });

      await request(app)
        .post('/api/events')
        .set('Authorization', `Bearer ${user2.accessToken}`)
        .send({
          title: 'Private Diary',
          startTime: '2026-10-01T14:00:00.000Z',
          endTime: '2026-10-01T15:00:00.000Z',
          calendarId: user2CalId,
          isPrivate: true,
        });

      // User1 views group calendars
      const res = await request(app)
        .get('/api/groups/calendars?start=2026-10-01T00:00:00.000Z&end=2026-10-02T00:00:00.000Z')
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(res.status).toBe(200);
      const user2Entry = res.body.find((e: any) => e.member.id === user2.user.id);
      expect(user2Entry).toBeDefined();

      const allEvents = user2Entry.calendars.flatMap((c: any) => c.events);
      const titles = allEvents.map((e: any) => e.title);
      expect(titles).toContain('Public Meeting');
      expect(titles).not.toContain('Private Diary');
    });

    it('owner can see their own private events', async () => {
      const g = await createGroup(user1.accessToken, '내 비밀 일정');

      // Get user1's personal calendar
      const calRes = await request(app)
        .get('/api/calendars')
        .set('Authorization', `Bearer ${user1.accessToken}`);
      const user1CalId = calRes.body[0].id;

      await request(app)
        .post('/api/events')
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({
          title: 'My Secret Event',
          startTime: '2026-10-01T10:00:00.000Z',
          endTime: '2026-10-01T11:00:00.000Z',
          calendarId: user1CalId,
          isPrivate: true,
        });

      const res = await request(app)
        .get('/api/groups/calendars?start=2026-10-01T00:00:00.000Z&end=2026-10-02T00:00:00.000Z')
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(res.status).toBe(200);
      const user1Entry = res.body.find((e: any) => e.member.id === user1.user.id);
      const allEvents = user1Entry.calendars.flatMap((c: any) => c.events);
      expect(allEvents.map((e: any) => e.title)).toContain('My Secret Event');
    });

    it('filters events by start/end query', async () => {
      const g = await createGroup(user1.accessToken, '필터 테스트');

      // Create group event
      await request(app)
        .post(`/api/groups/${g.body.id}/events`)
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({
          title: 'October Event',
          startTime: '2026-10-15T10:00:00.000Z',
          endTime: '2026-10-15T11:00:00.000Z',
        });

      await request(app)
        .post(`/api/groups/${g.body.id}/events`)
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({
          title: 'November Event',
          startTime: '2026-11-15T10:00:00.000Z',
          endTime: '2026-11-15T11:00:00.000Z',
        });

      // Query only October
      const res = await request(app)
        .get('/api/groups/calendars?start=2026-10-01T00:00:00.000Z&end=2026-11-01T00:00:00.000Z')
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(res.status).toBe(200);
      const allEvents = res.body.flatMap((entry: any) =>
        entry.calendars.flatMap((c: any) => c.events),
      );
      const titles = allEvents.map((e: any) => e.title);
      expect(titles).toContain('October Event');
      expect(titles).not.toContain('November Event');
    });
  });

  describe('GET /api/groups/:id/calendars', () => {
    it('returns calendars for a specific group', async () => {
      const g = await createGroup(user1.accessToken, '특정 그룹 캘린더');
      await joinGroup(user2.accessToken, g.body.code);

      const res = await request(app)
        .get(`/api/groups/${g.body.id}/calendars`)
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body).toBeInstanceOf(Array);
      expect(res.body.length).toBeGreaterThanOrEqual(1);
    });

    it('returns 403 for non-member', async () => {
      const g = await createGroup(user1.accessToken, '외부인 캘린더');

      const res = await request(app)
        .get(`/api/groups/${g.body.id}/calendars`)
        .set('Authorization', `Bearer ${user2.accessToken}`);

      expect(res.status).toBe(403);
    });
  });

  describe('POST /api/groups/:id/events', () => {
    it('creates event in group shared calendar', async () => {
      const g = await createGroup(user1.accessToken, '이벤트 그룹');

      const res = await request(app)
        .post(`/api/groups/${g.body.id}/events`)
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({
          title: 'Group Dinner',
          startTime: '2026-10-20T18:00:00.000Z',
          endTime: '2026-10-20T20:00:00.000Z',
        });

      expect(res.status).toBe(201);
      expect(res.body.title).toBe('Group Dinner');
    });

    it('member (non-owner) can create events', async () => {
      const g = await createGroup(user1.accessToken, '멤버 이벤트');
      await joinGroup(user2.accessToken, g.body.code);

      const res = await request(app)
        .post(`/api/groups/${g.body.id}/events`)
        .set('Authorization', `Bearer ${user2.accessToken}`)
        .send({
          title: 'Member Created Event',
          startTime: '2026-10-21T10:00:00.000Z',
          endTime: '2026-10-21T11:00:00.000Z',
        });

      expect(res.status).toBe(201);
      expect(res.body.title).toBe('Member Created Event');
    });

    it('non-member cannot create events', async () => {
      const g = await createGroup(user1.accessToken, '비회원 이벤트');

      const res = await request(app)
        .post(`/api/groups/${g.body.id}/events`)
        .set('Authorization', `Bearer ${user2.accessToken}`)
        .send({
          title: 'Unauthorized Event',
          startTime: '2026-10-21T10:00:00.000Z',
          endTime: '2026-10-21T11:00:00.000Z',
        });

      expect(res.status).toBe(403);
    });

    it('group events are visible to all members via calendars', async () => {
      const g = await createGroup(user1.accessToken, '공유 확인');
      await joinGroup(user2.accessToken, g.body.code);

      await request(app)
        .post(`/api/groups/${g.body.id}/events`)
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({
          title: 'Shared Meetup',
          startTime: '2026-10-25T10:00:00.000Z',
          endTime: '2026-10-25T11:00:00.000Z',
        });

      // User2 should see it via group calendars
      const res = await request(app)
        .get(`/api/groups/${g.body.id}/calendars?start=2026-10-25T00:00:00.000Z&end=2026-10-26T00:00:00.000Z`)
        .set('Authorization', `Bearer ${user2.accessToken}`);

      expect(res.status).toBe(200);
      const allEvents = res.body.flatMap((entry: any) =>
        entry.calendars.flatMap((c: any) => c.events),
      );
      expect(allEvents.map((e: any) => e.title)).toContain('Shared Meetup');
    });
  });

  // ─── 4. /family backwards compatibility ────────────────────────────

  describe('Family API backwards compatibility', () => {
    it('POST /api/family creates a group with type 가족', async () => {
      const res = await request(app)
        .post('/api/family')
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({ name: '호환성 가족' });

      expect(res.status).toBe(201);
      expect(res.body.name).toBe('호환성 가족');

      // Should appear in /api/groups list too
      const groupsRes = await request(app)
        .get('/api/groups')
        .set('Authorization', `Bearer ${user1.accessToken}`);
      expect(groupsRes.body.map((g: any) => g.name)).toContain('호환성 가족');
    });

    it('GET /api/family/calendars and GET /api/groups/calendars return same data', async () => {
      const g = await request(app)
        .post('/api/family')
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({ name: '호환 캘린더' });

      await joinGroup(user2.accessToken, g.body.code);

      const familyRes = await request(app)
        .get('/api/family/calendars')
        .set('Authorization', `Bearer ${user1.accessToken}`);

      const groupsRes = await request(app)
        .get('/api/groups/calendars')
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(familyRes.status).toBe(200);
      expect(groupsRes.status).toBe(200);
      expect(familyRes.body.length).toBe(groupsRes.body.length);
    });

    it('POST /api/family/join uses same group code as /api/groups', async () => {
      const g = await createGroup(user1.accessToken, '교차 합류');

      const res = await request(app)
        .post('/api/family/join')
        .set('Authorization', `Bearer ${user2.accessToken}`)
        .send({ code: g.body.code });

      expect(res.status).toBe(200);
      expect(res.body.name).toBe('교차 합류');
    });
  });

  // ─── 5. Multi-group scenarios ──────────────────────────────────────

  describe('Multi-group scenarios', () => {
    it('user can be in multiple groups simultaneously', async () => {
      const g1 = await createGroup(user1.accessToken, '가족');
      const g2 = await createGroup(user2.accessToken, '동료');
      const g3 = await createGroup(user3.accessToken, '동아리');

      await joinGroup(user1.accessToken, g2.body.code);
      await joinGroup(user1.accessToken, g3.body.code);

      const res = await request(app)
        .get('/api/groups')
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(res.body).toHaveLength(3);
    });

    it('combined calendars include events from all groups', async () => {
      const g1 = await createGroup(user1.accessToken, '가족');
      const g2 = await createGroup(user2.accessToken, '동료');
      await joinGroup(user1.accessToken, g2.body.code);

      // Create events in each group calendar
      await request(app)
        .post(`/api/groups/${g1.body.id}/events`)
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({
          title: 'Family Dinner',
          startTime: '2026-10-01T18:00:00.000Z',
          endTime: '2026-10-01T20:00:00.000Z',
        });

      await request(app)
        .post(`/api/groups/${g2.body.id}/events`)
        .set('Authorization', `Bearer ${user2.accessToken}`)
        .send({
          title: 'Team Meeting',
          startTime: '2026-10-01T09:00:00.000Z',
          endTime: '2026-10-01T10:00:00.000Z',
        });

      const res = await request(app)
        .get('/api/groups/calendars?start=2026-10-01T00:00:00.000Z&end=2026-10-02T00:00:00.000Z')
        .set('Authorization', `Bearer ${user1.accessToken}`);

      const allEvents = res.body.flatMap((entry: any) =>
        entry.calendars.flatMap((c: any) => c.events),
      );
      const titles = allEvents.map((e: any) => e.title);
      expect(titles).toContain('Family Dinner');
      expect(titles).toContain('Team Meeting');
    });

    it('leaving a group removes access to that group calendar', async () => {
      const g = await createGroup(user1.accessToken, '탈퇴 후 캘린더');
      await joinGroup(user2.accessToken, g.body.code);

      await request(app)
        .post(`/api/groups/${g.body.id}/events`)
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({
          title: 'Group Secret',
          startTime: '2026-10-01T10:00:00.000Z',
          endTime: '2026-10-01T11:00:00.000Z',
        });

      // User2 leaves
      await request(app)
        .post(`/api/groups/${g.body.id}/leave`)
        .set('Authorization', `Bearer ${user2.accessToken}`);

      // User2 should no longer see group calendars
      const res = await request(app)
        .get('/api/groups/calendars')
        .set('Authorization', `Bearer ${user2.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body).toEqual([]);
    });

    it('deleting a group removes it from all members', async () => {
      const g = await createGroup(user1.accessToken, '삭제 테스트');
      await joinGroup(user2.accessToken, g.body.code);

      await request(app)
        .delete(`/api/groups/${g.body.id}`)
        .set('Authorization', `Bearer ${user1.accessToken}`);

      // User2 should have no groups
      const res = await request(app)
        .get('/api/groups')
        .set('Authorization', `Bearer ${user2.accessToken}`);
      expect(res.body).toHaveLength(0);
    });
  });
});
