import crypto from 'crypto';
import prisma from '../lib/prisma';

export const familyService = {
  async create(userId: string, name: string) {
    // 64-bit entropy family code (11 char base64url). Unguessable via brute force
    // even with /api/family/join rate limiting removed.
    const code = crypto.randomBytes(8).toString('base64url');

    const group = await prisma.familyGroup.create({
      data: {
        name,
        code,
        createdById: userId,
        members: {
          create: {
            userId,
            role: 'OWNER',
          },
        },
        calendar: {
          create: {
            name: `${name} 가족 캘린더`,
            type: 'FAMILY',
            ownerId: userId,
          },
        },
      },
      include: {
        members: true,
        calendar: true,
      },
    });

    return group;
  },

  async getMyFamily(userId: string) {
    const membership = await prisma.familyMembership.findFirst({
      where: { userId },
      include: {
        familyGroup: {
          include: {
            _count: { select: { members: true } },
          },
        },
      },
    });

    if (!membership) {
      return null;
    }

    return {
      ...membership.familyGroup,
      role: membership.role,
    };
  },

  async join(userId: string, code: string) {
    const group = await prisma.familyGroup.findUnique({
      where: { code },
    });

    if (!group) {
      const error = new Error('Family group not found');
      (error as any).statusCode = 404;
      throw error;
    }

    const existing = await prisma.familyMembership.findUnique({
      where: {
        userId_familyGroupId: {
          userId,
          familyGroupId: group.id,
        },
      },
    });

    if (existing) {
      const error = new Error('Already a member');
      (error as any).statusCode = 409;
      throw error;
    }

    await prisma.familyMembership.create({
      data: {
        userId,
        familyGroupId: group.id,
        role: 'MEMBER',
      },
    });

    return group;
  },

  async getMembers(userId: string) {
    const membership = await prisma.familyMembership.findFirst({
      where: { userId },
    });

    if (!membership) {
      const error = new Error('Not a member of any family group');
      (error as any).statusCode = 404;
      throw error;
    }

    const members = await prisma.familyMembership.findMany({
      where: { familyGroupId: membership.familyGroupId },
      include: {
        user: {
          select: { id: true, name: true, email: true },
        },
      },
    });

    return members.map((m) => ({
      id: m.user.id,
      name: m.user.name,
      email: m.user.email,
      role: m.role,
      joinedAt: m.joinedAt,
    }));
  },

  async removeMember(userId: string, targetUserId: string) {
    const membership = await prisma.familyMembership.findFirst({
      where: { userId },
    });

    if (!membership) {
      const error = new Error('Not a member of any family group');
      (error as any).statusCode = 404;
      throw error;
    }

    if (membership.role !== 'OWNER') {
      const error = new Error('Only the owner can remove members');
      (error as any).statusCode = 403;
      throw error;
    }

    if (userId === targetUserId) {
      const error = new Error('Cannot remove yourself');
      (error as any).statusCode = 400;
      throw error;
    }

    const targetMembership = await prisma.familyMembership.findUnique({
      where: {
        userId_familyGroupId: {
          userId: targetUserId,
          familyGroupId: membership.familyGroupId,
        },
      },
    });

    if (!targetMembership) {
      const error = new Error('Target user is not a member');
      (error as any).statusCode = 404;
      throw error;
    }

    await prisma.familyMembership.delete({
      where: { id: targetMembership.id },
    });
  },

  async getFamilyCalendars(userId: string, query?: { start?: string; end?: string }) {
    const membership = await prisma.familyMembership.findFirst({
      where: { userId },
      include: { familyGroup: true },
    });

    if (!membership) {
      const error = new Error('Not a member of any family group');
      (error as any).statusCode = 404;
      throw error;
    }

    const members = await prisma.familyMembership.findMany({
      where: { familyGroupId: membership.familyGroupId },
      include: {
        user: { select: { id: true, name: true } },
      },
    });

    const eventWhere: any = {};
    if (query?.end) {
      eventWhere.startTime = { lt: new Date(query.end) };
    }
    if (query?.start) {
      eventWhere.endTime = { gt: new Date(query.start) };
    }

    const result = [];

    for (const member of members) {
      const isCurrentUser = member.userId === userId;

      // Get PUBLIC calendars of family members + the FAMILY calendar
      const calendars = await prisma.calendar.findMany({
        where: {
          OR: [
            {
              ownerId: member.userId,
              visibility: 'PUBLIC',
              type: 'PERSONAL',
            },
            {
              familyGroupId: membership.familyGroupId,
              type: 'FAMILY',
            },
          ],
        },
        include: {
          events: {
            where: {
              ...eventWhere,
              // Hide private events from other members' calendars
              ...(isCurrentUser ? {} : { isPrivate: false }),
            },
          },
        },
      });

      result.push({
        member: { id: member.user.id, name: member.user.name },
        calendars,
      });
    }

    return result;
  },

  async createFamilyEvent(
    userId: string,
    data: {
      title: string;
      description?: string;
      startTime: string;
      endTime: string;
      isAllDay?: boolean;
      isPrivate?: boolean;
    },
  ) {
    const membership = await prisma.familyMembership.findFirst({
      where: { userId },
      include: { familyGroup: { include: { calendar: true } } },
    });

    if (!membership) {
      const error = new Error('Not a member of any family group');
      (error as any).statusCode = 404;
      throw error;
    }

    const familyCalendar = membership.familyGroup.calendar;
    if (!familyCalendar) {
      const error = new Error('Family calendar not found');
      (error as any).statusCode = 404;
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
        calendarId: familyCalendar.id,
        createdById: userId,
      },
    });
  },
};
