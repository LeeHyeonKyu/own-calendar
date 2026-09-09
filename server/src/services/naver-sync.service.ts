import ical, { VEvent, ParameterValue } from 'node-ical';
import prisma from '../lib/prisma';

const NAVER_CALDAV_BASE = 'https://caldav.calendar.naver.com';

function paramValue(v: ParameterValue | undefined): string | undefined {
  if (v == null) return undefined;
  if (typeof v === 'string') return v;
  return v.val;
}

export const naverSyncService = {
  async connect(userId: string, naverId: string, password: string) {
    const icsUrl = `${NAVER_CALDAV_BASE}/caldav/${naverId}/calendar/`;
    const authHeader = 'Basic ' + Buffer.from(`${naverId}:${password}`).toString('base64');

    // Verify credentials by attempting a PROPFIND
    const res = await fetch(icsUrl, {
      method: 'PROPFIND',
      headers: {
        Authorization: authHeader,
        Depth: '0',
        'Content-Type': 'application/xml',
      },
    });

    if (!res.ok) {
      const error = new Error('Naver 인증에 실패했습니다. ID와 비밀번호를 확인해주세요.');
      (error as any).statusCode = 401;
      throw error;
    }

    const calendar = await prisma.calendar.create({
      data: {
        name: 'Naver Calendar',
        color: '#03C75A',
        type: 'EXTERNAL',
        ownerId: userId,
      },
    });

    const connection = await prisma.externalCalendarConnection.create({
      data: {
        provider: 'naver',
        externalId: naverId,
        accessToken: password,
        refreshToken: '',
        calendarId: calendar.id,
        userId,
      },
    });

    // Pull events immediately after connecting
    const pullResult = await naverSyncService.pullEvents(userId, connection.id);

    return { calendar, connection: { id: connection.id, provider: 'naver' }, ...pullResult };
  },

  async pullEvents(userId: string, connectionId: string) {
    const connection = await prisma.externalCalendarConnection.findFirst({
      where: { id: connectionId, userId, provider: 'naver' },
    });
    if (!connection) {
      const error = new Error('Connection not found');
      (error as any).statusCode = 404;
      throw error;
    }

    const icsUrl = `${NAVER_CALDAV_BASE}/caldav/${connection.externalId}/calendar/`;
    const authHeader = 'Basic ' + Buffer.from(`${connection.externalId}:${connection.accessToken}`).toString('base64');

    // Fetch calendar data via CalDAV REPORT (calendar-multiget fallback to GET)
    let icsContent: string;
    try {
      const res = await fetch(icsUrl, {
        method: 'GET',
        headers: { Authorization: authHeader, Accept: 'text/calendar' },
      });
      if (!res.ok) {
        const error = new Error('Naver CalDAV 접근에 실패했습니다. 경로가 차단되었을 수 있습니다.');
        (error as any).statusCode = res.status;
        throw error;
      }
      icsContent = await res.text();
    } catch (err: any) {
      if (err.statusCode) throw err;
      const error = new Error('Naver Calendar 동기화에 실패했습니다.');
      (error as any).statusCode = 502;
      throw error;
    }

    const parsed = ical.parseICS(icsContent);

    const vevents: VEvent[] = [];
    for (const key of Object.keys(parsed)) {
      const component = parsed[key];
      if (component && component.type === 'VEVENT') {
        vevents.push(component as VEvent);
      }
    }

    let added = 0;
    let updated = 0;
    let skipped = 0;
    let deleted = 0;

    const seenUids = new Set<string>();

    for (const vevent of vevents) {
      const uid = vevent.uid;
      if (!uid) continue;

      seenUids.add(uid);

      const title = paramValue(vevent.summary) || '(제목 없음)';
      const description = paramValue(vevent.description) || null;
      const startTime = vevent.start ? new Date(vevent.start) : null;
      const endTime = vevent.end ? new Date(vevent.end) : null;

      if (!startTime) continue;
      const effectiveEndTime = endTime || startTime;
      const isAllDay = vevent.datetype === 'date';

      const existing = await prisma.event.findFirst({
        where: { externalId: uid, calendarId: connection.calendarId },
      });

      if (existing) {
        const contentSame =
          existing.title === title &&
          existing.description === description &&
          existing.startTime.getTime() === startTime.getTime() &&
          existing.endTime.getTime() === effectiveEndTime.getTime() &&
          existing.isAllDay === isAllDay;

        if (contentSame) {
          skipped++;
        } else {
          await prisma.event.update({
            where: { id: existing.id },
            data: { title, description, startTime, endTime: effectiveEndTime, isAllDay },
          });
          updated++;
        }
      } else {
        await prisma.event.create({
          data: {
            title,
            description,
            startTime,
            endTime: effectiveEndTime,
            isAllDay,
            calendarId: connection.calendarId,
            createdById: userId,
            externalId: uid,
          },
        });
        added++;
      }
    }

    // Delete events that are no longer in Naver
    const localEvents = await prisma.event.findMany({
      where: { calendarId: connection.calendarId, externalId: { not: null } },
      select: { id: true, externalId: true },
    });
    for (const local of localEvents) {
      if (local.externalId && !seenUids.has(local.externalId)) {
        await prisma.event.delete({ where: { id: local.id } });
        deleted++;
      }
    }

    await prisma.externalCalendarConnection.update({
      where: { id: connection.id },
      data: { lastSyncedAt: new Date() },
    });

    return { added, updated, skipped, deleted };
  },

  async listConnections(userId: string) {
    return prisma.externalCalendarConnection.findMany({
      where: { userId, provider: 'naver' },
      select: {
        id: true,
        provider: true,
        externalId: true,
        lastSyncedAt: true,
        calendar: { select: { id: true, name: true, color: true } },
      },
    });
  },

  async disconnect(userId: string, connectionId: string) {
    const connection = await prisma.externalCalendarConnection.findFirst({
      where: { id: connectionId, userId, provider: 'naver' },
    });
    if (!connection) {
      const error = new Error('Connection not found');
      (error as any).statusCode = 404;
      throw error;
    }

    await prisma.externalCalendarConnection.delete({ where: { id: connection.id } });
    await prisma.calendar.delete({ where: { id: connection.calendarId } });

    return { success: true };
  },
};
