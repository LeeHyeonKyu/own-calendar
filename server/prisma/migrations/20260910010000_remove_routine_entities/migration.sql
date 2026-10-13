-- DropForeignKey
ALTER TABLE "RoutineCompletion" DROP CONSTRAINT "RoutineCompletion_routineId_fkey";

-- DropForeignKey
ALTER TABLE "Routine" DROP CONSTRAINT "Routine_groupId_fkey";

-- DropForeignKey
ALTER TABLE "Routine" DROP CONSTRAINT "Routine_userId_fkey";

-- DropForeignKey
ALTER TABLE "RoutineGroup" DROP CONSTRAINT "RoutineGroup_userId_fkey";

-- DropTable
DROP TABLE "RoutineCompletion";

-- DropTable
DROP TABLE "Routine";

-- DropTable
DROP TABLE "RoutineGroup";
