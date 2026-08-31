import { z } from 'zod';

export const createFamilySchema = z.object({
  name: z.string().min(1),
});

export const joinFamilySchema = z.object({
  code: z.string().min(1),
});
