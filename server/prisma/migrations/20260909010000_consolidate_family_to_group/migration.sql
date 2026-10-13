-- Consolidate FamilyGroup/FamilyMembership into Group/GroupMembership
-- FamilyGroup role enum was already renamed to GroupRole in 20260908010000_group_follow_invite

-- 1. Create Group table (mirrors FamilyGroup structure)
CREATE TABLE IF NOT EXISTS "Group" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "type" TEXT NOT NULL DEFAULT '가족',
    "createdById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Group_pkey" PRIMARY KEY ("id")
);

-- 2. Create GroupMembership table (mirrors FamilyMembership structure)
CREATE TABLE IF NOT EXISTS "GroupMembership" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "groupId" TEXT NOT NULL,
    "role" "GroupRole" NOT NULL DEFAULT 'MEMBER',
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "GroupMembership_pkey" PRIMARY KEY ("id")
);

-- 3. Add groupId column to Calendar (if not already present)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'Calendar' AND column_name = 'groupId'
    ) THEN
        ALTER TABLE "Calendar" ADD COLUMN "groupId" TEXT;
    END IF;
END $$;

-- 4. Create indexes
CREATE UNIQUE INDEX IF NOT EXISTS "Group_code_key" ON "Group"("code");
CREATE UNIQUE INDEX IF NOT EXISTS "GroupMembership_userId_groupId_key" ON "GroupMembership"("userId", "groupId");
CREATE UNIQUE INDEX IF NOT EXISTS "Calendar_groupId_key" ON "Calendar"("groupId");

-- 5. Add foreign keys (skip if already exist)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'Group_createdById_fkey') THEN
        ALTER TABLE "Group" ADD CONSTRAINT "Group_createdById_fkey"
            FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'GroupMembership_userId_fkey') THEN
        ALTER TABLE "GroupMembership" ADD CONSTRAINT "GroupMembership_userId_fkey"
            FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'GroupMembership_groupId_fkey') THEN
        ALTER TABLE "GroupMembership" ADD CONSTRAINT "GroupMembership_groupId_fkey"
            FOREIGN KEY ("groupId") REFERENCES "Group"("id") ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'Calendar_groupId_fkey') THEN
        ALTER TABLE "Calendar" ADD CONSTRAINT "Calendar_groupId_fkey"
            FOREIGN KEY ("groupId") REFERENCES "Group"("id") ON DELETE SET NULL ON UPDATE CASCADE;
    END IF;
END $$;

-- 6. Copy FamilyGroup data → Group (skip duplicates by code)
INSERT INTO "Group" ("id", "name", "code", "type", "createdById", "createdAt", "updatedAt")
SELECT "id", "name", "code", "type", "createdById", "createdAt", "updatedAt"
FROM "FamilyGroup"
ON CONFLICT ("code") DO NOTHING;

-- 7. Copy FamilyMembership data → GroupMembership (skip duplicates by userId+groupId)
INSERT INTO "GroupMembership" ("id", "userId", "groupId", "role", "joinedAt")
SELECT fm."id", fm."userId", fm."familyGroupId", fm."role"::text::"GroupRole", fm."joinedAt"
FROM "FamilyMembership" fm
WHERE EXISTS (SELECT 1 FROM "Group" g WHERE g."id" = fm."familyGroupId")
ON CONFLICT ("userId", "groupId") DO NOTHING;

-- 8. Update Calendar.groupId from Calendar.familyGroupId (only where groupId is null)
UPDATE "Calendar"
SET "groupId" = "familyGroupId"
WHERE "familyGroupId" IS NOT NULL
  AND "groupId" IS NULL
  AND EXISTS (SELECT 1 FROM "Group" g WHERE g."id" = "Calendar"."familyGroupId");
