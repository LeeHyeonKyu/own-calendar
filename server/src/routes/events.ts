import { Router, Response } from 'express';
import { eventService } from '../services/event.service';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { createEventSchema, updateEventSchema, queryEventSchema } from '../schemas/event.schema';
import { AuthRequest } from '../types';

const router = Router();

router.use(authenticate);

router.get('/', async (req: AuthRequest, res: Response) => {
  try {
    const parsed = queryEventSchema.safeParse(req.query);
    if (!parsed.success) {
      res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten() });
      return;
    }

    const result = await eventService.list(req.userId!, parsed.data);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.post('/', validate(createEventSchema), async (req: AuthRequest, res: Response) => {
  try {
    const result = await eventService.create(req.userId!, req.body);
    res.status(201).json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.put('/:id', validate(updateEventSchema), async (req: AuthRequest, res: Response) => {
  try {
    const result = await eventService.update(req.userId!, req.params.id as string, req.body);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.delete('/:id', async (req: AuthRequest, res: Response) => {
  try {
    await eventService.delete(req.userId!, req.params.id as string);
    res.status(204).send();
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

export default router;
