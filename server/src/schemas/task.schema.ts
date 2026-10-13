import { z } from 'zod';

const TASK_STATUSES = ['TODO', 'DONE', 'CANCELLED'] as const;
const TASK_PRIORITIES = ['HIGH', 'MEDIUM', 'LOW', 'NONE'] as const;
const RECURRENCE_TYPES = ['NONE', 'DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'] as const;
const EDIT_MODES = ['this', 'thisAndFuture', 'all'] as const;

const checklistItemSchema: z.ZodType<any> = z.lazy(() =>
  z.object({
    id: z.string().min(1),
    text: z.string(),
    checked: z.boolean(),
    children: z.array(checklistItemSchema).max(50).default([]),
  }),
);

/** Validate that nesting never exceeds 3 levels (root = level 1). */
function validateChecklistDepth(items: any[], depth = 1): boolean {
  if (depth > 3) return false;
  for (const item of items) {
    if (item.children && item.children.length > 0) {
      if (!validateChecklistDepth(item.children, depth + 1)) return false;
    }
  }
  return true;
}

export const checklistSchema = z
  .array(checklistItemSchema)
  .max(200)
  .refine((items) => validateChecklistDepth(items), {
    message: 'Checklist nesting must not exceed 3 levels',
  })
  .nullable()
  .optional();

export const createTaskSchema = z.object({
  title: z.string().min(1),
  description: z.string().optional(),
  priority: z.enum(TASK_PRIORITIES).optional().default('NONE'),
  dueDate: z.string().nullable().optional(),
  scheduledDate: z.string().nullable().optional(),
  scheduledTime: z.string().regex(/^\d{2}:\d{2}$/).nullable().optional(),
  recurrenceType: z.enum(RECURRENCE_TYPES).optional().default('NONE'),
  recurrenceEnd: z.string().nullable().optional(),
  rrule: z.string().nullable().optional(),
  eventId: z.string().nullable().optional(),
  calendarId: z.string(),
  sortOrder: z.number().int().optional(),
  checklist: checklistSchema,
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
  rrule: z.string().nullable().optional(),
  eventId: z.string().nullable().optional(),
  calendarId: z.string().optional(),
  sortOrder: z.number().int().optional(),
  checklist: checklistSchema,
  // Recurrence edit scope - normally sent as query params (see routes/tasks.ts),
  // but also accepted in the body for flexibility.
  editMode: z.enum(EDIT_MODES).optional(),
  instanceDate: z.string().optional(),
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
