#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────
# Own Calendar — 배포 파이프라인
# 사용법:
#   ./scripts/deploy.sh                  # main에서 전체 파이프라인
#   ./scripts/deploy.sh --from <branch>  # feature 브랜치를 squash merge 후 배포
#   ./scripts/deploy.sh --web-only       # 웹 빌드+배포+검증만
#   ./scripts/deploy.sh --server-only    # 서버 빌드+배포+검증만
#   ./scripts/deploy.sh --skip-tag       # iOS 빌드 태그 생성 건너뛰기
# ──────────────────────────────────────────────────

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER="$HOME/flutter-sdk/bin/flutter"
WEB_DEPLOY_DIR="$HOME/own-calendar-data/web"
HEALTH_URL="https://own-calendar.tailb2886a.ts.net/health"
APP_URL="https://own-calendar.tailb2886a.ts.net"
COMPOSE_FILE="$PROJECT_ROOT/server/docker-compose.yml"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

step=0
total_steps=0

log()   { step=$((step+1)); echo -e "\n${CYAN}[$step/$total_steps]${NC} $1"; }
ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
fail()  { echo -e "  ${RED}✗${NC} $1"; exit 1; }
warn()  { echo -e "  ${YELLOW}!${NC} $1"; }

# ──────────────────────────────────────────────────
# Parse args
# ──────────────────────────────────────────────────
FEATURE_BRANCH=""
WEB_ONLY=false
SERVER_ONLY=false
SKIP_TAG=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --from)       FEATURE_BRANCH="$2"; shift 2 ;;
    --web-only)   WEB_ONLY=true; shift ;;
    --server-only) SERVER_ONLY=true; shift ;;
    --skip-tag)   SKIP_TAG=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ──────────────────────────────────────────────────
# Calculate total steps
# ──────────────────────────────────────────────────
if $WEB_ONLY; then
  total_steps=4
elif $SERVER_ONLY; then
  total_steps=4
else
  total_steps=10
  [[ -n "$FEATURE_BRANCH" ]] && total_steps=$((total_steps+2))
  $SKIP_TAG && total_steps=$((total_steps-1))
fi

echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}  Own Calendar 배포 파이프라인${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

cd "$PROJECT_ROOT"

# ──────────────────────────────────────────────────
# 0. Pre-flight checks
# ──────────────────────────────────────────────────
log "Pre-flight 확인"

# Docker 실행 확인
docker info > /dev/null 2>&1 || fail "Docker가 실행되지 않음"
ok "Docker 실행 중"

# Flutter 존재 확인
[[ -x "$FLUTTER" ]] || fail "Flutter not found at $FLUTTER"
ok "Flutter: $($FLUTTER --version 2>&1 | head -1)"

# Git clean 확인
if [[ -n "$(git status --porcelain -- ':!.claude/' ':!.playwright-mcp/')" ]]; then
  warn "커밋되지 않은 변경사항 있음 (계속 진행)"
fi

# ──────────────────────────────────────────────────
# 1. Squash merge (if --from)
# ──────────────────────────────────────────────────
if [[ -n "$FEATURE_BRANCH" ]]; then
  log "Feature 브랜치 squash merge: $FEATURE_BRANCH → main"

  current_branch=$(git branch --show-current)
  if [[ "$current_branch" != "main" ]]; then
    git checkout main || fail "main 체크아웃 실패"
  fi

  git merge --squash "$FEATURE_BRANCH" || fail "Squash merge 실패"
  ok "Squash merge 완료"

  log "Merge 커밋 생성"
  # 커밋 메시지는 사용자가 편집하도록
  echo -e "  ${YELLOW}커밋 메시지를 입력하세요:${NC}"
  read -r -p "  > " commit_msg
  git commit -m "$commit_msg" || fail "커밋 실패"
  ok "커밋: $(git log --oneline -1)"
fi

# ──────────────────────────────────────────────────
# 2. Push to origin
# ──────────────────────────────────────────────────
if ! $WEB_ONLY && ! $SERVER_ONLY; then
  log "origin/main에 push"
  git push origin main || fail "Push 실패"
  ok "Push 완료: $(git log --oneline -1)"
fi

# ──────────────────────────────────────────────────
# 2b. iOS/macOS 빌드 태그 생성
# ──────────────────────────────────────────────────
if ! $WEB_ONLY && ! $SERVER_ONLY && ! $SKIP_TAG; then
  log "iOS/macOS 빌드 태그 생성"
  DATE_TAG="v$(date -u +'%Y.%m.%d')"
  EXISTING=$(git tag -l "${DATE_TAG}.*" | wc -l | tr -d ' ')
  RUN_NUM=$((EXISTING + 1))
  NEW_TAG="${DATE_TAG}.${RUN_NUM}"
  if git tag "$NEW_TAG" && git push origin "$NEW_TAG" 2>/dev/null; then
    ok "태그 생성 + push: $NEW_TAG (CI 빌드 트리거)"
  else
    warn "태그 생성 실패 — iOS/macOS 빌드는 수동으로 트리거하세요"
  fi
elif $SKIP_TAG && ! $WEB_ONLY && ! $SERVER_ONLY; then
  warn "태그 생성 건너뜀 (--skip-tag)"
fi

# ──────────────────────────────────────────────────
# 3. Server 빌드 + 배포
# ──────────────────────────────────────────────────
if ! $WEB_ONLY; then
  log "서버 빌드 + 배포 (docker compose)"
  docker compose -f "$COMPOSE_FILE" up -d --build api 2>&1 | tail -5
  ok "API 컨테이너 재빌드 완료"

  log "서버 시작 대기 + 헬스체크"
  for i in $(seq 1 30); do
    sleep 2
    if curl -sf "$HEALTH_URL" > /dev/null 2>&1; then
      ok "서버 헬스체크 통과: $(curl -s "$HEALTH_URL")"
      break
    fi
    if [[ $i -eq 30 ]]; then
      echo ""
      echo "  서버 로그:"
      docker compose -f "$COMPOSE_FILE" logs api --tail 15
      fail "서버 헬스체크 실패 (60초 초과)"
    fi
    printf "."
  done

  # Migration 확인
  migration_log=$(docker compose -f "$COMPOSE_FILE" logs api --tail 30 2>&1)
  if echo "$migration_log" | grep -q "Applying migration"; then
    ok "DB Migration 적용됨"
  elif echo "$migration_log" | grep -q "All migrations have been successfully applied"; then
    ok "DB Migration 최신 상태"
  fi

  # 에러 로그 확인
  error_count=$(docker compose -f "$COMPOSE_FILE" logs api --tail 30 2>&1 | grep -c "ERR\|Error\|error" || true)
  if [[ $error_count -gt 0 ]]; then
    warn "서버 로그에 에러 $error_count건 감지 — 확인 필요"
  else
    ok "서버 에러 로그 없음"
  fi
fi

# ──────────────────────────────────────────────────
# 4. Web 빌드 + 배포
# ──────────────────────────────────────────────────
if ! $SERVER_ONLY; then
  log "Flutter Web 빌드"
  cd "$PROJECT_ROOT/client"
  $FLUTTER build web --release --dart-define-from-file=config/prod.json 2>&1 | tail -3
  ok "Web 빌드 완료"

  log "Web 배포 (nginx)"
  # 기존 파일 삭제 (rm -rf 대신 안전하게)
  if [[ -d "$WEB_DEPLOY_DIR" ]]; then
    find "$WEB_DEPLOY_DIR" -mindepth 1 -delete 2>/dev/null || true
  fi
  cp -r "$PROJECT_ROOT/client/build/web/"* "$WEB_DEPLOY_DIR/"
  ok "Web 배포 완료: $WEB_DEPLOY_DIR"

  log "Web 접근 검증"
  sleep 2
  http_status=$(curl -so /dev/null -w '%{http_code}' "$APP_URL" 2>/dev/null)
  if [[ "$http_status" == "200" ]]; then
    ok "Web 응답 정상: HTTP $http_status"
  else
    fail "Web 응답 비정상: HTTP $http_status"
  fi

  # index.html에 Flutter 부트스트랩 존재 확인
  if curl -s "$APP_URL" | grep -q "flutter_bootstrap.js"; then
    ok "Flutter 앱 로드 확인"
  else
    warn "Flutter 부트스트랩 미확인 — 수동 점검 필요"
  fi
fi

# ──────────────────────────────────────────────────
# 5. Feature 브랜치 정리 (if --from)
# ──────────────────────────────────────────────────
if [[ -n "$FEATURE_BRANCH" ]]; then
  log "Feature 브랜치 정리"
  git branch -D "$FEATURE_BRANCH" 2>/dev/null && ok "브랜치 삭제: $FEATURE_BRANCH" || warn "브랜치 이미 없음"
fi

# ──────────────────────────────────────────────────
# Done
# ──────────────────────────────────────────────────
echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}  배포 완료!${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""
echo "  API:  $HEALTH_URL"
echo "  Web:  $APP_URL"
echo "  Git:  $(git log --oneline -1)"
echo ""
