import { Router, Response } from 'express';
import { eventService } from '../services/event.service';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { createEventSchema, updateEventSchema, queryEventSchema, searchEventSchema } from '../schemas/event.schema';
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

router.get('/search', async (req: AuthRequest, res: Response) => {
  try {
    const result = searchEventSchema.safeParse(req.query);
    if (!result.success) {
      res.status(400).json({ error: 'Validation failed', details: result.error.flatten() });
      return;
    }
    const { q, start, end } = result.data;
    const events = await eventService.search(req.userId!, q, start, end);
    res.json(events);
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
    const editMode = ((req.query.editMode as string) || (req.body as any).editMode || 'all') as 'this' | 'thisAndFuture' | 'all';
    const instanceDate = (req.query.instanceDate as string) || (req.body as any).instanceDate;
    const { editMode: _em, instanceDate: _id, ...data } = req.body as any;
    const result = await eventService.updateWithMode(req.userId!, req.params.id as string, instanceDate, editMode, data);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.delete('/:id', async (req: AuthRequest, res: Response) => {
  try {
    const editMode = ((req.query.editMode as string) || 'all') as 'this' | 'thisAndFuture' | 'all';
    const instanceDate = req.query.instanceDate as string | undefined;
    await eventService.deleteWithMode(req.userId!, req.params.id as string, instanceDate, editMode);
    res.status(204).send();
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

export default router;
