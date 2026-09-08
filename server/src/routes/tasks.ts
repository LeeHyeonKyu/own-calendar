import { Router, Response } from 'express';
import { taskService } from '../services/task.service';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { createTaskSchema, updateTaskSchema, queryTaskSchema, linkEventSchema } from '../schemas/task.schema';
import { AuthRequest } from '../types';

const router = Router();

router.use(authenticate);

router.get('/', async (req: AuthRequest, res: Response) => {
  try {
    const parsed = queryTaskSchema.safeParse(req.query);
    if (!parsed.success) {
      res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten() });
      return;
    }

    const result = await taskService.list(req.userId!, parsed.data);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.post('/', validate(createTaskSchema), async (req: AuthRequest, res: Response) => {
  try {
    const result = await taskService.create(req.userId!, req.body);
    res.status(201).json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.put('/:id', validate(updateTaskSchema), async (req: AuthRequest, res: Response) => {
  try {
    const editMode = ((req.query.editMode as string) || (req.body as any).editMode || 'all') as 'this' | 'thisAndFuture' | 'all';
    const instanceDate = (req.query.instanceDate as string) || (req.body as any).instanceDate;
    const { editMode: _em, instanceDate: _id, ...data } = req.body as any;
    const result = await taskService.updateWithMode(req.userId!, req.params.id as string, instanceDate, editMode, data);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.patch('/:id/complete', async (req: AuthRequest, res: Response) => {
  try {
    const instanceDate = req.query.instanceDate as string | undefined;
    const result = await taskService.toggleComplete(req.userId!, req.params.id as string, instanceDate);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.patch('/:id/link', validate(linkEventSchema), async (req: AuthRequest, res: Response) => {
  try {
    const result = await taskService.linkEvent(req.userId!, req.params.id as string, req.body.eventId);
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
    await taskService.deleteWithMode(req.userId!, req.params.id as string, instanceDate, editMode);
    res.status(204).send();
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

export default router;
