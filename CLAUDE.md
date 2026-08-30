## Project Compass
This project follows the principles defined in [PROJECT.md](./docs/PROJECT.md).
Technical decisions are documented in [TECHNICAL.md](./docs/TECHNICAL.md).
AI agents MUST read docs/PROJECT.md and docs/TECHNICAL.md before starting any work.
NON-NEGOTIABLE rules in PROJECT.md cannot be overridden.

## Development Workflow

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
   - Only when all three reviewers fully pass does the orchestrator accept the work

### Document References
- Project definition: `docs/PROJECT.md`
- Technical foundation: `docs/TECHNICAL.md`
- QA checklist: `docs/QA_CHECKLIST.md`
- Feature specs: `specs/features/NNN.md`
- Feature registry: `docs/PROJECT.md` → Feature Registry section
