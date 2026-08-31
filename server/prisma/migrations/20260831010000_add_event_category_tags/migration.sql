-- CreateEnum
CREATE TYPE "EventCategory" AS ENUM ('WORK', 'PERSONAL', 'FAMILY', 'HEALTH', 'SOCIAL', 'FINANCE', 'OTHER');

-- AlterTable
ALTER TABLE "Event" ADD COLUMN "category" "EventCategory" NOT NULL DEFAULT 'PERSONAL',
ADD COLUMN "tags" TEXT[] DEFAULT ARRAY[]::TEXT[];
