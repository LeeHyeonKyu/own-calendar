import { Router, Response } from 'express';
import prisma from '../lib/prisma';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { registerTokenSchema } from '../schemas/device-token.schema';
import { AuthRequest } from '../types';
import { sendError } from '../lib/send-error';

const router = Router();

router.use(authenticate);

// Register FCM token
router.post('/', validate(registerTokenSchema), async (req: AuthRequest, res: Response) => {
  try {
    const { token, platform } = req.body;

    // Upsert: if token already exists, update userId and platform
    const deviceToken = await prisma.deviceToken.upsert({
      where: { token },
      update: { userId: req.userId!, platform },
      create: { token, platform, userId: req.userId! },
    });

    res.status(201).json(deviceToken);
  } catch (err: any) {
    sendError(res, err);
  }
});

// Unregister FCM token
router.delete('/:token', async (req: AuthRequest, res: Response) => {
  try {
    const token = req.params.token as string;

    await prisma.deviceToken.deleteMany({
      where: { token, userId: req.userId! },
    });

    res.status(204).send();
  } catch (err: any) {
    sendError(res, err);
  }
});

export default router;
