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
   - Tests edge cases: interruption (app background/foreground, network loss mid-action), concurrency (rapid taps, simultaneous family edits), boundary (empty, long text, special chars, midnight-crossing events), state corruption (expired session, deleted resource)
   - Verifies NON-NEGOTIABLE principles: data manipulation freedom (CRUD without unnecessary steps), data ownership (data persists independently of external services)
   - Captures evidence for every test: screenshots, console output, state checks
   - Adopts the most paranoid, impatient, careless user persona — tests both primary persona (developer) and secondary persona (non-developer family member)
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

# iOS 앱 배포 (IPA 빌드 + GitHub Release + AltStore 소스 업데이트)
./scripts/deploy.sh --ios

# 서버+웹+iOS 전부
./scripts/deploy.sh --ios
```

파이프라인이 수행하는 것:
1. Pre-flight (Docker, Flutter, git 상태 확인)
2. Squash merge + push (--from 사용 시)
3. 서버 빌드 (docker compose up -d --build api)
4. 서버 헬스체크 (60초 타임아웃)
5. DB Migration 확인
6. 서버 에러 로그 확인
7. Flutter Web 빌드 + nginx 배포
8. Web HTTP 200 + Flutter 부트스트랩 확인
9. Feature 브랜치 정리
10. (--ios) iOS IPA 빌드 + GitHub Release + AltStore apps.json 업데이트

**배포 없이 "구현 완료"를 선언하지 않는다.**

### AltStore 버전 규칙 (NON-NEGOTIABLE)

`altstore/apps.json`의 `versions[].version`은 **IPA의 CFBundleShortVersionString과 반드시 일치**해야 한다.
Flutter에서는 `client/pubspec.yaml`의 `version:` 필드에서 `+` 앞부분이 CFBundleShortVersionString이다.
예: `version: 1.0.0+5` → CFBundleShortVersionString = `1.0.0`, CFBundleVersion = `5`.

- `--ios` 플래그가 이 동기화를 자동 처리한다
- 수동으로 apps.json을 수정할 때는 반드시 `grep '^version:' client/pubspec.yaml`로 확인
- buildVersion도 pubspec.yaml의 `+` 뒤 숫자와 일치해야 함

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
