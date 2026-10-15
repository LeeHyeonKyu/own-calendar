import { google } from 'googleapis';
import { config } from '../config';
import prisma from '../lib/prisma';

function createOAuth2Client() {
  return new google.auth.OAuth2(
    config.google.clientId,
    config.google.clientSecret,
    config.google.redirectUri
  );
}

export const googleSyncService = {
  getAuthUrl(userId: string): string {
    const oauth2Client = createOAuth2Client();
    return oauth2Client.generateAuthUrl({
      access_type: 'offline',
      prompt: 'consent',
      scope: ['https://www.googleapis.com/auth/calendar'],
      state: userId,
    });
  },

  async handleCallback(code: string, userId: string) {
    const oauth2Client = createOAuth2Client();
    const { tokens } = await oauth2Client.getToken(code);
    oauth2Client.setCredentials(tokens);

    const calendarApi = google.calendar({ version: 'v3', auth: oauth2Client });
    const calendarList = await calendarApi.calendarList.list();
    const primaryCal = calendarList.data.items?.find(c => c.primary) || calendarList.data.items?.[0];

    if (!primaryCal || !primaryCal.id) {
      const error = new Error('No Google Calendar found');
      (error as any).statusCode = 404;
      throw error;
    }

    const existing = await prisma.externalCalendarConnection.findFirst({
      where: { provider: 'google', externalId: primaryCal.id, userId },
      include: { calendar: true },
    });

    if (existing) {
      await prisma.externalCalendarConnection.update({
        where: { id: existing.id },
        data: {
          accessToken: tokens.access_token!,
          refreshToken: tokens.refresh_token || existing.refreshToken,
          tokenExpiry: tokens.expiry_date ? new Date(tokens.expiry_date) : null,
          syncToken: null,
          syncStatus: 'ok',
          lastSyncError: null,
          consecutiveFailures: 0,
        },
      });
      return { calendar: existing.calendar, connection: { id: existing.id, provider: existing.provider } };
    }

    const calendar = await prisma.calendar.create({
      data: {
        name: primaryCal.summary || 'Google Calendar',
        color: primaryCal.backgroundColor || '#4285F4',
        type: 'EXTERNAL',
        ownerId: userId,
      },
    });

    const connection = await prisma.externalCalendarConnection.create({
      data: {
        provider: 'google',
        externalId: primaryCal.id,
        accessToken: tokens.access_token!,
        refreshToken: tokens.refresh_token!,
        tokenExpiry: tokens.expiry_date ? new Date(tokens.expiry_date) : null,
        calendarId: calendar.id,
        userId,
      },
    });

    return { calendar, connection: { id: connection.id, provider: connection.provider } };
  },

  async pullEvents(userId: string, connectionId: string) {
    const connection = await prisma.externalCalendarConnection.findFirst({
      where: { id: connectionId, userId },
    });
    if (!connection) {
      const error = new Error('Connection not found');
      (error as any).statusCode = 404;
      throw error;
    }

    const oauth2Client = createOAuth2Client();
    oauth2Client.setCredentials({
      access_token: connection.accessToken,
      refresh_token: connection.refreshToken,
    });

    // Refresh token if needed
    const tokenInfo = await oauth2Client.getAccessToken();
    if (tokenInfo.token !== connection.accessToken) {
      await prisma.externalCalendarConnection.update({
        where: { id: connection.id },
        data: {
          accessToken: tokenInfo.token!,
          tokenExpiry: oauth2Client.credentials.expiry_date
            ? new Date(oauth2Client.credentials.expiry_date)
            : null,
        },
      });
    }

    const calendarApi = google.calendar({ version: 'v3', auth: oauth2Client });

    const params: any = {
      calendarId: connection.externalId,
      singleEvents: true,
      orderBy: 'startTime',
    };

    if (connection.syncToken) {
      params.syncToken = connection.syncToken;
    } else {
      const threeMonthsAgo = new Date();
      threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);
      params.timeMin = threeMonthsAgo.toISOString();
      const sixMonthsAhead = new Date();
      sixMonthsAhead.setMonth(sixMonthsAhead.getMonth() + 6);
      params.timeMax = sixMonthsAhead.toISOString();
    }

    let allEvents: any[] = [];
    let pageToken: string | undefined;
    let newSyncToken: string | undefined;

    do {
      const response = await calendarApi.events.list({
        ...params,
        pageToken,
      });

      if (response.data.items) {
        allEvents = allEvents.concat(response.data.items);
      }
      pageToken = response.data.nextPageToken || undefined;
      newSyncToken = response.data.nextSyncToken || undefined;
    } while (pageToken);

    let created = 0, updated = 0, deleted = 0;

    for (const gEvent of allEvents) {
      if (!gEvent.id) continue;

      // Skip non-event types (working location, focus time, out of office)
      const eventType = gEvent.eventType || 'default';
      if (eventType !== 'default' && eventType !== 'birthday') continue;

      if (gEvent.status === 'cancelled') {
        const result = await prisma.event.deleteMany({
          where: { externalId: gEvent.id, calendarId: connection.calendarId },
        });
        deleted += result.count;
        continue;
      }

      const startTime = gEvent.start?.dateTime
        ? new Date(gEvent.start.dateTime)
        : gEvent.start?.date
          ? new Date(gEvent.start.date)
          : null;
      const endTime = gEvent.end?.dateTime
        ? new Date(gEvent.end.dateTime)
        : gEvent.end?.date
          ? new Date(gEvent.end.date)
          : null;

      if (!startTime || !endTime) continue;

      const isAllDay = !gEvent.start?.dateTime;

      const existing = await prisma.event.findFirst({
        where: { externalId: gEvent.id, calendarId: connection.calendarId },
      });

      const location = gEvent.location || null;
      const attendees = gEvent.attendees
        ? gEvent.attendees.map((a: any) => ({ name: a.displayName || null, email: a.email || null }))
        : null;

      if (existing) {
        await prisma.event.update({
          where: { id: existing.id },
          data: {
            title: gEvent.summary || '(제목 없음)',
            description: gEvent.description || null,
            startTime,
            endTime,
            isAllDay,
            location,
            attendees: attendees ?? undefined,
          },
        });
        updated++;
      } else {
        await prisma.event.create({
          data: {
            title: gEvent.summary || '(제목 없음)',
            description: gEvent.description || null,
            startTime,
            endTime,
            isAllDay,
            location,
            attendees: attendees ?? undefined,
            calendarId: connection.calendarId,
            createdById: userId,
            externalId: gEvent.id,
          },
        });
        created++;
      }
    }

    if (newSyncToken) {
      await prisma.externalCalendarConnection.update({
        where: { id: connection.id },
        data: { syncToken: newSyncToken, lastSyncedAt: new Date() },
      });
    }

    return { created, updated, deleted };
  },

  async pushEvent(userId: string, eventId: string) {
    const event = await prisma.event.findFirst({
      where: { id: eventId, createdById: userId },
      include: { calendar: { include: { externalConnection: true } } },
    });

    if (!event) {
      const error = new Error('Event not found');
      (error as any).statusCode = 404;
      throw error;
    }
    if (!event.calendar.externalConnection) {
      const error = new Error('Calendar is not connected to Google');
      (error as any).statusCode = 400;
      throw error;
    }

    const connection = event.calendar.externalConnection;
    const oauth2Client = createOAuth2Client();
    oauth2Client.setCredentials({
      access_token: connection.accessToken,
      refresh_token: connection.refreshToken,
    });

    const calendarApi = google.calendar({ version: 'v3', auth: oauth2Client });

    const gEventData: any = {
      summary: event.title,
      description: event.description || undefined,
      start: event.isAllDay
        ? { date: event.startTime.toISOString().split('T')[0] }
        : { dateTime: event.startTime.toISOString() },
      end: event.isAllDay
        ? { date: event.endTime.toISOString().split('T')[0] }
        : { dateTime: event.endTime.toISOString() },
    };

    if (event.externalId) {
      await calendarApi.events.update({
        calendarId: connection.externalId,
        eventId: event.externalId,
        requestBody: gEventData,
      });
    } else {
      const result = await calendarApi.events.insert({
        calendarId: connection.externalId,
        requestBody: gEventData,
      });
      await prisma.event.update({
        where: { id: event.id },
        data: { externalId: result.data.id },
      });
    }

    return { success: true };
  },

  async deleteExternalEvent(userId: string, eventId: string) {
    const event = await prisma.event.findFirst({
      where: { id: eventId, createdById: userId },
      include: { calendar: { include: { externalConnection: true } } },
    });

    if (!event?.externalId || !event.calendar.externalConnection) return;

    const connection = event.calendar.externalConnection;
    const oauth2Client = createOAuth2Client();
    oauth2Client.setCredentials({
      access_token: connection.accessToken,
      refresh_token: connection.refreshToken,
    });

    const calendarApi = google.calendar({ version: 'v3', auth: oauth2Client });

    try {
      await calendarApi.events.delete({
        calendarId: connection.externalId,
        eventId: event.externalId,
      });
    } catch {
      // Ignore if already deleted on Google side
    }
  },

  async listConnections(userId: string) {
    return prisma.externalCalendarConnection.findMany({
      where: { userId },
      select: {
        id: true,
        provider: true,
        externalId: true,
        lastSyncedAt: true,
        syncStatus: true,
        lastSyncError: true,
        consecutiveFailures: true,
        calendar: { select: { id: true, name: true, color: true } },
      },
    });
  },

  async disconnect(userId: string, connectionId: string) {
    const connection = await prisma.externalCalendarConnection.findFirst({
      where: { id: connectionId, userId },
    });
    if (!connection) {
      const error = new Error('Connection not found');
      (error as any).statusCode = 404;
      throw error;
    }

    await prisma.externalCalendarConnection.delete({ where: { id: connection.id } });
    await prisma.calendar.delete({ where: { id: connection.calendarId } });

    return { success: true };
  },

  startAutoSync(): NodeJS.Timeout {
    const intervalMs = config.googleSyncIntervalMs;
    console.log(`[Google Sync] Auto-sync started (interval: ${intervalMs / 1000}s)`);

    const run = async () => {
      const connections = await prisma.externalCalendarConnection.findMany({
        where: { provider: 'google' },
        select: { userId: true },
        distinct: ['userId'],
      });
      if (connections.length === 0) return;

      console.log(`[Google Sync] Syncing ${connections.length} user(s)...`);
      for (const { userId } of connections) {
        try {
          await googleSyncService.autoSync(userId);
        } catch (err: any) {
          console.error(`[Google Sync] User ${userId} failed: ${err.message}`);
        }
      }
      console.log('[Google Sync] Cycle complete');
    };

    run();
    return setInterval(run, intervalMs);
  },

  async autoSync(userId: string) {
    const connections = await prisma.externalCalendarConnection.findMany({
      where: { userId, provider: 'google' },
    });

    let totalCreated = 0;
    let totalUpdated = 0;
    let totalDeleted = 0;

    for (const conn of connections) {
      try {
        const result = await googleSyncService.pullEvents(userId, conn.id);
        totalCreated += result.created;
        totalUpdated += result.updated;
        totalDeleted += result.deleted;
        await prisma.externalCalendarConnection.update({
          where: { id: conn.id },
          data: { syncStatus: 'ok', lastSyncError: null, consecutiveFailures: 0 },
        });
      } catch (err: any) {
        const statusCode = err?.response?.status || err?.statusCode || 0;
        const errMsg = err.message || String(err);
        const isTokenError = statusCode === 401 || statusCode === 403
          || errMsg.includes('invalid_grant') || errMsg.includes('Token has been expired or revoked');
        const syncStatus = isTokenError ? 'token_expired' : 'error';
        await prisma.externalCalendarConnection.update({
          where: { id: conn.id },
          data: {
            syncStatus,
            lastSyncError: err.message || String(err),
            consecutiveFailures: { increment: 1 },
          },
        }).catch(() => {});
      }
    }

    return { created: totalCreated, updated: totalUpdated, deleted: totalDeleted, synced: connections.length };
  },
};
