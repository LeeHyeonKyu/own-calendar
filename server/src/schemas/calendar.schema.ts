import { z } from 'zod';

export const createCalendarSchema = z.object({
  name: z.string().min(1),
  color: z.string().regex(/^#[0-9A-Fa-f]{6}$/).optional(),
  visibility: z.enum(['PUBLIC', 'PRIVATE']).optional(),
});

export const updateCalendarSchema = z.object({
  name: z.string().min(1).optional(),
  color: z.string().regex(/^#[0-9A-Fa-f]{6}$/).optional(),
  visibility: z.enum(['PUBLIC', 'PRIVATE']).optional(),
});
