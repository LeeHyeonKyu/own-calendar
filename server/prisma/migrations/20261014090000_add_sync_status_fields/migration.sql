-- AlterTable
ALTER TABLE "ExternalCalendarConnection" ADD COLUMN "syncStatus" TEXT NOT NULL DEFAULT 'ok',
ADD COLUMN "lastSyncError" TEXT,
ADD COLUMN "consecutiveFailures" INTEGER NOT NULL DEFAULT 0;
