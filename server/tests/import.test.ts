/**
 * Characterization tests for POST /api/import/ics (issue #48).
 *
 * These tests pin the current behaviour of the ICS upload route without
 * modifying any source code under server/src/.
 */
import path from 'path';
import request from 'supertest';
import app from '../src/app';
import { prisma, createTestUser } from './setup';

const FIXTURE_PATH = path.join(__dirname, 'fixtures', 'sample.ics');

describe('test_48_import_ics', () => {
  it('test_48_happy_path — uploading sample.ics creates 2 events with correct titles', async () => {
    const user = await createTestUser(app, {
      email: 'import-happy@test.com',
      name: 'Import Happy',
    });

    const res = await request(app)
      .post('/api/import/ics')
      .set('Authorization', `Bearer ${user.accessToken}`)
      .attach('file', FIXTURE_PATH);

    expect(res.status).toBe(200);
    expect(res.body.added).toBe(2);
    expect(res.body.calendarId).toBeDefined();

    // Verify events were actually persisted in the database
    const events = await prisma.event.findMany({
      where: { calendarId: res.body.calendarId },
      orderBy: { startTime: 'asc' },
    });

    expect(events).toHaveLength(2);

    // First event is all-day
    const allDayEvent = events.find((e) => e.title === 'New Year Kickoff');
    expect(allDayEvent).toBeDefined();
    expect(allDayEvent!.isAllDay).toBe(true);

    // Second event is timed
    const timedEvent = events.find((e) => e.title === 'Team Standup');
    expect(timedEvent).toBeDefined();
    expect(timedEvent!.isAllDay).toBe(false);
  });

  it('test_48_non_ics_file — uploading a non-ICS file returns an error', async () => {
    const user = await createTestUser(app, {
      email: 'import-noics@test.com',
      name: 'Import NonIcs',
    });

    // Upload a .txt file — MIME type text/plain is rejected by the fileFilter.
    // The fileFilter calls cb(new Error('ICS 파일만 업로드할 수 있습니다')) which
    // bypasses the route handler (2-arg) and reaches Express's global error handler
    // (app.ts:82-85) returning 500 + { error: 'Internal server error' }.
    // This test characterizes actual behaviour, not the idealized dw1(b) expectation.
    // See plan dissent d2 and open_risks for full rationale.
    const res = await request(app)
      .post('/api/import/ics')
      .set('Authorization', `Bearer ${user.accessToken}`)
      .attach('file', Buffer.from('this is not an ics file'), 'notvalid.txt');

    expect(res.status).toBe(500);
    expect(res.body.error).toBe('Internal server error');
  });

  it('test_48_missing_file — POST with no file field returns 400', async () => {
    const user = await createTestUser(app, {
      email: 'import-nofile@test.com',
      name: 'Import NoFile',
    });

    const res = await request(app)
      .post('/api/import/ics')
      .set('Authorization', `Bearer ${user.accessToken}`)
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('파일이 선택되지 않았습니다');
  });

  it('test_48_unauthenticated — POST without auth returns 401', async () => {
    const res = await request(app)
      .post('/api/import/ics')
      .attach('file', FIXTURE_PATH);

    expect(res.status).toBe(401);
    expect(res.body.error).toBeDefined();
  });
});
