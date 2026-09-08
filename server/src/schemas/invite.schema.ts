import { z } from 'zod';

export const createInviteSchema = z.object({
  eventId: z.string().min(1),
  inviteeId: z.string().min(1),
});
