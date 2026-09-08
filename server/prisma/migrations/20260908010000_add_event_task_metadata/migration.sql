-- AlterTable
ALTER TABLE "Event" ADD COLUMN     "location" TEXT,
ADD COLUMN     "notes" TEXT,
ADD COLUMN     "attendees" JSONB;

-- AlterTable
ALTER TABLE "Task" ADD COLUMN     "location" TEXT,
ADD COLUMN     "notes" TEXT,
ADD COLUMN     "attendees" JSONB,
ADD COLUMN     "metaInherited" BOOLEAN NOT NULL DEFAULT false;
