import { z } from 'zod';

export const createGroupSchema = z.object({
  name: z.string().min(1),
  type: z.string().optional().default('가족'),
});

export const joinGroupSchema = z.object({
  code: z.string().min(1),
});
