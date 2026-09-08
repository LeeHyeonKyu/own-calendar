-- AlterTable
ALTER TABLE "Event" ADD COLUMN     "rrule" TEXT;

-- AlterTable
ALTER TABLE "Task" ADD COLUMN     "rrule" TEXT;

-- CreateTable
CREATE TABLE "RecurrenceException" (
    "id" TEXT NOT NULL,
    "masterEventId" TEXT,
    "masterTaskId" TEXT,
    "originalDate" TIMESTAMP(3) NOT NULL,
    "isDeleted" BOOLEAN NOT NULL DEFAULT false,
    "title" TEXT,
    "description" TEXT,
    "startTime" TIMESTAMP(3),
    "endTime" TIMESTAMP(3),
    "isAllDay" BOOLEAN,
    "status" "TaskStatus",
    "completedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "RecurrenceException_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "RecurrenceException_masterEventId_idx" ON "RecurrenceException"("masterEventId");

-- CreateIndex
CREATE INDEX "RecurrenceException_masterTaskId_idx" ON "RecurrenceException"("masterTaskId");

-- CreateIndex
CREATE UNIQUE INDEX "RecurrenceException_masterEventId_originalDate_key" ON "RecurrenceException"("masterEventId", "originalDate");

-- CreateIndex
CREATE UNIQUE INDEX "RecurrenceException_masterTaskId_originalDate_key" ON "RecurrenceException"("masterTaskId", "originalDate");

-- AddForeignKey
ALTER TABLE "RecurrenceException" ADD CONSTRAINT "RecurrenceException_masterEventId_fkey" FOREIGN KEY ("masterEventId") REFERENCES "Event"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RecurrenceException" ADD CONSTRAINT "RecurrenceException_masterTaskId_fkey" FOREIGN KEY ("masterTaskId") REFERENCES "Task"("id") ON DELETE CASCADE ON UPDATE CASCADE;
