-- AlterTable
ALTER TABLE "Task" ADD COLUMN "checklist" JSONB;

-- AlterTable
ALTER TABLE "RecurrenceException" ADD COLUMN "checklist" JSONB;
