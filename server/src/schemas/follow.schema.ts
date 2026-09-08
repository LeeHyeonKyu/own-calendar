import { z } from 'zod';

export const sendFollowSchema = z.object({
  followeeId: z.string().min(1),
});

export const searchUsersSchema = z.object({
  q: z.string().min(1),
});
