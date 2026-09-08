import { Router, Response } from 'express';
import { followService } from '../services/follow.service';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { sendFollowSchema } from '../schemas/follow.schema';
import { AuthRequest } from '../types';

const router = Router();

router.use(authenticate);

// Search users (for follow UI)
router.get('/search', async (req: AuthRequest, res: Response) => {
  try {
    const q = req.query.q as string;
    if (!q || q.length < 1) {
      res.status(400).json({ error: 'Query parameter q is required' });
      return;
    }
    const result = await followService.searchUsers(q, req.userId!);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Send follow request
router.post('/', validate(sendFollowSchema), async (req: AuthRequest, res: Response) => {
  try {
    const result = await followService.sendFollowRequest(req.userId!, req.body.followeeId);
    res.status(201).json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Get my followers
router.get('/followers', async (req: AuthRequest, res: Response) => {
  try {
    const result = await followService.getFollowers(req.userId!);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Get who I'm following
router.get('/following', async (req: AuthRequest, res: Response) => {
  try {
    const result = await followService.getFollowing(req.userId!);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Get pending follow requests (received)
router.get('/pending', async (req: AuthRequest, res: Response) => {
  try {
    const result = await followService.getPendingRequests(req.userId!);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Get sent follow requests
router.get('/sent', async (req: AuthRequest, res: Response) => {
  try {
    const result = await followService.getSentRequests(req.userId!);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Accept a follow request
router.post('/:followId/accept', async (req: AuthRequest, res: Response) => {
  try {
    const result = await followService.acceptFollow(req.userId!, req.params.followId as string);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Reject a follow request
router.post('/:followId/reject', async (req: AuthRequest, res: Response) => {
  try {
    const result = await followService.rejectFollow(req.userId!, req.params.followId as string);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Unfollow a user
router.delete('/:followeeId', async (req: AuthRequest, res: Response) => {
  try {
    await followService.unfollow(req.userId!, req.params.followeeId as string);
    res.status(204).send();
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Get public events of a followed user
router.get('/:followeeId/events', async (req: AuthRequest, res: Response) => {
  try {
    const query = {
      start: req.query.start as string | undefined,
      end: req.query.end as string | undefined,
    };
    const result = await followService.getFolloweePublicEvents(req.userId!, req.params.followeeId as string, query);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

export default router;
