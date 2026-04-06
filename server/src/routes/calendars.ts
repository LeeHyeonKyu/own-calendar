import { Router, Response } from 'express';
import { calendarService } from '../services/calendar.service';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { createCalendarSchema, updateCalendarSchema } from '../schemas/calendar.schema';
import { AuthRequest } from '../types';

const router = Router();

router.use(authenticate);

router.get('/', async (req: AuthRequest, res: Response) => {
  try {
    const result = await calendarService.list(req.userId!);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.post('/', validate(createCalendarSchema), async (req: AuthRequest, res: Response) => {
  try {
    const result = await calendarService.create(req.userId!, req.body);
    res.status(201).json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.put('/:id', validate(updateCalendarSchema), async (req: AuthRequest, res: Response) => {
  try {
    const result = await calendarService.update(req.userId!, req.params.id as string, req.body);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.delete('/:id', async (req: AuthRequest, res: Response) => {
  try {
    await calendarService.delete(req.userId!, req.params.id as string);
    res.status(204).send();
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

export default router;
