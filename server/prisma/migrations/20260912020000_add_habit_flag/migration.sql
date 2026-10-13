-- AlterTable
ALTER TABLE "Task" ADD COLUMN "isHabit" BOOLEAN NOT NULL DEFAULT false;

-- CreateIndex
CREATE INDEX "Task_isHabit_idx" ON "Task"("isHabit") WHERE "isHabit" = true;
