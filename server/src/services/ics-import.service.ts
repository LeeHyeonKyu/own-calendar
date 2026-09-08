import ical, { VEvent, ParameterValue } from 'node-ical';
import prisma from '../lib/prisma';

export interface IcsImportResult {
  added: number;
  updated: number;
  skipped: number;
  calendarId: string;
  calendarName: string;
}

/** Extract the plain string value from a ParameterValue (which may be string or {val, params}). */
function paramValue(v: ParameterValue | undefined): string | undefined {
  if (v == null) return undefined;
  if (typeof v === 'string') return v;
  return v.val;
}

export const icsImportService = {
  /**
   * Parse an ICS file buffer and import VEVENT entries into a new PERSONAL calendar.
   * UID-based dedup: same UID + same content → skip, same UID + different SEQUENCE/LAST-MODIFIED → update, new UID → insert.
   */
  async importIcs(userId: string, fileBuffer: Buffer, fileName?: string): Promise<IcsImportResult> {
    const icsContent = fileBuffer.toString('utf-8');

    // Parse ICS
    const parsed = ical.parseICS(icsContent);

    // Extract VEVENT components
    const vevents: VEvent[] = [];
    for (const key of Object.keys(parsed)) {
      const component = parsed[key];
      if (component && component.type === 'VEVENT') {
        vevents.push(component as VEvent);
      }
    }

    if (vevents.length === 0) {
      const error = new Error('가져올 일정이 없습니다');
      (error as any).statusCode = 400;
      throw error;
    }

    // Derive calendar name from the ICS file or filename
    const calName = parsed.vcalendar?.['WR-CALNAME'];
    const sourceName = calName || (fileName ? fileName.replace(/\.ics$/i, '') : 'ICS');
    const today = new Date().toISOString().split('T')[0];
    const calendarName = `${sourceName} Import ${today}`;

    // Create an import-dedicated PERSONAL calendar
    const calendar = await prisma.calendar.create({
      data: {
        name: calendarName,
        type: 'PERSONAL',
        ownerId: userId,
      },
    });

    let added = 0;
    let updated = 0;
    let skipped = 0;

    for (const vevent of vevents) {
      const uid = vevent.uid;
      if (!uid) continue;

      const title = paramValue(vevent.summary) || '(제목 없음)';
      const description = paramValue(vevent.description) || null;
      const startTime = vevent.start ? new Date(vevent.start) : null;
      const endTime = vevent.end ? new Date(vevent.end) : null;

      if (!startTime) continue;

      // If no end time, default to same as start (for all-day events or point events)
      const effectiveEndTime = endTime || startTime;

      // Determine if all-day event
      const isAllDay = vevent.datetype === 'date';

      // Check for existing event with the same UID in ANY calendar owned by this user
      const existing = await prisma.event.findFirst({
        where: {
          externalId: uid,
          calendar: { ownerId: userId },
        },
      });

      if (existing) {
        // Check if content has changed (SEQUENCE or LAST-MODIFIED based)
        const incomingSequence = vevent.sequence ?? 0;
        const incomingLastModified = vevent.lastmodified
          ? new Date(vevent.lastmodified).getTime()
          : 0;

        // Compare content: title, description, start, end
        const contentSame =
          existing.title === title &&
          existing.description === description &&
          existing.startTime.getTime() === startTime.getTime() &&
          existing.endTime.getTime() === effectiveEndTime.getTime() &&
          existing.isAllDay === isAllDay;

        if (contentSame) {
          skipped++;
        } else {
          // Update the existing event
          await prisma.event.update({
            where: { id: existing.id },
            data: {
              title,
              description,
              startTime,
              endTime: effectiveEndTime,
              isAllDay,
            },
          });
          updated++;
        }
      } else {
        // Insert new event
        await prisma.event.create({
          data: {
            title,
            description,
            startTime,
            endTime: effectiveEndTime,
            isAllDay,
            calendarId: calendar.id,
            createdById: userId,
            externalId: uid,
          },
        });
        added++;
      }
    }

    return {
      added,
      updated,
      skipped,
      calendarId: calendar.id,
      calendarName,
    };
  },
};
