import { Router, Response } from 'express';
import { holidayService } from '../services/holiday.service';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { subscribeHolidaySchema, getHolidaysQuerySchema } from '../schemas/holiday.schema';
import { AuthRequest } from '../types';
import { sendError } from '../lib/send-error';

const router = Router();

router.use(authenticate);

router.get('/', async (req: AuthRequest, res: Response) => {
  try {
    const subscriptions = await holidayService.listSubscriptions(req.userId!);
    res.json(subscriptions);
  } catch (err: any) {
    sendError(res, err);
  }
});

router.post('/subscribe', validate(subscribeHolidaySchema), async (req: AuthRequest, res: Response) => {
  try {
    const { countryCode } = req.body;
    const result = await holidayService.subscribe(req.userId!, countryCode);
    res.json(result);
  } catch (err: any) {
    sendError(res, err);
  }
});

router.delete('/subscribe/:countryCode', async (req: AuthRequest, res: Response) => {
  try {
    const result = await holidayService.unsubscribe(req.userId!, String(req.params.countryCode));
    res.json(result);
  } catch (err: any) {
    sendError(res, err);
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
    sendError(res, err);
  }
});

export default router;
