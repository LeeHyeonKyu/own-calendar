import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import type { SignOptions } from 'jsonwebtoken';
import prisma from '../lib/prisma';
import { config } from '../config';

function generateTokens(userId: string) {
  const accessToken = jwt.sign({ userId }, config.jwt.secret, {
    expiresIn: config.jwt.accessExpiresIn,
  } as SignOptions);

  const refreshToken = crypto.randomBytes(40).toString('hex');

  return { accessToken, refreshToken };
}

function parseExpiresIn(expiresIn: string): number {
  const match = expiresIn.match(/^(\d+)([smhd])$/);
  if (!match) return 7 * 24 * 60 * 60 * 1000; // default 7 days
  const value = parseInt(match[1], 10);
  const unit = match[2];
  switch (unit) {
    case 's': return value * 1000;
    case 'm': return value * 60 * 1000;
    case 'h': return value * 60 * 60 * 1000;
    case 'd': return value * 24 * 60 * 60 * 1000;
    default: return 7 * 24 * 60 * 60 * 1000;
  }
}

export const authService = {
  async register(email: string, name: string, password: string) {
    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      const error = new Error('Email already in use');
      (error as any).statusCode = 409;
      throw error;
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const user = await prisma.user.create({
      data: {
        email,
        name,
        passwordHash,
        calendars: {
          create: {
            name: '내 캘린더',
            isDefault: true,
          },
        },
      },
      select: {
        id: true,
        email: true,
        name: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    // Auto-subscribe KR holidays for new users
    await prisma.holidaySubscription.create({
      data: { userId: user.id, countryCode: 'KR' },
    }).catch(() => {});

    const { accessToken, refreshToken } = generateTokens(user.id);

    const expiresMs = parseExpiresIn(config.jwt.refreshExpiresIn);
    await prisma.refreshToken.create({
      data: {
        token: refreshToken,
        userId: user.id,
        expiresAt: new Date(Date.now() + expiresMs),
      },
    });

    return { user, accessToken, refreshToken };
  },

  async login(email: string, password: string, rememberMe = false) {
    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      const error = new Error('Invalid email or password');
      (error as any).statusCode = 401;
      throw error;
    }

    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) {
      const error = new Error('Invalid email or password');
      (error as any).statusCode = 401;
      throw error;
    }

    const { accessToken, refreshToken } = generateTokens(user.id);

    const expiresMs = rememberMe
      ? 30 * 24 * 60 * 60 * 1000  // 30 days
      : parseExpiresIn(config.jwt.refreshExpiresIn);  // default 7 days
    await prisma.refreshToken.create({
      data: {
        token: refreshToken,
        userId: user.id,
        expiresAt: new Date(Date.now() + expiresMs),
      },
    });

    const { passwordHash: _, ...userWithoutPassword } = user;

    return { user: userWithoutPassword, accessToken, refreshToken };
  },

  async refreshTokens(refreshToken: string) {
    const stored = await prisma.refreshToken.findUnique({
      where: { token: refreshToken },
    });

    if (!stored) {
      const error = new Error('Invalid refresh token');
      (error as any).statusCode = 401;
      throw error;
    }

    if (stored.expiresAt < new Date()) {
      await prisma.refreshToken.delete({ where: { id: stored.id } });
      const error = new Error('Refresh token expired');
      (error as any).statusCode = 401;
      throw error;
    }

    // Token rotation: grace period — keep old token valid for 10s so a
    // concurrent refresh racing with the same token can still succeed.
    await prisma.refreshToken.update({
      where: { id: stored.id },
      data: { expiresAt: new Date(Date.now() + 10_000) },
    });

    const { accessToken, refreshToken: newRefreshToken } = generateTokens(stored.userId);

    const expiresMs = parseExpiresIn(config.jwt.refreshExpiresIn);
    await prisma.refreshToken.create({
      data: {
        token: newRefreshToken,
        userId: stored.userId,
        expiresAt: new Date(Date.now() + expiresMs),
      },
    });

    return { accessToken, refreshToken: newRefreshToken };
  },

  async logout(refreshToken: string) {
    await prisma.refreshToken.deleteMany({
      where: { token: refreshToken },
    });
  },

  async getUserById(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        name: true,
        createdAt: true,
        updatedAt: true,
      },
    });
    if (!user) {
      const error = new Error('User not found');
      (error as any).statusCode = 404;
      throw error;
    }
    return user;
  },
};
