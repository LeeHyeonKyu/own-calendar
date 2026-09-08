import { z } from 'zod';

const dayOfWeek = z.number().int().min(0).max(6);

export const createRoutineSchema = z.object({
  name: z.string().min(1),
  time: z.string().regex(/^\d{2}:\d{2}$/).nullable().optional(),
  repeatDays: z.array(dayOfWeek).min(1),
  groupId: z.string().nullable().optional(),
  sortOrder: z.number().int().optional(),
});

export const updateRoutineSchema = z.object({
  name: z.string().min(1).optional(),
  time: z.string().regex(/^\d{2}:\d{2}$/).nullable().optional(),
  repeatDays: z.array(dayOfWeek).min(1).optional(),
  groupId: z.string().nullable().optional(),
  sortOrder: z.number().int().optional(),
});

export const queryRoutineSchema = z.object({
  date: z.string().optional(),
});

export const completeRoutineSchema = z.object({
  date: z.string(),
});

export const createRoutineGroupSchema = z.object({
  name: z.string().min(1),
  sortOrder: z.number().int().optional(),
});

export const updateRoutineGroupSchema = z.object({
  name: z.string().min(1).optional(),
  sortOrder: z.number().int().optional(),
});
