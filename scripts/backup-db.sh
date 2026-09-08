#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────
# Own Calendar — DB Backup
# 사용법:
#   ./scripts/backup-db.sh              # 기본 백업 (backups/ 디렉토리)
#   ./scripts/backup-db.sh --upload     # 백업 후 S3 업로드 (AWS_* 환경변수 필요)
#   ./scripts/backup-db.sh --dir /path  # 백업 디렉토리 지정
# ──────────────────────────────────────────────────

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/server/docker-compose.yml"
BACKUP_DIR="$PROJECT_ROOT/backups"
RETENTION_DAYS=7
UPLOAD=false
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

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
    --upload)  UPLOAD=true; shift ;;
    --dir)     BACKUP_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--upload] [--dir /path]"
      echo ""
      echo "Options:"
      echo "  --upload    Upload to S3 after backup (requires AWS_* env vars)"
      echo "  --dir PATH  Custom backup directory (default: backups/)"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ──────────────────────────────────────────────────
# Pre-flight checks
# ──────────────────────────────────────────────────
info "DB 백업 시작 ($TIMESTAMP)"

# Check docker compose is available
if ! command -v docker &>/dev/null; then
  fail "docker가 설치되어 있지 않습니다"
fi

# Check postgres container is running
if ! docker compose -f "$COMPOSE_FILE" ps --status running postgres 2>/dev/null | grep -q postgres; then
  fail "PostgreSQL 컨테이너가 실행 중이 아닙니다. 'docker compose -f $COMPOSE_FILE up -d postgres' 실행 후 다시 시도하세요."
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# ──────────────────────────────────────────────────
# Backup (custom format for flexible restore)
# ──────────────────────────────────────────────────
BACKUP_FILE_CUSTOM="$BACKUP_DIR/own_calendar_${TIMESTAMP}.dump"
BACKUP_FILE_SQL="$BACKUP_DIR/own_calendar_${TIMESTAMP}.sql.gz"

info "pg_dump 실행 (custom format)..."
docker compose -f "$COMPOSE_FILE" exec -T postgres \
  pg_dump -U postgres -d own_calendar -Fc --no-owner --no-acl \
  > "$BACKUP_FILE_CUSTOM" 2>/dev/null

if [[ ! -s "$BACKUP_FILE_CUSTOM" ]]; then
  rm -f "$BACKUP_FILE_CUSTOM"
  fail "pg_dump가 빈 파일을 생성했습니다. DB 연결을 확인하세요."
fi
ok "Custom format: $(basename "$BACKUP_FILE_CUSTOM") ($(du -h "$BACKUP_FILE_CUSTOM" | cut -f1))"

info "pg_dump 실행 (plain SQL, compressed)..."
docker compose -f "$COMPOSE_FILE" exec -T postgres \
  pg_dump -U postgres -d own_calendar --no-owner --no-acl \
  2>/dev/null | gzip > "$BACKUP_FILE_SQL"

if [[ ! -s "$BACKUP_FILE_SQL" ]]; then
  rm -f "$BACKUP_FILE_SQL"
  fail "SQL dump 압축이 실패했습니다."
fi
ok "Plain SQL (gzip): $(basename "$BACKUP_FILE_SQL") ($(du -h "$BACKUP_FILE_SQL" | cut -f1))"

# ──────────────────────────────────────────────────
# Retention: keep last N days
# ──────────────────────────────────────────────────
info "오래된 백업 정리 (${RETENTION_DAYS}일 이전 삭제)..."
deleted=0
while IFS= read -r -d '' old_file; do
  rm -f "$old_file"
  deleted=$((deleted + 1))
done < <(find "$BACKUP_DIR" -name "own_calendar_*" -type f -mtime +${RETENTION_DAYS} -print0 2>/dev/null)

if [[ $deleted -gt 0 ]]; then
  ok "${deleted}개 파일 삭제됨"
else
  ok "삭제할 파일 없음"
fi

# ──────────────────────────────────────────────────
# Optional: S3 Upload
# ──────────────────────────────────────────────────
if [[ "$UPLOAD" == true ]]; then
  info "S3 업로드..."

  if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" || -z "${BACKUP_S3_BUCKET:-}" ]]; then
    warn "S3 업로드를 건너뜁니다 — AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, BACKUP_S3_BUCKET 환경변수가 필요합니다"
  else
    S3_ENDPOINT="${BACKUP_S3_ENDPOINT:+--endpoint-url $BACKUP_S3_ENDPOINT}"
    S3_PREFIX="${BACKUP_S3_PREFIX:-own-calendar-backups}"

    if ! command -v aws &>/dev/null; then
      fail "aws CLI가 설치되어 있지 않습니다. 'brew install awscli' 또는 'pip install awscli'로 설치하세요."
    fi

    # Upload both files
    # shellcheck disable=SC2086
    aws s3 cp "$BACKUP_FILE_CUSTOM" \
      "s3://${BACKUP_S3_BUCKET}/${S3_PREFIX}/$(basename "$BACKUP_FILE_CUSTOM")" \
      $S3_ENDPOINT 2>/dev/null \
      && ok "Custom dump 업로드 완료" \
      || warn "Custom dump 업로드 실패"

    # shellcheck disable=SC2086
    aws s3 cp "$BACKUP_FILE_SQL" \
      "s3://${BACKUP_S3_BUCKET}/${S3_PREFIX}/$(basename "$BACKUP_FILE_SQL")" \
      $S3_ENDPOINT 2>/dev/null \
      && ok "SQL dump 업로드 완료" \
      || warn "SQL dump 업로드 실패"
  fi
fi

# ──────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────
echo ""
info "백업 완료"
echo "  Custom format : $BACKUP_FILE_CUSTOM"
echo "  Plain SQL.gz  : $BACKUP_FILE_SQL"

# Count total backups
total_backups=$(find "$BACKUP_DIR" -name "own_calendar_*.dump" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "  보관 중인 백업 : ${total_backups}개"
echo ""
