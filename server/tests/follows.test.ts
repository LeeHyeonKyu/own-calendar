import request from 'supertest';
import app from '../src/app';
import { createTestUser } from './setup';

describe('Follows API', () => {
  let userA: any;
  let userB: any;

  beforeEach(async () => {
    userA = await createTestUser(app, { email: 'follower@example.com', name: 'User A' });
    userB = await createTestUser(app, { email: 'followee@example.com', name: 'User B' });
  });

  /**
   * Helper: A sends a follow request to B and B accepts it.
   * Returns the follow record from the sendFollowRequest response.
   */
  async function followAndAccept(follower: any, followee: any) {
    const sendRes = await request(app)
      .post('/api/follows')
      .set('Authorization', `Bearer ${follower.accessToken}`)
      .send({ followeeId: followee.user.id });

    const followId = sendRes.body.id;

    await request(app)
      .post(`/api/follows/${followId}/accept`)
      .set('Authorization', `Bearer ${followee.accessToken}`);

    return sendRes.body;
  }

  describe('test_49_follow_accept_lifecycle', () => {
    it('PENDING follow request does not appear in following or followers lists', async () => {
      const sendRes = await request(app)
        .post('/api/follows')
        .set('Authorization', `Bearer ${userA.accessToken}`)
        .send({ followeeId: userB.user.id });

      expect(sendRes.status).toBe(201);
      expect(sendRes.body.status).toBe('PENDING');

      // B should NOT appear in A's following list while PENDING
      const followingRes = await request(app)
        .get('/api/follows/following')
        .set('Authorization', `Bearer ${userA.accessToken}`);
      expect(followingRes.status).toBe(200);
      const followingUserIds = followingRes.body.map((f: any) => f.user.id);
      expect(followingUserIds).not.toContain(userB.user.id);

      // A should NOT appear in B's followers list while PENDING
      const followersRes = await request(app)
        .get('/api/follows/followers')
        .set('Authorization', `Bearer ${userB.accessToken}`);
      expect(followersRes.status).toBe(200);
      const followerUserIds = followersRes.body.map((f: any) => f.user.id);
      expect(followerUserIds).not.toContain(userA.user.id);
    });

    it('after accept, followee appears in following list and follower appears in followers list', async () => {
      const sendRes = await request(app)
        .post('/api/follows')
        .set('Authorization', `Bearer ${userA.accessToken}`)
        .send({ followeeId: userB.user.id });

      expect(sendRes.status).toBe(201);
      const followId = sendRes.body.id;

      // B accepts the request
      const acceptRes = await request(app)
        .post(`/api/follows/${followId}/accept`)
        .set('Authorization', `Bearer ${userB.accessToken}`);
      expect(acceptRes.status).toBe(200);
      expect(acceptRes.body.status).toBe('ACCEPTED');

      // B should now appear in A's following list
      const followingRes = await request(app)
        .get('/api/follows/following')
        .set('Authorization', `Bearer ${userA.accessToken}`);
      expect(followingRes.status).toBe(200);
      const followingUserIds = followingRes.body.map((f: any) => f.user.id);
      expect(followingUserIds).toContain(userB.user.id);

      // A should now appear in B's followers list
      const followersRes = await request(app)
        .get('/api/follows/followers')
        .set('Authorization', `Bearer ${userB.accessToken}`);
      expect(followersRes.status).toBe(200);
      const followerUserIds = followersRes.body.map((f: any) => f.user.id);
      expect(followerUserIds).toContain(userA.user.id);
    });
  });

  describe('test_49_event_visibility', () => {
    it('returns 403 before follow request is accepted', async () => {
      // A sends a follow request to B (still PENDING)
      await request(app)
        .post('/api/follows')
        .set('Authorization', `Bearer ${userA.accessToken}`)
        .send({ followeeId: userB.user.id });

      // A tries to see B's events while PENDING — should be 403
      const eventsRes = await request(app)
        .get(`/api/follows/${userB.user.id}/events`)
        .set('Authorization', `Bearer ${userA.accessToken}`);
      expect(eventsRes.status).toBe(403);
    });

    it('returns public events on PUBLIC calendar after accept; excludes PRIVATE calendar events and isPrivate events', async () => {
      // Create the follow relationship
      await followAndAccept(userA, userB);

      // B gets their default calendar (PUBLIC visibility by schema default)
      const calRes = await request(app)
        .get('/api/calendars')
        .set('Authorization', `Bearer ${userB.accessToken}`);
      const publicCalendarId = calRes.body[0].id;

      // B creates a PRIVATE calendar
      const privateCalRes = await request(app)
        .post('/api/calendars')
        .set('Authorization', `Bearer ${userB.accessToken}`)
        .send({ name: 'Secret Calendar', visibility: 'PRIVATE' });
      expect(privateCalRes.status).toBe(201);
      const privateCalendarId = privateCalRes.body.id;

      // B creates a public event on the PUBLIC calendar
      await request(app)
        .post('/api/events')
        .set('Authorization', `Bearer ${userB.accessToken}`)
        .send({
          title: 'Visible Public Event',
          startTime: '2026-06-15T10:00:00.000Z',
          endTime: '2026-06-15T11:00:00.000Z',
          calendarId: publicCalendarId,
          isPrivate: false,
        });

      // B creates a private event (isPrivate: true) on the PUBLIC calendar
      await request(app)
        .post('/api/events')
        .set('Authorization', `Bearer ${userB.accessToken}`)
        .send({
          title: 'Hidden Private Event',
          startTime: '2026-06-15T12:00:00.000Z',
          endTime: '2026-06-15T13:00:00.000Z',
          calendarId: publicCalendarId,
          isPrivate: true,
        });

      // B creates an event on the PRIVATE calendar
      await request(app)
        .post('/api/events')
        .set('Authorization', `Bearer ${userB.accessToken}`)
        .send({
          title: 'Private Calendar Event',
          startTime: '2026-06-15T14:00:00.000Z',
          endTime: '2026-06-15T15:00:00.000Z',
          calendarId: privateCalendarId,
          isPrivate: false,
        });

      // Create userC with a public event on C's default PUBLIC calendar.
      // This exercises the ownerId scoping: A follows B (not C), so C's
      // public events must NOT appear when A views B's followed events.
      const userC = await createTestUser(app, { email: 'userc@example.com', name: 'User C' });
      const calCRes = await request(app)
        .get('/api/calendars')
        .set('Authorization', `Bearer ${userC.accessToken}`);
      const userCCalendarId = calCRes.body[0].id;

      await request(app)
        .post('/api/events')
        .set('Authorization', `Bearer ${userC.accessToken}`)
        .send({
          title: 'User C Public Event',
          startTime: '2026-06-15T16:00:00.000Z',
          endTime: '2026-06-15T17:00:00.000Z',
          calendarId: userCCalendarId,
          isPrivate: false,
        });

      // A views B's events
      const eventsRes = await request(app)
        .get(`/api/follows/${userB.user.id}/events`)
        .set('Authorization', `Bearer ${userA.accessToken}`);
      expect(eventsRes.status).toBe(200);

      const titles = eventsRes.body.map((e: any) => e.title);
      // Only the public event on the PUBLIC calendar should be visible
      expect(titles).toContain('Visible Public Event');
      // isPrivate event on PUBLIC calendar should be excluded
      expect(titles).not.toContain('Hidden Private Event');
      // Event on PRIVATE calendar should be excluded
      expect(titles).not.toContain('Private Calendar Event');
      // User C's public event must NOT leak — proves ownerId scoping
      expect(titles).not.toContain('User C Public Event');
    });
  });

  describe('test_49_unfollow_revokes', () => {
    it('after unfollow, followee is removed from following list and events return 403', async () => {
      // Establish follow relationship
      await followAndAccept(userA, userB);

      // Verify A is following B
      const beforeRes = await request(app)
        .get('/api/follows/following')
        .set('Authorization', `Bearer ${userA.accessToken}`);
      const beforeIds = beforeRes.body.map((f: any) => f.user.id);
      expect(beforeIds).toContain(userB.user.id);

      // A unfollows B
      const unfollowRes = await request(app)
        .delete(`/api/follows/${userB.user.id}`)
        .set('Authorization', `Bearer ${userA.accessToken}`);
      expect(unfollowRes.status).toBe(204);

      // B should no longer appear in A's following list
      const afterRes = await request(app)
        .get('/api/follows/following')
        .set('Authorization', `Bearer ${userA.accessToken}`);
      const afterIds = afterRes.body.map((f: any) => f.user.id);
      expect(afterIds).not.toContain(userB.user.id);

      // A should no longer be able to see B's events
      const eventsRes = await request(app)
        .get(`/api/follows/${userB.user.id}/events`)
        .set('Authorization', `Bearer ${userA.accessToken}`);
      expect(eventsRes.status).toBe(403);
    });
  });

  describe('test_49_error_paths', () => {
    it('self-follow returns 400', async () => {
      const res = await request(app)
        .post('/api/follows')
        .set('Authorization', `Bearer ${userA.accessToken}`)
        .send({ followeeId: userA.user.id });

      expect(res.status).toBe(400);
    });

    it('follow non-existent user returns 404', async () => {
      const res = await request(app)
        .post('/api/follows')
        .set('Authorization', `Bearer ${userA.accessToken}`)
        .send({ followeeId: 'clxxxxxxxxxxxxxxxxxxxxxxxxx' });

      expect(res.status).toBe(404);
    });

    it('duplicate follow request returns 409', async () => {
      // First request succeeds
      const first = await request(app)
        .post('/api/follows')
        .set('Authorization', `Bearer ${userA.accessToken}`)
        .send({ followeeId: userB.user.id });
      expect(first.status).toBe(201);

      // Second request to same user returns 409
      const second = await request(app)
        .post('/api/follows')
        .set('Authorization', `Bearer ${userA.accessToken}`)
        .send({ followeeId: userB.user.id });
      expect(second.status).toBe(409);
    });
  });

  describe('test_49_unauthenticated_401', () => {
    it('POST /api/follows without auth returns 401', async () => {
      const res = await request(app)
        .post('/api/follows')
        .send({ followeeId: 'some-user-id' });

      expect(res.status).toBe(401);
    });

    it('GET /api/follows/following without auth returns 401', async () => {
      const res = await request(app)
        .get('/api/follows/following');

      expect(res.status).toBe(401);
    });
  });
});
