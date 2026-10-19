import { Router, Response, NextFunction } from 'express';
import crypto from 'crypto';
import { authenticate } from '../middleware/auth';
import { AuthRequest } from '../types';
import { eventService } from '../services/event.service';
import { taskService } from '../services/task.service';
import { holidayService } from '../services/holiday.service';
import prisma from '../lib/prisma';
import { monthlyQuerySchema } from '../schemas/widget.schema';

const KST_OFFSET_MS = 9 * 60 * 60 * 1000;
function toKST(date: Date): Date {
  return new Date(date.getTime() + KST_OFFSET_MS);
}
function toUTC(kstDate: Date): Date {
  return new Date(kstDate.getTime() - KST_OFFSET_MS);
}

const router = Router();

async function widgetAuth(req: AuthRequest, res: Response, next: NextFunction) {
  const key = req.query.key as string;
  if (key) {
    const widgetToken = await prisma.widgetToken.findUnique({ where: { token: key } });
    if (widgetToken) {
      req.userId = widgetToken.userId;
      return next();
    }
    res.status(401).json({ error: 'Invalid widget key' });
    return;
  }
  return authenticate(req, res, next);
}

router.post('/key', authenticate, async (req: AuthRequest, res: Response) => {
  try {
    await prisma.widgetToken.deleteMany({ where: { userId: req.userId! } });
    const token = crypto.randomBytes(32).toString('hex');
    await prisma.widgetToken.create({ data: { userId: req.userId!, token } });
    res.json({ key: token });
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.get('/today', widgetAuth, async (req: AuthRequest, res: Response) => {
  try {
    const now = new Date();
    const nowKST = toKST(now);
    const todayStartKST = new Date(Date.UTC(nowKST.getUTCFullYear(), nowKST.getUTCMonth(), nowKST.getUTCDate()));
    const todayStart = toUTC(todayStartKST);
    const todayEnd = new Date(todayStart.getTime() + 86400000);

    const [events, tasks] = await Promise.all([
      eventService.list(req.userId!, {
        start: todayStart.toISOString(),
        end: todayEnd.toISOString(),
      }),
      taskService.list(req.userId!, {
        start: todayStart.toISOString(),
        end: todayEnd.toISOString(),
        includeDone: 'true',
      }),
    ]);

    const widgetEvents = events
      .sort((a: any, b: any) => new Date(a.startTime).getTime() - new Date(b.startTime).getTime())
      .slice(0, 8)
      .map((e: any) => {
        const start = new Date(e.startTime);
        return {
          title: e.title,
          time: e.isAllDay
            ? '종일'
            : `${start.getHours().toString().padStart(2, '0')}:${start.getMinutes().toString().padStart(2, '0')}`,
          category: e.category,
        };
      });

    const widgetTasks = tasks
      .sort((a: any, b: any) => {
        const aOverdue = a.dueDate && new Date(a.dueDate) < now && a.status !== 'DONE';
        const bOverdue = b.dueDate && new Date(b.dueDate) < now && b.status !== 'DONE';
        if (aOverdue && !bOverdue) return -1;
        if (!aOverdue && bOverdue) return 1;
        const aTime = a.scheduledDate || a.dueDate;
        const bTime = b.scheduledDate || b.dueDate;
        if (!aTime && !bTime) return 0;
        if (!aTime) return 1;
        if (!bTime) return -1;
        return new Date(aTime).getTime() - new Date(bTime).getTime();
      })
      .slice(0, 8)
      .map((t: any) => {
        const dueDate = t.dueDate ? new Date(t.dueDate) : null;
        const scheduledDate = t.scheduledDate ? new Date(t.scheduledDate) : null;
        const timeDate = scheduledDate || dueDate;
        return {
          title: t.title,
          status: t.status,
          priority: t.priority,
          time: timeDate
            ? `${timeDate.getHours().toString().padStart(2, '0')}:${timeDate.getMinutes().toString().padStart(2, '0')}`
            : '',
          dueDate: t.dueDate || '',
          eventTitle: t.event?.title || '',
          isOverdue: !!(dueDate && dueDate < now && t.status !== 'DONE'),
        };
      });

    const doneCount = tasks.filter((t: any) => t.status === 'DONE').length;

    res.json({
      events: widgetEvents,
      tasks: widgetTasks,
      taskDone: doneCount,
      taskTotal: tasks.length,
    });
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

router.get('/monthly', widgetAuth, async (req: AuthRequest, res: Response) => {
  try {
    const parsed = monthlyQuerySchema.safeParse(req.query);
    if (!parsed.success) {
      res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten() });
      return;
    }

    const { year, month } = parsed.data;
    const now = new Date();
    const monthStartKST = new Date(Date.UTC(year, month - 1, 1));
    const monthStart = toUTC(monthStartKST);
    const monthEndKST = new Date(Date.UTC(year, month, 1));
    const monthEnd = toUTC(monthEndKST);

    const [events, tasks] = await Promise.all([
      eventService.list(req.userId!, {
        start: monthStart.toISOString(),
        end: monthEnd.toISOString(),
      }),
      taskService.list(req.userId!, {
        start: monthStart.toISOString(),
        end: monthEnd.toISOString(),
        includeDone: 'true',
      }),
    ]);

    const eventsMap: Record<string, any[]> = {};
    for (const event of events as any[]) {
      const start = new Date(event.startTime);
      const end = new Date(event.endTime);
      const clampedStart = start < monthStart ? monthStart : start;
      const clampedEnd = end > monthEnd ? monthEnd : end;

      // Convert to KST for day-key generation
      const kstClampedStart = toKST(clampedStart);
      const kstClampedEnd = toKST(clampedEnd);

      for (
        let d = new Date(Date.UTC(kstClampedStart.getUTCFullYear(), kstClampedStart.getUTCMonth(), kstClampedStart.getUTCDate()));
        d < kstClampedEnd;
        d = new Date(d.getTime() + 86400000)
      ) {
        if (d.getUTCMonth() !== month - 1) continue;
        const dayKey = d.getUTCDate().toString();
        if (!eventsMap[dayKey]) eventsMap[dayKey] = [];
        if (eventsMap[dayKey].some((e: any) => e.id === event.id)) continue;
        const eventStart = new Date(event.startTime);
        eventsMap[dayKey].push({
          id: event.id,
          title: event.title,
          time: event.isAllDay
            ? '종일'
            : `${eventStart.getHours().toString().padStart(2, '0')}:${eventStart.getMinutes().toString().padStart(2, '0')}`,
          endTime: event.isAllDay
            ? null
            : (() => {
                const e = new Date(event.endTime);
                return `${e.getHours().toString().padStart(2, '0')}:${e.getMinutes().toString().padStart(2, '0')}`;
              })(),
          category: event.category,
          isAllDay: event.isAllDay || false,
        });
      }
    }

    const taskDays: Record<string, boolean> = {};
    const tasksMap: Record<string, any[]> = {};
    for (const task of tasks as any[]) {
      const date = task.scheduledDate ? new Date(task.scheduledDate) : task.dueDate ? new Date(task.dueDate) : null;
      if (!date) continue;
      const kstDate = toKST(date);
      if (kstDate.getUTCMonth() !== month - 1 || kstDate.getUTCFullYear() !== year) continue;
      const dayKey = kstDate.getUTCDate().toString();
      taskDays[dayKey] = true;
      if (!tasksMap[dayKey]) tasksMap[dayKey] = [];
      const scheduledTime = task.scheduledTime || '';
      tasksMap[dayKey].push({
        id: task.id,
        title: task.title,
        status: task.status,
        priority: task.priority,
        time: scheduledTime,
        isOverdue: !!(task.dueDate && new Date(task.dueDate) < now && task.status !== 'DONE'),
      });
    }

    const holidays = await holidayService.getHolidays(req.userId!, year, month);
    const holidaysMap: Record<string, string> = {};
    for (const h of holidays as any[]) {
      const hDate = new Date(h.date);
      holidaysMap[hDate.getDate().toString()] = h.name;
    }

    res.json({
      year,
      month,
      events: eventsMap,
      taskDays,
      tasks: tasksMap,
      holidays: holidaysMap,
    });
  } catch (err: any) {
    const status = err.statusCode || 500;
    res.status(status).json({ error: err.message });
  }
});

export default router;
