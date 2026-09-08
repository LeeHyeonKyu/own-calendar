import prisma from '../lib/prisma';

export const routineService = {
  // ─── Routines ───

  async getRoutinesForDate(userId: string, dateStr: string) {
    const date = new Date(dateStr);
    const dayOfWeek = date.getUTCDay(); // 0=Sunday

    // Normalize date to midnight UTC for completion lookup
    const dateOnly = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));

    const routines = await prisma.routine.findMany({
      where: { userId },
      include: {
        group: { select: { id: true, name: true, sortOrder: true } },
        completions: {
          where: { date: dateOnly },
        },
      },
      orderBy: [
        { sortOrder: 'asc' },
        { createdAt: 'asc' },
      ],
    });

    // Filter routines whose repeatDays include the target day of week
    return routines
      .filter((r) => {
        const days = r.repeatDays as number[];
        return days.includes(dayOfWeek);
      })
      .map((r) => ({
        ...r,
        completed: r.completions.length > 0,
        completedAt: r.completions[0]?.completedAt ?? null,
      }));
  },

  async create(
    userId: string,
    data: {
      name: string;
      time?: string | null;
      repeatDays: number[];
      groupId?: string | null;
      sortOrder?: number;
    },
  ) {
    if (data.groupId) {
      const group = await prisma.routineGroup.findUnique({
        where: { id: data.groupId },
      });
      if (!group || group.userId !== userId) {
        const error = new Error('Routine group not found');
        (error as any).statusCode = 404;
        throw error;
      }
    }

    return prisma.routine.create({
      data: {
        name: data.name,
        time: data.time ?? null,
        repeatDays: data.repeatDays,
        groupId: data.groupId ?? null,
        userId,
        sortOrder: data.sortOrder ?? 0,
      },
      include: {
        group: { select: { id: true, name: true, sortOrder: true } },
      },
    });
  },

  async update(
    userId: string,
    routineId: string,
    data: {
      name?: string;
      time?: string | null;
      repeatDays?: number[];
      groupId?: string | null;
      sortOrder?: number;
    },
  ) {
    const routine = await prisma.routine.findUnique({ where: { id: routineId } });
    if (!routine) {
      const error = new Error('Routine not found');
      (error as any).statusCode = 404;
      throw error;
    }
    if (routine.userId !== userId) {
      const error = new Error('Forbidden');
      (error as any).statusCode = 403;
      throw error;
    }

    if (data.groupId) {
      const group = await prisma.routineGroup.findUnique({
        where: { id: data.groupId },
      });
      if (!group || group.userId !== userId) {
        const error = new Error('Routine group not found');
        (error as any).statusCode = 404;
        throw error;
      }
    }

    const updateData: any = {};
    if (data.name !== undefined) updateData.name = data.name;
    if (data.time !== undefined) updateData.time = data.time;
    if (data.repeatDays !== undefined) updateData.repeatDays = data.repeatDays;
    if (data.groupId !== undefined) updateData.groupId = data.groupId;
    if (data.sortOrder !== undefined) updateData.sortOrder = data.sortOrder;

    return prisma.routine.update({
      where: { id: routineId },
      data: updateData,
      include: {
        group: { select: { id: true, name: true, sortOrder: true } },
      },
    });
  },

  async delete(userId: string, routineId: string) {
    const routine = await prisma.routine.findUnique({ where: { id: routineId } });
    if (!routine) {
      const error = new Error('Routine not found');
      (error as any).statusCode = 404;
      throw error;
    }
    if (routine.userId !== userId) {
      const error = new Error('Forbidden');
      (error as any).statusCode = 403;
      throw error;
    }
    await prisma.routine.delete({ where: { id: routineId } });
  },

  async toggleComplete(userId: string, routineId: string, dateStr: string) {
    const routine = await prisma.routine.findUnique({ where: { id: routineId } });
    if (!routine) {
      const error = new Error('Routine not found');
      (error as any).statusCode = 404;
      throw error;
    }
    if (routine.userId !== userId) {
      const error = new Error('Forbidden');
      (error as any).statusCode = 403;
      throw error;
    }

    const date = new Date(dateStr);
    const dateOnly = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));

    // Check if completion already exists
    const existing = await prisma.routineCompletion.findUnique({
      where: {
        routineId_date: {
          routineId,
          date: dateOnly,
        },
      },
    });

    if (existing) {
      // Remove completion (uncomplete)
      await prisma.routineCompletion.delete({ where: { id: existing.id } });
      return { completed: false, completedAt: null };
    } else {
      // Create completion
      const completion = await prisma.routineCompletion.create({
        data: {
          routineId,
          date: dateOnly,
          completedAt: new Date(),
        },
      });
      return { completed: true, completedAt: completion.completedAt };
    }
  },

  // ─── Routine Groups ───

  async listGroups(userId: string) {
    return prisma.routineGroup.findMany({
      where: { userId },
      include: {
        routines: {
          orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
        },
      },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
    });
  },

  async createGroup(userId: string, data: { name: string; sortOrder?: number }) {
    return prisma.routineGroup.create({
      data: {
        name: data.name,
        userId,
        sortOrder: data.sortOrder ?? 0,
      },
    });
  },

  async updateGroup(userId: string, groupId: string, data: { name?: string; sortOrder?: number }) {
    const group = await prisma.routineGroup.findUnique({ where: { id: groupId } });
    if (!group) {
      const error = new Error('Routine group not found');
      (error as any).statusCode = 404;
      throw error;
    }
    if (group.userId !== userId) {
      const error = new Error('Forbidden');
      (error as any).statusCode = 403;
      throw error;
    }

    const updateData: any = {};
    if (data.name !== undefined) updateData.name = data.name;
    if (data.sortOrder !== undefined) updateData.sortOrder = data.sortOrder;

    return prisma.routineGroup.update({
      where: { id: groupId },
      data: updateData,
    });
  },

  async deleteGroup(userId: string, groupId: string) {
    const group = await prisma.routineGroup.findUnique({ where: { id: groupId } });
    if (!group) {
      const error = new Error('Routine group not found');
      (error as any).statusCode = 404;
      throw error;
    }
    if (group.userId !== userId) {
      const error = new Error('Forbidden');
      (error as any).statusCode = 403;
      throw error;
    }

    // Ungroup routines that belong to this group
    await prisma.routine.updateMany({
      where: { groupId },
      data: { groupId: null },
    });

    await prisma.routineGroup.delete({ where: { id: groupId } });
  },
};
