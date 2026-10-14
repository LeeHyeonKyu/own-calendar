import app from './app';
import { config } from './config';
import { fcmService } from './services/fcm.service';
import { alarmService } from './services/alarm.service';
import { googleSyncService } from './services/google-sync.service';

app.listen(config.port, () => {
  console.log(`Server running on port ${config.port}`);

  fcmService.init();
  alarmService.start();
  googleSyncService.startAutoSync();
});
