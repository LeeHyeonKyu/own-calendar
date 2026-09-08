import { z } from 'zod';

const TASK_STATUSES = ['TODO', 'DONE', 'CANCELLED'] as const;
const TASK_PRIORITIES = ['HIGH', 'MEDIUM', 'LOW', 'NONE'] as const;
const RECURRENCE_TYPES = ['NONE', 'DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'] as const;

const attendeeSchema = z.object({
  name: z.string(),
  email: z.string().email().optional(),
});

export const createTaskSchema = z.object({
  title: z.string().min(1),
  description: z.string().optional(),
  priority: z.enum(TASK_PRIORITIES).optional().default('NONE'),
  dueDate: z.string().nullable().optional(),
  scheduledDate: z.string().nullable().optional(),
  scheduledTime: z.string().regex(/^\d{2}:\d{2}$/).nullable().optional(),
  recurrenceType: z.enum(RECURRENCE_TYPES).optional().default('NONE'),
  recurrenceEnd: z.string().nullable().optional(),
  location: z.string().nullable().optional(),
  notes: z.string().nullable().optional(),
  attendees: z.array(attendeeSchema).nullable().optional(),
  eventId: z.string().nullable().optional(),
  calendarId: z.string(),
  sortOrder: z.number().int().optional(),
});

export const updateTaskSchema = z.object({
  title: z.string().min(1).optional(),
  description: z.string().nullable().optional(),
  status: z.enum(TASK_STATUSES).optional(),
  priority: z.enum(TASK_PRIORITIES).optional(),
  dueDate: z.string().nullable().optional(),
  scheduledDate: z.string().nullable().optional(),
  scheduledTime: z.string().regex(/^\d{2}:\d{2}$/).nullable().optional(),
  recurrenceType: z.enum(RECURRENCE_TYPES).optional(),
  recurrenceEnd: z.string().nullable().optional(),
  location: z.string().nullable().optional(),
  notes: z.string().nullable().optional(),
  attendees: z.array(attendeeSchema).nullable().optional(),
  eventId: z.string().nullable().optional(),
  calendarId: z.string().optional(),
  sortOrder: z.number().int().optional(),
});

export const queryTaskSchema = z.object({
  calendarId: z.string().optional(),
  status: z.enum(TASK_STATUSES).optional(),
  eventId: z.string().optional(),
  start: z.string().optional(),
  end: z.string().optional(),
  includeDone: z.string().optional(),
});

export const linkEventSchema = z.object({
  eventId: z.string().nullable(),
});
