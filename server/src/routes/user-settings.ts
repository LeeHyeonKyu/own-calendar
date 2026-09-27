import { Router, Response } from 'express';
import prisma from '../lib/prisma';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { updateUserSettingsSchema } from '../schemas/user-settings.schema';
import { AuthRequest } from '../types';
import { sendError } from '../lib/send-error';

const router = Router();

router.use(authenticate);

// Get user settings
router.get('/', async (req: AuthRequest, res: Response) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.userId! },
      select: { defaultReminderMinutes: true },
    });

    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    res.json(user);
  } catch (err: any) {
    sendError(res, err);
  }
});

// Update user settings
router.put('/', validate(updateUserSettingsSchema), async (req: AuthRequest, res: Response) => {
  try {
    const user = await prisma.user.update({
      where: { id: req.userId! },
      data: { defaultReminderMinutes: req.body.defaultReminderMinutes },
      select: { defaultReminderMinutes: true },
    });

    res.json(user);
  } catch (err: any) {
    sendError(res, err);
  }
});

export default router;
