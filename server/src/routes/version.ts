import { Router, Request, Response } from 'express';

const router = Router();

router.get('/', (_req: Request, res: Response) => {
  res.json({
    latestVersion: process.env.APP_LATEST_VERSION || null,
    downloadUrl: process.env.APP_DOWNLOAD_URL || 'https://github.com/LeeHyeonKyu/own-calendar/releases/latest',
    altStoreSource: 'https://raw.githubusercontent.com/LeeHyeonKyu/own-calendar/main/altstore/apps.json',
  });
});

export default router;
