# Calendar Event Task Management with Obsidian Integration

Research findings for adding per-event task management to Own Calendar with bidirectional Obsidian vault integration.

**Date:** 2026-09-02
**Context:** Own Calendar is a Flutter + Node.js + PostgreSQL personal/family calendar hub (see `docs/PROJECT.md`, `docs/TECHNICAL.md`).

---

## Table of Contents

1. [iCalendar VTODO & CalDAV Specification](#1-icalendar-vtodo--caldav-specification)
2. [Calendar + Task Integration Patterns](#2-calendar--task-integration-patterns)
3. [Markdown-Based Task Management](#3-markdown-based-task-management)
4. [Obsidian Vault Integration Strategies](#4-obsidian-vault-integration-strategies)
5. [Existing Implementations](#5-existing-implementations)
6. [Data Model Recommendations](#6-data-model-recommendations)
7. [Recommended Architecture for Own Calendar](#7-recommended-architecture-for-own-calendar)

---

## 1. iCalendar VTODO & CalDAV Specification

### 1.1 VTODO Component (RFC 5545, Section 3.6.2)

The iCalendar standard defines VTODO as the component for tasks/to-dos, parallel to VEVENT for calendar events. A VTODO requires only `UID` and `DTSTAMP`.

**Key optional properties:**

| Property | RFC Section | Description |
|----------|------------|-------------|
| `STATUS` | 3.8.1.11 | `NEEDS-ACTION` (default), `COMPLETED`, `IN-PROCESS`, `CANCELLED` |
| `PERCENT-COMPLETE` | 3.8.1.8 | Integer 0-100 |
| `PRIORITY` | 3.8.1.9 | 0 = undefined, 1-4 = high, 5 = medium, 6-9 = low |
| `DUE` | 3.8.2.3 | DATE or DATE-TIME; mutually exclusive with DURATION |
| `COMPLETED` | 3.8.2.1 | DATE-TIME in UTC only; marks completion moment |
| `DTSTART` | 3.8.2.4 | When task work begins |
| `SUMMARY` | 3.8.1.12 | Title/name of the task |
| `DESCRIPTION` | 3.8.1.5 | Body text |
| `CATEGORIES` | 3.8.1.2 | Tags/categories |
| `RELATED-TO` | 3.8.4.5 | Links to other components by UID |
| `RRULE` | 3.8.5.3 | Recurring tasks |
| `VALARM` | 3.6.6 | Alarm/reminder sub-component |

**Source:** [RFC 5545](https://www.rfc-editor.org/rfc/rfc5545), Sections 3.6.2, 3.8.1.8-12, 3.8.2.1, 3.8.2.3

### 1.2 RELATED-TO Property (RFC 5545, Section 3.8.4.5)

This is the **standard mechanism to link a VTODO to a VEVENT**. The value is the `UID` of the related component.

**RELTYPE parameter values:**
- `PARENT` (default) -- the referenced component is a superior/container
- `CHILD` -- the referenced component is subordinate
- `SIBLING` -- peer relationship

**Example -- linking a task to an event:**
```
BEGIN:VTODO
UID:task-001@owncalendar.local
RELATED-TO;RELTYPE=PARENT:event-042@owncalendar.local
SUMMARY:Prepare presentation slides
DUE:20260915T090000Z
STATUS:NEEDS-ACTION
END:VTODO
```

This makes `event-042` the parent of `task-001`, expressing "this task belongs to that event."

**Source:** [RFC 5545, Section 3.8.4.5](https://www.rfc-editor.org/rfc/rfc5545#section-3.8.4.5)

### 1.3 RFC 9253 Extensions

RFC 9253 extends RELATED-TO with:
- Temporal relations (`FINISHTOSTART`, `STARTTOFINISH`, etc.)
- `GAP` parameter for time offsets between related components
- URI values for cross-collection references
- `DEPENDS-ON` relationship type
- `LINK` property for external resource references

**Source:** [RFC 9253](https://datatracker.ietf.org/doc/html/rfc9253)

### 1.4 Draft: iCalendar Tasks Extensions

The IETF CalExt working group has a draft (`draft-ietf-calext-ical-tasks`) that adds:
- `PENDING` and `FAILED` statuses
- `ESTIMATED-DURATION` property
- `SUBSTATE` for finer status granularity
- `TASK-MODE` (automatic/manual)
- `VSTATUS` history component
- Explicit support for "VTODO related to VEVENT to block time for a task"

**Source:** [draft-ietf-calext-ical-tasks-12](https://datatracker.ietf.org/doc/html/draft-ietf-calext-ical-tasks-12)

### 1.5 CalDAV VTODO Storage (RFC 4791)

- VTODO objects are stored as calendar object resources, same model as VEVENT (Section 4.1)
- VTODO and VEVENT can coexist in the same calendar collection but in separate object resources (Section 4.2)
- `supported-calendar-component-set` property declares which types a collection accepts (Section 5.2.3)
- `CALDAV:calendar-query REPORT` supports filtering/querying VTODO components (Section 7.8); Section 7.8.9 has a worked example for "Retrieval of All Pending To-Dos"

**Source:** [RFC 4791](https://www.rfc-editor.org/rfc/rfc4791), Sections 4.1, 4.2, 5.2.3, 7.8

### 1.6 Major Server VTODO Support

| Server | VTODO Support | Notes |
|--------|--------------|-------|
| **Google Calendar** | **No** | CalDAV explicitly excludes VTODO and VJOURNAL. Tasks are a separate API (Google Tasks API). |
| **Apple iCloud** | **Partial** | iCloud CalDAV stores VTODO, but since iOS 13/macOS Catalina, Apple Reminders uses a private sync store, not CalDAV. Third-party CalDAV clients can read/write VTODO on iCloud, but those won't appear in Reminders. |
| **Nextcloud** | **Yes** | Full VTODO support via CalDAV. Calendar collections contain both events and tasks. Dedicated Tasks app reads VTODO from the same CalDAV store. |
| **Radicale/Baikal** | **Yes** | Lightweight CalDAV servers with full VTODO support. |

**Sources:** [Google CalDAV v2 Guide](https://developers.google.com/workspace/calendar/caldav/v2/guide), [BusyMac blog on Reminders dropping CalDAV](https://support.busymac.com/blog/112990-reminders-in-ios-13-and-macos-catalina-drops-support-for-caldav), [Nextcloud Calendar Admin Manual](https://docs.nextcloud.com/server/stable/admin_manual/groupware/calendar.html)

---

## 2. Calendar + Task Integration Patterns

### 2.1 Per-Event Tasks Model

The cleanest standards-based approach:

1. **Events** are stored as VEVENT in the calendar (PostgreSQL `events` table in Own Calendar)
2. **Tasks** are stored as VTODO, linked to events via `RELATED-TO;RELTYPE=PARENT:<event-uid>`
3. Each event can have zero or many child tasks
4. Tasks can also exist independently (not linked to any event)
5. Tasks can have sub-tasks via nested RELATED-TO (PARENT/CHILD hierarchy)

### 2.2 Ownership Separation

The key architectural decision: **where is the source of truth?**

| Field | Owner | Rationale |
|-------|-------|-----------|
| Task status, due date, priority | Calendar app (PostgreSQL) | Structured data, needs validation |
| Task title, description | Both (bidirectional) | Editable from either side |
| Task body/notes (free text) | Obsidian (markdown) | Rich text belongs in markdown |
| Event association | Calendar app | Relational data |

### 2.3 Google Calendar Limitation

Since Google Calendar's CalDAV does not support VTODO, any task data for Google-synced events must live in Own Calendar's own database. This reinforces the architecture where Own Calendar's PostgreSQL is the task source of truth, and Obsidian is a projection/interface.

---

## 3. Markdown-Based Task Management

### 3.1 Task Format Conventions

**GitHub Flavored Markdown (GFM)** defines the basic checkbox syntax: `- [ ] task` / `- [x] done`.

**Source:** [GFM Spec](https://github.github.com/gfm/)

**Obsidian Tasks plugin** extends this with emoji-based metadata parsed from the task line:

| Emoji | Field | Example |
|-------|-------|---------|
| `📅` | Due date | `📅 2024-04-16` |
| `🛫` | Start date | `🛫 2024-04-15` |
| `⏳` | Scheduled date | `⏳ 2024-04-14` |
| `➕` | Created date | `➕ 2024-04-13` |
| `✅` | Done date | `✅ 2024-04-17` |
| `❌` | Cancelled date | `❌ 2024-04-18` |
| `🔁` | Recurrence | `🔁 every week` |
| `🆔` | Task ID | `🆔 dcf64c` |
| `⛔` | Depends on | `⛔ dcf64c,0h17ye` |
| `🔺⏫🔼🔽⏬` | Priority (highest to lowest) | inline marker |

**Source:** [Obsidian Tasks Emoji Format](https://publish.obsidian.md/tasks/Reference/Task+Formats/Tasks+Emoji+Format), [GitHub: obsidian-tasks-group/obsidian-tasks](https://github.com/obsidian-tasks-group/obsidian-tasks)

### 3.2 Dataview Inline Fields

Obsidian Dataview supports three metadata methods:

1. **YAML frontmatter** -- all fields auto-indexed, applies to the whole note
2. **Inline fields** -- `Key:: Value` (standalone line) or `[key:: value]` (inline, visible) or `(key:: value)` (inline, hidden in reader mode)
3. **Implicit fields** -- `file.cday`, `file.tasks`, `file.outlinks`, etc.

Task-level inline fields work: `- [ ] Send mail [due:: 2022-04-05] [priority:: high]`

**Source:** [Dataview Metadata Docs](https://blacksmithgu.github.io/obsidian-dataview/annotation/add-metadata/)

### 3.3 Hybrid Approach (Recommended)

Use **frontmatter** for file-level metadata (event link, calendar, sync hash) and **Obsidian Tasks emoji format** for per-task fields within the file body. This gives maximum compatibility:

- Obsidian Tasks plugin reads/writes emoji-formatted task lines
- Dataview queries frontmatter for event-level grouping
- Calendar app reads/writes frontmatter for sync metadata
- Human-readable in any markdown viewer

---

## 4. Obsidian Vault Integration Strategies

### 4.1 Obsidian URI Scheme

Official actions supported:

| Action | Purpose | Key Params |
|--------|---------|------------|
| `open` | Open vault/file | `vault`, `file`, `path`, `paneType` |
| `new` | Create note | `vault`, `name`/`file`, `content`, `silent`, `append`, `overwrite` |
| `daily` | Open daily note | `vault` (requires Daily Notes plugin) |
| `search` | Launch search | `vault`, `query` |

**Example deep links from the calendar app:**
```
obsidian://open?vault=my-vault&file=calendar/events/2024-04-16_team-meeting
obsidian://new?vault=my-vault&name=calendar/events/2024-04-16_meeting&content=---...---&silent=true
obsidian://search?vault=my-vault&query=tag:meeting
```

**Source:** [Obsidian Help -- Obsidian URI](https://obsidian.md/help/Extending+Obsidian/Obsidian+URI)

### 4.2 Advanced URI Plugin

The Advanced URI community plugin extends the scheme with:
- Writing to specific headings within a file
- Appending content to existing files
- Frontmatter field manipulation
- Executing Obsidian commands

**Source:** [Advanced URI Plugin Docs](https://publish.obsidian.md/advanced-uri-doc/Home)

### 4.3 Direct Vault File Writing (Primary Strategy)

The app writes `.md` files directly into the Obsidian vault folder. Obsidian detects changes via filesystem events. This is the most reliable approach for an external app.

**Considerations:**
- Obsidian watches the vault folder and picks up external changes
- The **Vault File Refresh** community plugin polls every 8s for reconciliation of externally-created files
- On mobile (iOS), Obsidian's sandbox means direct writes must go through a shared folder (iCloud, Dropbox, etc.)
- Avoid writing while Obsidian Sync is active on the same vault -- use file-based sync (iCloud/Dropbox/Syncthing) OR Obsidian Sync, never both

**Source:** [Obsidian Help -- Vault Types](https://obsidian.md/help/sync/vault-types)

### 4.4 Sync Approaches

| Approach | Pros | Cons | Best For |
|----------|------|------|----------|
| **Direct file write** (same machine) | Instant, simple | Only works on same device | Desktop/server |
| **Shared folder** (iCloud/Dropbox) | Multi-device | Sync delays, mobile sandbox issues | Multi-device family use |
| **Symlink** from vault to app data | Clean separation | Platform-specific, fragile on mobile | Developer setup |
| **Obsidian Sync** | Official, E2E encrypted | Cannot mix with other sync; closed protocol | Obsidian-only users |

**Recommendation for Own Calendar:** Direct file write on the server/desktop. The Node.js backend writes `.md` files into a configured vault path. For multi-device access, the vault is synced via iCloud/Dropbox/Syncthing (not Obsidian Sync, to avoid conflicts with the app's writes).

### 4.5 Calendar-Related Obsidian Community Plugins

| Plugin | Status | What It Does |
|--------|--------|-------------|
| **Full Calendar** | Archived (Aug 2026) | Events as notes with frontmatter. Local, ICS (read-only), CalDAV (read-only). Two-way CalDAV never completed. |
| **Calendar.MD** | Active | Reads tasks from Obsidian Tasks/Dataview formats, month/week/day views, drag-and-drop rescheduling. |
| **ICS** | Active | Imports ICS feeds into daily notes. Read-only. |

**Source:** [obsidian-community/obsidian-full-calendar](https://github.com/obsidian-community/obsidian-full-calendar), [taskgenius/calendar.md](https://github.com/taskgenius/calendar.md)

---

## 5. Existing Implementations

### 5.1 Agenda App ("Notes meet Calendar")

The closest existing model to what Own Calendar wants to achieve.

- Links notes to Apple Calendar events **bidirectionally**
- Notes appear on a timeline alongside calendar events
- Stores an "Agenda link" in the Calendar event's Notes field (portable metadata)
- Uses Apple EventKit natively for calendar access
- Each note can contain tasks (checkboxes) associated with the calendar event

**Key pattern:** Event-to-note linking via metadata stored in the event's notes/description field. This makes the link visible in any calendar client.

**Source:** [agenda.com](https://agenda.com/), [MacStories Agenda review](https://www.macstories.net/reviews/agenda-60-adds-full-integration-with-apples-reminders/)

### 5.2 Fantastical

- Integrates Apple Reminders, Todoist, and Google Tasks into calendar views
- Shows tasks alongside events in the calendar timeline
- Deep links via URL scheme
- No markdown support -- purely native task integrations

**Source:** [flexibits.com/fantastical](https://flexibits.com/fantastical)

### 5.3 Logseq Agenda Plugin

- Overlays a calendar view on journal-embedded tasks
- Imports Google/iCloud events (read-only, public calendars only)
- No bidirectional write-back to external calendars
- Tasks live in daily journal markdown files

**Source:** [haydenull/logseq-plugin-agenda](https://github.com/haydenull/logseq-plugin-agenda)

### 5.4 Notion Calendar

- Database-backed tasks with calendar views
- Proprietary sync (Notion API)
- Not markdown-based
- One-way bridges to Fantastical via Zapier exist

### 5.5 Pattern Summary

| App | Calendar Source | Task Source | Bidirectional | Markdown |
|-----|---------------|-------------|---------------|----------|
| Agenda | Apple Calendar | In-app notes | Yes (event link) | No |
| Fantastical | Multi-platform | Apple Reminders/Todoist | Yes (native APIs) | No |
| Logseq Agenda | ICS import (read-only) | Journal markdown | No | Yes |
| Calendar.MD | Obsidian frontmatter | Obsidian Tasks format | N/A (single source) | Yes |
| **Own Calendar (proposed)** | Multi-platform + own DB | PostgreSQL + markdown | Yes | Yes |

No existing app combines multi-platform calendar sync with markdown-based task management and bidirectional Obsidian integration. This is a genuinely novel combination.

---

## 6. Data Model Recommendations

### 6.1 PostgreSQL Schema (Task Table)

```sql
CREATE TABLE tasks (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id      UUID REFERENCES events(id) ON DELETE SET NULL,
  calendar_id   UUID REFERENCES calendars(id) NOT NULL,
  user_id       UUID REFERENCES users(id) NOT NULL,

  -- Core VTODO fields
  uid           TEXT UNIQUE NOT NULL,        -- iCalendar UID
  summary       TEXT NOT NULL,
  description   TEXT,
  status        TEXT DEFAULT 'NEEDS-ACTION', -- NEEDS-ACTION | IN-PROCESS | COMPLETED | CANCELLED
  priority      INTEGER DEFAULT 0,          -- 0=undefined, 1-4=high, 5=medium, 6-9=low
  percent_complete INTEGER DEFAULT 0,       -- 0-100
  due           TIMESTAMPTZ,
  dtstart       TIMESTAMPTZ,
  completed_at  TIMESTAMPTZ,

  -- Hierarchy
  parent_task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
  sort_order     INTEGER DEFAULT 0,

  -- Sync metadata
  sync_hash     TEXT,                        -- Hash of markdown content for change detection
  obsidian_path TEXT,                        -- Relative path in vault (e.g., "calendar/events/2024-04-16_meeting.md")

  -- Timestamps
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_tasks_event ON tasks(event_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_due ON tasks(due);
```

### 6.2 Markdown File Schema (Per-Event Task File)

**File path pattern:** `<vault>/calendar/events/YYYY-MM-DD_<event-slug>.md`

**Example:** `calendar/events/2026-09-15_team-meeting.md`

```markdown
---
type: event-tasks
event_id: "evt_abc123"
event_uid: "event-042@owncalendar.local"
event_title: "Team Meeting"
calendar: "work"
event_date: 2026-09-15
event_time: "14:00-15:00"
sync_hash: "a3f8c2d1"
synced_at: 2026-09-14T10:30:00Z
---

# Team Meeting
**2026-09-15 14:00-15:00** | Work Calendar

## Tasks

- [ ] Prepare presentation slides 📅 2026-09-14 🔼 🆔 task001
- [ ] Review meeting agenda 📅 2026-09-15 🆔 task002
- [x] Book conference room ✅ 2026-09-10 🆔 task003

## Notes

Free-form notes about this event. This section is owned by Obsidian --
the calendar app will not overwrite content here.
```

### 6.3 Folder Structure

```
vault/
  calendar/
    events/                          # Per-event task files
      2026-09-15_team-meeting.md
      2026-09-16_dentist.md
      2026-09-20_family-dinner.md
    daily/                           # Auto-generated daily summaries (optional)
      2026-09-15.md
    templates/
      event-tasks.md                 # Template for new event task files
```

### 6.4 Naming Convention

`YYYY-MM-DD_<slug>.md` where:
- Date is the event start date (sortable)
- Slug is a URL-safe lowercase version of the event title (max 50 chars)
- Collisions resolved by appending `-2`, `-3`, etc.

### 6.5 iCalendar Export Format

For standards compliance and data portability, tasks should be exportable as VTODO:

```
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Own Calendar//EN
BEGIN:VTODO
UID:task-001@owncalendar.local
DTSTAMP:20260914T103000Z
RELATED-TO;RELTYPE=PARENT:event-042@owncalendar.local
SUMMARY:Prepare presentation slides
DUE:20260914T235959Z
STATUS:NEEDS-ACTION
PRIORITY:3
END:VTODO
END:VCALENDAR
```

---

## 7. Recommended Architecture for Own Calendar

### 7.1 System Architecture

```
Flutter App ←→ Node.js API Server ←→ PostgreSQL
                    ↕                     ↕
           External Calendar APIs    Markdown Sync Engine
                                         ↕
                                   Obsidian Vault (.md files)
                                         ↕
                                   Obsidian App (user's device)
```

### 7.2 Sync Flow: App → Obsidian

1. User creates/modifies a task in the Flutter app
2. API server persists to PostgreSQL
3. **Markdown Sync Engine** (Node.js service, part of the API server):
   - Generates/updates the `.md` file for the event
   - Writes frontmatter with sync metadata (event_id, sync_hash, synced_at)
   - Writes task lines in Obsidian Tasks emoji format
   - Preserves the `## Notes` section (does not overwrite user content)
   - Computes `sync_hash` from the task data and stores it in both DB and frontmatter

### 7.3 Sync Flow: Obsidian → App

1. User modifies a task in Obsidian (checks a checkbox, changes due date, adds a note)
2. **File Watcher** (Node.js `chokidar` or similar) detects the file change
3. Sync Engine:
   - Parses frontmatter to identify the event
   - Parses task lines (Obsidian Tasks format) to extract status, dates, priority
   - Compares `sync_hash` in file vs. DB to detect conflicts
   - Updates PostgreSQL with changes
   - If conflict: **field-level merge** -- structured fields (status, due) use last-modified timestamp; free-text (notes) uses file version

### 7.4 Conflict Resolution Strategy

| Scenario | Resolution |
|----------|-----------|
| App changes task status, Obsidian unchanged | App wins, update file |
| Obsidian changes task status, app unchanged | Obsidian wins, update DB |
| Both changed same field | Last-modified timestamp wins |
| Both changed different fields | Merge both (no conflict) |
| Obsidian adds notes text, app changes task data | Merge both (different sections) |

### 7.5 Deep Linking (Flutter → Obsidian)

The Flutter app can open tasks in Obsidian via URI scheme:

```dart
// Open event's task file in Obsidian
final uri = 'obsidian://open?vault=${vaultName}&file=calendar/events/2026-09-15_team-meeting';
await launchUrl(Uri.parse(uri));
```

This works on iOS, macOS, and desktop platforms where Obsidian is installed.

### 7.6 Configuration

The user configures the integration in the app settings:
- **Vault path** (local filesystem path to the Obsidian vault)
- **Vault name** (for URI deep links)
- **Sync enabled** (on/off toggle)
- **Sync direction** (app-to-vault, vault-to-app, bidirectional)
- **Auto-create files** (whether to create .md files for events without tasks)

### 7.7 Implementation Phases

| Phase | Scope | Depends On |
|-------|-------|-----------|
| **Phase 1: Task CRUD** | Add tasks table to PostgreSQL. Task CRUD API endpoints. Flutter task UI (per-event task list). | Existing event system |
| **Phase 2: Markdown Export** | Generate .md files from tasks. Write to configured vault path. One-way sync (app → vault). | Phase 1 |
| **Phase 3: Obsidian Read-back** | File watcher for vault changes. Parse Obsidian Tasks format. Sync checkbox/date changes back to DB. | Phase 2 |
| **Phase 4: Deep Linking** | Obsidian URI links in Flutter app. "Open in Obsidian" button per event. | Phase 2 |
| **Phase 5: Conflict Resolution** | Sync hash comparison. Field-level merge. Conflict UI in app. | Phase 3 |
| **Phase 6: iCalendar Export** | Export tasks as VTODO with RELATED-TO. Import VTODO from CalDAV sources. | Phase 1 |

---

## Sources

### RFCs and Standards
- [RFC 5545 -- Internet Calendaring (iCalendar)](https://www.rfc-editor.org/rfc/rfc5545) -- VTODO, RELATED-TO, STATUS, etc.
- [RFC 4791 -- CalDAV](https://www.rfc-editor.org/rfc/rfc4791) -- VTODO storage and querying
- [RFC 9253 -- iCalendar Relations](https://datatracker.ietf.org/doc/html/rfc9253) -- Extended RELATED-TO
- [draft-ietf-calext-ical-tasks-12](https://datatracker.ietf.org/doc/html/draft-ietf-calext-ical-tasks-12) -- Task extensions draft
- [GitHub Flavored Markdown Spec](https://github.github.com/gfm/) -- Task list syntax

### Obsidian
- [Obsidian URI Scheme](https://obsidian.md/help/Extending+Obsidian/Obsidian+URI) -- Official deep linking docs
- [Obsidian Vault Types](https://obsidian.md/help/sync/vault-types) -- Sync and file watching
- [Obsidian Tasks Plugin](https://github.com/obsidian-tasks-group/obsidian-tasks) -- Task format and queries
- [Obsidian Tasks Emoji Format](https://publish.obsidian.md/tasks/Reference/Task+Formats/Tasks+Emoji+Format) -- Emoji signifiers
- [Obsidian Dataview](https://blacksmithgu.github.io/obsidian-dataview/annotation/add-metadata/) -- Metadata and queries
- [Advanced URI Plugin](https://publish.obsidian.md/advanced-uri-doc/Home) -- Extended URI scheme

### Obsidian Community Plugins
- [Full Calendar (archived)](https://github.com/obsidian-community/obsidian-full-calendar)
- [Calendar.MD](https://github.com/taskgenius/calendar.md) -- Active calendar plugin
- [Vault File Refresh](https://community.obsidian.md/plugins/vault-file-refresh) -- External file detection

### Calendar Services
- [Google CalDAV v2 Guide](https://developers.google.com/workspace/calendar/caldav/v2/guide) -- No VTODO support
- [Nextcloud Calendar Admin Manual](https://docs.nextcloud.com/server/stable/admin_manual/groupware/calendar.html) -- Full VTODO support

### Existing Implementations
- [Agenda App](https://agenda.com/) -- Notes-calendar bidirectional linking
- [Fantastical](https://flexibits.com/fantastical) -- Multi-source task integration
- [Logseq Agenda Plugin](https://github.com/haydenull/logseq-plugin-agenda) -- Journal-based calendar
- [Agenda MacStories Review](https://www.macstories.net/reviews/agenda-60-adds-full-integration-with-apples-reminders/) -- Reminders integration analysis
