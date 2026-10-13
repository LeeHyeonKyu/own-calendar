-- DropForeignKey
ALTER TABLE "RoutineCompletion" DROP CONSTRAINT IF EXISTS "RoutineCompletion_routineId_fkey";

-- DropForeignKey
ALTER TABLE "Routine" DROP CONSTRAINT IF EXISTS "Routine_groupId_fkey";

-- DropForeignKey
ALTER TABLE "Routine" DROP CONSTRAINT IF EXISTS "Routine_userId_fkey";

-- DropForeignKey
ALTER TABLE "RoutineGroup" DROP CONSTRAINT IF EXISTS "RoutineGroup_userId_fkey";

-- DropTable
DROP TABLE IF EXISTS "RoutineCompletion";

-- DropTable
DROP TABLE IF EXISTS "Routine";

-- DropTable
DROP TABLE IF EXISTS "RoutineGroup";
