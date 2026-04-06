import { Router, Response } from 'express';
import { googleSyncService } from '../services/google-sync.service';
import { authenticate } from '../middleware/auth';
import { AuthRequest } from '../types';

const router = Router();

router.get('/auth', authenticate, async (req: AuthRequest, res: Response) => {
  const url = googleSyncService.getAuthUrl(req.userId!);
  res.json({ url });
});

router.get('/callback', async (req, res) => {
  try {
    const { code, state: userId } = req.query;
    if (!code || !userId) {
      res.status(400).json({ error: 'Missing code or state' });
      return;
    }
    const result = await googleSyncService.handleCallback(code as string, userId as string);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.use(authenticate);

router.get('/connections', async (req: AuthRequest, res: Response) => {
  try {
    const connections = await googleSyncService.listConnections(req.userId!);
    res.json(connections);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.post('/sync/:connectionId', async (req: AuthRequest, res: Response) => {
  try {
    const result = await googleSyncService.pullEvents(req.userId!, req.params.connectionId);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.post('/push/:eventId', async (req: AuthRequest, res: Response) => {
  try {
    const result = await googleSyncService.pushEvent(req.userId!, req.params.eventId);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.delete('/connections/:connectionId', async (req: AuthRequest, res: Response) => {
  try {
    const result = await googleSyncService.disconnect(req.userId!, req.params.connectionId);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

export default router;
