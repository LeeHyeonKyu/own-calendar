import { randomUUID } from 'crypto';
import prisma from '../lib/prisma';
import { recurrenceService } from './recurrence.service';

type EditMode = 'this' | 'thisAndFuture' | 'all';

function ensureChecklistIds(items: any[] | null | undefined): any[] | undefined {
  if (!items) return undefined;
  return items.map((item: any) => ({
    ...item,
    id: item.id || randomUUID(),
    children: item.children ? ensureChecklistIds(item.children) : [],
  }));
}

const taskIncludes = {
  calendar: { select: { id: true, name: true, color: true } },
  event: { select: { id: true, title: true, startTime: true } },
  categoryRef: { select: { id: true, name: true, color: true, emoji: true } },
} as const;

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
 * Expand a single master task into its concrete occurrences within
 * [queryStart, queryEnd], applying any RecurrenceException overrides
 * (edited, deleted, or completed instances) along the way.
 */
function expandTaskInstances(task: any, queryStart: Date, queryEnd: Date): any[] {
  const baseDate: Date | null = task.dueDate || task.scheduledDate;
  if (!baseDate) return [task];

  const rruleStr = recurrenceService.resolveRRule(task);
  if (!rruleStr) return [task];

  let occurrences: Date[];
  try {
    occurrences = recurrenceService.expandInstances(rruleStr, new Date(baseDate), queryStart, queryEnd);
  } catch {
    return [task];
  }

  const exceptionsByDate = new Map<number, any>();
  for (const ex of task.exceptions || []) {
    exceptionsByDate.set(new Date(ex.originalDate).getTime(), ex);
  }

  const origTime = new Date(baseDate).getTime();
  const instances: any[] = [];

  for (const occDate of occurrences) {
    const exception = exceptionsByDate.get(occDate.getTime());
    if (exception?.isDeleted) continue;

    const isOriginal = occDate.getTime() === origTime;
    const hasStatusOverride = !!exception && exception.status != null;

    instances.push({
      ...task,
      id: isOriginal ? task.id : `${task.id}_${occDate.toISOString()}`,
      title: exception?.title ?? task.title,
      description: exception?.description ?? task.description,
      dueDate: task.dueDate ? occDate : null,
      scheduledDate: task.scheduledDate ? occDate : null,
      status: hasStatusOverride ? exception.status : isOriginal ? task.status : 'TODO',
      completedAt: hasStatusOverride ? exception.completedAt : isOriginal ? task.completedAt : null,
      checklist: exception?.checklist ?? task.checklist,
      exceptions: undefined,
    });
  }

  return instances;
}

export const taskService = {
  async list(userId: string, query: {
    calendarId?: string;
    status?: string;
    eventId?: string;
    start?: string;
    end?: string;
    includeDone?: string;
    isHabit?: string;
  }) {
    const where: any = {
      calendar: { ownerId: userId },
    };

    if (query.calendarId) {
      where.calendarId = query.calendarId;
    }

    if (query.status) {
      where.status = query.status;
    } else if (query.includeDone !== 'true') {
      where.status = { not: 'CANCELLED' };
    }

    if (query.eventId) {
      where.eventId = query.eventId;
    }

    if (query.isHabit === 'true') {
      where.isHabit = true;
    } else if (query.isHabit === 'false') {
      where.isHabit = false;
    }

    const queryStart = query.start ? new Date(query.start) : new Date(0);
    const queryEnd = query.end ? new Date(query.end) : new Date('2100-01-01');

    const dbTasks = await prisma.task.findMany({
      where: {
        ...where,
        OR: [
          // Non-recurring with due date
          {
            recurrenceType: 'NONE',
            rrule: null,
            dueDate: { not: null },
            ...(query.start ? { dueDate: { gte: queryStart } } : {}),
            ...(query.end ? { dueDate: { lte: queryEnd } } : {}),
          },
          // Non-recurring with scheduled date
          {
            recurrenceType: 'NONE',
            rrule: null,
            dueDate: null,
            scheduledDate: { not: null },
            ...(query.start ? { scheduledDate: { gte: queryStart } } : {}),
            ...(query.end ? { scheduledDate: { lte: queryEnd } } : {}),
          },
          // Non-recurring with no date (always included)
          {
            recurrenceType: 'NONE',
            rrule: null,
            dueDate: null,
            scheduledDate: null,
          },
          // Recurring (rrule field or legacy recurrenceType): base date before query end
          {
            AND: [
              { OR: [{ recurrenceType: { not: 'NONE' } }, { rrule: { not: null } }] },
              {
                OR: [
                  {
                    dueDate: { lte: queryEnd },
                    OR: [{ recurrenceEnd: null }, { recurrenceEnd: { gte: queryStart } }],
                  },
                  {
                    scheduledDate: { lte: queryEnd },
                    OR: [{ recurrenceEnd: null }, { recurrenceEnd: { gte: queryStart } }],
                  },
                ],
              },
            ],
          },
        ],
      },
      include: {
        ...taskIncludes,
        exceptions: true,
      },
      orderBy: [
        { sortOrder: 'asc' },
        { dueDate: 'asc' },
        { createdAt: 'asc' },
      ],
    });

    const result: any[] = [];
    for (const task of dbTasks) {
      const rruleStr = recurrenceService.resolveRRule(task);
      if (!rruleStr) {
        const { exceptions, ...rest } = task as any;
        result.push(rest);
      } else {
        result.push(...expandTaskInstances(task, queryStart, queryEnd));
      }
    }

    return result;
  },

  async create(
    userId: string,
    data: {
      title: string;
      description?: string;
      priority?: string;
      dueDate?: string | null;
      scheduledDate?: string | null;
      scheduledTime?: string | null;
      recurrenceType?: string;
      recurrenceEnd?: string | null;
      rrule?: string | null;
      eventId?: string | null;
      calendarId: string;
      sortOrder?: number;
      location?: string;
      notes?: string;
      attendees?: any;
      metaInherited?: boolean;
      categoryId?: string | null;
      checklist?: any;
      isHabit?: boolean;
    },
  ) {
    // Habits require a recurrence rule
    if (data.isHabit && !data.rrule && (!data.recurrenceType || data.recurrenceType === 'NONE')) {
      const error = new Error('Habits must have a recurrence rule');
      (error as any).statusCode = 400;
      throw error;
    }

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

    if (data.eventId) {
      const event = await prisma.event.findUnique({ where: { id: data.eventId } });
      if (!event) {
        const error = new Error('Event not found');
        (error as any).statusCode = 404;
        throw error;
      }
    }

    return prisma.task.create({
      data: {
        title: data.title,
        description: data.description,
        priority: (data.priority as any) || 'NONE',
        dueDate: data.dueDate ? new Date(data.dueDate) : null,
        scheduledDate: data.scheduledDate ? new Date(data.scheduledDate) : null,
        scheduledTime: data.scheduledTime || null,
        recurrenceType: (data.recurrenceType as any) || 'NONE',
        recurrenceEnd: data.recurrenceEnd ? new Date(data.recurrenceEnd) : null,
        rrule: data.rrule || null,
        eventId: data.eventId || null,
        calendarId: data.calendarId,
        createdById: userId,
        sortOrder: data.sortOrder ?? 0,
        location: data.location || null,
        notes: data.notes || null,
        attendees: data.attendees || undefined,
        metaInherited: data.metaInherited ?? false,
        categoryId: data.categoryId || null,
        checklist: ensureChecklistIds(data.checklist),
        isHabit: data.isHabit ?? false,
      },
      include: taskIncludes,
    });
  },

  async update(
    userId: string,
    taskId: string,
    data: {
      title?: string;
      description?: string | null;
      status?: string;
      priority?: string;
      dueDate?: string | null;
      scheduledDate?: string | null;
      scheduledTime?: string | null;
      recurrenceType?: string;
      recurrenceEnd?: string | null;
      rrule?: string | null;
      eventId?: string | null;
      calendarId?: string;
      sortOrder?: number;
      location?: string | null;
      notes?: string | null;
      attendees?: any;
      metaInherited?: boolean;
      categoryId?: string | null;
      checklist?: any;
      isHabit?: boolean;
    },
  ) {
    const { baseId } = resolveInstance(taskId);
    const task = await prisma.task.findUnique({ where: { id: baseId } });

    if (!task) {
      const error = new Error('Task not found');
      (error as any).statusCode = 404;
      throw error;
    }

    if (task.createdById !== userId) {
      const error = new Error('Forbidden');
      (error as any).statusCode = 403;
      throw error;
    }

    // Validate habit requires rrule
    const effectiveIsHabit = data.isHabit !== undefined ? data.isHabit : task.isHabit;
    const effectiveRrule = data.rrule !== undefined ? data.rrule : task.rrule;
    const effectiveRecurrenceType = data.recurrenceType !== undefined ? data.recurrenceType : task.recurrenceType;
    if (effectiveIsHabit && !effectiveRrule && (!effectiveRecurrenceType || effectiveRecurrenceType === 'NONE')) {
      const error = new Error('Habits must have a recurrence rule');
      (error as any).statusCode = 400;
      throw error;
    }

    if (data.calendarId) {
      const calendar = await prisma.calendar.findUnique({ where: { id: data.calendarId } });
      if (!calendar || calendar.ownerId !== userId) {
        const error = new Error('Calendar not found or forbidden');
        (error as any).statusCode = data.calendarId ? 403 : 404;
        throw error;
      }
    }

    if (data.eventId) {
      const event = await prisma.event.findUnique({ where: { id: data.eventId } });
      if (!event) {
        const error = new Error('Event not found');
        (error as any).statusCode = 404;
        throw error;
      }
    }

    const updateData: any = {};
    if (data.title !== undefined) updateData.title = data.title;
    if (data.description !== undefined) updateData.description = data.description;
    if (data.status !== undefined) {
      updateData.status = data.status;
      if (data.status === 'DONE') {
        updateData.completedAt = new Date();
      } else if (data.status === 'TODO') {
        updateData.completedAt = null;
      }
    }
    if (data.priority !== undefined) updateData.priority = data.priority;
    if (data.dueDate !== undefined) updateData.dueDate = data.dueDate ? new Date(data.dueDate) : null;
    if (data.scheduledDate !== undefined) updateData.scheduledDate = data.scheduledDate ? new Date(data.scheduledDate) : null;
    if (data.scheduledTime !== undefined) updateData.scheduledTime = data.scheduledTime;
    if (data.recurrenceType !== undefined) updateData.recurrenceType = data.recurrenceType;
    if (data.recurrenceEnd !== undefined) updateData.recurrenceEnd = data.recurrenceEnd ? new Date(data.recurrenceEnd) : null;
    if (data.rrule !== undefined) updateData.rrule = data.rrule || null;
    if (data.eventId !== undefined) updateData.eventId = data.eventId;
    if (data.calendarId !== undefined) updateData.calendarId = data.calendarId;
    if (data.sortOrder !== undefined) updateData.sortOrder = data.sortOrder;
    if (data.location !== undefined) updateData.location = data.location;
    if (data.notes !== undefined) updateData.notes = data.notes;
    if (data.attendees !== undefined) updateData.attendees = data.attendees;
    if (data.metaInherited !== undefined) updateData.metaInherited = data.metaInherited;
    if (data.categoryId !== undefined) updateData.categoryId = data.categoryId;
    if (data.checklist !== undefined) updateData.checklist = ensureChecklistIds(data.checklist);
    if (data.isHabit !== undefined) updateData.isHabit = data.isHabit;

    return prisma.task.update({
      where: { id: baseId },
      data: updateData,
      include: taskIncludes,
    });
  },

  /**
   * Update a task honoring the recurrence edit scope:
   *  - 'all'          - update the master task (and thus every occurrence).
   *  - 'this'          - create/update a RecurrenceException for just this occurrence.
   *  - 'thisAndFuture' - truncate the master's rrule to end right before this
   *                      occurrence, and spin off a new master task (with the
   *                      submitted data) that continues the series from here.
   */
  async updateWithMode(
    userId: string,
    taskId: string,
    instanceDateParam: string | undefined,
    editMode: EditMode,
    data: {
      title?: string;
      description?: string | null;
      status?: string;
      priority?: string;
      dueDate?: string | null;
      scheduledDate?: string | null;
      scheduledTime?: string | null;
      recurrenceType?: string;
      recurrenceEnd?: string | null;
      rrule?: string | null;
      eventId?: string | null;
      calendarId?: string;
      sortOrder?: number;
    },
  ) {
    const { baseId, instanceDate } = resolveInstance(taskId, instanceDateParam);

    if (editMode === 'all' || !instanceDate) {
      return taskService.update(userId, baseId, data);
    }

    const task = await prisma.task.findUnique({ where: { id: baseId } });
    if (!task) {
      const error = new Error('Task not found');
      (error as any).statusCode = 404;
      throw error;
    }
    if (task.createdById !== userId) {
      const error = new Error('Forbidden');
      (error as any).statusCode = 403;
      throw error;
    }

    if (editMode === 'this') {
      const exceptionData: any = { isDeleted: false };
      if (data.title !== undefined) exceptionData.title = data.title;
      if (data.description !== undefined) exceptionData.description = data.description;
      if (data.status !== undefined) {
        exceptionData.status = data.status;
        exceptionData.completedAt = data.status === 'DONE' ? new Date() : null;
      }

      const exception = await prisma.recurrenceException.upsert({
        where: {
          masterTaskId_originalDate: {
            masterTaskId: baseId,
            originalDate: instanceDate,
          },
        },
        create: {
          masterTaskId: baseId,
          originalDate: instanceDate,
          ...exceptionData,
        },
        update: exceptionData,
      });

      const taskWithRelations = await prisma.task.findUnique({ where: { id: baseId }, include: taskIncludes });

      return {
        ...taskWithRelations,
        id: `${baseId}_${instanceDate.toISOString()}`,
        title: exception.title ?? task.title,
        description: exception.description ?? task.description,
        dueDate: task.dueDate ? instanceDate : null,
        scheduledDate: task.scheduledDate ? instanceDate : null,
        status: exception.status ?? task.status,
        completedAt: exception.completedAt,
      };
    }

    // thisAndFuture
    const currentRRule = recurrenceService.resolveRRule(task);
    if (!currentRRule) {
      return taskService.update(userId, baseId, data);
    }

    const untilBoundary = new Date(instanceDate.getTime() - 1000);
    const truncatedRRule = recurrenceService.truncateRRule(currentRRule, untilBoundary);

    await prisma.$transaction([
      prisma.task.update({
        where: { id: baseId },
        data: { rrule: truncatedRRule },
      }),
      prisma.recurrenceException.deleteMany({
        where: { masterTaskId: baseId, originalDate: { gte: instanceDate } },
      }),
    ]);

    return prisma.task.create({
      data: {
        title: data.title ?? task.title,
        description: data.description !== undefined ? data.description : task.description,
        priority: (data.priority as any) ?? task.priority,
        dueDate: data.dueDate !== undefined ? (data.dueDate ? new Date(data.dueDate) : null) : task.dueDate ? instanceDate : null,
        scheduledDate: data.scheduledDate !== undefined
          ? (data.scheduledDate ? new Date(data.scheduledDate) : null)
          : task.scheduledDate ? instanceDate : null,
        scheduledTime: data.scheduledTime !== undefined ? data.scheduledTime : task.scheduledTime,
        recurrenceType: (data.recurrenceType as any) ?? task.recurrenceType,
        recurrenceEnd: data.recurrenceEnd !== undefined
          ? (data.recurrenceEnd ? new Date(data.recurrenceEnd) : null)
          : task.recurrenceEnd,
        rrule: data.rrule !== undefined ? (data.rrule || null) : currentRRule,
        eventId: data.eventId !== undefined ? data.eventId : task.eventId,
        calendarId: data.calendarId ?? task.calendarId,
        createdById: userId,
        sortOrder: task.sortOrder,
      },
      include: taskIncludes,
    });
  },

  async toggleComplete(userId: string, taskId: string, instanceDateParam?: string) {
    const { baseId, instanceDate } = resolveInstance(taskId, instanceDateParam);
    const task = await prisma.task.findUnique({ where: { id: baseId } });

    if (!task) {
      const error = new Error('Task not found');
      (error as any).statusCode = 404;
      throw error;
    }

    if (task.createdById !== userId) {
      const error = new Error('Forbidden');
      (error as any).statusCode = 403;
      throw error;
    }

    const rruleStr = recurrenceService.resolveRRule(task);

    if (!instanceDate || !rruleStr) {
      const newStatus = task.status === 'DONE' ? 'TODO' : 'DONE';
      return prisma.task.update({
        where: { id: baseId },
        data: {
          status: newStatus,
          completedAt: newStatus === 'DONE' ? new Date() : null,
        },
        include: taskIncludes,
      });
    }

    const existing = await prisma.recurrenceException.findUnique({
      where: {
        masterTaskId_originalDate: {
          masterTaskId: baseId,
          originalDate: instanceDate,
        },
      },
    });

    const currentlyDone = existing?.status === 'DONE';
    const newStatus = currentlyDone ? 'TODO' : 'DONE';

    const exception = await prisma.recurrenceException.upsert({
      where: {
        masterTaskId_originalDate: {
          masterTaskId: baseId,
          originalDate: instanceDate,
        },
      },
      create: {
        masterTaskId: baseId,
        originalDate: instanceDate,
        status: newStatus,
        completedAt: newStatus === 'DONE' ? new Date() : null,
      },
      update: {
        status: newStatus,
        completedAt: newStatus === 'DONE' ? new Date() : null,
      },
    });

    const taskWithRelations = await prisma.task.findUnique({ where: { id: baseId }, include: taskIncludes });
    const origTime = (task.dueDate || task.scheduledDate)?.getTime();
    const isOriginal = origTime !== undefined && instanceDate.getTime() === origTime;

    return {
      ...taskWithRelations,
      id: isOriginal ? baseId : `${baseId}_${instanceDate.toISOString()}`,
      dueDate: task.dueDate ? instanceDate : null,
      scheduledDate: task.scheduledDate ? instanceDate : null,
      status: exception.status,
      completedAt: exception.completedAt,
    };
  },

  async toggleChecklistItem(userId: string, taskId: string, itemId: string) {
    const { baseId } = resolveInstance(taskId);
    const task = await prisma.task.findUnique({ where: { id: baseId } });

    if (!task) {
      const error = new Error('Task not found');
      (error as any).statusCode = 404;
      throw error;
    }

    if (task.createdById !== userId) {
      const error = new Error('Forbidden');
      (error as any).statusCode = 403;
      throw error;
    }

    const checklist = (task.checklist as any[]) || [];

    function toggleItem(items: any[]): boolean {
      for (const item of items) {
        if (item.id === itemId) {
          item.checked = !item.checked;
          return true;
        }
        if (item.children && item.children.length > 0) {
          if (toggleItem(item.children)) return true;
        }
      }
      return false;
    }

    if (!toggleItem(checklist)) {
      const error = new Error('Checklist item not found');
      (error as any).statusCode = 404;
      throw error;
    }

    return prisma.task.update({
      where: { id: baseId },
      data: { checklist },
      include: taskIncludes,
    });
  },

  async linkEvent(userId: string, taskId: string, eventId: string | null) {
    const { baseId } = resolveInstance(taskId);
    const task = await prisma.task.findUnique({ where: { id: baseId } });

    if (!task) {
      const error = new Error('Task not found');
      (error as any).statusCode = 404;
      throw error;
    }

    if (task.createdById !== userId) {
      const error = new Error('Forbidden');
      (error as any).statusCode = 403;
      throw error;
    }

    if (eventId) {
      const event = await prisma.event.findUnique({ where: { id: eventId } });
      if (!event) {
        const error = new Error('Event not found');
        (error as any).statusCode = 404;
        throw error;
      }
    }

    return prisma.task.update({
      where: { id: baseId },
      data: { eventId },
      include: taskIncludes,
    });
  },

  async delete(userId: string, taskId: string) {
    const { baseId } = resolveInstance(taskId);
    const task = await prisma.task.findUnique({ where: { id: baseId } });

    if (!task) {
      const error = new Error('Task not found');
      (error as any).statusCode = 404;
      throw error;
    }

    if (task.createdById !== userId) {
      const error = new Error('Forbidden');
      (error as any).statusCode = 403;
      throw error;
    }

    await prisma.task.delete({ where: { id: baseId } });
  },

  /**
   * Delete a task honoring the recurrence edit scope:
   *  - 'all'          - delete the master task (and, via cascade, its exceptions).
   *  - 'this'          - mark just this occurrence deleted via a RecurrenceException.
   *  - 'thisAndFuture' - truncate the master's rrule to end right before this
   *                      occurrence; nothing continues after it.
   */
  async deleteWithMode(userId: string, taskId: string, instanceDateParam: string | undefined, editMode: EditMode) {
    const { baseId, instanceDate } = resolveInstance(taskId, instanceDateParam);

    if (editMode === 'all' || !instanceDate) {
      return taskService.delete(userId, baseId);
    }

    const task = await prisma.task.findUnique({ where: { id: baseId } });
    if (!task) {
      const error = new Error('Task not found');
      (error as any).statusCode = 404;
      throw error;
    }
    if (task.createdById !== userId) {
      const error = new Error('Forbidden');
      (error as any).statusCode = 403;
      throw error;
    }

    if (editMode === 'this') {
      await prisma.recurrenceException.upsert({
        where: {
          masterTaskId_originalDate: {
            masterTaskId: baseId,
            originalDate: instanceDate,
          },
        },
        create: {
          masterTaskId: baseId,
          originalDate: instanceDate,
          isDeleted: true,
        },
        update: { isDeleted: true },
      });
      return;
    }

    // thisAndFuture
    const currentRRule = recurrenceService.resolveRRule(task);
    if (!currentRRule) {
      await taskService.delete(userId, baseId);
      return;
    }

    const untilBoundary = new Date(instanceDate.getTime() - 1000);
    const truncatedRRule = recurrenceService.truncateRRule(currentRRule, untilBoundary);

    await prisma.$transaction([
      prisma.task.update({
        where: { id: baseId },
        data: { rrule: truncatedRRule },
      }),
      prisma.recurrenceException.deleteMany({
        where: { masterTaskId: baseId, originalDate: { gte: instanceDate } },
      }),
    ]);
  },

  /**
   * Get habit statistics for a specific task.
   * Returns streak, weekly summary, and monthly completion grid.
   */
  async getHabitStats(userId: string, taskId: string, year: number, month?: number) {
    const task = await prisma.task.findUnique({
      where: { id: taskId },
      include: { exceptions: true },
    });

    if (!task) {
      const error = new Error('Task not found');
      (error as any).statusCode = 404;
      throw error;
    }

    if (task.createdById !== userId) {
      const error = new Error('Forbidden');
      (error as any).statusCode = 403;
      throw error;
    }

    if (!task.isHabit) {
      const error = new Error('Task is not a habit');
      (error as any).statusCode = 400;
      throw error;
    }

    const rruleStr = recurrenceService.resolveRRule(task);
    if (!rruleStr) {
      return { streak: 0, weekSummary: [], monthGrid: [] };
    }

    const baseDate: Date = task.dueDate || task.scheduledDate || task.createdAt;

    // Build a set of completed dates from RecurrenceExceptions
    const completedDates = new Set<string>();
    for (const ex of task.exceptions) {
      if (ex.status === 'DONE' && !ex.isDeleted) {
        const d = new Date(ex.originalDate);
        completedDates.add(`${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`);
      }
    }
    // Also check the master task itself
    if (task.status === 'DONE' && baseDate) {
      completedDates.add(`${baseDate.getFullYear()}-${baseDate.getMonth() + 1}-${baseDate.getDate()}`);
    }

    // --- Streak calculation ---
    // Look back from today, counting consecutive completed days
    const today = new Date();
    today.setHours(23, 59, 59, 999);
    const streakStart = new Date(today);
    streakStart.setFullYear(streakStart.getFullYear() - 1); // look back up to 1 year

    let occurrences: Date[];
    try {
      occurrences = recurrenceService.expandInstances(rruleStr, baseDate, streakStart, today);
    } catch {
      occurrences = [];
    }

    // Sort descending (most recent first)
    occurrences.sort((a, b) => b.getTime() - a.getTime());

    let streak = 0;
    for (const occ of occurrences) {
      const key = `${occ.getFullYear()}-${occ.getMonth() + 1}-${occ.getDate()}`;
      if (completedDates.has(key)) {
        streak++;
      } else {
        // If today's occurrence is not yet complete, skip it (don't break streak)
        const todayKey = `${today.getFullYear()}-${today.getMonth() + 1}-${today.getDate()}`;
        if (key === todayKey) {
          continue;
        }
        break;
      }
    }

    // --- Weekly summary ---
    // This week: Monday to Sunday
    const now = new Date();
    const dayOfWeek = now.getDay(); // 0=Sun, 1=Mon, ...
    const mondayOffset = dayOfWeek === 0 ? -6 : 1 - dayOfWeek;
    const weekStart = new Date(now.getFullYear(), now.getMonth(), now.getDate() + mondayOffset);
    const weekEnd = new Date(weekStart);
    weekEnd.setDate(weekEnd.getDate() + 6);
    weekEnd.setHours(23, 59, 59, 999);

    let weekOccurrences: Date[];
    try {
      weekOccurrences = recurrenceService.expandInstances(rruleStr, baseDate, weekStart, weekEnd);
    } catch {
      weekOccurrences = [];
    }

    const weekDayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    const weekSummary = weekDayLabels.map((label, i) => {
      const date = new Date(weekStart);
      date.setDate(date.getDate() + i);
      const key = `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
      const isScheduled = weekOccurrences.some(
        (o) => o.getFullYear() === date.getFullYear() && o.getMonth() === date.getMonth() && o.getDate() === date.getDate(),
      );
      const isCompleted = completedDates.has(key);
      const isFuture = date > now;
      return { day: label, date: date.toISOString().slice(0, 10), scheduled: isScheduled, completed: isCompleted, future: isFuture };
    });

    // --- Monthly grid ---
    const targetMonth = month ?? now.getMonth() + 1;
    const monthStart = new Date(year, targetMonth - 1, 1);
    const monthEnd = new Date(year, targetMonth, 0, 23, 59, 59, 999);

    let monthOccurrences: Date[];
    try {
      monthOccurrences = recurrenceService.expandInstances(rruleStr, baseDate, monthStart, monthEnd);
    } catch {
      monthOccurrences = [];
    }

    const daysInMonth = monthEnd.getDate();
    const monthGrid = [];
    for (let d = 1; d <= daysInMonth; d++) {
      const date = new Date(year, targetMonth - 1, d);
      const key = `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
      const isScheduled = monthOccurrences.some(
        (o) => o.getFullYear() === date.getFullYear() && o.getMonth() === date.getMonth() && o.getDate() === date.getDate(),
      );
      const isCompleted = completedDates.has(key);
      const isFuture = date > now;
      monthGrid.push({
        day: d,
        date: date.toISOString().slice(0, 10),
        scheduled: isScheduled,
        completed: isCompleted,
        future: isFuture,
      });
    }

    // Monthly achievement rate
    const scheduledCount = monthGrid.filter((d) => d.scheduled && !d.future).length;
    const completedCount = monthGrid.filter((d) => d.scheduled && d.completed && !d.future).length;
    const achievementRate = scheduledCount > 0 ? Math.round((completedCount / scheduledCount) * 100) : 0;

    return {
      streak,
      weekSummary,
      monthGrid,
      achievementRate,
      scheduledCount,
      completedCount,
    };
  },
};
