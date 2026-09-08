#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────
# Own Calendar — Backup Cron Setup
# 사용법:
#   ./scripts/setup-backup-cron.sh           # 매일 03:00 백업 cron 설치
#   ./scripts/setup-backup-cron.sh --remove  # cron 제거
#   ./scripts/setup-backup-cron.sh --status  # 현재 cron 상태 확인
# ──────────────────────────────────────────────────

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_SCRIPT="$PROJECT_ROOT/scripts/backup-db.sh"
CRON_MARKER="# own-calendar-backup"
CRON_SCHEDULE="0 3 * * *"
LOG_FILE="$PROJECT_ROOT/backups/cron-backup.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; exit 1; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
info() { echo -e "${CYAN}==>${NC} $1"; }

ACTION="install"

while [[ $# -gt 0 ]]; do
  case $1 in
    --remove)  ACTION="remove"; shift ;;
    --status)  ACTION="status"; shift ;;
    -h|--help)
      echo "Usage: $0 [--remove] [--status]"
      echo ""
      echo "Actions:"
      echo "  (default)   Install daily backup cron at 03:00"
      echo "  --remove    Remove the backup cron job"
      echo "  --status    Show current cron status"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ──────────────────────────────────────────────────
# Status
# ──────────────────────────────────────────────────
show_status() {
  info "현재 cron 상태:"
  echo ""
  if crontab -l 2>/dev/null | grep -q "$CRON_MARKER"; then
    existing=$(crontab -l 2>/dev/null | grep "$CRON_MARKER")
    echo -e "  ${GREEN}활성화됨${NC}"
    echo "  $existing"
  else
    echo -e "  ${YELLOW}비활성화${NC} — own-calendar 백업 cron이 설치되어 있지 않습니다"
  fi
  echo ""

  # Show recent backup log if exists
  if [[ -f "$LOG_FILE" ]]; then
    info "최근 백업 로그 (마지막 10줄):"
    echo ""
    tail -10 "$LOG_FILE" | while IFS= read -r line; do
      echo "  $line"
    done
    echo ""
  fi
}

# ──────────────────────────────────────────────────
# Remove
# ──────────────────────────────────────────────────
remove_cron() {
  info "백업 cron 제거..."
  if crontab -l 2>/dev/null | grep -q "$CRON_MARKER"; then
    crontab -l 2>/dev/null | grep -v "$CRON_MARKER" | crontab -
    ok "cron 작업이 제거되었습니다"
  else
    warn "제거할 cron 작업이 없습니다"
  fi
}

# ──────────────────────────────────────────────────
# Install
# ──────────────────────────────────────────────────
install_cron() {
  info "백업 cron 설치..."

  # Verify backup script exists and is executable
  if [[ ! -x "$BACKUP_SCRIPT" ]]; then
    fail "백업 스크립트를 찾을 수 없거나 실행 권한이 없습니다: $BACKUP_SCRIPT"
  fi

  # Create backups dir for log file
  mkdir -p "$(dirname "$LOG_FILE")"

  # Remove existing entry if present, then add new one
  CRON_LINE="$CRON_SCHEDULE $BACKUP_SCRIPT >> $LOG_FILE 2>&1 $CRON_MARKER"

  (
    crontab -l 2>/dev/null | grep -v "$CRON_MARKER" || true
    echo "$CRON_LINE"
  ) | crontab -

  ok "cron 설치 완료"
  echo ""
  echo "  스케줄 : 매일 03:00"
  echo "  명령어 : $BACKUP_SCRIPT"
  echo "  로그   : $LOG_FILE"
  echo ""

  show_status
}

# ──────────────────────────────────────────────────
# Execute
# ──────────────────────────────────────────────────
case "$ACTION" in
  install) install_cron ;;
  remove)  remove_cron ;;
  status)  show_status ;;
esac
