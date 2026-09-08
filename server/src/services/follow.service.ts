import prisma from '../lib/prisma';

export const followService = {
  async sendFollowRequest(followerId: string, followeeId: string) {
    if (followerId === followeeId) {
      const error = new Error('Cannot follow yourself');
      (error as any).statusCode = 400;
      throw error;
    }

    const followee = await prisma.user.findUnique({
      where: { id: followeeId },
    });

    if (!followee) {
      const error = new Error('User not found');
      (error as any).statusCode = 404;
      throw error;
    }

    const existing = await prisma.follow.findUnique({
      where: {
        followerId_followeeId: {
          followerId,
          followeeId,
        },
      },
    });

    if (existing) {
      if (existing.status === 'REJECTED') {
        // Allow re-requesting after rejection
        return prisma.follow.update({
          where: { id: existing.id },
          data: { status: 'PENDING', createdAt: new Date() },
          include: {
            followee: { select: { id: true, name: true, email: true } },
          },
        });
      }
      const error = new Error('Follow request already exists');
      (error as any).statusCode = 409;
      throw error;
    }

    return prisma.follow.create({
      data: {
        followerId,
        followeeId,
        status: 'PENDING',
      },
      include: {
        followee: { select: { id: true, name: true, email: true } },
      },
    });
  },

  async acceptFollow(userId: string, followId: string) {
    const follow = await prisma.follow.findUnique({
      where: { id: followId },
    });

    if (!follow) {
      const error = new Error('Follow request not found');
      (error as any).statusCode = 404;
      throw error;
    }

    if (follow.followeeId !== userId) {
      const error = new Error('Not authorized to accept this request');
      (error as any).statusCode = 403;
      throw error;
    }

    if (follow.status !== 'PENDING') {
      const error = new Error('Request is not pending');
      (error as any).statusCode = 400;
      throw error;
    }

    return prisma.follow.update({
      where: { id: followId },
      data: { status: 'ACCEPTED' },
      include: {
        follower: { select: { id: true, name: true, email: true } },
      },
    });
  },

  async rejectFollow(userId: string, followId: string) {
    const follow = await prisma.follow.findUnique({
      where: { id: followId },
    });

    if (!follow) {
      const error = new Error('Follow request not found');
      (error as any).statusCode = 404;
      throw error;
    }

    if (follow.followeeId !== userId) {
      const error = new Error('Not authorized to reject this request');
      (error as any).statusCode = 403;
      throw error;
    }

    if (follow.status !== 'PENDING') {
      const error = new Error('Request is not pending');
      (error as any).statusCode = 400;
      throw error;
    }

    return prisma.follow.update({
      where: { id: followId },
      data: { status: 'REJECTED' },
    });
  },

  async unfollow(followerId: string, followeeId: string) {
    const follow = await prisma.follow.findUnique({
      where: {
        followerId_followeeId: {
          followerId,
          followeeId,
        },
      },
    });

    if (!follow) {
      const error = new Error('Not following this user');
      (error as any).statusCode = 404;
      throw error;
    }

    await prisma.follow.delete({
      where: { id: follow.id },
    });
  },

  async getFollowers(userId: string) {
    const follows = await prisma.follow.findMany({
      where: {
        followeeId: userId,
        status: 'ACCEPTED',
      },
      include: {
        follower: { select: { id: true, name: true, email: true } },
      },
    });

    return follows.map((f: any) => ({
      id: f.id,
      user: f.follower,
      createdAt: f.createdAt,
    }));
  },

  async getFollowing(userId: string) {
    const follows = await prisma.follow.findMany({
      where: {
        followerId: userId,
        status: 'ACCEPTED',
      },
      include: {
        followee: { select: { id: true, name: true, email: true } },
      },
    });

    return follows.map((f: any) => ({
      id: f.id,
      user: f.followee,
      createdAt: f.createdAt,
    }));
  },

  async getPendingRequests(userId: string) {
    const follows = await prisma.follow.findMany({
      where: {
        followeeId: userId,
        status: 'PENDING',
      },
      include: {
        follower: { select: { id: true, name: true, email: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return follows.map((f: any) => ({
      id: f.id,
      user: f.follower,
      createdAt: f.createdAt,
    }));
  },

  async getSentRequests(userId: string) {
    const follows = await prisma.follow.findMany({
      where: {
        followerId: userId,
        status: 'PENDING',
      },
      include: {
        followee: { select: { id: true, name: true, email: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return follows.map((f: any) => ({
      id: f.id,
      user: f.followee,
      createdAt: f.createdAt,
    }));
  },

  async getFolloweePublicEvents(userId: string, followeeId: string, query?: { start?: string; end?: string }) {
    // Verify the follow relationship exists and is accepted
    const follow = await prisma.follow.findUnique({
      where: {
        followerId_followeeId: {
          followerId: userId,
          followeeId,
        },
      },
    });

    if (!follow || follow.status !== 'ACCEPTED') {
      const error = new Error('Not following this user');
      (error as any).statusCode = 403;
      throw error;
    }

    const eventWhere: any = {
      isPrivate: false,
      calendar: {
        ownerId: followeeId,
        visibility: 'PUBLIC',
      },
    };

    if (query?.end) {
      eventWhere.startTime = { lt: new Date(query.end) };
    }
    if (query?.start) {
      eventWhere.endTime = { gt: new Date(query.start) };
    }

    return prisma.event.findMany({
      where: eventWhere,
      include: {
        calendar: { select: { id: true, name: true, color: true } },
        createdBy: { select: { id: true, name: true } },
      },
      orderBy: { startTime: 'asc' },
    });
  },

  async searchUsers(query: string, currentUserId: string) {
    const users = await prisma.user.findMany({
      where: {
        id: { not: currentUserId },
        OR: [
          { email: { contains: query, mode: 'insensitive' } },
          { name: { contains: query, mode: 'insensitive' } },
        ],
      },
      select: { id: true, name: true, email: true },
      take: 20,
    });

    // For each user, check the follow status with the current user
    const usersWithStatus = await Promise.all(
      users.map(async (user: any) => {
        const sentFollow = await prisma.follow.findUnique({
          where: {
            followerId_followeeId: {
              followerId: currentUserId,
              followeeId: user.id,
            },
          },
        });
        const receivedFollow = await prisma.follow.findUnique({
          where: {
            followerId_followeeId: {
              followerId: user.id,
              followeeId: currentUserId,
            },
          },
        });

        return {
          ...user,
          followStatus: sentFollow?.status ?? null,
          isFollowedBy: receivedFollow?.status === 'ACCEPTED',
        };
      }),
    );

    return usersWithStatus;
  },
};
