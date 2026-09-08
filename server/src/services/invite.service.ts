import prisma from '../lib/prisma';

export const inviteService = {
  async inviteToEvent(userId: string, eventId: string, inviteeId: string) {
    // Verify event exists and belongs to the user
    const event = await prisma.event.findUnique({
      where: { id: eventId },
    });

    if (!event) {
      const error = new Error('Event not found');
      (error as any).statusCode = 404;
      throw error;
    }

    if (event.createdById !== userId) {
      const error = new Error('Only the event creator can send invites');
      (error as any).statusCode = 403;
      throw error;
    }

    if (userId === inviteeId) {
      const error = new Error('Cannot invite yourself');
      (error as any).statusCode = 400;
      throw error;
    }

    // Verify invitee exists
    const invitee = await prisma.user.findUnique({
      where: { id: inviteeId },
    });

    if (!invitee) {
      const error = new Error('User not found');
      (error as any).statusCode = 404;
      throw error;
    }

    // Check for existing invite
    const existing = await prisma.eventInvite.findUnique({
      where: {
        eventId_inviteeId: {
          eventId,
          inviteeId,
        },
      },
    });

    if (existing) {
      if (existing.status === 'DECLINED') {
        // Allow re-inviting after decline
        return prisma.eventInvite.update({
          where: { id: existing.id },
          data: { status: 'PENDING', createdAt: new Date() },
          include: {
            invitee: { select: { id: true, name: true, email: true } },
            event: { select: { id: true, title: true, startTime: true, endTime: true } },
          },
        });
      }
      const error = new Error('Invite already exists');
      (error as any).statusCode = 409;
      throw error;
    }

    return prisma.eventInvite.create({
      data: {
        eventId,
        inviteeId,
        status: 'PENDING',
      },
      include: {
        invitee: { select: { id: true, name: true, email: true } },
        event: { select: { id: true, title: true, startTime: true, endTime: true } },
      },
    });
  },

  async acceptInvite(userId: string, inviteId: string) {
    const invite = await prisma.eventInvite.findUnique({
      where: { id: inviteId },
    });

    if (!invite) {
      const error = new Error('Invite not found');
      (error as any).statusCode = 404;
      throw error;
    }

    if (invite.inviteeId !== userId) {
      const error = new Error('Not authorized');
      (error as any).statusCode = 403;
      throw error;
    }

    if (invite.status !== 'PENDING') {
      const error = new Error('Invite is not pending');
      (error as any).statusCode = 400;
      throw error;
    }

    return prisma.eventInvite.update({
      where: { id: inviteId },
      data: { status: 'ACCEPTED' },
      include: {
        event: { select: { id: true, title: true, startTime: true, endTime: true } },
      },
    });
  },

  async declineInvite(userId: string, inviteId: string) {
    const invite = await prisma.eventInvite.findUnique({
      where: { id: inviteId },
    });

    if (!invite) {
      const error = new Error('Invite not found');
      (error as any).statusCode = 404;
      throw error;
    }

    if (invite.inviteeId !== userId) {
      const error = new Error('Not authorized');
      (error as any).statusCode = 403;
      throw error;
    }

    if (invite.status !== 'PENDING') {
      const error = new Error('Invite is not pending');
      (error as any).statusCode = 400;
      throw error;
    }

    return prisma.eventInvite.update({
      where: { id: inviteId },
      data: { status: 'DECLINED' },
    });
  },

  async getEventInvites(userId: string, eventId: string) {
    // Verify the event belongs to the user
    const event = await prisma.event.findUnique({
      where: { id: eventId },
    });

    if (!event) {
      const error = new Error('Event not found');
      (error as any).statusCode = 404;
      throw error;
    }

    if (event.createdById !== userId) {
      const error = new Error('Not authorized');
      (error as any).statusCode = 403;
      throw error;
    }

    return prisma.eventInvite.findMany({
      where: { eventId },
      include: {
        invitee: { select: { id: true, name: true, email: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  },

  async getUserInvites(userId: string, status?: string) {
    const where: any = { inviteeId: userId };
    if (status) {
      where.status = status;
    }

    return prisma.eventInvite.findMany({
      where,
      include: {
        event: {
          select: {
            id: true,
            title: true,
            startTime: true,
            endTime: true,
            isAllDay: true,
            createdBy: { select: { id: true, name: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  },

  async removeInvite(userId: string, inviteId: string) {
    const invite = await prisma.eventInvite.findUnique({
      where: { id: inviteId },
      include: { event: true },
    });

    if (!invite) {
      const error = new Error('Invite not found');
      (error as any).statusCode = 404;
      throw error;
    }

    // Only event creator or invitee can remove
    if (invite.event.createdById !== userId && invite.inviteeId !== userId) {
      const error = new Error('Not authorized');
      (error as any).statusCode = 403;
      throw error;
    }

    await prisma.eventInvite.delete({
      where: { id: inviteId },
    });
  },
};
