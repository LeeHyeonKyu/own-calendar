import prisma from '../lib/prisma';

export const calendarService = {
  async list(userId: string) {
    return prisma.calendar.findMany({
      where: { ownerId: userId },
    });
  },

  async create(userId: string, data: { name: string; color?: string; visibility?: 'PUBLIC' | 'PRIVATE' }) {
    return prisma.calendar.create({
      data: {
        name: data.name,
        color: data.color,
        visibility: data.visibility,
        type: 'PERSONAL',
        ownerId: userId,
      },
    });
  },

  async update(userId: string, calendarId: string, data: { name?: string; color?: string; visibility?: 'PUBLIC' | 'PRIVATE' }) {
    const calendar = await prisma.calendar.findUnique({ where: { id: calendarId } });
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

    return prisma.calendar.update({
      where: { id: calendarId },
      data,
    });
  },

  async delete(userId: string, calendarId: string) {
    const calendar = await prisma.calendar.findUnique({ where: { id: calendarId } });
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

    if (calendar.isDefault) {
      const error = new Error('Cannot delete default calendar');
      (error as any).statusCode = 400;
      throw error;
    }

    await prisma.calendar.delete({ where: { id: calendarId } });
  },
};
