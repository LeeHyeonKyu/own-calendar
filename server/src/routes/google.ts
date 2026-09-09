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
      res.status(400).send(callbackPage('연결 실패', '인증 정보가 누락되었습니다.', false));
      return;
    }
    await googleSyncService.handleCallback(code as string, userId as string);
    res.send(callbackPage('Google Calendar 연결 완료!', '앱으로 돌아가주세요. 일정이 자동으로 동기화됩니다.', true));
  } catch (err: any) {
    res.status(500).send(callbackPage('연결 실패', err.message || '알 수 없는 오류가 발생했습니다.', false));
  }
});

function callbackPage(title: string, message: string, success: boolean): string {
  const color = success ? '#4285F4' : '#EA4335';
  const icon = success ? '✓' : '✗';
  return `<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${title}</title>
<style>
  body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;display:flex;justify-content:center;align-items:center;min-height:100vh;margin:0;background:#f5f5f5;color:#333}
  .card{background:white;border-radius:16px;padding:48px;text-align:center;box-shadow:0 2px 12px rgba(0,0,0,0.08);max-width:400px}
  .icon{font-size:48px;width:80px;height:80px;border-radius:50%;background:${color};color:white;display:flex;align-items:center;justify-content:center;margin:0 auto 24px}
  h1{font-size:20px;margin:0 0 8px;color:#333}
  p{font-size:14px;color:#666;margin:0}
</style></head>
<body><div class="card">
  <div class="icon">${icon}</div>
  <h1>${title}</h1>
  <p>${message}</p>
</div></body></html>`;
}

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
    const result = await googleSyncService.pullEvents(req.userId!, String(req.params.connectionId));
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.post('/push/:eventId', async (req: AuthRequest, res: Response) => {
  try {
    const result = await googleSyncService.pushEvent(req.userId!, String(req.params.eventId));
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.delete('/connections/:connectionId', async (req: AuthRequest, res: Response) => {
  try {
    const result = await googleSyncService.disconnect(req.userId!, String(req.params.connectionId));
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

export default router;
