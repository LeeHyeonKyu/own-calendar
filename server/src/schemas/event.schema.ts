import { z } from 'zod';

const EVENT_CATEGORIES = ['WORK', 'PERSONAL', 'FAMILY', 'HEALTH', 'SOCIAL', 'FINANCE', 'OTHER'] as const;
const RECURRENCE_TYPES = ['NONE', 'DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'] as const;

const timeOrderRefinement = <T extends { startTime?: string; endTime?: string }>(data: T) => {
  if (data.startTime && data.endTime) {
    return new Date(data.endTime) >= new Date(data.startTime);
  }
  return true;
};

const timeOrderMessage = { message: 'endTime must be after startTime', path: ['endTime'] as const };

export const createEventBaseSchema = z.object({
  title: z.string().min(1),
  description: z.string().optional(),
  startTime: z.string(),
  endTime: z.string(),
  isAllDay: z.boolean().optional(),
  isPrivate: z.boolean().optional(),
  category: z.enum(EVENT_CATEGORIES).optional().default('PERSONAL'),
  tags: z.array(z.string()).optional().default([]),
  recurrenceType: z.enum(RECURRENCE_TYPES).optional().default('NONE'),
  recurrenceEnd: z.string().nullable().optional(),
  calendarId: z.string(),
});

export const createEventSchema = createEventBaseSchema.refine(timeOrderRefinement, timeOrderMessage);

export const updateEventSchema = z.object({
  title: z.string().min(1).optional(),
  description: z.string().nullable().optional(),
  startTime: z.string().optional(),
  endTime: z.string().optional(),
  isAllDay: z.boolean().optional(),
  isPrivate: z.boolean().optional(),
  category: z.enum(EVENT_CATEGORIES).optional(),
  tags: z.array(z.string()).optional(),
  recurrenceType: z.enum(RECURRENCE_TYPES).optional(),
  recurrenceEnd: z.string().nullable().optional(),
  calendarId: z.string().optional(),
}).refine(timeOrderRefinement, timeOrderMessage);

export const queryEventSchema = z.object({
  calendarId: z.string().optional(),
  category: z.enum(EVENT_CATEGORIES).optional(),
  start: z.string().optional(),
  end: z.string().optional(),
});

export const searchEventSchema = z.object({
  q: z.string().min(1),
  start: z.string().optional(),
  end: z.string().optional(),
});
