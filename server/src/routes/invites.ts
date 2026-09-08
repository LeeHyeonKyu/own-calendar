import { Router, Response } from 'express';
import { inviteService } from '../services/invite.service';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { createInviteSchema } from '../schemas/invite.schema';
import { AuthRequest } from '../types';

const router = Router();

router.use(authenticate);

// Create an event invite
router.post('/', validate(createInviteSchema), async (req: AuthRequest, res: Response) => {
  try {
    const result = await inviteService.inviteToEvent(req.userId!, req.body.eventId, req.body.inviteeId);
    res.status(201).json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Get my received invites
router.get('/', async (req: AuthRequest, res: Response) => {
  try {
    const status = req.query.status as string | undefined;
    const result = await inviteService.getUserInvites(req.userId!, status);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Get invites for a specific event
router.get('/event/:eventId', async (req: AuthRequest, res: Response) => {
  try {
    const result = await inviteService.getEventInvites(req.userId!, req.params.eventId as string);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Accept an invite
router.post('/:inviteId/accept', async (req: AuthRequest, res: Response) => {
  try {
    const result = await inviteService.acceptInvite(req.userId!, req.params.inviteId as string);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Decline an invite
router.post('/:inviteId/decline', async (req: AuthRequest, res: Response) => {
  try {
    const result = await inviteService.declineInvite(req.userId!, req.params.inviteId as string);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Remove/cancel an invite
router.delete('/:inviteId', async (req: AuthRequest, res: Response) => {
  try {
    await inviteService.removeInvite(req.userId!, req.params.inviteId as string);
    res.status(204).send();
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

export default router;
