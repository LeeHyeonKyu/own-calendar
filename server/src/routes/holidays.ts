import { Router, Response } from 'express';
import { holidayService } from '../services/holiday.service';
import { authenticate } from '../middleware/auth';
import { AuthRequest } from '../types';

const router = Router();

router.use(authenticate);

router.get('/', async (req: AuthRequest, res: Response) => {
  try {
    const subscriptions = await holidayService.listSubscriptions(req.userId!);
    res.json(subscriptions);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.post('/subscribe', async (req: AuthRequest, res: Response) => {
  try {
    const { countryCode } = req.body;
    if (!countryCode) {
      res.status(400).json({ error: '국가 코드를 입력해주세요' });
      return;
    }
    const result = await holidayService.subscribe(req.userId!, countryCode);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.delete('/subscribe/:countryCode', async (req: AuthRequest, res: Response) => {
  try {
    const result = await holidayService.unsubscribe(req.userId!, String(req.params.countryCode));
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.get('/holidays', async (req: AuthRequest, res: Response) => {
  try {
    const year = parseInt(String(req.query.year)) || new Date().getFullYear();
    const month = req.query.month ? parseInt(String(req.query.month)) : undefined;
    const holidays = await holidayService.getHolidays(req.userId!, year, month);
    res.json(holidays);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

export default router;
