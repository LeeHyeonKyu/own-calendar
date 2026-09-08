import prisma from '../lib/prisma';

export const categoryService = {
  async list(userId: string) {
    return prisma.category.findMany({
      where: { userId },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
    });
  },

  async create(
    userId: string,
    data: {
      name: string;
      color?: string;
      emoji?: string | null;
      sortOrder?: number;
    },
  ) {
    const maxSort = await prisma.category.aggregate({
      where: { userId },
      _max: { sortOrder: true },
    });
    const nextSort = (maxSort._max.sortOrder ?? 0) + 1;

    return prisma.category.create({
      data: {
        name: data.name,
        color: data.color || '#9E9E9E',
        emoji: data.emoji || null,
        sortOrder: data.sortOrder ?? nextSort,
        userId,
      },
    });
  },

  async update(
    userId: string,
    categoryId: string,
    data: {
      name?: string;
      color?: string;
      emoji?: string | null;
      sortOrder?: number;
    },
  ) {
    const category = await prisma.category.findUnique({ where: { id: categoryId } });

    if (!category) {
      const error = new Error('Category not found');
      (error as any).statusCode = 404;
      throw error;
    }

    if (category.userId !== userId) {
      const error = new Error('Forbidden');
      (error as any).statusCode = 403;
      throw error;
    }

    const updateData: any = {};
    if (data.name !== undefined) updateData.name = data.name;
    if (data.color !== undefined) updateData.color = data.color;
    if (data.emoji !== undefined) updateData.emoji = data.emoji;
    if (data.sortOrder !== undefined) updateData.sortOrder = data.sortOrder;

    return prisma.category.update({
      where: { id: categoryId },
      data: updateData,
    });
  },

  async delete(userId: string, categoryId: string) {
    const category = await prisma.category.findUnique({ where: { id: categoryId } });

    if (!category) {
      const error = new Error('Category not found');
      (error as any).statusCode = 404;
      throw error;
    }

    if (category.userId !== userId) {
      const error = new Error('Forbidden');
      (error as any).statusCode = 403;
      throw error;
    }

    if (category.isDefault) {
      const error = new Error('Cannot delete default category');
      (error as any).statusCode = 400;
      throw error;
    }

    // Find the user's default category to reassign items
    const defaultCategory = await prisma.category.findFirst({
      where: { userId, isDefault: true },
    });

    if (!defaultCategory) {
      const error = new Error('No default category found');
      (error as any).statusCode = 500;
      throw error;
    }

    // Move all events and tasks to default category, then delete
    await prisma.$transaction([
      prisma.event.updateMany({
        where: { categoryId: categoryId },
        data: { categoryId: defaultCategory.id },
      }),
      prisma.task.updateMany({
        where: { categoryId: categoryId },
        data: { categoryId: defaultCategory.id },
      }),
      prisma.category.delete({ where: { id: categoryId } }),
    ]);
  },

  /** Create default category for a new user */
  async createDefaultForUser(userId: string) {
    return prisma.category.create({
      data: {
        name: '기본',
        color: '#9E9E9E',
        isDefault: true,
        sortOrder: 0,
        userId,
      },
    });
  },
};
