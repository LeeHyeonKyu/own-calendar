import { Router, Response } from 'express';
import multer from 'multer';
import { icsImportService } from '../services/ics-import.service';
import { authenticate } from '../middleware/auth';
import { AuthRequest } from '../types';

const router = Router();

// Configure multer for in-memory file uploads (max 10MB)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    // Accept .ics files and text/calendar MIME type
    const isIcs =
      file.originalname.toLowerCase().endsWith('.ics') ||
      file.mimetype === 'text/calendar' ||
      file.mimetype === 'application/octet-stream';
    if (isIcs) {
      cb(null, true);
    } else {
      cb(new Error('ICS 파일만 업로드할 수 있습니다'));
    }
  },
});

router.use(authenticate);

router.post('/ics', upload.single('file'), async (req: AuthRequest, res: Response) => {
  try {
    if (!req.file) {
      res.status(400).json({ error: '파일이 선택되지 않았습니다' });
      return;
    }

    const result = await icsImportService.importIcs(
      req.userId!,
      req.file.buffer,
      req.file.originalname,
    );

    res.json(result);
  } catch (err: any) {
    // Handle multer errors
    if (err.code === 'LIMIT_FILE_SIZE') {
      res.status(400).json({ error: '파일 크기는 10MB를 초과할 수 없습니다' });
      return;
    }
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

export default router;
