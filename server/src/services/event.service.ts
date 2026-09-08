import prisma from '../lib/prisma';

function generateRecurrenceInstances(event: any, queryStart: Date, queryEnd: Date): any[] {
  if (event.recurrenceType === 'NONE') return [event];

  const instances: any[] = [];
  const eventDuration = event.endTime.getTime() - event.startTime.getTime();
  const origStart = event.startTime;
  const recEnd = event.recurrenceEnd ? new Date(event.recurrenceEnd) : queryEnd;
  const limit = recEnd < queryEnd ? recEnd : queryEnd;

  let cursor = new Date(origStart);

  for (let i = 0; i < 1000; i++) {
    const instanceStart = new Date(cursor);
    const instanceEnd = new Date(instanceStart.getTime() + eventDuration);

    if (instanceStart > limit) break;

    if (instanceEnd >= queryStart && instanceStart <= queryEnd) {
      const isOriginal = instanceStart.getTime() === origStart.getTime();
      instances.push({
        ...event,
        id: isOriginal ? event.id : `${event.id}_${instanceStart.toISOString()}`,
        startTime: instanceStart,
        endTime: instanceEnd,
      });
    }

    switch (event.recurrenceType) {
      case 'DAILY':
        cursor.setDate(cursor.getDate() + 1);
        break;
      case 'WEEKLY':
        cursor.setDate(cursor.getDate() + 7);
        break;
      case 'MONTHLY': {
        const origDay = origStart.getDate();
        const nextMonth = cursor.getMonth() + 1;
        cursor.setMonth(nextMonth);
        const daysInMonth = new Date(cursor.getFullYear(), cursor.getMonth() + 1, 0).getDate();
        if (origDay > daysInMonth) {
          cursor.setDate(daysInMonth);
        } else {
          cursor.setDate(origDay);
        }
        break;
      }
      case 'YEARLY': {
        const origMonth = origStart.getMonth();
        const origDayY = origStart.getDate();
        cursor.setFullYear(cursor.getFullYear() + 1);
        cursor.setMonth(origMonth);
        const daysInMonthY = new Date(cursor.getFullYear(), origMonth + 1, 0).getDate();
        if (origDayY > daysInMonthY) {
          cursor.setDate(daysInMonthY);
        } else {
          cursor.setDate(origDayY);
        }
        break;
      }
    }
  }

  return instances;
}

export const eventService = {
  async list(userId: string, query: { calendarId?: string; category?: string; start?: string; end?: string; includeTasks?: string }) {
    const where: any = {
      calendar: { ownerId: userId },
    };

    if (query.calendarId) {
      where.calendarId = query.calendarId;
    }

    if (query.category) {
      where.category = query.category;
    }

    const queryStart = query.start ? new Date(query.start) : new Date(0);
    const queryEnd = query.end ? new Date(query.end) : new Date('2100-01-01');

    // For recurring events, we need to find events whose original start is before queryEnd
    // and whose recurrenceEnd (or infinity) is after queryStart
    const dbEvents = await prisma.event.findMany({
      where: {
        ...where,
        OR: [
          // Non-recurring: normal time range filter
          {
            recurrenceType: 'NONE',
            ...(query.start ? { startTime: { gte: queryStart } } : {}),
            ...(query.end ? { endTime: { lte: queryEnd } } : {}),
          },
          // Recurring: original start before query end, and (no recurrenceEnd OR recurrenceEnd after query start)
          {
            recurrenceType: { not: 'NONE' },
            startTime: { lte: queryEnd },
            OR: [
              { recurrenceEnd: null },
              { recurrenceEnd: { gte: queryStart } },
            ],
          },
        ],
      },
      include: {
        calendar: true,
        ...(query.includeTasks === 'true' ? { tasks: { orderBy: [{ sortOrder: 'asc' as const }, { dueDate: 'asc' as const }] } } : {}),
      },
    });

    const result: any[] = [];
    for (const event of dbEvents) {
      if (event.recurrenceType === 'NONE') {
        result.push(event);
      } else {
        result.push(...generateRecurrenceInstances(event, queryStart, queryEnd));
      }
    }

    return result;
  },

  async create(
    userId: string,
    data: {
      title: string;
      description?: string;
      startTime: string;
      endTime: string;
      isAllDay?: boolean;
      isPrivate?: boolean;
      category?: string;
      tags?: string[];
      recurrenceType?: string;
      recurrenceEnd?: string | null;
      calendarId: string;
    },
  ) {
    const calendar = await prisma.calendar.findUnique({
      where: { id: data.calendarId },
    });

    if (!calendar) {
      const error = new Error('Calendar not found');
      (error as any).statusCode = 404;
      throw error;
    }

    if (calendar.ownerId !== userId) {
      const error = new Error('Forbidden');
      (error as any).statusCode = 403;
      throw error;
    }

    return prisma.event.create({
      data: {
        title: data.title,
        description: data.description,
        startTime: new Date(data.startTime),
        endTime: new Date(data.endTime),
        isAllDay: data.isAllDay,
        isPrivate: data.isPrivate,
        category: data.category as any,
        tags: data.tags,
        recurrenceType: (data.recurrenceType as any) || 'NONE',
        recurrenceEnd: data.recurrenceEnd ? new Date(data.recurrenceEnd) : null,
        calendarId: data.calendarId,
        createdById: userId,
      },
    });
  },

  async update(
    userId: string,
    eventId: string,
    data: {
      title?: string;
      description?: string | null;
      startTime?: string;
      endTime?: string;
      isAllDay?: boolean;
      isPrivate?: boolean;
      category?: string;
      tags?: string[];
      recurrenceType?: string;
      recurrenceEnd?: string | null;
      calendarId?: string;
    },
  ) {
    // Strip recurrence instance suffix to find the original event
    const baseId = eventId.includes('_') ? eventId.split('_').slice(0, -1).join('_') : eventId;
    const event = await prisma.event.findUnique({ where: { id: baseId } });

    if (!event) {
      const error = new Error('Event not found');
      (error as any).statusCode = 404;
      throw error;
    }

    if (event.createdById !== userId) {
      const error = new Error('Forbidden');
      (error as any).statusCode = 403;
      throw error;
    }

    if (data.calendarId) {
      const calendar = await prisma.calendar.findUnique({
        where: { id: data.calendarId },
      });

      if (!calendar) {
        const error = new Error('Calendar not found');
        (error as any).statusCode = 404;
        throw error;
      }

      if (calendar.ownerId !== userId) {
        const error = new Error('Forbidden');
        (error as any).statusCode = 403;
        throw error;
      }
    }

    const updateData: any = { ...data };
    if (data.startTime) {
      updateData.startTime = new Date(data.startTime);
    }
    if (data.endTime) {
      updateData.endTime = new Date(data.endTime);
    }
    if (data.recurrenceEnd !== undefined) {
      updateData.recurrenceEnd = data.recurrenceEnd ? new Date(data.recurrenceEnd) : null;
    }

    return prisma.event.update({
      where: { id: baseId },
      data: updateData,
    });
  },

  async search(userId: string, query: string, start?: string, end?: string) {
    const calendars = await prisma.calendar.findMany({
      where: { ownerId: userId },
      select: { id: true },
    });
    const calendarIds = calendars.map((c) => c.id);

    const memberships = await prisma.familyMembership.findMany({
      where: { userId },
      include: { familyGroup: { include: { calendar: true } } },
    });
    for (const m of memberships) {
      if (m.familyGroup.calendar) {
        calendarIds.push(m.familyGroup.calendar.id);
      }
    }

    const where: any = {
      calendarId: { in: calendarIds },
      OR: [
        { title: { contains: query, mode: 'insensitive' } },
        { description: { contains: query, mode: 'insensitive' } },
        { tags: { has: query } },
      ],
    };

    if (start) where.startTime = { ...(where.startTime || {}), gte: new Date(start) };
    if (end) where.endTime = { ...(where.endTime || {}), lte: new Date(end) };

    return prisma.event.findMany({
      where,
      include: { calendar: { select: { id: true, name: true, color: true } } },
      orderBy: { startTime: 'desc' },
    });
  },

  async delete(userId: string, eventId: string) {
    // Strip recurrence instance suffix
    const baseId = eventId.includes('_') ? eventId.split('_').slice(0, -1).join('_') : eventId;
    const event = await prisma.event.findUnique({ where: { id: baseId } });

    if (!event) {
      const error = new Error('Event not found');
      (error as any).statusCode = 404;
      throw error;
    }

    if (event.createdById !== userId) {
      const error = new Error('Forbidden');
      (error as any).statusCode = 403;
      throw error;
    }

    await prisma.event.delete({ where: { id: baseId } });
  },
};
