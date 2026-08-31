-- CreateEnum
CREATE TYPE "RecurrenceType" AS ENUM ('NONE', 'DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY');

-- AlterTable
ALTER TABLE "Event" ADD COLUMN "recurrenceType" "RecurrenceType" NOT NULL DEFAULT 'NONE';
ALTER TABLE "Event" ADD COLUMN "recurrenceEnd" TIMESTAMP(3);
