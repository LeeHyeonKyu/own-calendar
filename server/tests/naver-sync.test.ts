/**
 * Characterization tests for naverSyncService.pullEvents (issue #50).
 *
 * Mock strategy: only global.fetch is mocked (the sole network I/O).
 * node-ical.parseICS is NOT mocked — it is a synchronous pure parser
 * and exercising it is part of characterizing the service's ICS-to-event
 * transformation (plan dissent d1: "only fetch is I/O, only fetch should
 * be mocked"). Prisma operations run against the real test database.
 */
import app from '../src/app';
import { prisma, createTestUser } from './setup';
import { naverSyncService } from '../src/services/naver-sync.service';

// Two valid VEVENTs: one timed (with description), one all-day (no description).
const TWO_EVENTS_ICS = [
  'BEGIN:VCALENDAR',
  'VERSION:2.0',
  'PRODID:-//Naver//CalDAV//KO',
  'BEGIN:VEVENT',
  'UID:naver-uid-001@naver.com',
  'DTSTART:20260301T100000Z',
  'DTEND:20260301T120000Z',
  'SUMMARY:Morning Meeting',
  'DESCRIPTION:Team sync meeting',
  'END:VEVENT',
  'BEGIN:VEVENT',
  'UID:naver-uid-002@naver.com',
  'DTSTART;VALUE=DATE:20260315',
  'DTEND;VALUE=DATE:20260316',
  'SUMMARY:Company Holiday',
  'END:VEVENT',
  'END:VCALENDAR',
].join('\r\n');

describe('test_50_naver_sync', () => {
  let userId: string;
  let connectionId: string;
  let calendarId: string;
  const realFetch = globalThis.fetch;

  beforeEach(async () => {
    const user = await createTestUser(app, {
      email: 'naver-sync@test.com',
      name: 'Naver Sync Test',
    });
    userId = user.user.id;

    const calendar = await prisma.calendar.create({
      data: {
        name: 'Naver Calendar',
        color: '#03C75A',
        type: 'EXTERNAL',
        ownerId: userId,
      },
    });
    calendarId = calendar.id;

    const connection = await prisma.externalCalendarConnection.create({
      data: {
        provider: 'naver',
        externalId: 'testnaverid',
        accessToken: 'test-app-password',
        refreshToken: '',
        calendarId: calendar.id,
        userId,
      },
    });
    connectionId = connection.id;
  });

  afterEach(() => {
    globalThis.fetch = realFetch;
  });

  it('test_50_upsert_vevent_events — fetched VEVENTs are upserted for the Naver connection', async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: true,
      text: async () => TWO_EVENTS_ICS,
    });

    const result = await naverSyncService.pullEvents(userId, connectionId);

    // Service reports 2 adds, 0 updates
    expect(result.added).toBe(2);
    expect(result.updated).toBe(0);

    // Verify events persisted in DB with correct fields
    const events = await prisma.event.findMany({
      where: { calendarId },
      orderBy: { startTime: 'asc' },
    });
    expect(events).toHaveLength(2);

    const timed = events.find((e) => e.externalId === 'naver-uid-001@naver.com');
    expect(timed).toBeDefined();
    expect(timed!.title).toBe('Morning Meeting');
    expect(timed!.description).toBe('Team sync meeting');
    expect(timed!.isAllDay).toBe(false);
    expect(timed!.createdById).toBe(userId);
    expect(timed!.calendarId).toBe(calendarId);

    const allDay = events.find((e) => e.externalId === 'naver-uid-002@naver.com');
    expect(allDay).toBeDefined();
    expect(allDay!.title).toBe('Company Holiday');
    expect(allDay!.isAllDay).toBe(true);
    expect(allDay!.description).toBeNull();
  });

  it('test_50_no_duplicate_on_repeat_sync — repeat sync with same UIDs does not duplicate events', async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: true,
      text: async () => TWO_EVENTS_ICS,
    });

    // First sync creates 2 events
    const first = await naverSyncService.pullEvents(userId, connectionId);
    expect(first.added).toBe(2);

    // Second sync with identical content skips both
    const second = await naverSyncService.pullEvents(userId, connectionId);
    expect(second.added).toBe(0);
    expect(second.skipped).toBe(2);

    // DB still holds exactly 2 events
    const events = await prisma.event.findMany({ where: { calendarId } });
    expect(events).toHaveLength(2);
  });

  it('test_50_caldav_failure_surfaces_error — CalDAV HTTP error propagates with status code and message', async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 403,
    });

    await expect(naverSyncService.pullEvents(userId, connectionId)).rejects.toMatchObject({
      message: 'Naver CalDAV 접근에 실패했습니다. 경로가 차단되었을 수 있습니다.',
      statusCode: 403,
    });
  });

  it('test_50_nonexistent_connection_throws — pullEvents for nonexistent connection throws 404', async () => {
    // No fetch mock needed — error is thrown before any network I/O
    await expect(
      naverSyncService.pullEvents(userId, 'nonexistent-connection-id'),
    ).rejects.toMatchObject({
      message: 'Connection not found',
      statusCode: 404,
    });
  });
});
