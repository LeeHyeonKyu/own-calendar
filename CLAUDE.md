## Project Compass
This project follows the principles defined in [PROJECT.md](./docs/PROJECT.md).
Technical decisions are documented in [TECHNICAL.md](./docs/TECHNICAL.md).
AI agents MUST read docs/PROJECT.md and docs/TECHNICAL.md before starting any work.
NON-NEGOTIABLE rules in PROJECT.md cannot be overridden.

## Worktree Workflow

### Principle
- Feature specs (`docs/`, `specs/`) are defined **only in main**.
- Implementation code is modified **only in the worktree**. Worktree path: `../own-calendar-wt`
- If a spec change is needed, edit it in main and sync to worktree via `git merge main` (one-way flow).
- Merge strategy: **squash merge** — `feat(NNN): title` format.
- On feature completion: `git worktree remove` + `git branch -d` automatic cleanup.

### Feature Lifecycle

```
main:
  /know-thy-build:feature → spec finalized → worktree created → sub-agent dispatched

worktree (sub-agent orchestrates the entire lifecycle):
  Phase 1 — Define:
    /know-thy-build:architect  → scaffold, signature tests
    /know-thy-build:designer   → design intent (UI features only)
    /know-thy-build:qa REVIEW  → test cases

  Phase 2 — Implement:
    Sub-agent fills scaffolds and implements code

  Phase 3 — Review:
    Architect review → gate.architect ✓
    Designer review  → gate.designer ✓
    QA TEST          → gate.qa ✓

  Phase 4 — Finish:
    All gates passed → /know-thy-build:finish → squash merge + cleanup
```

### Gate (Merge Prerequisite)
The `gate` field in the feature spec frontmatter tracks review status.
Merge is allowed only when all gates are `passed` or `skipped`.

| Role | Gate Status | Updated When |
|------|-----------|--------------|
| architect | pending → passed | Architect review passes |
| designer | pending → passed / skipped | Designer review passes (skipped for non-UI) |
| qa | pending → passed | All QA test cases pass |

### Orchestrator Model
The user session acts as **orchestrator only** — it does NOT implement directly.
All implementation is delegated to sub-agents with explicit scope and goals.

### Implementation Flow

1. **Orchestrator identifies work** from `docs/features/NNN.md`
   - Determines scope: which files, which components, what changes
   - Sets goal: specific acceptance criteria from the feature spec
   - Dispatches implementation sub-agent

2. **Implementation sub-agent — Pre-work (mandatory)**
   Before writing any code, the sub-agent MUST read:
   - `docs/PROJECT.md` — project principles and boundaries
   - `docs/TECHNICAL.md` — technical decisions and patterns
   - `docs/features/NNN.md` — feature spec, acceptance criteria, design intent
   The sub-agent confirms its understanding of scope and goal before proceeding.

3. **Implementation sub-agent — Execution**
   Implements within the defined scope. Does not expand beyond the goal.

4. **Post-implementation review (mandatory)**
   After implementation, the sub-agent dispatches **three review agents**:

   **Designer Review Agent:**
   - Reads the feature's Design Intent Map (if present)
   - Verifies every design intent step is correctly reflected in implementation
   - Checks all UI states are handled (empty, loading, error, success)
   - Adopts the most critical stance — assumes implementation is wrong until proven otherwise
   - Produces checklist: `- [x]` passed or `- [ ]` failed with specific reason

   **Architect Review Agent:**
   - Reads `docs/TECHNICAL.md` and the feature spec
   - Verifies code follows technical decisions, patterns, and constraints
   - Checks code structure, naming, boundaries, and error handling
   - Adopts the most critical stance — looks for what will break, not what looks nice
   - Produces checklist: `- [x]` passed or `- [ ]` failed with specific reason

5. **Designer + Architect must both pass before QA begins.**

6. **QA Review Agent (mandatory — runs the product)**
   - Actually starts the application and tests it as a real user
   - Reads `docs/QA_CHECKLIST.md` and executes relevant scenarios for the implemented feature
   - Executes every acceptance criterion from the feature spec step by step
   - Verifies all 4 design states per screen: empty, loading, error, success
   - Tests user interaction flows: navigation transitions, form behavior, back navigation
   - Tests edge cases: interruption (app background/foreground, network loss mid-action), concurrency (rapid taps, simultaneous group member edits), boundary (empty, long text, special chars, midnight-crossing events), state corruption (expired session, deleted resource)
   - Verifies NON-NEGOTIABLE principles: data manipulation freedom (CRUD without unnecessary steps), data ownership (data persists independently of external services)
   - Captures evidence for every test: screenshots, console output, state checks
   - Adopts the most paranoid, impatient, careless user persona — tests both primary persona (developer) and secondary persona (non-developer group member)
   - Produces checklist: `- [x]` passed with evidence or `- [ ]` failed with reproduction steps

7. **Review loop**
   - If ANY criterion is `[ ]` (failed): implementer fixes and re-submits
   - Designer + Architect re-review if changes are structural
   - QA re-tests failed scenarios + regression check on happy path
   - Loop continues until ALL reviewers' criteria are `[x]`
   - Only when all three reviewers fully pass does `/know-thy-build:finish` proceed

### 배포 파이프라인 (NON-NEGOTIABLE)

Feature 구현 완료 후 배포는 반드시 `scripts/deploy.sh`를 통해 진행한다.
수동으로 개별 단계를 실행하지 않는다 — 파이프라인이 merge → push → 서버 빌드 → 웹 빌드 → 배포 → 헬스체크 → 검증을 순서대로 강제 실행한다.

```bash
# Feature 브랜치에서 배포까지 한번에
./scripts/deploy.sh --from feature/NNN-name

# main에서 이미 merge된 상태라면
./scripts/deploy.sh

# 부분 배포
./scripts/deploy.sh --web-only      # 웹만
./scripts/deploy.sh --server-only   # 서버만
./scripts/deploy.sh --no-docker-build  # Docker 이미지 빌드 스킵 (소스만 변경 시)
```

파이프라인이 수행하는 것:
1. Pre-flight (Docker, Flutter, git 상태 확인)
2. Squash merge + push (--from 사용 시)
3. 서버 빌드 (docker compose up -d --build api)
4. 서버 헬스체크 (60초 타임아웃)
5. DB Migration 확인
6. 서버 에러 로그 확인
7. **Flutter `clean` + `pub get` + `build web --release`** (flutter clean 없이 빌드하면 웹 플러그인 미등록 + 아이콘 트리쉐이킹 오류. clean 후 빌드하면 트리쉐이킹 정상 동작. `--no-tree-shake-icons`는 1.6MB 폰트로 성능 저하 유발하므로 사용 금지)
8. **웹 플러그인 등록 검증** (web_plugin_registrant.dart에서 shared_preferences_web 등 필수 플러그인 확인)
9. **폰트 + FontManifest 캐시 버스팅** (폰트 파일명에 해시 → FontManifest.json 내 참조 갱신 → FontManifest.json 자체도 해시 rename → main.dart.js에서 참조 갱신. 이 전체 체인이 빠지면 브라우저 immutable 캐시 때문에 아이콘 누락)
10. nginx 배포 + flutter_service_worker.js 자체해제 버전으로 교체
11. Web HTTP 200 + Flutter 부트스트랩 확인
12. **브라우저 콘솔 검증 (NON-NEGOTIABLE)** — Playwright로 페이지 로드 후 `console_messages(level: "error")` 확인. `MissingPluginException`, `SyntaxError`, `TypeError` 하나라도 있으면 **배포 실패**
13. Feature 브랜치 정리

**배포 없이 "구현 완료"를 선언하지 않는다.**
**콘솔 에러 확인 없이 "배포 완료"를 선언하지 않는다.**
**`flutter analyze` 통과는 배포 검증이 아니다 — 런타임 에러는 analyze에서 안 잡힌다.**

### 테스트 DB 격리 (NON-NEGOTIABLE)

**서버 테스트는 절대로 프로덕션 DB에서 실행하지 않는다.**
- `tests/setup.ts`가 `DATABASE_URL`을 `_test` suffix DB로 자동 리다이렉트
- `beforeEach`에서 DB 이름 재검증 (non-test DB면 throw)
- **Docker 컨테이너 안에서 테스트 실행 금지** — 컨테이너의 DATABASE_URL이 프로덕션을 가리킴
- 테스트 실행 전 `own_calendar_test` DB가 존재하는지 확인: `docker exec server-postgres-1 psql -U postgres -c "SELECT 1 FROM pg_database WHERE datname='own_calendar_test'"`
- 로컬에서 `npx vitest run`으로 실행 (setup.ts가 DATABASE_URL을 자동 리다이렉트)

### iOS Build (Widget / Native)

Intel iMac (macOS 15.x) 환경 제약:
- **Xcode 16.4 사용** (`/Users/hk/Downloads/Xcode16.app`) — 최신 Xcode(26+)는 macOS 26.2+ 필요
- `sudo xcode-select -s "/Users/hk/Downloads/Xcode16.app/Contents/Developer"` 확인 필수
- iOS build 전: `cd ios && pod install` 필수 (flutter clean 후 특히)
- `IPHONEOS_DEPLOYMENT_TARGET = 16.0` (Podfile + pbxproj 통일)
- Widget Extension 추가 시 pbxproj에서 "Thin Binary"를 마지막 빌드 페이즈로 이동
- iPhone 테스트: `flutter build ios --release` + `flutter install --release` (debug 모드는 홈화면 실행 불가)
- iPhone 설정: 개발자 모드 ON + 기기 관리에서 개발자 앱 신뢰

### Document References
- Project definition: `docs/PROJECT.md`
- Technical foundation: `docs/TECHNICAL.md`
- QA checklist: `docs/QA_CHECKLIST.md`
- QA test cases: `docs/QA.md`
- Feature specs: `docs/features/NNN.md`
- Feature registry: `docs/PROJECT.md` → Feature Registry section
