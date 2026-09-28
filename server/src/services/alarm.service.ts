import prisma from '../lib/prisma';
import { fcmService } from './fcm.service';
import { logger } from '../lib/logger';

const CHECK_INTERVAL_MS = 60 * 1000; // 60 seconds
const WINDOW_MS = 90 * 1000; // 90-second lookahead to avoid missing events between checks

// Track sent notifications to avoid duplicates (eventId:startTime)
const sentNotifications = new Set<string>();

// Periodically prune old entries to prevent unbounded memory growth
const PRUNE_INTERVAL_MS = 60 * 60 * 1000; // 1 hour

function pruneOldNotifications() {
  // Simple strategy: clear everything older than the last check window.
  // Since we only look ahead 90 seconds, clearing the set hourly is safe.
  if (sentNotifications.size > 10000) {
    sentNotifications.clear();
  }
}

async function checkUpcomingAlarms() {
  if (!fcmService.isReady()) return;

  const now = new Date();
  const windowEnd = new Date(now.getTime() + WINDOW_MS);

  try {
    // Find all events that might need a notification:
    // - startTime is in the future (or very near past for edge cases)
    // - We need events where startTime minus reminderMinutes falls within [now, windowEnd]
    //
    // Since the reminder offset varies per event/user, we fetch events starting
    // within a generous window and filter in code.
    const maxReminderMinutes = 60; // 1 hour max lookahead
    const fetchWindowEnd = new Date(windowEnd.getTime() + maxReminderMinutes * 60 * 1000);

    const events = await prisma.event.findMany({
      where: {
        startTime: {
          gte: now,
          lte: fetchWindowEnd,
        },
        // Skip events with reminderMinutes = -1 (alarm off)
        NOT: {
          reminderMinutes: -1,
        },
      },
      include: {
        createdBy: {
          select: {
            id: true,
            defaultReminderMinutes: true,
          },
        },
      },
    });

    for (const event of events) {
      // Determine effective reminder minutes
      const reminderMinutes = event.reminderMinutes ?? event.createdBy.defaultReminderMinutes;

      // Skip if alarm is off
      if (reminderMinutes === -1) continue;

      // Calculate when the notification should fire
      const notifyAt = new Date(event.startTime.getTime() - reminderMinutes * 60 * 1000);

      // Check if notifyAt falls within [now, windowEnd]
      if (notifyAt < now || notifyAt > windowEnd) continue;

      // Check for duplicate
      const dedupKey = `${event.id}:${event.startTime.toISOString()}`;
      if (sentNotifications.has(dedupKey)) continue;

      // Get user's device tokens
      const deviceTokens = await prisma.deviceToken.findMany({
        where: { userId: event.createdBy.id },
      });

      if (deviceTokens.length === 0) continue;

      // Format notification
      const title = '일정 알림';
      const body = reminderMinutes === 0
        ? `${event.title} - 지금 시작`
        : `${event.title} - ${reminderMinutes}분 후 시작`;

      const data = { eventId: event.id };

      // Send to all device tokens
      const invalidTokenIds: string[] = [];
      for (const dt of deviceTokens) {
        const success = await fcmService.sendNotification(dt.token, title, body, data);
        if (!success) {
          invalidTokenIds.push(dt.id);
        }
      }

      // Clean up invalid tokens
      if (invalidTokenIds.length > 0) {
        await prisma.deviceToken.deleteMany({
          where: { id: { in: invalidTokenIds } },
        });
      }

      // Mark as sent
      sentNotifications.add(dedupKey);
    }
  } catch (err) {
    logger.error('[Alarm] Error checking upcoming alarms:', err);
  }
}

let intervalId: ReturnType<typeof setInterval> | null = null;
let pruneIntervalId: ReturnType<typeof setInterval> | null = null;

export const alarmService = {
  start() {
    if (!fcmService.isReady()) {
      logger.info('[Alarm] FCM not ready — alarm scheduler disabled');
      return;
    }

    logger.info('[Alarm] Starting alarm scheduler (check every 60s)');
    intervalId = setInterval(checkUpcomingAlarms, CHECK_INTERVAL_MS);
    pruneIntervalId = setInterval(pruneOldNotifications, PRUNE_INTERVAL_MS);

    // Run an initial check immediately
    checkUpcomingAlarms();
  },

  stop() {
    if (intervalId) {
      clearInterval(intervalId);
      intervalId = null;
    }
    if (pruneIntervalId) {
      clearInterval(pruneIntervalId);
      pruneIntervalId = null;
    }
  },
};
