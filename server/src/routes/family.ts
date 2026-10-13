// @deprecated — Use /api/groups instead. Kept for backwards compatibility.
// All handlers delegate to groupService via familyService wrapper.
import { Router, Response } from 'express';
import { familyService } from '../services/family.service';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { createFamilySchema, joinFamilySchema } from '../schemas/family.schema';
import { createEventBaseSchema } from '../schemas/event.schema';
import { AuthRequest } from '../types';

const router = Router();

router.use(authenticate);

router.post('/', validate(createFamilySchema), async (req: AuthRequest, res: Response) => {
  try {
    const result = await familyService.create(req.userId!, req.body.name);
    res.status(201).json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.get('/', async (req: AuthRequest, res: Response) => {
  try {
    const result = await familyService.getMyFamily(req.userId!);
    if (!result) {
      res.json(null);
      return;
    }
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.post('/join', validate(joinFamilySchema), async (req: AuthRequest, res: Response) => {
  try {
    const result = await familyService.join(req.userId!, req.body.code);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.get('/members', async (req: AuthRequest, res: Response) => {
  try {
    const result = await familyService.getMembers(req.userId!);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.delete('/members/:userId', async (req: AuthRequest, res: Response) => {
  try {
    await familyService.removeMember(req.userId!, String(req.params.userId));
    res.status(204).send();
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.get('/calendars', async (req: AuthRequest, res: Response) => {
  try {
    const query = {
      start: req.query.start as string | undefined,
      end: req.query.end as string | undefined,
    };
    const result = await familyService.getFamilyCalendars(req.userId!, query);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.post('/events', validate(createEventBaseSchema.omit({ calendarId: true })), async (req: AuthRequest, res: Response) => {
  try {
    const result = await familyService.createFamilyEvent(req.userId!, req.body);
    res.status(201).json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

export default router;
