import { z } from 'zod';

export const registerTokenSchema = z.object({
  token: z.string().min(1),
  platform: z.enum(['IOS', 'ANDROID', 'WEB']),
});
