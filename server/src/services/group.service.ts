import crypto from 'crypto';
import prisma from '../lib/prisma';

export const groupService = {
  async create(userId: string, name: string, type: string = '가족') {
    const code = crypto.randomBytes(8).toString('base64url').slice(0, 8);

    const group = await prisma.group.create({
      data: {
        name,
        type,
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
            name: type === '가족' ? `${name} 가족 캘린더` : `${name} 공유 캘린더`,
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

  async getMyGroups(userId: string) {
    const memberships = await prisma.groupMembership.findMany({
      where: { userId },
      include: {
        group: {
          include: {
            _count: { select: { members: true } },
          },
        },
      },
    });

    return memberships.map((m: any) => ({
      ...m.group,
      role: m.role,
    }));
  },

  async getGroup(userId: string, groupId: string) {
    const membership = await prisma.groupMembership.findUnique({
      where: {
        userId_groupId: {
          userId,
          groupId,
        },
      },
      include: {
        group: {
          include: {
            members: {
              include: {
                user: {
                  select: { id: true, name: true, email: true },
                },
              },
            },
            calendar: true,
            _count: { select: { members: true } },
          },
        },
      },
    });

    if (!membership) {
      const error = new Error('Not a member of this group');
      (error as any).statusCode = 403;
      throw error;
    }

    return {
      ...membership.group,
      role: membership.role,
      members: membership.group.members.map((m: any) => ({
        id: m.user.id,
        name: m.user.name,
        email: m.user.email,
        role: m.role,
        joinedAt: m.joinedAt,
      })),
    };
  },

  async join(userId: string, code: string) {
    const group = await prisma.group.findUnique({
      where: { code },
    });

    if (!group) {
      const error = new Error('Group not found');
      (error as any).statusCode = 404;
      throw error;
    }

    const existing = await prisma.groupMembership.findUnique({
      where: {
        userId_groupId: {
          userId,
          groupId: group.id,
        },
      },
    });

    if (existing) {
      const error = new Error('Already a member');
      (error as any).statusCode = 409;
      throw error;
    }

    await prisma.groupMembership.create({
      data: {
        userId,
        groupId: group.id,
        role: 'MEMBER',
      },
    });

    return group;
  },

  async leave(userId: string, groupId: string) {
    const membership = await prisma.groupMembership.findUnique({
      where: {
        userId_groupId: {
          userId,
          groupId,
        },
      },
    });

    if (!membership) {
      const error = new Error('Not a member of this group');
      (error as any).statusCode = 404;
      throw error;
    }

    if (membership.role === 'OWNER') {
      const error = new Error('Owner cannot leave. Delete the group or transfer ownership first.');
      (error as any).statusCode = 400;
      throw error;
    }

    await prisma.groupMembership.delete({
      where: { id: membership.id },
    });
  },

  async removeMember(userId: string, groupId: string, targetUserId: string) {
    const membership = await prisma.groupMembership.findUnique({
      where: {
        userId_groupId: {
          userId,
          groupId,
        },
      },
    });

    if (!membership) {
      const error = new Error('Not a member of this group');
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

    const targetMembership = await prisma.groupMembership.findUnique({
      where: {
        userId_groupId: {
          userId: targetUserId,
          groupId,
        },
      },
    });

    if (!targetMembership) {
      const error = new Error('Target user is not a member');
      (error as any).statusCode = 404;
      throw error;
    }

    await prisma.groupMembership.delete({
      where: { id: targetMembership.id },
    });
  },

  async deleteGroup(userId: string, groupId: string) {
    const membership = await prisma.groupMembership.findUnique({
      where: {
        userId_groupId: {
          userId,
          groupId,
        },
      },
    });

    if (!membership || membership.role !== 'OWNER') {
      const error = new Error('Only the owner can delete the group');
      (error as any).statusCode = 403;
      throw error;
    }

    // Delete calendar first (cascade will handle events)
    const calendar = await prisma.calendar.findFirst({
      where: { groupId },
    });
    if (calendar) {
      await prisma.calendar.delete({ where: { id: calendar.id } });
    }

    await prisma.group.delete({ where: { id: groupId } });
  },

  async getGroupCalendars(userId: string, groupId: string, query?: { start?: string; end?: string }) {
    const membership = await prisma.groupMembership.findUnique({
      where: {
        userId_groupId: {
          userId,
          groupId,
        },
      },
      include: { group: true },
    });

    if (!membership) {
      const error = new Error('Not a member of this group');
      (error as any).statusCode = 403;
      throw error;
    }

    const members = await prisma.groupMembership.findMany({
      where: { groupId },
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

      const calendars = await prisma.calendar.findMany({
        where: {
          OR: [
            {
              ownerId: member.userId,
              visibility: 'PUBLIC',
              type: 'PERSONAL',
            },
            {
              groupId,
              type: 'FAMILY',
            },
          ],
        },
        include: {
          events: {
            where: {
              ...eventWhere,
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

  // Backwards compatibility: get all groups' calendars combined (used by /family/calendars endpoint)
  async getAllGroupCalendars(userId: string, query?: { start?: string; end?: string }) {
    const memberships = await prisma.groupMembership.findMany({
      where: { userId },
    });

    if (memberships.length === 0) {
      return [];
    }

    const allResults = [];
    for (const membership of memberships) {
      const groupResult = await this.getGroupCalendars(userId, membership.groupId, query);
      allResults.push(...groupResult);
    }

    return allResults;
  },

  async createGroupEvent(
    userId: string,
    groupId: string,
    data: {
      title: string;
      description?: string;
      startTime: string;
      endTime: string;
      isAllDay?: boolean;
      isPrivate?: boolean;
    },
  ) {
    const membership = await prisma.groupMembership.findUnique({
      where: {
        userId_groupId: {
          userId,
          groupId,
        },
      },
      include: { group: { include: { calendar: true } } },
    });

    if (!membership) {
      const error = new Error('Not a member of this group');
      (error as any).statusCode = 403;
      throw error;
    }

    const groupCalendar = membership.group.calendar;
    if (!groupCalendar) {
      const error = new Error('Group calendar not found');
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
        calendarId: groupCalendar.id,
        createdById: userId,
      },
    });
  },
};
