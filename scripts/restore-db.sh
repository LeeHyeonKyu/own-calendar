#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────
# Own Calendar — DB Restore
# 사용법:
#   ./scripts/restore-db.sh backups/own_calendar_20260908.dump    # custom format
#   ./scripts/restore-db.sh backups/own_calendar_20260908.sql.gz  # SQL format
#   ./scripts/restore-db.sh --force backups/own_calendar_*.dump   # 확인 없이 복원
#   ./scripts/restore-db.sh --list                                # 사용 가능한 백업 목록
# ──────────────────────────────────────────────────

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/server/docker-compose.yml"
BACKUP_DIR="$PROJECT_ROOT/backups"
FORCE=false
LIST=false
BACKUP_FILE=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; exit 1; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
info() { echo -e "${CYAN}==>${NC} $1"; }

# ──────────────────────────────────────────────────
# Parse args
# ──────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --force)  FORCE=true; shift ;;
    --list)   LIST=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--force] [--list] <backup_file>"
      echo ""
      echo "Options:"
      echo "  --force   Skip confirmation prompt"
      echo "  --list    Show available backups"
      echo ""
      echo "Supported formats:"
      echo "  .dump     pg_dump custom format (pg_restore)"
      echo "  .sql.gz   Compressed plain SQL (gunzip | psql)"
      exit 0
      ;;
    -*) echo "Unknown option: $1"; exit 1 ;;
    *)  BACKUP_FILE="$1"; shift ;;
  esac
done

# ──────────────────────────────────────────────────
# List backups
# ──────────────────────────────────────────────────
if [[ "$LIST" == true ]]; then
  info "사용 가능한 백업 목록 ($BACKUP_DIR):"
  echo ""
  if [[ -d "$BACKUP_DIR" ]]; then
    found=0
    while IFS= read -r f; do
      size=$(du -h "$f" | cut -f1)
      mod=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$f" 2>/dev/null || date -r "$f" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
      echo "  $(basename "$f")  ($size, $mod)"
      found=$((found + 1))
    done < <(find "$BACKUP_DIR" -name "own_calendar_*" -type f | sort -r)
    echo ""
    if [[ $found -eq 0 ]]; then
      warn "백업 파일이 없습니다"
    else
      echo "  총 ${found}개 파일"
    fi
  else
    warn "백업 디렉토리가 존재하지 않습니다: $BACKUP_DIR"
  fi
  exit 0
fi

# ──────────────────────────────────────────────────
# Validate input
# ──────────────────────────────────────────────────
if [[ -z "$BACKUP_FILE" ]]; then
  fail "백업 파일을 지정하세요. 사용법: $0 [--force] <backup_file>"
fi

if [[ ! -f "$BACKUP_FILE" ]]; then
  fail "파일을 찾을 수 없습니다: $BACKUP_FILE"
fi

# Determine format
if [[ "$BACKUP_FILE" == *.dump ]]; then
  FORMAT="custom"
elif [[ "$BACKUP_FILE" == *.sql.gz ]]; then
  FORMAT="sql"
else
  fail "지원하지 않는 형식입니다. .dump 또는 .sql.gz 파일을 사용하세요."
fi

# ──────────────────────────────────────────────────
# Pre-flight checks
# ──────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
  fail "docker가 설치되어 있지 않습니다"
fi

if ! docker compose -f "$COMPOSE_FILE" ps --status running postgres 2>/dev/null | grep -q postgres; then
  fail "PostgreSQL 컨테이너가 실행 중이 아닙니다"
fi

# ──────────────────────────────────────────────────
# Confirmation
# ──────────────────────────────────────────────────
file_size=$(du -h "$BACKUP_FILE" | cut -f1)

echo ""
echo -e "${RED}┌──────────────────────────────────────────────┐${NC}"
echo -e "${RED}│  경고: 현재 DB의 모든 데이터가 덮어씌워집니다  │${NC}"
echo -e "${RED}└──────────────────────────────────────────────┘${NC}"
echo ""
echo "  파일   : $(basename "$BACKUP_FILE")"
echo "  크기   : $file_size"
echo "  형식   : $FORMAT"
echo ""

if [[ "$FORCE" != true ]]; then
  read -rp "계속하시겠습니까? (yes를 입력하세요): " confirm
  if [[ "$confirm" != "yes" ]]; then
    echo "취소되었습니다."
    exit 0
  fi
fi

# ──────────────────────────────────────────────────
# Create a safety backup before restoring
# ──────────────────────────────────────────────────
info "복원 전 안전 백업 생성..."
SAFETY_BACKUP="$BACKUP_DIR/own_calendar_pre_restore_$(date +%Y%m%d_%H%M%S).dump"
mkdir -p "$BACKUP_DIR"

docker compose -f "$COMPOSE_FILE" exec -T postgres \
  pg_dump -U postgres -d own_calendar -Fc --no-owner --no-acl \
  > "$SAFETY_BACKUP" 2>/dev/null

if [[ -s "$SAFETY_BACKUP" ]]; then
  ok "안전 백업: $(basename "$SAFETY_BACKUP") ($(du -h "$SAFETY_BACKUP" | cut -f1))"
else
  rm -f "$SAFETY_BACKUP"
  warn "안전 백업 생성 실패 — 빈 DB일 수 있습니다. 계속 진행합니다."
fi

# ──────────────────────────────────────────────────
# Restore
# ──────────────────────────────────────────────────
info "DB 복원 시작..."

# Drop and recreate the database
docker compose -f "$COMPOSE_FILE" exec -T postgres \
  psql -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='own_calendar' AND pid <> pg_backend_pid();" \
  >/dev/null 2>&1 || true

docker compose -f "$COMPOSE_FILE" exec -T postgres \
  psql -U postgres -c "DROP DATABASE IF EXISTS own_calendar;" \
  >/dev/null 2>&1

docker compose -f "$COMPOSE_FILE" exec -T postgres \
  psql -U postgres -c "CREATE DATABASE own_calendar;" \
  >/dev/null 2>&1

ok "DB 재생성 완료"

if [[ "$FORMAT" == "custom" ]]; then
  info "pg_restore 실행 (custom format)..."
  docker compose -f "$COMPOSE_FILE" exec -T postgres \
    pg_restore -U postgres -d own_calendar --no-owner --no-acl --single-transaction \
    < "$BACKUP_FILE" 2>/dev/null
elif [[ "$FORMAT" == "sql" ]]; then
  info "SQL 복원 (gzip)..."
  gunzip -c "$BACKUP_FILE" | \
    docker compose -f "$COMPOSE_FILE" exec -T postgres \
      psql -U postgres -d own_calendar --single-transaction -q \
      >/dev/null 2>&1
fi

ok "복원 완료"

# ──────────────────────────────────────────────────
# Verify
# ──────────────────────────────────────────────────
info "테이블별 레코드 수 확인..."
echo ""

docker compose -f "$COMPOSE_FILE" exec -T postgres \
  psql -U postgres -d own_calendar -c "
    SELECT schemaname || '.' || relname AS table_name,
           n_live_tup AS row_count
    FROM pg_stat_user_tables
    ORDER BY relname;
  " 2>/dev/null

echo ""
info "복원 완료"
echo "  복원 파일  : $(basename "$BACKUP_FILE")"
if [[ -s "${SAFETY_BACKUP:-}" ]]; then
  echo "  안전 백업  : $(basename "$SAFETY_BACKUP")"
fi
echo ""
warn "API 서버를 재시작하세요: docker compose -f $COMPOSE_FILE restart api"
echo ""
