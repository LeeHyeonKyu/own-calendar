import { z } from 'zod';

export const createEventSchema = z.object({
  title: z.string().min(1),
  description: z.string().optional(),
  startTime: z.string().datetime(),
  endTime: z.string().datetime(),
  isAllDay: z.boolean().optional(),
  isPrivate: z.boolean().optional(),
  calendarId: z.string(),
});

export const updateEventSchema = z.object({
  title: z.string().min(1).optional(),
  description: z.string().nullable().optional(),
  startTime: z.string().datetime().optional(),
  endTime: z.string().datetime().optional(),
  isAllDay: z.boolean().optional(),
  isPrivate: z.boolean().optional(),
  calendarId: z.string().optional(),
});

export const queryEventSchema = z.object({
  calendarId: z.string().optional(),
  start: z.string().datetime().optional(),
  end: z.string().datetime().optional(),
});
