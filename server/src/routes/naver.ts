import { Router, Response } from 'express';
import { naverSyncService } from '../services/naver-sync.service';
import { authenticate } from '../middleware/auth';
import { AuthRequest } from '../types';

const router = Router();

router.use(authenticate);

router.post('/connect', async (req: AuthRequest, res: Response) => {
  try {
    const { naverId, password } = req.body;
    if (!naverId || !password) {
      res.status(400).json({ error: 'Naver ID와 비밀번호를 입력해주세요' });
      return;
    }
    const result = await naverSyncService.connect(req.userId!, naverId, password);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.get('/connections', async (req: AuthRequest, res: Response) => {
  try {
    const connections = await naverSyncService.listConnections(req.userId!);
    res.json(connections);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.post('/sync/:connectionId', async (req: AuthRequest, res: Response) => {
  try {
    const result = await naverSyncService.pullEvents(req.userId!, String(req.params.connectionId));
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.delete('/connections/:connectionId', async (req: AuthRequest, res: Response) => {
  try {
    const result = await naverSyncService.disconnect(req.userId!, String(req.params.connectionId));
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

export default router;
