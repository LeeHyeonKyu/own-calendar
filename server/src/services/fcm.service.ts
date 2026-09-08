import { initializeApp, cert, type App } from 'firebase-admin/app';
import { getMessaging, type Messaging } from 'firebase-admin/messaging';
import { config } from '../config';

let firebaseApp: App | null = null;
let messaging: Messaging | null = null;

function initializeFirebase(): boolean {
  if (firebaseApp) return true;

  const json = config.firebase.serviceAccountJson;
  if (!json) {
    console.warn('[FCM] FIREBASE_SERVICE_ACCOUNT_JSON not set — push notifications disabled');
    return false;
  }

  try {
    const serviceAccount = JSON.parse(json);
    firebaseApp = initializeApp({
      credential: cert(serviceAccount),
    });
    messaging = getMessaging(firebaseApp);
    console.log('[FCM] Firebase Admin SDK initialized');
    return true;
  } catch (err) {
    console.error('[FCM] Failed to initialize Firebase Admin SDK:', err);
    return false;
  }
}

export const fcmService = {
  init(): boolean {
    return initializeFirebase();
  },

  isReady(): boolean {
    return messaging !== null;
  },

  async sendNotification(
    token: string,
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<boolean> {
    if (!messaging) return false;

    try {
      await messaging.send({
        token,
        notification: { title, body },
        data: data || {},
        android: {
          priority: 'high' as const,
          notification: { channelId: 'event_reminders' },
        },
        apns: {
          payload: {
            aps: {
              alert: { title, body },
              sound: 'default',
            },
          },
        },
      });
      return true;
    } catch (err: any) {
      // Token is no longer valid — caller should handle cleanup
      if (
        err.code === 'messaging/registration-token-not-registered' ||
        err.code === 'messaging/invalid-registration-token'
      ) {
        console.warn(`[FCM] Invalid token: ${token.substring(0, 20)}...`);
        return false;
      }
      console.error('[FCM] Failed to send notification:', err.message);
      return false;
    }
  },
};
