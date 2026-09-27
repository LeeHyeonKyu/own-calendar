import { Router, Response } from 'express';
import { holidayService } from '../services/holiday.service';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { subscribeHolidaySchema, getHolidaysQuerySchema } from '../schemas/holiday.schema';
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

router.post('/subscribe', validate(subscribeHolidaySchema), async (req: AuthRequest, res: Response) => {
  try {
    const { countryCode } = req.body;
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
    const parsed = getHolidaysQuerySchema.safeParse(req.query);
    if (!parsed.success) {
      res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten() });
      return;
    }
    const { year, month, countryCode } = parsed.data;
    const holidays = await holidayService.getHolidays(req.userId!, year, month, countryCode);
    res.json(holidays);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

export default router;
