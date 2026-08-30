/**
 * TickTick CSV → Own Calendar import.
 *
 * Default mode is dry-run (parse + normalize, print summary).
 * Pass --apply to actually write to the database.
 * Pass --owner <email> to choose the owning user (default: hk).
 *
 * Usage:
 *   tsx scripts/import-ticktick.ts <csv-path>
 *   tsx scripts/import-ticktick.ts <csv-path> --apply
 *   tsx scripts/import-ticktick.ts <csv-path> --apply --owner hk
 */

import { readFileSync } from 'node:fs';
import { parse } from 'csv-parse/sync';
import { PrismaClient } from '../src/generated/prisma/client';

type CsvRow = Record<string, string>;

interface ProposedEvent {
  externalId: string;          // ticktick:{taskId}
  calendarBucket: string;      // List Name → 향후 Calendar.name
  title: string;
  description: string | null;
  startTime: Date;
  endTime: Date;
  isAllDay: boolean;
  isPrivate: boolean;
  // 참고용 메타 (DB에는 안 들어가지만 dry-run 검토에 필요)
  _sourceTimezone: string;
  _kind: 'TEXT' | 'CHECKLIST';
  _ticktickStatus: string;     // 0/1/2
}

interface SkipReason {
  taskId: string;
  title: string;
  reason: string;
}

function readCsv(path: string): CsvRow[] {
  const raw = readFileSync(path, 'utf8').replace(/^﻿/, '');
  // 메타 record(Date/Version/Status, multi-line)는 1컬럼이라 strict CSV로 읽으면 컬럼 수 불일치.
  // 헤더 시작 위치(첫 `"Folder Name"`)부터 잘라내서 파싱한다.
  const headerStart = raw.indexOf('"Folder Name"');
  if (headerStart < 0) throw new Error('헤더(Folder Name)를 찾지 못함 — CSV 형식이 변경되었을 수 있음');
  const body = raw.slice(headerStart);
  return parse(body, {
    columns: true,
    skip_empty_lines: true,
    relax_column_count: false,
  }) as CsvRow[];
}

/**
 * TickTick은 종일 일정의 시간을 "타임존 자정에 해당하는 UTC instant"로 저장한다.
 * 예: KST 2026-02-16 종일 → CSV에는 "2026-02-15T14:00:00+0000".
 * 그대로 Date로 저장하면 사용자 지역에 따라 하루 어긋난다.
 *
 * 정책: All-day 이벤트는
 *   - startTime: 해당 TZ 기준 자정의 UTC instant (CSV 값 그대로 — TickTick이 이미 그렇게 저장)
 *   - endTime: Due Date (TickTick은 같은 TZ의 자정으로 줘서 그대로 사용 가능)
 * → 즉, CSV 값을 그대로 Date로 만들면 instant는 정확하다.
 *   *표시할 때* 반드시 _sourceTimezone 기준으로 렌더링해야 함을 메모.
 */
function parseDate(iso: string): Date | null {
  if (!iso) return null;
  const d = new Date(iso);
  return isNaN(d.getTime()) ? null : d;
}

function formatChecklistAsDescription(content: string): string {
  // CHECKLIST의 Content는 "▫미체크\r▪체크\r..." 형태
  // \r 단위로 split → markdown 체크박스로 변환
  return content
    .split(/\r\n|\r|\n/)
    .filter((line) => line.length > 0)
    .map((line) => {
      if (line.startsWith('▫')) return `- [ ] ${line.slice(1).trim()}`;
      if (line.startsWith('▪')) return `- [x] ${line.slice(1).trim()}`;
      return line;
    })
    .join('\n');
}

function buildDescription(row: CsvRow): string | null {
  // 정책: Tags 제외, List 표기 제외 — 순수 사용자 입력만 보존.
  if (!row.Content) return null;
  if (row.Kind === 'CHECKLIST') return formatChecklistAsDescription(row.Content);
  return row.Content.replace(/\r\n|\r/g, '\n');
}

/**
 * 모든 일정을 Asia/Seoul 기준 종일로 정규화한다.
 * KST는 UTC+9 고정(DST 없음).
 */
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;
function toAllDayKstMidnight(d: Date): Date {
  const kstShifted = d.getTime() + KST_OFFSET_MS;
  const dayMs = 24 * 60 * 60 * 1000;
  const kstMidnightShifted = Math.floor(kstShifted / dayMs) * dayMs;
  return new Date(kstMidnightShifted - KST_OFFSET_MS);
}

function normalize(rows: CsvRow[]): { events: ProposedEvent[]; skipped: SkipReason[] } {
  const events: ProposedEvent[] = [];
  const skipped: SkipReason[] = [];

  for (const row of rows) {
    const taskId = row.taskId || '(no-id)';
    const title = row.Title || '';
    const start = parseDate(row['Start Date']);
    const due = parseDate(row['Due Date']);

    if (!title) {
      skipped.push({ taskId, title: '(empty)', reason: 'no title' });
      continue;
    }
    if (!start && !due) {
      skipped.push({ taskId, title, reason: 'no start/due date' });
      continue;
    }

    // 전부 KST 종일로 강제 정규화
    const rawStart = start ?? due!;
    const rawEnd = due ?? start!;
    const startTime = toAllDayKstMidnight(rawStart);
    let endTime = toAllDayKstMidnight(rawEnd);
    if (endTime.getTime() < startTime.getTime()) endTime = startTime;
    const kind = row.Kind === 'CHECKLIST' ? 'CHECKLIST' : 'TEXT';

    events.push({
      externalId: `ticktick:${taskId}`,
      calendarBucket: row['List Name'] || '(no list)',
      title,
      description: buildDescription(row),
      startTime,
      endTime,
      isAllDay: true,
      isPrivate: false,
      _sourceTimezone: 'Asia/Seoul',
      _kind: kind,
      _ticktickStatus: row.Status,
    });
  }

  return { events, skipped };
}

function fmtDateInTz(d: Date, tz: string): string {
  // Intl로 TZ 기준 표시 (정규화 검증용)
  return new Intl.DateTimeFormat('ko-KR', {
    timeZone: tz,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(d);
}

// 9개 List에 부여할 색 팔레트 (List Name이 9개를 넘으면 wrap)
const CALENDAR_COLORS = [
  '#E74C3C', '#3498DB', '#2ECC71', '#F39C12', '#9B59B6',
  '#1ABC9C', '#E91E63', '#34495E', '#FF6F61',
];

async function applyToDb(
  events: ProposedEvent[],
  ownerEmail: string,
): Promise<void> {
  const prisma = new PrismaClient();
  try {
    const owner = await prisma.user.findUnique({ where: { email: ownerEmail } });
    if (!owner) throw new Error(`User not found: email=${ownerEmail}`);
    console.log(`\n👤 Owner: ${owner.email} (${owner.id})`);

    // 1) List별 Calendar 9개 — 같은 (ownerId, name)이 이미 있으면 재사용
    const buckets = [...new Set(events.map((e) => e.calendarBucket))];
    const calendarByBucket = new Map<string, string>(); // bucket → calendarId
    for (let i = 0; i < buckets.length; i++) {
      const name = buckets[i];
      const existing = await prisma.calendar.findFirst({
        where: { ownerId: owner.id, name, type: 'PERSONAL' },
      });
      if (existing) {
        calendarByBucket.set(name, existing.id);
        console.log(`  · 캘린더 재사용  ${name}  (${existing.id})`);
      } else {
        const created = await prisma.calendar.create({
          data: {
            name,
            color: CALENDAR_COLORS[i % CALENDAR_COLORS.length],
            ownerId: owner.id,
            type: 'PERSONAL',
            visibility: 'PRIVATE',
            isDefault: false,
          },
        });
        calendarByBucket.set(name, created.id);
        console.log(`  + 캘린더 생성    ${name}  (${created.id})  ${created.color}`);
      }
    }

    // 2) Event upsert: 기존 ticktick: prefix events를 미리 조회해서 set 만들고
    //    set에 없는 것만 createMany. (재실행해도 중복 안 만들어지게)
    const existingIds = new Set(
      (
        await prisma.event.findMany({
          where: {
            calendarId: { in: [...calendarByBucket.values()] },
            externalId: { startsWith: 'ticktick:' },
          },
          select: { externalId: true },
        })
      )
        .map((e) => e.externalId)
        .filter((x): x is string => !!x),
    );

    const toCreate = events.filter((e) => !existingIds.has(e.externalId));
    const toSkip = events.length - toCreate.length;

    console.log(`\n  Events to create: ${toCreate.length}`);
    console.log(`  Already exist (skip): ${toSkip}`);

    if (toCreate.length === 0) {
      console.log('\n✓ 새로 만들 일정 없음.');
      return;
    }

    const result = await prisma.event.createMany({
      data: toCreate.map((e) => ({
        externalId: e.externalId,
        title: e.title,
        description: e.description,
        startTime: e.startTime,
        endTime: e.endTime,
        isAllDay: e.isAllDay,
        isPrivate: e.isPrivate,
        calendarId: calendarByBucket.get(e.calendarBucket)!,
        createdById: owner.id,
      })),
    });
    console.log(`\n✓ Inserted ${result.count} events.`);
  } finally {
    await prisma.$disconnect();
  }
}

async function main() {
  const args = process.argv.slice(2);
  const csvPath = args.find((a) => !a.startsWith('--'));
  const apply = args.includes('--apply');
  const ownerIdx = args.indexOf('--owner');
  const ownerEmail = ownerIdx >= 0 ? args[ownerIdx + 1] : 'hk';

  if (!csvPath) {
    console.error('Usage: tsx scripts/import-ticktick.ts <csv-path> [--apply] [--owner <email>]');
    process.exit(1);
  }

  console.log(`\n📂 Reading: ${csvPath}`);
  console.log(`   Mode: ${apply ? '⚡ APPLY (DB write)' : '🔍 DRY-RUN'}`);
  if (apply) console.log(`   Owner: ${ownerEmail}\n`);
  else console.log('');

  const rows = readCsv(csvPath);
  console.log(`✓ Parsed ${rows.length} CSV rows\n`);

  const { events, skipped } = normalize(rows);

  // ── 통계
  console.log('═══ 정규화 결과 ═══');
  console.log(`  변환됨:   ${events.length}`);
  console.log(`  스킵:     ${skipped.length}`);
  console.log(`  종일:     ${events.filter((e) => e.isAllDay).length}`);
  console.log(`  CHECKLIST:${events.filter((e) => e._kind === 'CHECKLIST').length}`);

  // List(=캘린더 버킷)별 분포
  const byList = new Map<string, number>();
  for (const e of events) byList.set(e.calendarBucket, (byList.get(e.calendarBucket) ?? 0) + 1);
  console.log('\n═══ 캘린더 버킷 (List Name) ═══');
  [...byList.entries()]
    .sort((a, b) => b[1] - a[1])
    .forEach(([k, v]) => console.log(`  ${v.toString().padStart(4)}  ${k}`));

  // TZ 분포
  const byTz = new Map<string, number>();
  for (const e of events) byTz.set(e._sourceTimezone, (byTz.get(e._sourceTimezone) ?? 0) + 1);
  console.log('\n═══ Timezone ═══');
  [...byTz.entries()].forEach(([k, v]) => console.log(`  ${v.toString().padStart(4)}  ${k}`));

  // 스킵 사유
  if (skipped.length > 0) {
    console.log('\n═══ 스킵된 row ═══');
    skipped.forEach((s) =>
      console.log(`  [${s.taskId}] ${s.title.slice(0, 40)} — ${s.reason}`),
    );
  }

  // ── 샘플 (각 List에서 1건씩, 종일/시각 일정 골고루)
  console.log('\n═══ 샘플 (List별 1건) ═══');
  const seenLists = new Set<string>();
  for (const e of events) {
    if (seenLists.has(e.calendarBucket)) continue;
    seenLists.add(e.calendarBucket);
    console.log(`\n── ${e.calendarBucket} ──`);
    console.log(`  externalId: ${e.externalId}`);
    console.log(`  title:      ${e.title}`);
    console.log(`  isAllDay:   ${e.isAllDay}  kind: ${e._kind}  status: ${e._ticktickStatus}`);
    console.log(`  startTime:  ${e.startTime.toISOString()}`);
    console.log(`              → ${fmtDateInTz(e.startTime, e._sourceTimezone)} (${e._sourceTimezone})`);
    console.log(`  endTime:    ${e.endTime.toISOString()}`);
    console.log(`              → ${fmtDateInTz(e.endTime, e._sourceTimezone)} (${e._sourceTimezone})`);
    if (e.description) {
      const preview = e.description.split('\n').slice(0, 4).join('\n    ');
      console.log(`  description:\n    ${preview}${e.description.split('\n').length > 4 ? '\n    ...' : ''}`);
    }
  }

  // CHECKLIST 샘플 1건 추가 (위 샘플에 안 잡혔을 수 있음)
  const cl = events.find((e) => e._kind === 'CHECKLIST');
  if (cl) {
    console.log('\n── CHECKLIST 변환 샘플 ──');
    console.log(`  title: ${cl.title}`);
    console.log(`  description:\n    ${cl.description?.split('\n').join('\n    ')}`);
  }

  if (!apply) {
    console.log('\n✓ Dry-run 끝. DB에는 아무것도 쓰지 않았습니다.');
    return;
  }

  console.log('\n═══ DB 적용 ═══');
  await applyToDb(events, ownerEmail);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
