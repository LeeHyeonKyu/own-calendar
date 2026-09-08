import { Router, Response } from 'express';
import { routineService } from '../services/routine.service';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';
import {
  createRoutineSchema,
  updateRoutineSchema,
  queryRoutineSchema,
  completeRoutineSchema,
  createRoutineGroupSchema,
  updateRoutineGroupSchema,
} from '../schemas/routine.schema';
import { AuthRequest } from '../types';

const router = Router();

router.use(authenticate);

// ─── Routines ───

router.get('/', async (req: AuthRequest, res: Response) => {
  try {
    const parsed = queryRoutineSchema.safeParse(req.query);
    if (!parsed.success) {
      res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten() });
      return;
    }

    const date = parsed.data.date || new Date().toISOString().split('T')[0];
    const result = await routineService.getRoutinesForDate(req.userId!, date);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.post('/', validate(createRoutineSchema), async (req: AuthRequest, res: Response) => {
  try {
    const result = await routineService.create(req.userId!, req.body);
    res.status(201).json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.put('/:id', validate(updateRoutineSchema), async (req: AuthRequest, res: Response) => {
  try {
    const result = await routineService.update(req.userId!, req.params.id as string, req.body);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.delete('/:id', async (req: AuthRequest, res: Response) => {
  try {
    await routineService.delete(req.userId!, req.params.id as string);
    res.status(204).send();
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.post('/:id/complete', validate(completeRoutineSchema), async (req: AuthRequest, res: Response) => {
  try {
    const result = await routineService.toggleComplete(req.userId!, req.params.id as string, req.body.date);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// ─── Routine Groups ───

router.get('/groups', async (req: AuthRequest, res: Response) => {
  try {
    const result = await routineService.listGroups(req.userId!);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.post('/groups', validate(createRoutineGroupSchema), async (req: AuthRequest, res: Response) => {
  try {
    const result = await routineService.createGroup(req.userId!, req.body);
    res.status(201).json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.put('/groups/:id', validate(updateRoutineGroupSchema), async (req: AuthRequest, res: Response) => {
  try {
    const result = await routineService.updateGroup(req.userId!, req.params.id as string, req.body);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.delete('/groups/:id', async (req: AuthRequest, res: Response) => {
  try {
    await routineService.deleteGroup(req.userId!, req.params.id as string);
    res.status(204).send();
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

export default router;
