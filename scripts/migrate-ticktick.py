#!/usr/bin/env python3
"""TickTick CSV → own-calendar DB migration script."""

import csv
import io
import subprocess
import sys
import uuid
from datetime import datetime, timezone

CSV_PATH = "/Users/hk/Downloads/TickTick-backup-2026-09-08.csv"
USER_ID = "cmtu2p0so001eyz4f7moqr85g"

# TickTick List → own-calendar config
# type: "event" or "task"
# category: EventCategory enum (for events only)
LIST_CONFIG = {
    "📜Daily TODO":       {"type": "task",  "color": "#F5A623"},
    "💼Work":             {"type": "task",  "color": "#7B68EE", "category": "WORK"},
    "🙍🏻HK schedule":   {"type": "event", "color": "#4A90D9", "category": "PERSONAL"},
    "👩‍❤️‍👨Share schedule": {"type": "event", "color": "#E91E63", "category": "FAMILY"},
    "🧗🏻Climbing":      {"type": "event", "color": "#4CAF50", "category": "HEALTH"},
    "🎮Game":             {"type": "task",  "color": "#9C27B0"},
    "🏌Golf":             {"type": "event", "color": "#8BC34A", "category": "HEALTH"},
    "👰🏻YE schedule":   {"type": "event", "color": "#FF9800", "category": "FAMILY"},
}

SKIP_LISTS = {"🇰🇷Holiday"}

STATUS_MAP = {"0": "TODO", "2": "DONE", "-1": "CANCELLED"}
PRIORITY_MAP = {"0": "NONE", "1": "LOW", "3": "MEDIUM", "5": "HIGH"}


def generate_cuid():
    return "cm" + uuid.uuid4().hex[:23]


def parse_csv(path):
    with open(path, "r", encoding="utf-8-sig") as f:
        lines = f.readlines()

    header_idx = next(i for i, l in enumerate(lines) if l.startswith('"Folder Name"'))
    csv_text = "".join(lines[header_idx:])
    return list(csv.DictReader(io.StringIO(csv_text)))


def escape_sql(s):
    if s is None:
        return "NULL"
    return "'" + s.replace("'", "''").replace("\x00", "") + "'"


def to_timestamp(s):
    if not s or not s.strip():
        return "NULL"
    return escape_sql(s.replace("+0000", "+00:00"))


def build_sql(rows):
    sql_lines = []
    sql_lines.append("-- TickTick Migration Script")
    sql_lines.append(f"-- Generated: {datetime.now(timezone.utc).isoformat()}")
    sql_lines.append(f"-- Records: {len(rows)} (excluding Holiday)")
    sql_lines.append("")
    sql_lines.append("BEGIN;")
    sql_lines.append("")

    # 1. Create calendars
    calendar_ids = {}
    sql_lines.append("-- === Calendars ===")
    for list_name, config in LIST_CONFIG.items():
        cal_id = generate_cuid()
        calendar_ids[list_name] = cal_id
        sql_lines.append(
            f'INSERT INTO "Calendar" (id, name, color, "isDefault", visibility, type, "ownerId", "createdAt", "updatedAt")'
            f" VALUES ({escape_sql(cal_id)}, {escape_sql(list_name)}, {escape_sql(config['color'])}, false, 'PUBLIC', 'PERSONAL', {escape_sql(USER_ID)}, NOW(), NOW());"
        )
    sql_lines.append("")

    # 2. Create events and tasks
    event_count = 0
    task_count = 0
    skipped = 0

    sql_lines.append("-- === Events & Tasks ===")
    for row in rows:
        list_name = row["List Name"]
        if list_name in SKIP_LISTS:
            skipped += 1
            continue

        config = LIST_CONFIG.get(list_name)
        if not config:
            skipped += 1
            continue

        cal_id = calendar_ids[list_name]
        title = row["Title"].strip()
        if not title:
            skipped += 1
            continue

        description = row["Content"].strip() if row["Content"].strip() else None
        # Clean up obsidian links in description
        if description:
            import re
            description = re.sub(r'\[📜Daily TODO\.md\]\(obsidian://[^)]+\)', '', description).strip()
            if not description:
                description = None

        created_at = to_timestamp(row["Created Time"])
        status_raw = row["Status"].strip()
        start_date = row["Start Date"].strip()
        due_date = row["Due Date"].strip()
        is_all_day = row["Is All Day"].strip().lower() == "true"
        completed_time = row["Completed Time"].strip()

        record_id = generate_cuid()

        if config["type"] == "event":
            # Event: needs startTime and endTime
            if not start_date or not due_date:
                if created_at != "NULL":
                    start_ts = to_timestamp(row["Created Time"])
                    end_ts = start_ts
                else:
                    skipped += 1
                    continue
            else:
                start_ts = to_timestamp(start_date)
                end_ts = to_timestamp(due_date)
                # All-day single-day events: endTime = startTime + 1 day
                if is_all_day and start_date == due_date:
                    from datetime import timedelta
                    dt = datetime.fromisoformat(start_date.replace("+0000", "+00:00"))
                    end_dt = dt + timedelta(days=1)
                    end_ts = escape_sql(end_dt.strftime("%Y-%m-%dT%H:%M:%S+00:00"))

            category = config.get("category", "PERSONAL")

            sql_lines.append(
                f'INSERT INTO "Event" (id, title, description, "startTime", "endTime", "isAllDay", "isPrivate", category, tags, "recurrenceType", "calendarId", "createdById", "createdAt", "updatedAt")'
                f" VALUES ({escape_sql(record_id)}, {escape_sql(title)}, {escape_sql(description)}, {start_ts}, {end_ts}, {str(is_all_day).lower()}, false, {escape_sql(category)}, ARRAY[]::text[], 'NONE', {escape_sql(cal_id)}, {escape_sql(USER_ID)}, {created_at}, {created_at});"
            )
            event_count += 1

        else:
            # Task
            task_status = STATUS_MAP.get(status_raw, "TODO")
            priority = PRIORITY_MAP.get(row["Priority"].strip(), "NONE")
            due_ts = to_timestamp(due_date) if due_date else "NULL"
            scheduled_ts = to_timestamp(start_date) if start_date else "NULL"
            completed_ts = to_timestamp(completed_time) if completed_time and task_status == "DONE" else "NULL"

            # For timed tasks, extract HH:mm
            scheduled_time = "NULL"
            if start_date and not is_all_day:
                try:
                    dt = datetime.fromisoformat(start_date.replace("+0000", "+00:00"))
                    if dt.hour != 0 or dt.minute != 0:
                        # Convert to KST (UTC+9)
                        from datetime import timedelta
                        kst = dt + timedelta(hours=9)
                        scheduled_time = escape_sql(f"{kst.hour:02d}:{kst.minute:02d}")
                except (ValueError, AttributeError):
                    pass

            sql_lines.append(
                f'INSERT INTO "Task" (id, title, description, status, priority, "dueDate", "scheduledDate", "scheduledTime", "recurrenceType", "completedAt", "calendarId", "createdById", "sortOrder", "createdAt", "updatedAt")'
                f" VALUES ({escape_sql(record_id)}, {escape_sql(title)}, {escape_sql(description)}, {escape_sql(task_status)}, {escape_sql(priority)}, {due_ts}, {scheduled_ts}, {scheduled_time}, 'NONE', {completed_ts}, {escape_sql(cal_id)}, {escape_sql(USER_ID)}, 0, {created_at}, {created_at});"
            )
            task_count += 1

    sql_lines.append("")
    sql_lines.append("COMMIT;")
    sql_lines.append("")
    sql_lines.append(f"-- Summary: {event_count} events, {task_count} tasks, {skipped} skipped")

    return "\n".join(sql_lines), event_count, task_count, skipped


def main():
    print("Parsing TickTick CSV...")
    rows = parse_csv(CSV_PATH)
    print(f"  Total records: {len(rows)}")

    print("Generating SQL...")
    sql, events, tasks, skipped = build_sql(rows)

    out_path = "/Users/hk/workspace/own-calendar/scripts/ticktick-migration.sql"
    with open(out_path, "w") as f:
        f.write(sql)

    print(f"\nSQL written to: {out_path}")
    print(f"  Calendars: {len(LIST_CONFIG)}")
    print(f"  Events:    {events}")
    print(f"  Tasks:     {tasks}")
    print(f"  Skipped:   {skipped}")

    if "--dry-run" in sys.argv:
        print("\n[DRY RUN] SQL not executed.")
        return

    print("\nExecuting SQL against database...")
    result = subprocess.run(
        ["docker", "compose", "exec", "-T", "postgres",
         "psql", "-U", "postgres", "-d", "own_calendar"],
        input=sql, capture_output=True, text=True,
        cwd="/Users/hk/workspace/own-calendar/server"
    )

    if result.returncode == 0:
        print("Migration complete!")
        print(result.stdout[-500:] if len(result.stdout) > 500 else result.stdout)
    else:
        print(f"ERROR: {result.stderr}")
        sys.exit(1)


if __name__ == "__main__":
    main()
