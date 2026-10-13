import prisma from '../lib/prisma';
import { recurrenceService } from './recurrence.service';

type EditMode = 'this' | 'thisAndFuture' | 'all';

/**
 * Split a (possibly virtual) instance id into its master id and the
 * occurrence date encoded in the suffix, e.g.
 * `${masterId}_${instanceDate.toISOString()}` -> { baseId: masterId, instanceDate }
 */
function resolveInstance(id: string, instanceDateParam?: string): { baseId: string; instanceDate: Date | null } {
  let baseId = id;
  let instanceDate: Date | null = null;

  if (id.includes('_')) {
    const idx = id.lastIndexOf('_');
    const prefix = id.slice(0, idx);
    const suffix = id.slice(idx + 1);
    if (suffix.includes('T') && suffix.includes(':')) {
      baseId = prefix;
      const parsed = new Date(suffix);
      if (!isNaN(parsed.getTime())) {
        instanceDate = parsed;
      }
    }
  }

  if (instanceDateParam) {
    const parsed = new Date(instanceDateParam);
    if (!isNaN(parsed.getTime())) {
      instanceDate = parsed;
    }
  }

  return { baseId, instanceDate };
}

/**
 * Expand a single master event into its concrete occurrences within
 * [queryStart, queryEnd], applying any RecurrenceException overrides
 * (edited or deleted instances) along the way.
 */
function expandEventInstances(event: any, queryStart: Date, queryEnd: Date): any[] {
  const rruleStr = recurrenceService.resolveRRule(event);
  if (!rruleStr) return [event];

  const duration = event.endTime.getTime() - event.startTime.getTime();

  let occurrences: Date[];
  try {
    occurrences = recurrenceService.expandInstances(rruleStr, event.startTime, queryStart, queryEnd);
  } catch {
    // Malformed rrule string - fall back to treating it as a single event.
    return [event];
  }

  const exceptionsByDate = new Map<number, any>();
  for (const ex of event.exceptions || []) {
    exceptionsByDate.set(new Date(ex.originalDate).getTime(), ex);
  }

  const instances: any[] = [];
  for (const occStart of occurrences) {
    const exception = exceptionsByDate.get(occStart.getTime());
    if (exception?.isDeleted) continue;

    const isOriginal = occStart.getTime() === event.startTime.getTime();
    const instanceStart = exception?.startTime ?? occStart;
    const instanceEnd = exception?.endTime ?? new Date(occStart.getTime() + duration);

    instances.push({
      ...event,
      id: isOriginal ? event.id : `${event.id}_${occStart.toISOString()}`,
      title: exception?.title ?? event.title,
      description: exception?.description ?? event.description,
      startTime: instanceStart,
      endTime: instanceEnd,
      isAllDay: exception?.isAllDay ?? event.isAllDay,
      exceptions: undefined,
    });
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
          // Non-recurring: overlap check (event touches the query window)
          {
            recurrenceType: 'NONE',
            rrule: null,
            ...(query.end ? { startTime: { lt: queryEnd } } : {}),
            ...(query.start ? { endTime: { gt: queryStart } } : {}),
          },
          // Recurring (rrule field or legacy recurrenceType): original start before
          // query end, and (no recurrenceEnd OR recurrenceEnd after query start).
          // Note: recurrenceEnd may be null for rrule-based events even when the
          // rrule itself carries an UNTIL - the real bound is enforced during expansion.
          {
            AND: [
              { OR: [{ recurrenceType: { not: 'NONE' } }, { rrule: { not: null } }] },
              { startTime: { lte: queryEnd } },
              { OR: [{ recurrenceEnd: null }, { recurrenceEnd: { gte: queryStart } }] },
            ],
          },
        ],
      },
      include: {
        calendar: true,
        exceptions: true,
        ...(query.includeTasks === 'true' ? { tasks: { orderBy: [{ sortOrder: 'asc' as const }, { dueDate: 'asc' as const }] } } : {}),
      },
    });

    const result: any[] = [];
    for (const event of dbEvents) {
      const rruleStr = recurrenceService.resolveRRule(event);
      if (!rruleStr) {
        const { exceptions, ...rest } = event as any;
        result.push(rest);
      } else {
        result.push(...expandEventInstances(event, queryStart, queryEnd));
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
      rrule?: string | null;
      calendarId: string;
      location?: string;
      notes?: string;
      attendees?: any;
      reminderMinutes?: number | null;
      categoryId?: string | null;
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
        rrule: data.rrule || null,
        calendarId: data.calendarId,
        createdById: userId,
        location: data.location || null,
        notes: data.notes || null,
        attendees: data.attendees || undefined,
        reminderMinutes: data.reminderMinutes ?? null,
        categoryId: data.categoryId || null,
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
      rrule?: string | null;
      calendarId?: string;
      location?: string | null;
      notes?: string | null;
      attendees?: any;
      reminderMinutes?: number | null;
      categoryId?: string | null;
    },
  ) {
    // Strip recurrence instance suffix to find the original event
    const { baseId } = resolveInstance(eventId);
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
    delete updateData.editMode;
    delete updateData.instanceDate;
    if (data.startTime) {
      updateData.startTime = new Date(data.startTime);
    }
    if (data.endTime) {
      updateData.endTime = new Date(data.endTime);
    }
    if (data.recurrenceEnd !== undefined) {
      updateData.recurrenceEnd = data.recurrenceEnd ? new Date(data.recurrenceEnd) : null;
    }
    if (data.rrule !== undefined) {
      updateData.rrule = data.rrule || null;
    }

    return prisma.event.update({
      where: { id: baseId },
      data: updateData,
    });
  },

  /**
   * Update an event honoring the recurrence edit scope:
   *  - 'all'          - update the master event (and thus every occurrence).
   *  - 'this'          - create/update a RecurrenceException for just this occurrence.
   *  - 'thisAndFuture' - truncate the master's rrule to end right before this
   *                      occurrence, and spin off a new master event (with the
   *                      submitted data) that continues the series from here.
   */
  async updateWithMode(
    userId: string,
    eventId: string,
    instanceDateParam: string | undefined,
    editMode: EditMode,
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
      rrule?: string | null;
      calendarId?: string;
      location?: string | null;
      notes?: string | null;
      attendees?: any;
      reminderMinutes?: number | null;
      categoryId?: string | null;
    },
  ) {
    const { baseId, instanceDate } = resolveInstance(eventId, instanceDateParam);

    if (editMode === 'all' || !instanceDate) {
      return eventService.update(userId, baseId, data);
    }

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

    if (editMode === 'this') {
      const exceptionData: any = {
        isDeleted: false,
      };
      if (data.title !== undefined) exceptionData.title = data.title;
      if (data.description !== undefined) exceptionData.description = data.description;
      if (data.startTime !== undefined) exceptionData.startTime = new Date(data.startTime);
      if (data.endTime !== undefined) exceptionData.endTime = new Date(data.endTime);
      if (data.isAllDay !== undefined) exceptionData.isAllDay = data.isAllDay;

      const exception = await prisma.recurrenceException.upsert({
        where: {
          masterEventId_originalDate: {
            masterEventId: baseId,
            originalDate: instanceDate,
          },
        },
        create: {
          masterEventId: baseId,
          originalDate: instanceDate,
          ...exceptionData,
        },
        update: exceptionData,
      });

      const duration = event.endTime.getTime() - event.startTime.getTime();
      return {
        ...event,
        id: `${event.id}_${instanceDate.toISOString()}`,
        title: exception.title ?? event.title,
        description: exception.description ?? event.description,
        startTime: exception.startTime ?? instanceDate,
        endTime: exception.endTime ?? new Date(instanceDate.getTime() + duration),
        isAllDay: exception.isAllDay ?? event.isAllDay,
      };
    }

    // thisAndFuture
    const currentRRule = recurrenceService.resolveRRule(event);
    if (!currentRRule) {
      // Not actually recurring - fall back to a plain update.
      return eventService.update(userId, baseId, data);
    }

    const untilBoundary = new Date(instanceDate.getTime() - 1000);
    const truncatedRRule = recurrenceService.truncateRRule(currentRRule, untilBoundary);

    await prisma.$transaction([
      prisma.event.update({
        where: { id: baseId },
        data: { rrule: truncatedRRule },
      }),
      prisma.recurrenceException.deleteMany({
        where: { masterEventId: baseId, originalDate: { gte: instanceDate } },
      }),
    ]);

    const duration = event.endTime.getTime() - event.startTime.getTime();
    const newStartTime = data.startTime ? new Date(data.startTime) : instanceDate;
    const newEndTime = data.endTime ? new Date(data.endTime) : new Date(newStartTime.getTime() + duration);

    return prisma.event.create({
      data: {
        title: data.title ?? event.title,
        description: data.description !== undefined ? data.description : event.description,
        startTime: newStartTime,
        endTime: newEndTime,
        isAllDay: data.isAllDay ?? event.isAllDay,
        isPrivate: data.isPrivate ?? event.isPrivate,
        category: (data.category as any) ?? event.category,
        tags: data.tags ?? event.tags,
        recurrenceType: (data.recurrenceType as any) ?? event.recurrenceType,
        recurrenceEnd: data.recurrenceEnd !== undefined
          ? (data.recurrenceEnd ? new Date(data.recurrenceEnd) : null)
          : event.recurrenceEnd,
        rrule: data.rrule !== undefined ? (data.rrule || null) : currentRRule,
        calendarId: data.calendarId ?? event.calendarId,
        createdById: userId,
      },
    });
  },

  async search(userId: string, query: string, start?: string, end?: string) {
    const calendars = await prisma.calendar.findMany({
      where: { ownerId: userId },
      select: { id: true },
    });
    const calendarIds = calendars.map((c) => c.id);

    const familyMemberships = await prisma.familyMembership.findMany({
      where: { userId },
      include: { familyGroup: { include: { calendar: true } } },
    });
    for (const m of familyMemberships) {
      if (m.familyGroup.calendar) {
        calendarIds.push(m.familyGroup.calendar.id);
      }
    }

    const groupMemberships = await prisma.groupMembership.findMany({
      where: { userId },
      include: { group: { include: { calendar: true } } },
    });
    for (const m of groupMemberships) {
      if (m.group.calendar && !calendarIds.includes(m.group.calendar.id)) {
        calendarIds.push(m.group.calendar.id);
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
    const { baseId } = resolveInstance(eventId);
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

  /**
   * Delete an event honoring the recurrence edit scope:
   *  - 'all'          - delete the master event (and, via cascade, its exceptions).
   *  - 'this'          - mark just this occurrence deleted via a RecurrenceException.
   *  - 'thisAndFuture' - truncate the master's rrule to end right before this
   *                      occurrence; nothing continues after it.
   */
  async deleteWithMode(userId: string, eventId: string, instanceDateParam: string | undefined, editMode: EditMode) {
    const { baseId, instanceDate } = resolveInstance(eventId, instanceDateParam);

    if (editMode === 'all' || !instanceDate) {
      return eventService.delete(userId, baseId);
    }

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

    if (editMode === 'this') {
      await prisma.recurrenceException.upsert({
        where: {
          masterEventId_originalDate: {
            masterEventId: baseId,
            originalDate: instanceDate,
          },
        },
        create: {
          masterEventId: baseId,
          originalDate: instanceDate,
          isDeleted: true,
        },
        update: { isDeleted: true },
      });
      return;
    }

    // thisAndFuture
    const currentRRule = recurrenceService.resolveRRule(event);
    if (!currentRRule) {
      // Not actually recurring - just delete the whole thing.
      await eventService.delete(userId, baseId);
      return;
    }

    const untilBoundary = new Date(instanceDate.getTime() - 1000);
    const truncatedRRule = recurrenceService.truncateRRule(currentRRule, untilBoundary);

    await prisma.$transaction([
      prisma.event.update({
        where: { id: baseId },
        data: { rrule: truncatedRRule },
      }),
      prisma.recurrenceException.deleteMany({
        where: { masterEventId: baseId, originalDate: { gte: instanceDate } },
      }),
    ]);
  },
};
