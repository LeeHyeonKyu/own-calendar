/**
 * Regression guard for issue #124: POST /api/auth/register intermittently
 * returned a non-201 response during createTestUser in follows.test.ts and
 * family.test.ts.  The reported error was "expected 201, got 200 — {}".
 *
 * Investigation findings (rework R2):
 *
 *   1. The authLimiter (app.ts, express-rate-limit v8.3.2) was configured with
 *      limit:10 and skipSuccessfulRequests:true but NO test-mode override.
 *      After 10 failed auth requests within a single test file, the 11th
 *      request is rate-limited with HTTP 429 (not 200).  The fix raises the
 *      limit to 10000 in test mode (matching globalLimiter) and adds
 *      resetRateLimitState() in beforeEach.
 *
 *   2. Vitest (^4.1.2) runs each file in its own worker (default pool with
 *      isolate:true).  Module caches are separate per worker, so the
 *      Express app singleton and its MemoryStore are NOT shared across
 *      files.  Cross-file rate-limiter accumulation is therefore not the
 *      mechanism behind the original issue.
 *
 *   3. No code path in the POST /api/auth/register middleware chain
 *      (validate.ts -> auth.ts -> authService.register) can produce HTTP
 *      200 with body {}.  The handler sends 201 on success, validate sends
 *      400, the rate limiter sends 429, and the error handler sends 500.
 *      The phantom 200 {} cannot be traced to application code.
 *
 * Conclusion: the authLimiter fix (item 1) eliminates a real within-file
 * rate-limiting hazard but does NOT explain the reported 200 {} symptom
 * (item 3).  Per plan dissent d1/d3, the 200 {} mechanism is documented
 * as unidentified and handed off to a human.  This test guards against
 * the reproducible rate-limiter accumulation path.
 */
import request from 'supertest';
import app from '../src/app';

describe('test_124_register_isolation', () => {
  it('test_124_register_never_answers_200_empty — register returns 201 even after accumulated auth failures', async () => {
    // Accumulate 10 failed POST /api/auth/register requests within this
    // file.  Each omits the required 'name' field, so the validate
    // middleware returns 400.  With skipSuccessfulRequests:true, these
    // failures count toward the authLimiter budget.
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

    // The 11th request must still return 201.  Without the test-mode
    // limit override, the authLimiter counter would be 10 and the 11th
    // request would be rate-limited (429).  The fix raises the limit to
    // 10000 in test mode so the counter never reaches the threshold.
    //
    // We make the raw request (not via createTestUser) to explicitly
    // assert both the 200-empty and the 429 conditions.
    const res = await request(app).post('/api/auth/register').send({
      email: 'should-still-work@test.com',
      name: 'Still Works',
      password: 'password123',
    });

    // Guard: register must not answer 200 {} (the reported symptom)
    if (res.status === 200) {
      throw new Error(
        `register returned 200 with body ${JSON.stringify(res.body)} — ` +
        'this is the phantom symptom from issue #124 whose root cause is unidentified',
      );
    }

    // Guard: register must not be rate-limited (the reproducible path)
    expect(res.status).not.toBe(429);

    // Primary assertion: register succeeds
    expect(res.status).toBe(201);
    expect(res.body.accessToken).toBeDefined();
    expect(res.body.user.email).toBe('should-still-work@test.com');
  });
});
