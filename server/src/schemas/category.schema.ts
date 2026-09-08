import { z } from 'zod';

export const createCategorySchema = z.object({
  name: z.string().min(1).max(50),
  color: z.string().regex(/^#[0-9A-Fa-f]{6}$/).optional().default('#9E9E9E'),
  emoji: z.string().max(10).nullable().optional(),
  sortOrder: z.number().int().optional(),
});

export const updateCategorySchema = z.object({
  name: z.string().min(1).max(50).optional(),
  color: z.string().regex(/^#[0-9A-Fa-f]{6}$/).optional(),
  emoji: z.string().max(10).nullable().optional(),
  sortOrder: z.number().int().optional(),
});
