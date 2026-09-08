import { z } from 'zod';

export const updateUserSettingsSchema = z.object({
  defaultReminderMinutes: z.number().int().min(-1).max(60),
});
