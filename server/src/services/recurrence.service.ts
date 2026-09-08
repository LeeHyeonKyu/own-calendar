import { RRule } from 'rrule';

function formatRRuleDate(d: Date): string {
  return d.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
}

const FREQ_MAP: Record<string, string> = {
  DAILY: 'DAILY',
  WEEKLY: 'WEEKLY',
  MONTHLY: 'MONTHLY',
  YEARLY: 'YEARLY',
};

export const recurrenceService = {
  /**
   * Parse an RRULE string (with a DTSTART anchor) and expand instance start
   * dates that fall within [rangeStart, rangeEnd] (inclusive).
   */
  expandInstances(rruleStr: string, dtstart: Date, rangeStart: Date, rangeEnd: Date): Date[] {
    if (!rruleStr) return [];
    const normalized = rruleStr.startsWith('RRULE:') ? rruleStr : `RRULE:${rruleStr}`;
    const rule = RRule.fromString(`DTSTART:${formatRRuleDate(dtstart)}\n${normalized}`);
    return rule.between(rangeStart, rangeEnd, true);
  },

  /**
   * Build an RRULE string from the legacy recurrenceType/recurrenceEnd
   * fields, for backward compatibility with events/tasks that predate the
   * rrule column.
   */
  buildRRuleFromLegacy(recurrenceType: string, recurrenceEnd: Date | null): string | null {
    if (!recurrenceType || recurrenceType === 'NONE') return null;
    const freq = FREQ_MAP[recurrenceType];
    if (!freq) return null;

    let rrule = `FREQ=${freq}`;
    if (recurrenceEnd) {
      rrule += `;UNTIL=${formatRRuleDate(recurrenceEnd)}`;
    }
    return `RRULE:${rrule}`;
  },

  /**
   * Resolve the effective RRULE string for an entity: an explicit `rrule`
   * field takes precedence over the legacy recurrenceType/recurrenceEnd
   * fields.
   */
  resolveRRule(entity: { rrule?: string | null; recurrenceType?: string | null; recurrenceEnd?: Date | null }): string | null {
    if (entity.rrule) return entity.rrule;
    if (entity.recurrenceType && entity.recurrenceType !== 'NONE') {
      return recurrenceService.buildRRuleFromLegacy(entity.recurrenceType, entity.recurrenceEnd ?? null);
    }
    return null;
  },

  /**
   * Generate a human-readable summary of an RRULE string.
   */
  toText(rruleStr: string, dtstart: Date): string {
    const normalized = rruleStr.startsWith('RRULE:') ? rruleStr : `RRULE:${rruleStr}`;
    const rule = RRule.fromString(`DTSTART:${formatRRuleDate(dtstart)}\n${normalized}`);
    return rule.toText();
  },

  /**
   * Append (or set) an UNTIL clause on an RRULE string so the recurrence
   * stops at/just before the given date. Used for "this and future" edits
   * and deletes.
   */
  truncateRRule(rruleStr: string, until: Date): string {
    const normalized = rruleStr.startsWith('RRULE:') ? rruleStr.slice('RRULE:'.length) : rruleStr;
    const parts = normalized.split(';').filter((p) => !p.startsWith('UNTIL='));
    parts.push(`UNTIL=${formatRRuleDate(until)}`);
    return `RRULE:${parts.join(';')}`;
  },

  formatRRuleDate,
};
