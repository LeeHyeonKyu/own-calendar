#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────
# Own Calendar — 배포 파이프라인
# 사용법:
#   ./scripts/deploy.sh                  # main에서 전체 파이프라인
#   ./scripts/deploy.sh --from <branch>  # feature 브랜치를 squash merge 후 배포
#   ./scripts/deploy.sh --web-only       # 웹 빌드+배포+검증만
#   ./scripts/deploy.sh --server-only    # 서버 빌드+배포+검증만
#   ./scripts/deploy.sh --no-docker-build # Docker 이미지 재빌드 스킵 (소스만 변경 시)
# ──────────────────────────────────────────────────

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER="$HOME/flutter-sdk/bin/flutter"
WEB_DEPLOY_DIR="$HOME/own-calendar-data/web"
HEALTH_URL="https://own-calendar.tailb2886a.ts.net/health"
APP_URL="https://own-calendar.tailb2886a.ts.net"
COMPOSE_FILE="$PROJECT_ROOT/server/docker-compose.yml"
DOCKER_BUILD_TIMEOUT=300

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
NO_DOCKER_BUILD=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --from)             FEATURE_BRANCH="$2"; shift 2 ;;
    --web-only)         WEB_ONLY=true; shift ;;
    --server-only)      SERVER_ONLY=true; shift ;;
    --no-docker-build)  NO_DOCKER_BUILD=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ──────────────────────────────────────────────────
# Calculate total steps
# ──────────────────────────────────────────────────
if $WEB_ONLY; then
  total_steps=5
elif $SERVER_ONLY; then
  total_steps=4
else
  total_steps=10
  [[ -n "$FEATURE_BRANCH" ]] && total_steps=$((total_steps+2))
fi

echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}  Own Calendar 배포 파이프라인${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

cd "$PROJECT_ROOT"

# ──────────────────────────────────────────────────
# 0. Pre-flight checks
# ──────────────────────────────────────────────────
log "Pre-flight 확인"

docker info > /dev/null 2>&1 || fail "Docker가 실행되지 않음"
ok "Docker 실행 중"

[[ -x "$FLUTTER" ]] || fail "Flutter not found at $FLUTTER"
ok "Flutter: $($FLUTTER --version 2>&1 | head -1)"

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
# 3. Server 빌드 + 배포
# ──────────────────────────────────────────────────
if ! $WEB_ONLY; then
  log "서버 빌드 + 배포"

  if $NO_DOCKER_BUILD; then
    warn "Docker 이미지 빌드 스킵 (--no-docker-build)"
    warn "tsx watch가 소스 변경을 자동 반영합니다"
    docker compose -f "$COMPOSE_FILE" restart api 2>&1 | tail -2
    ok "API 컨테이너 재시작 완료"
  else
    # Docker build with timeout
    ok "Docker 빌드 시작 (타임아웃: ${DOCKER_BUILD_TIMEOUT}초)"
    if timeout "$DOCKER_BUILD_TIMEOUT" docker compose -f "$COMPOSE_FILE" up -d --build api 2>&1 | tail -5; then
      ok "API 컨테이너 재빌드 완료"
    else
      exit_code=$?
      if [[ $exit_code -eq 124 ]]; then
        warn "Docker 빌드 타임아웃 (${DOCKER_BUILD_TIMEOUT}초) — 컨테이너 재시작으로 대체"
        warn "Docker Hub 접근이 느린 경우 --no-docker-build 옵션 사용"
        # Kill any lingering buildx processes
        pkill -f "docker-buildx.*bake" 2>/dev/null || true
        pkill -f "docker-compose.*build" 2>/dev/null || true
        sleep 2
        docker compose -f "$COMPOSE_FILE" restart api 2>&1 | tail -2
        ok "API 컨테이너 재시작 완료 (빌드 대체)"
      else
        fail "Docker 빌드 실패 (exit code: $exit_code)"
      fi
    fi
  fi

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
  log "Flutter Web 빌드 (clean → pub get → build)"
  cd "$PROJECT_ROOT/client"

  # flutter clean은 필수 — 없으면 트리쉐이킹이 오동작하여 아이콘 누락
  $FLUTTER clean 2>&1 | tail -1
  $FLUTTER pub get 2>&1 | tail -1
  $FLUTTER build web --release --dart-define-from-file=config/prod.json 2>&1 | tail -3
  ok "Web 빌드 완료"

  # 웹 플러그인 등록 검증
  REGISTRANT="$PROJECT_ROOT/client/build/web/main.dart.js"
  if [[ -f "$REGISTRANT" ]]; then
    if grep -q "SharedPreferences" "$REGISTRANT" 2>/dev/null; then
      ok "웹 플러그인 등록 확인 (SharedPreferences)"
    else
      warn "웹 플러그인 등록 미확인 — 런타임 에러 가능"
    fi
  fi

  cd "$PROJECT_ROOT"

  log "Web 배포 (nginx + 폰트 캐시 버스팅)"
  # 기존 파일 삭제
  if [[ -d "$WEB_DEPLOY_DIR" ]]; then
    find "$WEB_DEPLOY_DIR" -mindepth 1 -delete 2>/dev/null || true
  fi
  cp -r "$PROJECT_ROOT/client/build/web/"* "$WEB_DEPLOY_DIR/"

  # 폰트 파일 캐시 버스팅 — 브라우저 캐시된 구 폰트를 강제 갱신
  FONT_DIR="$WEB_DEPLOY_DIR/assets/fonts"
  CUPERTINO_FONT_DIR="$WEB_DEPLOY_DIR/assets/packages/cupertino_icons/assets"
  font_busted=0
  for f in "$FONT_DIR"/MaterialIcons-Regular.otf "$CUPERTINO_FONT_DIR"/CupertinoIcons.ttf; do
    if [[ -f "$f" ]]; then
      HASH=$(md5 -q "$f" 2>/dev/null || md5sum "$f" | cut -d' ' -f1)
      HASH="${HASH:0:8}"
      BASE=$(basename "$f")
      EXT="${BASE##*.}"
      NAME="${BASE%.*}"
      DIR=$(dirname "$f")
      cp "$f" "$DIR/${NAME}.${HASH}.${EXT}"
      # FontManifest.json에서 원본 파일명을 해시 파일명으로 교체
      sed -i '' "s|${BASE}|${NAME}.${HASH}.${EXT}|g" "$WEB_DEPLOY_DIR/assets/FontManifest.json"
      font_busted=$((font_busted+1))
    fi
  done
  ok "폰트 캐시 버스팅 완료 (${font_busted}개 파일)"

  # FontManifest.json 자체도 캐시 버스팅 — 브라우저가 immutable 캐시하면 구 manifest를 사용
  MANIFEST="$WEB_DEPLOY_DIR/assets/FontManifest.json"
  if [[ -f "$MANIFEST" ]]; then
    FM_HASH=$(md5 -q "$MANIFEST" 2>/dev/null || md5sum "$MANIFEST" | cut -d' ' -f1)
    FM_HASH="${FM_HASH:0:8}"
    FM_HASHED="FontManifest.${FM_HASH}.json"
    cp "$MANIFEST" "$WEB_DEPLOY_DIR/assets/$FM_HASHED"
    sed -i '' "s|FontManifest.json|$FM_HASHED|g" "$WEB_DEPLOY_DIR/main.dart.js"
    ok "FontManifest 캐시 버스팅: $FM_HASHED"
  fi

  # flutter_service_worker.js를 자체해제 버전으로 교체
  cat > "$WEB_DEPLOY_DIR/flutter_service_worker.js" << 'SWEOF'
self.addEventListener('install', function(e) { self.skipWaiting(); });
self.addEventListener('activate', function(e) {
  e.waitUntil(
    caches.keys().then(function(names) {
      return Promise.all(names.map(function(n) { return caches.delete(n); }));
    }).then(function() { return self.registration.unregister(); })
  );
});
SWEOF

  # nginx 재시작으로 캐시 헤더 갱신
  docker restart server-web-1 2>/dev/null || warn "nginx 재시작 실패"
  ok "Web 배포 완료: $WEB_DEPLOY_DIR"

  log "Web 접근 검증"
  sleep 3
  http_status=$(curl -so /dev/null -w '%{http_code}' "$APP_URL" 2>/dev/null)
  if [[ "$http_status" == "200" ]]; then
    ok "Web 응답 정상: HTTP $http_status"
  else
    fail "Web 응답 비정상: HTTP $http_status"
  fi

  if curl -s "$APP_URL" | grep -q "flutter_bootstrap.js"; then
    ok "Flutter 앱 로드 확인"
  else
    warn "Flutter 부트스트랩 미확인 — 수동 점검 필요"
  fi

  # FontManifest에 해시 파일명이 반영되었는지 확인
  if grep -q "MaterialIcons-Regular\." "$WEB_DEPLOY_DIR/assets/FontManifest.json" 2>/dev/null; then
    manifest_font=$(grep -o 'MaterialIcons-Regular[^"]*' "$WEB_DEPLOY_DIR/assets/FontManifest.json" | head -1)
    ok "FontManifest 검증: $manifest_font"
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
