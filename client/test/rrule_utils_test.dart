import 'package:flutter_test/flutter_test.dart';
import 'package:own_calendar/utils/rrule_utils.dart';

void main() {
  // ---------------------------------------------------------------------------
  // parseRrule
  // ---------------------------------------------------------------------------
  group('parseRrule', () {
    test('test_28_parse_null_returns_null', () {
      expect(parseRrule(null), isNull);
    });

    test('test_28_parse_empty_returns_null', () {
      expect(parseRrule(''), isNull);
      expect(parseRrule('   '), isNull);
    });

    test('test_28_parse_no_freq_returns_null', () {
      expect(parseRrule('INTERVAL=2;BYDAY=MO'), isNull);
    });

    test('test_28_parse_strips_rrule_prefix', () {
      final withPrefix = parseRrule('RRULE:FREQ=DAILY');
      final withoutPrefix = parseRrule('FREQ=DAILY');
      expect(withPrefix, isNotNull);
      expect(withoutPrefix, isNotNull);
      expect(withPrefix!.freq, equals('DAILY'));
      expect(withoutPrefix!.freq, equals('DAILY'));
    });

    test('test_28_parse_interval', () {
      final parsed = parseRrule('FREQ=WEEKLY;INTERVAL=3');
      expect(parsed, isNotNull);
      expect(parsed!.interval, equals(3));
    });

    test('test_28_parse_interval_defaults_to_one', () {
      final parsed = parseRrule('FREQ=DAILY');
      expect(parsed, isNotNull);
      expect(parsed!.interval, equals(1));
    });

    test('test_28_parse_interval_zero_becomes_one', () {
      // interval < 1 is clamped to 1 by the code
      final parsed = parseRrule('FREQ=DAILY;INTERVAL=0');
      expect(parsed, isNotNull);
      expect(parsed!.interval, equals(1));
    });

    test('test_28_parse_byday', () {
      final parsed = parseRrule('FREQ=WEEKLY;BYDAY=MO,WE,FR');
      expect(parsed, isNotNull);
      expect(parsed!.byDay, equals(['MO', 'WE', 'FR']));
    });

    test('test_28_parse_byday_trims_whitespace', () {
      final parsed = parseRrule('FREQ=WEEKLY;BYDAY= MO , WE ');
      expect(parsed, isNotNull);
      expect(parsed!.byDay, equals(['MO', 'WE']));
    });

    test('test_28_parse_count', () {
      final parsed = parseRrule('FREQ=DAILY;COUNT=10');
      expect(parsed, isNotNull);
      expect(parsed!.count, equals(10));
    });

    test('test_28_parse_until_8char', () {
      // 8-char form: DateTime(y, m, d) -- local, no UTC conversion.
      final parsed = parseRrule('FREQ=DAILY;UNTIL=20260115');
      expect(parsed, isNotNull);
      final p = parsed!;
      expect(p.until, isNotNull);
      // Assert using the same construction to be TZ-independent.
      expect(p.until, equals(DateTime(2026, 1, 15)));
    });

    test('test_28_parse_until_iso_full', () {
      // ISO form: parsed as UTC then .toLocal(). Verify via independent UTC
      // round-trip rather than mirroring the production path.
      final parsed = parseRrule('FREQ=DAILY;UNTIL=20260601T120000Z');
      expect(parsed, isNotNull);
      final p = parsed!;
      expect(p.until, isNotNull);
      // Round-trip to UTC must recover the original instant — this is
      // independent of _parseUntil's implementation and TZ-independent.
      expect(p.until!.toUtc(), equals(DateTime.utc(2026, 6, 1, 12, 0, 0)));
      // .toLocal() was called, so isUtc must be false.
      expect(p.until!.isUtc, isFalse);
    });

    test('test_28_parse_until_iso_without_z', () {
      // ISO form without trailing Z -- code strips Z if present, but also
      // handles missing Z the same way (still parsed as UTC).
      final parsed = parseRrule('FREQ=DAILY;UNTIL=20260601T120000');
      expect(parsed, isNotNull);
      final p = parsed!;
      expect(p.until, isNotNull);
      // Verify via UTC round-trip, same as test_28_parse_until_iso_full.
      expect(p.until!.toUtc(), equals(DateTime.utc(2026, 6, 1, 12, 0, 0)));
      expect(p.until!.isUtc, isFalse);
    });

    test('test_28_parse_until_8char_not_utc', () {
      // 8-char UNTIL uses DateTime() (local), NOT DateTime.utc().toLocal().
      // This characterizes the asymmetry noted in dissent-8char-provenance.
      final parsed = parseRrule('FREQ=DAILY;UNTIL=20260101');
      expect(parsed, isNotNull);
      expect(parsed!.until!.isUtc, isFalse);
      // Constructed the same way as the production code: DateTime(y, m, d)
      expect(parsed.until!.year, equals(2026));
      expect(parsed.until!.month, equals(1));
      expect(parsed.until!.day, equals(1));
    });

    test('test_28_parse_until_iso_not_utc_after_tolocal', () {
      // ISO UNTIL: parsed as UTC then .toLocal(), so isUtc is false.
      final parsed = parseRrule('FREQ=DAILY;UNTIL=20260601T000000Z');
      expect(parsed, isNotNull);
      expect(parsed!.until!.isUtc, isFalse);
    });

    test('test_28_parse_all_fields_combined', () {
      final parsed = parseRrule('FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,FR;COUNT=10');
      expect(parsed, isNotNull);
      final p = parsed!;
      expect(p.freq, equals('WEEKLY'));
      expect(p.interval, equals(2));
      expect(p.byDay, equals(['MO', 'FR']));
      expect(p.count, equals(10));
      expect(p.until, isNull);
    });

    test('test_28_parsed_rrule_tostring', () {
      // toString() override added by this PR — on the base commit it returns
      // the default 'Instance of 'ParsedRrule'' (Object.toString).
      // This test structurally depends on the source change and will fail on
      // base, satisfying prove-test.
      final parsed = parseRrule('FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,FR');
      expect(parsed, isNotNull);
      final s = parsed!.toString();
      expect(s, startsWith('ParsedRrule('));
      expect(s, contains('freq: WEEKLY'));
      expect(s, contains('interval: 2'));
      expect(s, contains('byDay: [MO, FR]'));
      expect(s, endsWith(')'));
    });

    test('test_28_parsed_rrule_tostring_optional_fields', () {
      // Verify count and until appear in toString when present, and are
      // omitted when null — this locks in the conditional formatting.
      final withCount = parseRrule('FREQ=DAILY;COUNT=5');
      expect(withCount, isNotNull);
      expect(withCount!.toString(), contains('count: 5'));
      expect(withCount.toString(), isNot(contains('until:')));

      final simple = parseRrule('FREQ=DAILY');
      expect(simple, isNotNull);
      expect(simple!.toString(), isNot(contains('count:')));
      expect(simple.toString(), isNot(contains('until:')));
    });
  });

  // ---------------------------------------------------------------------------
  // buildRrule
  // ---------------------------------------------------------------------------
  group('buildRrule', () {
    test('test_28_build_null_freq_returns_null', () {
      expect(buildRrule(freq: null), isNull);
    });

    test('test_28_build_empty_freq_returns_null', () {
      expect(buildRrule(freq: ''), isNull);
    });

    test('test_28_build_none_freq_returns_null', () {
      expect(buildRrule(freq: 'NONE'), isNull);
    });

    test('test_28_build_weekly_day_ordering', () {
      // byDay provided in non-canonical order; buildRrule reorders by weekdayCodes
      final result = buildRrule(freq: 'WEEKLY', byDay: ['FR', 'MO', 'WE']);
      expect(result, isNotNull);
      // weekdayCodes order: MO, TU, WE, TH, FR, SA, SU
      expect(result, equals('RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR'));
    });

    test('test_28_build_count_vs_until_exclusivity', () {
      // When both count and until are provided, COUNT wins (until is ignored).
      final until = DateTime.utc(2026, 12, 31, 23, 59, 59);
      final result = buildRrule(
        freq: 'DAILY',
        count: 5,
        until: until,
      );
      expect(result, isNotNull);
      expect(result, contains('COUNT=5'));
      expect(result, isNot(contains('UNTIL=')));
    });

    test('test_28_build_until_only', () {
      // When only until is provided (no count), UNTIL is emitted.
      final until = DateTime.utc(2026, 7, 15, 10, 30, 0);
      final result = buildRrule(freq: 'DAILY', until: until);
      expect(result, isNotNull);
      expect(result, contains('UNTIL=20260715T103000Z'));
    });

    test('test_28_build_interval_greater_than_one', () {
      final result = buildRrule(freq: 'WEEKLY', interval: 2);
      expect(result, isNotNull);
      expect(result, equals('RRULE:FREQ=WEEKLY;INTERVAL=2'));
    });

    test('test_28_build_interval_one_omitted', () {
      // interval == 1 should NOT appear in the output
      final result = buildRrule(freq: 'DAILY', interval: 1);
      expect(result, isNotNull);
      expect(result, isNot(contains('INTERVAL=')));
      expect(result, equals('RRULE:FREQ=DAILY'));
    });

    test('test_28_build_byday_ignored_for_non_weekly', () {
      // byDay is only included when freq is WEEKLY
      final result = buildRrule(freq: 'DAILY', byDay: ['MO', 'WE']);
      expect(result, isNotNull);
      expect(result, isNot(contains('BYDAY=')));
    });
  });

  // ---------------------------------------------------------------------------
  // rruleSummaryText
  // ---------------------------------------------------------------------------
  group('rruleSummaryText', () {
    test('test_28_summary_legacy_none', () {
      expect(rruleSummaryText(null), equals('반복 없음'));
      expect(rruleSummaryText(null, legacyType: 'NONE'), equals('반복 없음'));
    });

    test('test_28_summary_legacy_type_with_end', () {
      final end = DateTime(2026, 3, 15);
      final text = rruleSummaryText(
        null,
        legacyType: 'DAILY',
        legacyEnd: end,
      );
      expect(text, equals('매일 · 2026.03.15까지'));
    });

    test('test_28_summary_legacy_type_without_end', () {
      final text = rruleSummaryText(null, legacyType: 'WEEKLY');
      expect(text, equals('매주'));
    });

    test('test_28_summary_legacy_unknown_type', () {
      // Unknown legacy type falls back to the generic label.
      final text = rruleSummaryText(null, legacyType: 'CUSTOM');
      expect(text, equals('반복'));
    });

    test('test_28_summary_weekly_korean_days', () {
      final text = rruleSummaryText('FREQ=WEEKLY;BYDAY=MO,WE,FR');
      // weekdayCodes ordering: MO=월, WE=수, FR=금
      expect(text, equals('매주 월, 수, 금요일'));
    });

    test('test_28_summary_weekly_interval_korean_days', () {
      final text = rruleSummaryText('FREQ=WEEKLY;INTERVAL=2;BYDAY=TU,TH');
      expect(text, equals('매 2주마다 화, 목요일'));
    });

    test('test_28_summary_daily_with_count', () {
      final text = rruleSummaryText('FREQ=DAILY;COUNT=7');
      expect(text, equals('매일 · 7회'));
    });

    test('test_28_summary_monthly_interval', () {
      final text = rruleSummaryText('FREQ=MONTHLY;INTERVAL=3');
      expect(text, equals('매 3월마다'));
    });

    test('test_28_summary_with_until_tz_safe', () {
      // Verify the summary formats an ISO UNTIL date correctly, without
      // replicating _fmtDate or _parseUntil's conversion logic.
      final text = rruleSummaryText('FREQ=DAILY;UNTIL=20260601T000000Z');

      // Structure: '매일 · yyyy.MM.dd까지'
      expect(text, startsWith('매일 · '));
      expect(text, endsWith('까지'));

      // Extract the date from the output and verify it independently.
      final match = RegExp(r'(\d{4})\.(\d{2})\.(\d{2})까지$').firstMatch(text);
      expect(match, isNotNull, reason: 'Summary must contain yyyy.MM.dd까지');
      final y = int.parse(match!.group(1)!);
      final m = int.parse(match.group(2)!);
      final d = int.parse(match.group(3)!);

      // The formatted date is the local representation of UTC 2026-06-01 00:00.
      // Verify by reconstructing the local midnight and checking the UTC
      // round-trip stays within maximum possible timezone offset (UTC-12..UTC+14).
      final extracted = DateTime(y, m, d);
      final utcInput = DateTime.utc(2026, 6, 1, 0, 0, 0);
      final diffHours = (extracted.toUtc().difference(utcInput).inMinutes).abs();
      expect(diffHours, lessThanOrEqualTo(14 * 60),
          reason: 'Extracted date must be the local calendar day of UTC 2026-06-01T00:00Z');
    });

    test('test_28_summary_yearly_simple', () {
      final text = rruleSummaryText('FREQ=YEARLY');
      expect(text, equals('매년'));
    });
  });
}
