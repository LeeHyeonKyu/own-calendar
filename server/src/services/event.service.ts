import prisma from '../lib/prisma';

export const eventService = {
  async list(userId: string, query: { calendarId?: string; start?: string; end?: string }) {
    const where: any = {
      calendar: { ownerId: userId },
    };

    if (query.calendarId) {
      where.calendarId = query.calendarId;
    }

    if (query.start) {
      where.startTime = { ...(where.startTime || {}), gte: new Date(query.start) };
    }

    if (query.end) {
      where.endTime = { ...(where.endTime || {}), lte: new Date(query.end) };
    }

    return prisma.event.findMany({
      where,
      include: { calendar: true },
    });
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
      calendarId?: string;
    },
  ) {
    const event = await prisma.event.findUnique({ where: { id: eventId } });

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

    return prisma.event.update({
      where: { id: eventId },
      data: updateData,
    });
  },

  async search(userId: string, query: string, start?: string, end?: string) {
    // Get user's calendar IDs
    const calendars = await prisma.calendar.findMany({
      where: { ownerId: userId },
      select: { id: true },
    });
    const calendarIds = calendars.map((c) => c.id);

    // Also include family calendar IDs the user has access to
    const memberships = await prisma.familyMembership.findMany({
      where: { userId },
      include: { familyGroup: { include: { calendar: true } } },
    });
    for (const m of memberships) {
      if (m.familyGroup.calendar) {
        calendarIds.push(m.familyGroup.calendar.id);
      }
    }

    // Build where clause
    const where: any = {
      calendarId: { in: calendarIds },
      OR: [
        { title: { contains: query, mode: 'insensitive' } },
        { description: { contains: query, mode: 'insensitive' } },
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
    const event = await prisma.event.findUnique({ where: { id: eventId } });

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

    await prisma.event.delete({ where: { id: eventId } });
  },
};
