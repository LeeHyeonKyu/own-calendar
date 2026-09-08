import { Router, Response } from 'express';
import { categoryService } from '../services/category.service';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { createCategorySchema, updateCategorySchema } from '../schemas/category.schema';
import { AuthRequest } from '../types';

const router = Router();

router.use(authenticate);

router.get('/', async (req: AuthRequest, res: Response) => {
  try {
    const result = await categoryService.list(req.userId!);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.post('/', validate(createCategorySchema), async (req: AuthRequest, res: Response) => {
  try {
    const result = await categoryService.create(req.userId!, req.body);
    res.status(201).json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.put('/:id', validate(updateCategorySchema), async (req: AuthRequest, res: Response) => {
  try {
    const result = await categoryService.update(req.userId!, req.params.id as string, req.body);
    res.json(result);
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.delete('/:id', async (req: AuthRequest, res: Response) => {
  try {
    await categoryService.delete(req.userId!, req.params.id as string);
    res.status(204).send();
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

export default router;
