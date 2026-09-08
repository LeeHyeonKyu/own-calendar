import prisma from '../lib/prisma';

function generateTaskRecurrenceInstances(task: any, queryStart: Date, queryEnd: Date): any[] {
  if (task.recurrenceType === 'NONE') return [task];

  const baseDate = task.dueDate || task.scheduledDate;
  if (!baseDate) return [task];

  const instances: any[] = [];
  const origDate = new Date(baseDate);
  const recEnd = task.recurrenceEnd ? new Date(task.recurrenceEnd) : queryEnd;
  const limit = recEnd < queryEnd ? recEnd : queryEnd;
  let cursor = new Date(origDate);

  for (let i = 0; i < 1000; i++) {
    const instanceDate = new Date(cursor);
    if (instanceDate > limit) break;

    if (instanceDate >= queryStart && instanceDate <= queryEnd) {
      const isOriginal = instanceDate.getTime() === origDate.getTime();
      instances.push({
        ...task,
        id: isOriginal ? task.id : `${task.id}_${instanceDate.toISOString()}`,
        dueDate: task.dueDate ? instanceDate : null,
        scheduledDate: task.scheduledDate ? instanceDate : null,
      });
    }

    switch (task.recurrenceType) {
      case 'DAILY':
        cursor.setDate(cursor.getDate() + 1);
        break;
      case 'WEEKLY':
        cursor.setDate(cursor.getDate() + 7);
        break;
      case 'MONTHLY': {
        const origDay = origDate.getDate();
        cursor.setMonth(cursor.getMonth() + 1);
        const daysInMonth = new Date(cursor.getFullYear(), cursor.getMonth() + 1, 0).getDate();
        cursor.setDate(Math.min(origDay, daysInMonth));
        break;
      }
      case 'YEARLY': {
        const origMonth = origDate.getMonth();
        const origDay = origDate.getDate();
        cursor.setFullYear(cursor.getFullYear() + 1);
        cursor.setMonth(origMonth);
        const daysInMonth = new Date(cursor.getFullYear(), origMonth + 1, 0).getDate();
        cursor.setDate(Math.min(origDay, daysInMonth));
        break;
      }
    }
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

    const queryStart = query.start ? new Date(query.start) : new Date(0);
    const queryEnd = query.end ? new Date(query.end) : new Date('2100-01-01');

    const dbTasks = await prisma.task.findMany({
      where: {
        ...where,
        OR: [
          // Non-recurring with due date
          {
            recurrenceType: 'NONE',
            dueDate: { not: null },
            ...(query.start ? { dueDate: { gte: queryStart } } : {}),
            ...(query.end ? { dueDate: { lte: queryEnd } } : {}),
          },
          // Non-recurring with scheduled date
          {
            recurrenceType: 'NONE',
            dueDate: null,
            scheduledDate: { not: null },
            ...(query.start ? { scheduledDate: { gte: queryStart } } : {}),
            ...(query.end ? { scheduledDate: { lte: queryEnd } } : {}),
          },
          // Non-recurring with no date (always included)
          {
            recurrenceType: 'NONE',
            dueDate: null,
            scheduledDate: null,
          },
          // Recurring: base date before query end
          {
            recurrenceType: { not: 'NONE' },
            OR: [
              {
                dueDate: { lte: queryEnd },
                OR: [
                  { recurrenceEnd: null },
                  { recurrenceEnd: { gte: queryStart } },
                ],
              },
              {
                scheduledDate: { lte: queryEnd },
                OR: [
                  { recurrenceEnd: null },
                  { recurrenceEnd: { gte: queryStart } },
                ],
              },
            ],
          },
        ],
      },
      include: {
        calendar: { select: { id: true, name: true, color: true } },
        event: { select: { id: true, title: true, startTime: true } },
      },
      orderBy: [
        { sortOrder: 'asc' },
        { dueDate: 'asc' },
        { createdAt: 'asc' },
      ],
    });

    const result: any[] = [];
    for (const task of dbTasks) {
      if (task.recurrenceType === 'NONE') {
        result.push(task);
      } else {
        result.push(...generateTaskRecurrenceInstances(task, queryStart, queryEnd));
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
      location?: string | null;
      notes?: string | null;
      attendees?: Array<{ name: string; email?: string }> | null;
      eventId?: string | null;
      calendarId: string;
      sortOrder?: number;
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

    // Determine metadata: inherit from event if task's own metadata is empty
    let location = data.location ?? null;
    let notes = data.notes ?? null;
    let attendees: any = data.attendees ?? null;
    let metaInherited = false;

    if (data.eventId) {
      const event = await prisma.event.findUnique({ where: { id: data.eventId } });
      if (!event) {
        const error = new Error('Event not found');
        (error as any).statusCode = 404;
        throw error;
      }

      // Auto-inherit event metadata if task metadata is empty
      const hasOwnMeta = location || notes || (attendees && attendees.length > 0);
      if (!hasOwnMeta && (event.location || event.notes || event.attendees)) {
        location = event.location;
        notes = event.notes;
        attendees = event.attendees;
        metaInherited = true;
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
        location,
        notes,
        attendees: attendees ?? undefined,
        metaInherited,
        eventId: data.eventId || null,
        calendarId: data.calendarId,
        createdById: userId,
        sortOrder: data.sortOrder ?? 0,
      },
      include: {
        calendar: { select: { id: true, name: true, color: true } },
        event: { select: { id: true, title: true, startTime: true } },
      },
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
      location?: string | null;
      notes?: string | null;
      attendees?: Array<{ name: string; email?: string }> | null;
      eventId?: string | null;
      calendarId?: string;
      sortOrder?: number;
    },
  ) {
    const baseId = taskId.includes('_') ? taskId.split('_').slice(0, -1).join('_') : taskId;
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
    if (data.eventId !== undefined) updateData.eventId = data.eventId;
    if (data.calendarId !== undefined) updateData.calendarId = data.calendarId;
    if (data.sortOrder !== undefined) updateData.sortOrder = data.sortOrder;

    // Handle metadata fields
    if (data.location !== undefined) updateData.location = data.location;
    if (data.notes !== undefined) updateData.notes = data.notes;
    if (data.attendees !== undefined) updateData.attendees = data.attendees;

    // If user explicitly sets metadata, mark as not inherited
    const userSetMeta = data.location !== undefined || data.notes !== undefined || data.attendees !== undefined;
    if (userSetMeta) {
      updateData.metaInherited = false;
    }

    // If linking to an event and task has no own metadata, inherit from event
    if (data.eventId && data.eventId !== task.eventId) {
      const event = await prisma.event.findUnique({ where: { id: data.eventId } });
      if (event) {
        const taskLocation = data.location !== undefined ? data.location : task.location;
        const taskNotes = data.notes !== undefined ? data.notes : task.notes;
        const taskAttendees = data.attendees !== undefined ? data.attendees : task.attendees;
        const hasOwnMeta = taskLocation || taskNotes || (taskAttendees && (taskAttendees as any[]).length > 0);
        if (!hasOwnMeta && (event.location || event.notes || event.attendees)) {
          updateData.location = event.location;
          updateData.notes = event.notes;
          updateData.attendees = event.attendees;
          updateData.metaInherited = true;
        }
      }
    }

    return prisma.task.update({
      where: { id: baseId },
      data: updateData,
      include: {
        calendar: { select: { id: true, name: true, color: true } },
        event: { select: { id: true, title: true, startTime: true } },
      },
    });
  },

  async toggleComplete(userId: string, taskId: string) {
    const baseId = taskId.includes('_') ? taskId.split('_').slice(0, -1).join('_') : taskId;
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

    const newStatus = task.status === 'DONE' ? 'TODO' : 'DONE';
    return prisma.task.update({
      where: { id: baseId },
      data: {
        status: newStatus,
        completedAt: newStatus === 'DONE' ? new Date() : null,
      },
      include: {
        calendar: { select: { id: true, name: true, color: true } },
        event: { select: { id: true, title: true, startTime: true } },
      },
    });
  },

  async linkEvent(userId: string, taskId: string, eventId: string | null) {
    const baseId = taskId.includes('_') ? taskId.split('_').slice(0, -1).join('_') : taskId;
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

    const updateData: any = { eventId };

    if (eventId) {
      const event = await prisma.event.findUnique({ where: { id: eventId } });
      if (!event) {
        const error = new Error('Event not found');
        (error as any).statusCode = 404;
        throw error;
      }

      // Auto-inherit metadata if task's own metadata is empty
      const hasOwnMeta = task.location || task.notes || (task.attendees && (task.attendees as any[]).length > 0);
      if (!hasOwnMeta && (event.location || event.notes || event.attendees)) {
        updateData.location = event.location;
        updateData.notes = event.notes;
        updateData.attendees = event.attendees;
        updateData.metaInherited = true;
      }
    } else {
      // Unlinking from event: clear inherited metadata
      if (task.metaInherited) {
        updateData.location = null;
        updateData.notes = null;
        updateData.attendees = null;
        updateData.metaInherited = false;
      }
    }

    return prisma.task.update({
      where: { id: baseId },
      data: updateData,
      include: {
        calendar: { select: { id: true, name: true, color: true } },
        event: { select: { id: true, title: true, startTime: true } },
      },
    });
  },

  async delete(userId: string, taskId: string) {
    const baseId = taskId.includes('_') ? taskId.split('_').slice(0, -1).join('_') : taskId;
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
};
