#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────
# Own Calendar — Cloud DB Migration
# 사용법:
#   ./scripts/migrate-to-cloud.sh                        # 대화형 마이그레이션
#   ./scripts/migrate-to-cloud.sh --target-url <url>     # URL 직접 지정
#   ./scripts/migrate-to-cloud.sh --dry-run              # 실제 데이터 전송 없이 테스트
# ──────────────────────────────────────────────────

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/server/docker-compose.yml"
BACKUP_DIR="$PROJECT_ROOT/backups"
TARGET_URL=""
DRY_RUN=false

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

step=0
total_steps=6

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; exit 1; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
info() { step=$((step+1)); echo -e "\n${CYAN}[$step/$total_steps]${NC} $1"; }

# ──────────────────────────────────────────────────
# Parse args
# ──────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --target-url) TARGET_URL="$2"; shift 2 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--target-url <url>] [--dry-run]"
      echo ""
      echo "Options:"
      echo "  --target-url URL  Cloud database URL (e.g., postgresql://user:pass@host:5432/db)"
      echo "  --dry-run         Test connection and backup only, no data transfer"
      echo ""
      echo "Supported cloud providers:"
      echo "  - Supabase:  postgresql://postgres.[ref]:[pass]@aws-0-[region].pooler.supabase.com:6543/postgres"
      echo "  - Neon:      postgresql://[user]:[pass]@[endpoint].neon.tech/[db]?sslmode=require"
      echo "  - Railway:   postgresql://postgres:[pass]@[host].railway.app:5432/railway"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Own Calendar — Cloud DB Migration${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo ""

if [[ "$DRY_RUN" == true ]]; then
  echo -e "  ${YELLOW}DRY RUN 모드 — 실제 데이터 전송 없음${NC}"
  echo ""
fi

# ──────────────────────────────────────────────────
# Step 1: Pre-flight checks
# ──────────────────────────────────────────────────
info "사전 점검..."

if ! command -v docker &>/dev/null; then
  fail "docker가 설치되어 있지 않습니다"
fi

if ! command -v psql &>/dev/null; then
  fail "psql이 설치되어 있지 않습니다. 'brew install libpq'로 설치하세요."
fi

if ! docker compose -f "$COMPOSE_FILE" ps --status running postgres 2>/dev/null | grep -q postgres; then
  fail "로컬 PostgreSQL 컨테이너가 실행 중이 아닙니다"
fi

ok "docker, psql 사용 가능"
ok "로컬 PostgreSQL 컨테이너 실행 중"

# ──────────────────────────────────────────────────
# Step 2: Get target URL
# ──────────────────────────────────────────────────
info "클라우드 DB 연결 정보 확인..."

if [[ -z "$TARGET_URL" ]]; then
  # Try CLOUD_DATABASE_URL from environment
  if [[ -n "${CLOUD_DATABASE_URL:-}" ]]; then
    TARGET_URL="$CLOUD_DATABASE_URL"
    ok "CLOUD_DATABASE_URL 환경변수에서 읽음"
  else
    echo ""
    echo "  클라우드 DB URL을 입력하세요."
    echo "  예시:"
    echo "    Supabase: postgresql://postgres.[ref]:[pass]@aws-0-[region].pooler.supabase.com:6543/postgres"
    echo "    Neon:     postgresql://[user]:[pass]@[endpoint].neon.tech/[db]?sslmode=require"
    echo "    Railway:  postgresql://postgres:[pass]@[host].railway.app:5432/railway"
    echo ""
    read -rp "  URL: " TARGET_URL
  fi
fi

if [[ -z "$TARGET_URL" ]]; then
  fail "클라우드 DB URL이 필요합니다"
fi

# Mask password in display
DISPLAY_URL=$(echo "$TARGET_URL" | sed -E 's/(:\/\/[^:]+:)[^@]+(@)/\1****\2/')
ok "대상: $DISPLAY_URL"

# ──────────────────────────────────────────────────
# Step 3: Test cloud connection
# ──────────────────────────────────────────────────
info "클라우드 DB 연결 테스트..."

if psql "$TARGET_URL" -c "SELECT 1;" >/dev/null 2>&1; then
  ok "클라우드 DB 연결 성공"

  # Get cloud DB version
  cloud_version=$(psql "$TARGET_URL" -t -c "SELECT version();" 2>/dev/null | head -1 | xargs)
  ok "서버: $cloud_version"
else
  fail "클라우드 DB에 연결할 수 없습니다. URL과 네트워크를 확인하세요."
fi

# ──────────────────────────────────────────────────
# Step 4: Backup local DB
# ──────────────────────────────────────────────────
info "로컬 DB 백업..."

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
MIGRATION_BACKUP="$BACKUP_DIR/own_calendar_pre_migration_${TIMESTAMP}.dump"
mkdir -p "$BACKUP_DIR"

docker compose -f "$COMPOSE_FILE" exec -T postgres \
  pg_dump -U postgres -d own_calendar -Fc --no-owner --no-acl \
  > "$MIGRATION_BACKUP" 2>/dev/null

if [[ ! -s "$MIGRATION_BACKUP" ]]; then
  rm -f "$MIGRATION_BACKUP"
  fail "로컬 DB 백업 실패"
fi
ok "백업 완료: $(basename "$MIGRATION_BACKUP") ($(du -h "$MIGRATION_BACKUP" | cut -f1))"

# Get local record counts for verification
info "로컬 DB 레코드 수 확인..."
echo ""

LOCAL_COUNTS=$(docker compose -f "$COMPOSE_FILE" exec -T postgres \
  psql -U postgres -d own_calendar -t -A -c "
    SELECT relname, n_live_tup
    FROM pg_stat_user_tables
    WHERE schemaname = 'public'
    ORDER BY relname;
  " 2>/dev/null)

echo "$LOCAL_COUNTS" | while IFS='|' read -r table count; do
  [[ -z "$table" ]] && continue
  printf "  %-40s %s rows\n" "$table" "$count"
done
echo ""

if [[ "$DRY_RUN" == true ]]; then
  echo ""
  ok "DRY RUN 완료 — 연결 테스트와 백업까지만 실행했습니다."
  echo "  백업 파일: $MIGRATION_BACKUP"
  echo ""
  echo "  실제 마이그레이션을 진행하려면:"
  echo "    $0 --target-url '$DISPLAY_URL'"
  echo ""
  exit 0
fi

# ──────────────────────────────────────────────────
# Step 5: Migrate data
# ──────────────────────────────────────────────────
# Reset step counter for the remaining steps
step=4
total_steps=6

info "데이터 마이그레이션..."

echo ""
echo -e "${RED}┌──────────────────────────────────────────────────┐${NC}"
echo -e "${RED}│  경고: 클라우드 DB의 기존 데이터가 덮어씌워집니다  │${NC}"
echo -e "${RED}└──────────────────────────────────────────────────┘${NC}"
echo ""

read -rp "계속하시겠습니까? (yes를 입력하세요): " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "취소되었습니다. 백업 파일은 유지됩니다: $MIGRATION_BACKUP"
  exit 0
fi

echo ""

# Restore to cloud using pg_restore
# First, clean existing schema
ok "클라우드 DB 스키마 정리..."
psql "$TARGET_URL" -c "
  DO \$\$ DECLARE
    r RECORD;
  BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
      EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(r.tablename) || ' CASCADE';
    END LOOP;
    FOR r IN (SELECT typname FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid WHERE n.nspname = 'public' AND t.typtype = 'e') LOOP
      EXECUTE 'DROP TYPE IF EXISTS public.' || quote_ident(r.typname) || ' CASCADE';
    END LOOP;
  END \$\$;
" >/dev/null 2>&1

ok "기존 스키마 제거 완료"

# Restore
ok "pg_restore 실행..."
pg_restore -d "$TARGET_URL" --no-owner --no-acl --single-transaction \
  "$MIGRATION_BACKUP" 2>/dev/null

ok "데이터 전송 완료"

# ──────────────────────────────────────────────────
# Step 6: Verify
# ──────────────────────────────────────────────────
info "레코드 수 검증..."
echo ""

CLOUD_COUNTS=$(psql "$TARGET_URL" -t -A -c "
  SELECT relname, n_live_tup
  FROM pg_stat_user_tables
  WHERE schemaname = 'public'
  ORDER BY relname;
" 2>/dev/null)

# pg_stat may not be updated immediately, so also check with COUNT
mismatch=false

printf "  %-30s %10s %10s %s\n" "Table" "Local" "Cloud" "Status"
printf "  %-30s %10s %10s %s\n" "-----" "-----" "-----" "------"

echo "$LOCAL_COUNTS" | while IFS='|' read -r table local_count; do
  [[ -z "$table" ]] && continue
  # Get actual count from cloud
  cloud_count=$(psql "$TARGET_URL" -t -A -c "SELECT COUNT(*) FROM \"$table\";" 2>/dev/null | tr -d ' ')
  local_actual=$(docker compose -f "$COMPOSE_FILE" exec -T postgres \
    psql -U postgres -d own_calendar -t -A -c "SELECT COUNT(*) FROM \"$table\";" 2>/dev/null | tr -d ' ')

  if [[ "$local_actual" == "$cloud_count" ]]; then
    status="${GREEN}OK${NC}"
  else
    status="${RED}MISMATCH${NC}"
    mismatch=true
  fi
  printf "  %-30s %10s %10s " "$table" "$local_actual" "$cloud_count"
  echo -e "$status"
done

echo ""

if [[ "$mismatch" == true ]]; then
  warn "일부 테이블의 레코드 수가 일치하지 않습니다. 수동 확인이 필요합니다."
else
  ok "모든 테이블 레코드 수 일치"
fi

# ──────────────────────────────────────────────────
# Done
# ──────────────────────────────────────────────────
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  마이그레이션 완료${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""
echo "  다음 단계:"
echo ""
echo "  1. server/.env 에서 DATABASE_URL을 클라우드 URL로 변경:"
echo "     DATABASE_URL=\"$DISPLAY_URL\""
echo ""
echo "  2. docker-compose.yml에서 postgres 서비스 제거 또는 주석 처리"
echo "     (또는 로컬 DB를 백업용으로 유지)"
echo ""
echo "  3. API 서버 재시작:"
echo "     docker compose -f $COMPOSE_FILE up -d api"
echo ""
echo "  4. 앱에서 정상 동작 확인"
echo ""
echo "  백업 파일: $MIGRATION_BACKUP"
echo "  (문제 발생 시 ./scripts/restore-db.sh $MIGRATION_BACKUP 으로 복원)"
echo ""
