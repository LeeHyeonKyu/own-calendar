import app from './app';
import { config } from './config';
import { fcmService } from './services/fcm.service';
import { alarmService } from './services/alarm.service';

app.listen(config.port, () => {
  console.log(`Server running on port ${config.port}`);

  // Initialize Firebase and alarm scheduler
  fcmService.init();
  alarmService.start();
});
