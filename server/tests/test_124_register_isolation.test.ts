/**
 * Regression test for issue #124: POST /api/auth/register intermittently returns
 * a non-201 response because the authLimiter (app.ts:51-57) accumulates failed
 * request counts across test files via its in-memory MemoryStore.
 *
 * Root cause: authLimiter has limit:10 with NO test-mode override (unlike
 * globalLimiter at line 44 which uses 10000 in test mode). With
 * skipSuccessfulRequests:true, only failed requests (status >= 400) accumulate.
 * After 10 failed auth requests across the suite, subsequent register calls
 * are rate-limited. The MemoryStore is never reset between tests because
 * setup.ts only clears database tables, not app-level in-memory state.
 *
 * The test deterministically reproduces this by making 10 failed register
 * requests (missing required field -> 400), then verifying that the next
 * register call succeeds with 201. Without the fix (authLimiter limit:10),
 * the 11th request is rate-limited. With the fix (authLimiter limit:10000
 * in test mode), it passes.
 */
import request from 'supertest';
import app from '../src/app';
import { createTestUser } from './setup';

describe('test_124_register_isolation', () => {
  it('test_124_register_never_answers_200_empty — register returns 201 even after accumulated auth failures', async () => {
    // Simulate the leaking state: make 10 failed POST /api/auth/register
    // requests. Each sends a body missing the required 'name' field,
    // triggering a 400 from the validate middleware. With
    // skipSuccessfulRequests:true these failures are NOT decremented from
    // the authLimiter's counter, so the counter reaches 10.
    const failures: number[] = [];
    for (let i = 0; i < 10; i++) {
      const res = await request(app).post('/api/auth/register').send({
        email: `fail-${i}@test.com`,
        // intentionally omit 'name' -> zod validation returns 400
        password: 'password123',
      });
      failures.push(res.status);
    }

    // Verify the failures were 400 (validate middleware rejected them)
    expect(failures.every((s) => s === 400)).toBe(true);

    // The next register call (the 11th request through the authLimiter)
    // must still return 201. Before the fix, the authLimiter's counter
    // is 10, increment pushes it to 11 > limit(10), and the request is
    // rate-limited instead of reaching the register handler.
    const user = await createTestUser(app, {
      email: 'should-still-work@test.com',
      name: 'Still Works',
    });

    expect(user.accessToken).toBeDefined();
    expect(user.user.email).toBe('should-still-work@test.com');
  });
});
