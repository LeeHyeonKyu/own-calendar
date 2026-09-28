import { Router, Response } from 'express';
import { categoryService } from '../services/category.service';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { createCategorySchema, updateCategorySchema } from '../schemas/category.schema';
import { AuthRequest } from '../types';
import { sendError } from '../lib/send-error';

const router = Router();

router.use(authenticate);

router.get('/', async (req: AuthRequest, res: Response) => {
  try {
    const result = await categoryService.list(req.userId!);
    res.json(result);
  } catch (err: any) {
    sendError(res, err);
  }
});

router.post('/', validate(createCategorySchema), async (req: AuthRequest, res: Response) => {
  try {
    const result = await categoryService.create(req.userId!, req.body);
    res.status(201).json(result);
  } catch (err: any) {
    sendError(res, err);
  }
});

router.put('/:id', validate(updateCategorySchema), async (req: AuthRequest, res: Response) => {
  try {
    const result = await categoryService.update(req.userId!, req.params.id as string, req.body);
    res.json(result);
  } catch (err: any) {
    sendError(res, err);
  }
});

router.delete('/:id', async (req: AuthRequest, res: Response) => {
  try {
    await categoryService.delete(req.userId!, req.params.id as string);
    res.status(204).send();
  } catch (err: any) {
    sendError(res, err);
  }
});

export default router;
