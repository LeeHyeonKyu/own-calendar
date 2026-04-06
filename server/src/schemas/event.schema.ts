import { z } from 'zod';

export const createEventSchema = z.object({
  title: z.string().min(1),
  description: z.string().optional(),
  startTime: z.string(),
  endTime: z.string(),
  isAllDay: z.boolean().optional(),
  isPrivate: z.boolean().optional(),
  calendarId: z.string(),
});

export const updateEventSchema = z.object({
  title: z.string().min(1).optional(),
  description: z.string().nullable().optional(),
  startTime: z.string().optional(),
  endTime: z.string().optional(),
  isAllDay: z.boolean().optional(),
  isPrivate: z.boolean().optional(),
  calendarId: z.string().optional(),
});

export const queryEventSchema = z.object({
  calendarId: z.string().optional(),
  start: z.string().optional(),
  end: z.string().optional(),
});

export const searchEventSchema = z.object({
  q: z.string().min(1),
  start: z.string().optional(),
  end: z.string().optional(),
});
