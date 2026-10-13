import { Router, Response } from 'express';
import { groupService } from '../services/group.service';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { createGroupSchema, joinGroupSchema } from '../schemas/group.schema';
import { createEventBaseSchema } from '../schemas/event.schema';
import { AuthRequest } from '../types';

const router = Router();

router.use(authenticate);

// Create a new group
router.post('/', validate(createGroupSchema), async (req: AuthRequest, res: Response) => {
  try {
    const result = await groupService.create(req.userId!, req.body.name, req.body.type);
    res.status(201).json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Get all my groups
router.get('/', async (req: AuthRequest, res: Response) => {
  try {
    const result = await groupService.getMyGroups(req.userId!);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Get all groups' calendars combined
router.get('/calendars', async (req: AuthRequest, res: Response) => {
  try {
    const query = {
      start: req.query.start as string | undefined,
      end: req.query.end as string | undefined,
    };
    const result = await groupService.getAllGroupCalendars(req.userId!, query);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Get a specific group detail
router.get('/:groupId', async (req: AuthRequest, res: Response) => {
  try {
    const result = await groupService.getGroup(req.userId!, req.params.groupId as string);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Join a group by code
router.post('/join', validate(joinGroupSchema), async (req: AuthRequest, res: Response) => {
  try {
    const result = await groupService.join(req.userId!, req.body.code);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Leave a group
router.post('/:groupId/leave', async (req: AuthRequest, res: Response) => {
  try {
    await groupService.leave(req.userId!, req.params.groupId as string);
    res.status(204).send();
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Remove a member from a group (owner only)
router.delete('/:groupId/members/:userId', async (req: AuthRequest, res: Response) => {
  try {
    await groupService.removeMember(req.userId!, req.params.groupId as string, req.params.userId as string);
    res.status(204).send();
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Delete a group (owner only)
router.delete('/:groupId', async (req: AuthRequest, res: Response) => {
  try {
    await groupService.deleteGroup(req.userId!, req.params.groupId as string);
    res.status(204).send();
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Get group calendars
router.get('/:groupId/calendars', async (req: AuthRequest, res: Response) => {
  try {
    const query = {
      start: req.query.start as string | undefined,
      end: req.query.end as string | undefined,
    };
    const result = await groupService.getGroupCalendars(req.userId!, req.params.groupId as string, query);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

// Create a group event
router.post('/:groupId/events', validate(createEventBaseSchema.omit({ calendarId: true })), async (req: AuthRequest, res: Response) => {
  try {
    const result = await groupService.createGroupEvent(req.userId!, req.params.groupId as string, req.body);
    res.status(201).json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

export default router;
