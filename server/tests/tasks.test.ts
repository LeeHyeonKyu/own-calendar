import request from 'supertest';
import app from '../src/app';
import { createTestUser } from './setup';

describe('Tasks API', () => {
  /**
   * Helper: get the default calendar id for an authenticated user.
   */
  async function getUserCalendarId(accessToken: string): Promise<string> {
    const res = await request(app)
      .get('/api/calendars')
      .set('Authorization', `Bearer ${accessToken}`);
    const defaultCal = res.body.find((c: any) => c.isDefault === true);
    return defaultCal.id;
  }

  /**
   * Helper: create a task and return the response body.
   */
  async function createTask(
    accessToken: string,
    calendarId: string,
    overrides?: Partial<{ title: string; dueDate: string }>,
  ) {
    const res = await request(app)
      .post('/api/tasks')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        title: overrides?.title ?? 'Test Task',
        calendarId,
        ...(overrides?.dueDate ? { dueDate: overrides.dueDate } : {}),
      });
    return res;
  }

  // --- dw2: test_47_create_default_todo ---
  describe('POST /api/tasks', () => {
    it('test_47_create_default_todo', async () => {
      const user = await createTestUser(app);
      const calendarId = await getUserCalendarId(user.accessToken);

      const res = await createTask(user.accessToken, calendarId);

      expect(res.status).toBe(201);
      expect(res.body.title).toBe('Test Task');
      expect(res.body.calendarId).toBe(calendarId);
      // A freshly created task defaults to status TODO with no completedAt
      expect(res.body.status).toBe('TODO');
      expect(res.body.completedAt).toBeNull();
    });

    it('test_47_post_missing_title_400', async () => {
      const user = await createTestUser(app);
      const calendarId = await getUserCalendarId(user.accessToken);

      // POST without a title should fail validation (400)
      const res = await request(app)
        .post('/api/tasks')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ calendarId });

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error');
      expect(res.body.error).toBe('Validation failed');
      expect(res.body).toHaveProperty('details');
    });
  });

  // --- dw1 (backstop): list tasks for user ---
  describe('GET /api/tasks', () => {
    it('test_47_list_own_tasks', async () => {
      const user = await createTestUser(app);
      const calendarId = await getUserCalendarId(user.accessToken);

      // Create two tasks
      await createTask(user.accessToken, calendarId, { title: 'Task A' });
      await createTask(user.accessToken, calendarId, { title: 'Task B' });

      const res = await request(app)
        .get('/api/tasks')
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      const titles = res.body.map((t: any) => t.title);
      expect(titles).toContain('Task A');
      expect(titles).toContain('Task B');
    });

    it('test_47_list_isolation', async () => {
      // User B's GET /api/tasks never returns user A's tasks
      const userA = await createTestUser(app, { email: 'usera@example.com' });
      const userB = await createTestUser(app, { email: 'userb@example.com' });
      const calendarIdA = await getUserCalendarId(userA.accessToken);

      await createTask(userA.accessToken, calendarIdA, { title: 'Secret Task' });

      const res = await request(app)
        .get('/api/tasks')
        .set('Authorization', `Bearer ${userB.accessToken}`);

      expect(res.status).toBe(200);
      const titles = res.body.map((t: any) => t.title);
      expect(titles).not.toContain('Secret Task');
    });
  });

  // --- dw1 (backstop): update title ---
  describe('PUT /api/tasks/:id', () => {
    it('test_47_update_title', async () => {
      const user = await createTestUser(app);
      const calendarId = await getUserCalendarId(user.accessToken);

      const createRes = await createTask(user.accessToken, calendarId, { title: 'Original Title' });
      const taskId = createRes.body.id;

      const res = await request(app)
        .put(`/api/tasks/${taskId}`)
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ title: 'Updated Title' });

      expect(res.status).toBe(200);
      expect(res.body.title).toBe('Updated Title');
      // The id should remain the same
      expect(res.body.id).toBe(taskId);
    });
  });

  // --- dw3: test_47_toggle_complete ---
  describe('PATCH /api/tasks/:id/complete', () => {
    it('test_47_toggle_complete', async () => {
      const user = await createTestUser(app);
      const calendarId = await getUserCalendarId(user.accessToken);

      const createRes = await createTask(user.accessToken, calendarId);
      const taskId = createRes.body.id;

      // Verify initial state: TODO, completedAt null
      expect(createRes.body.status).toBe('TODO');
      expect(createRes.body.completedAt).toBeNull();

      // First toggle: TODO -> DONE
      const toggle1 = await request(app)
        .patch(`/api/tasks/${taskId}/complete`)
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send();

      expect(toggle1.status).toBe(200);
      expect(toggle1.body.status).toBe('DONE');
      // completedAt should be set to an ISO-8601 timestamp
      expect(toggle1.body.completedAt).not.toBeNull();
      expect(new Date(toggle1.body.completedAt).toISOString()).toBe(toggle1.body.completedAt);

      // Second toggle: DONE -> TODO
      const toggle2 = await request(app)
        .patch(`/api/tasks/${taskId}/complete`)
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send();

      expect(toggle2.status).toBe(200);
      expect(toggle2.body.status).toBe('TODO');
      expect(toggle2.body.completedAt).toBeNull();
    });
  });

  // --- dw1 (backstop): delete returns 204 ---
  describe('DELETE /api/tasks/:id', () => {
    it('test_47_delete_204', async () => {
      const user = await createTestUser(app);
      const calendarId = await getUserCalendarId(user.accessToken);

      const createRes = await createTask(user.accessToken, calendarId);
      const taskId = createRes.body.id;

      const res = await request(app)
        .delete(`/api/tasks/${taskId}`)
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(204);

      // Confirm the task is gone: listing should not contain it
      const listRes = await request(app)
        .get('/api/tasks')
        .set('Authorization', `Bearer ${user.accessToken}`);
      const ids = listRes.body.map((t: any) => t.id);
      expect(ids).not.toContain(taskId);
    });
  });

  // --- dw4: test_47_cross_user_isolation ---
  describe('Cross-user isolation', () => {
    it('test_47_cross_user_isolation', async () => {
      const userA = await createTestUser(app, { email: 'owner@example.com' });
      const userB = await createTestUser(app, { email: 'stranger@example.com' });
      const calendarIdA = await getUserCalendarId(userA.accessToken);

      // User A creates a task
      const createRes = await createTask(userA.accessToken, calendarIdA, { title: 'Private Task' });
      const taskId = createRes.body.id;

      // User B tries to PUT (update) user A's task -> 403
      const putRes = await request(app)
        .put(`/api/tasks/${taskId}`)
        .set('Authorization', `Bearer ${userB.accessToken}`)
        .send({ title: 'Hijacked' });

      expect(putRes.status).toBe(403);

      // User B tries to DELETE user A's task -> 403
      const deleteRes = await request(app)
        .delete(`/api/tasks/${taskId}`)
        .set('Authorization', `Bearer ${userB.accessToken}`);

      expect(deleteRes.status).toBe(403);

      // Verify user A's task is untouched
      const listRes = await request(app)
        .get('/api/tasks')
        .set('Authorization', `Bearer ${userA.accessToken}`);
      const task = listRes.body.find((t: any) => t.id === taskId);
      expect(task).toBeDefined();
      expect(task.title).toBe('Private Task');
    });
  });

  // --- mutation guard: boolean in app.ts (globalLimiter legacyHeaders: false) ---
  describe('Response headers', () => {
    it('test_47_no_legacy_ratelimit_headers', async () => {
      const user = await createTestUser(app);
      const calendarId = await getUserCalendarId(user.accessToken);

      // Exercise the task API through the full middleware stack (app.ts).
      const createRes = await createTask(user.accessToken, calendarId, { title: 'Header Check' });
      expect(createRes.status).toBe(201);

      // The global rate limiter in app.ts is configured with legacyHeaders: false.
      // When that boolean is mutated to true, X-RateLimit-* headers appear in every
      // response. These assertions guard the configured header policy.
      expect(createRes.headers['x-ratelimit-limit']).toBeUndefined();
      expect(createRes.headers['x-ratelimit-remaining']).toBeUndefined();
      expect(createRes.headers['x-ratelimit-reset']).toBeUndefined();

      // Also verify a GET response carries the same header policy.
      const listRes = await request(app)
        .get('/api/tasks')
        .set('Authorization', `Bearer ${user.accessToken}`);
      expect(listRes.status).toBe(200);
      expect(listRes.headers['x-ratelimit-limit']).toBeUndefined();
      expect(listRes.headers['x-ratelimit-remaining']).toBeUndefined();
      expect(listRes.headers['x-ratelimit-reset']).toBeUndefined();
    });

    it('test_47_ratelimit_headers_exact_set', async () => {
      const user = await createTestUser(app);
      const calendarId = await getUserCalendarId(user.accessToken);

      // Hit the task API through the full middleware stack to observe the
      // rate-limiter's header policy configured in app.ts.
      const res = await createTask(user.accessToken, calendarId, { title: 'RL Set Check' });
      expect(res.status).toBe(201);

      // Collect every rate-limit-related header present in the response.
      // With standardHeaders: 'draft-7' and legacyHeaders: false the
      // response must contain exactly 'ratelimit' and 'ratelimit-policy'.
      // Mutating legacyHeaders to true adds x-ratelimit-limit,
      // x-ratelimit-remaining, and x-ratelimit-reset — this assertion
      // catches that by comparing the full sorted set.
      const rlHeaders = Object.keys(res.headers)
        .filter((h) => h.includes('ratelimit'))
        .sort();

      expect(rlHeaders).toEqual(['ratelimit', 'ratelimit-policy']);

      // Positive format assertions for the standard draft-7 headers.
      // ratelimit-policy is "<limit>;w=<windowSec>" per RFC 9110 / draft-7.
      expect(res.headers['ratelimit-policy']).toMatch(/^\d+;w=\d+$/);
      // ratelimit is "limit=<n>, remaining=<n>, reset=<n>" per draft-7.
      expect(res.headers['ratelimit']).toMatch(
        /^limit=\d+, remaining=\d+, reset=\d+$/,
      );
    });
  });
});
