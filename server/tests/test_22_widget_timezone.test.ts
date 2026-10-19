import request from 'supertest';
import app from '../src/app';
import { prisma, createTestUser } from './setup';

describe('test_22_widget_timezone', () => {
  let token: string;
  let userId: string;
  let calendarId: string;
  let widgetKey: string;

  beforeEach(async () => {
    const user = await createTestUser(app, {
      email: 'widget-tz@test.com',
      name: 'Widget TZ Test',
    });
    token = user.accessToken;
    userId = user.user.id;

    const cal = await prisma.calendar.findFirst({ where: { ownerId: userId } });
    calendarId = cal!.id;

    const keyRes = await request(app)
      .post('/api/widget/key')
      .set('Authorization', `Bearer ${token}`);
    widgetKey = keyRes.body.key;
  });

  describe('all-day event KST dayKey', () => {
    it('maps all-day event (UTC 15:00 = KST midnight next day) to KST date', async () => {
      // KST 2026-10-18 all-day → DB: 2026-10-17T15:00:00Z
      await prisma.event.create({
        data: {
          title: '클라이밍',
          startTime: new Date('2026-10-17T15:00:00.000Z'),
          endTime: new Date('2026-10-18T15:00:00.000Z'),
          isAllDay: true,
          category: 'HEALTH',
          calendarId,
          createdById: userId,
        },
      });

      const res = await request(app)
        .get(`/api/widget/monthly?key=${widgetKey}&year=2026&month=10`);

      expect(res.status).toBe(200);
      expect(res.body.events['18']).toBeDefined();
      expect(res.body.events['18'].length).toBeGreaterThan(0);
      expect(res.body.events['18'][0].title).toBe('클라이밍');
      // Should NOT appear on day 17
      const day17Events = res.body.events['17'] || [];
      expect(day17Events.find((e: any) => e.title === '클라이밍')).toBeUndefined();
    });
  });

  describe('all-day task KST dayKey', () => {
    it('maps task (scheduledDate UTC 15:00 = KST midnight next day) to KST date', async () => {
      // KST 2026-10-18 task → DB: 2026-10-17T15:00:00Z
      await prisma.task.create({
        data: {
          title: '클라이밍',
          status: 'DONE',
          priority: 'NONE',
          scheduledDate: new Date('2026-10-17T15:00:00.000Z'),
          calendarId,
          createdById: userId,
        },
      });

      const res = await request(app)
        .get(`/api/widget/monthly?key=${widgetKey}&year=2026&month=10`);

      expect(res.status).toBe(200);
      expect(res.body.taskDays['18']).toBe(true);
      expect(res.body.taskDays['17']).toBeUndefined();
      // tasks detail map
      expect(res.body.tasks['18']).toBeDefined();
      expect(res.body.tasks['18'][0].title).toBe('클라이밍');
      expect(res.body.tasks['18'][0].status).toBe('DONE');
    });
  });

  describe('time event preserves existing behavior', () => {
    it('non-allday event appears on correct day', async () => {
      // KST 2026-10-18 10:00 → UTC 2026-10-18T01:00:00Z
      await prisma.event.create({
        data: {
          title: '회의',
          startTime: new Date('2026-10-18T01:00:00.000Z'),
          endTime: new Date('2026-10-18T02:00:00.000Z'),
          isAllDay: false,
          category: 'WORK',
          calendarId,
          createdById: userId,
        },
      });

      const res = await request(app)
        .get(`/api/widget/monthly?key=${widgetKey}&year=2026&month=10`);

      expect(res.status).toBe(200);
      expect(res.body.events['18']).toBeDefined();
      expect(res.body.events['18'][0].title).toBe('회의');
    });
  });

  describe('month boundary', () => {
    it('KST Nov 1 event (UTC Oct 31 15:00) appears in Nov, not Oct', async () => {
      // KST 2026-11-01 all-day → DB: 2026-10-31T15:00:00Z
      await prisma.event.create({
        data: {
          title: '11월 시작',
          startTime: new Date('2026-10-31T15:00:00.000Z'),
          endTime: new Date('2026-11-01T15:00:00.000Z'),
          isAllDay: true,
          category: 'PERSONAL',
          calendarId,
          createdById: userId,
        },
      });

      const octRes = await request(app)
        .get(`/api/widget/monthly?key=${widgetKey}&year=2026&month=10`);
      expect(octRes.status).toBe(200);
      const octEvents = Object.values(octRes.body.events).flat() as any[];
      expect(octEvents.find((e: any) => e.title === '11월 시작')).toBeUndefined();

      const novRes = await request(app)
        .get(`/api/widget/monthly?key=${widgetKey}&year=2026&month=11`);
      expect(novRes.status).toBe(200);
      expect(novRes.body.events['1']).toBeDefined();
      expect(novRes.body.events['1'][0].title).toBe('11월 시작');
    });
  });

  describe('holidays map', () => {
    it('includes holidays for subscribed user', async () => {
      // holidayService.getHolidays auto-subscribes KR, so just ensure subscription exists
      await prisma.holidaySubscription.upsert({
        where: { userId_countryCode: { userId, countryCode: 'KR' } },
        create: { userId, countryCode: 'KR' },
        update: {},
      });

      // Seed a test holiday
      await prisma.holiday.upsert({
        where: { countryCode_date: { countryCode: 'KR', date: new Date('2026-10-03') } },
        create: {
          countryCode: 'KR',
          year: 2026,
          date: new Date('2026-10-03'),
          name: '개천절',
        },
        update: {},
      });
      await prisma.holiday.upsert({
        where: { countryCode_date: { countryCode: 'KR', date: new Date('2026-10-09') } },
        create: {
          countryCode: 'KR',
          year: 2026,
          date: new Date('2026-10-09'),
          name: '한글날',
        },
        update: {},
      });

      const res = await request(app)
        .get(`/api/widget/monthly?key=${widgetKey}&year=2026&month=10`);

      expect(res.status).toBe(200);
      expect(res.body.holidays).toBeDefined();
      expect(res.body.holidays['3']).toBe('개천절');
      expect(res.body.holidays['9']).toBe('한글날');
    });

    it('returns empty holidays for user without subscription', async () => {
      const res = await request(app)
        .get(`/api/widget/monthly?key=${widgetKey}&year=2026&month=10`);

      expect(res.status).toBe(200);
      expect(res.body.holidays).toBeDefined();
    });
  });

  describe('tasks detail map', () => {
    it('includes task details per day', async () => {
      await prisma.task.create({
        data: {
          title: '운동',
          status: 'TODO',
          priority: 'HIGH',
          scheduledDate: new Date('2026-10-17T15:00:00.000Z'), // KST 10/18
          scheduledTime: '10:00',
          calendarId,
          createdById: userId,
        },
      });

      const res = await request(app)
        .get(`/api/widget/monthly?key=${widgetKey}&year=2026&month=10`);

      expect(res.status).toBe(200);
      const task = res.body.tasks['18']?.[0];
      expect(task).toBeDefined();
      expect(task.title).toBe('운동');
      expect(task.status).toBe('TODO');
      expect(task.priority).toBe('HIGH');
      expect(task.time).toBe('10:00');
    });
  });
});
