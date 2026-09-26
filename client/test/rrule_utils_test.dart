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
      // 8-char form: DateTime(y, m, d) — local, no UTC conversion.
      final parsed = parseRrule('FREQ=DAILY;UNTIL=20260115');
      expect(parsed, isNotNull);
      final p = parsed!;
      expect(p.until, isNotNull);
      // The code creates DateTime(2026, 1, 15) which is local.
      // Assert using the same construction to be TZ-independent.
      expect(p.until, equals(DateTime(2026, 1, 15)));
    });

    test('test_28_parse_until_iso_full', () {
      // ISO form: DateTime.utc(...).toLocal() — parsed as UTC then converted.
      final parsed = parseRrule('FREQ=DAILY;UNTIL=20260601T120000Z');
      expect(parsed, isNotNull);
      final p = parsed!;
      expect(p.until, isNotNull);
      // Derive expected value via the same path the production code uses:
      // DateTime.utc(2026, 6, 1, 12, 0, 0).toLocal()
      final expected = DateTime.utc(2026, 6, 1, 12, 0, 0).toLocal();
      expect(p.until, equals(expected));
    });

    test('test_28_parse_until_iso_without_z', () {
      // ISO form without trailing Z — code strips Z if present, but also
      // handles missing Z the same way (still parsed as UTC).
      final parsed = parseRrule('FREQ=DAILY;UNTIL=20260601T120000');
      expect(parsed, isNotNull);
      final p = parsed!;
      expect(p.until, isNotNull);
      final expected = DateTime.utc(2026, 6, 1, 12, 0, 0).toLocal();
      expect(p.until, equals(expected));
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
      // UNTIL with ISO form: the summary formats the local DateTime via _fmtDate.
      // To be TZ-independent, derive expected from the same UTC-to-local path.
      final expectedLocal = DateTime.utc(2026, 6, 1, 0, 0, 0).toLocal();
      final expectedDateStr =
          '${expectedLocal.year}.${expectedLocal.month.toString().padLeft(2, '0')}.${expectedLocal.day.toString().padLeft(2, '0')}';

      final text = rruleSummaryText('FREQ=DAILY;UNTIL=20260601T000000Z');
      expect(text, equals('매일 · $expectedDateStr까지'));
    });
  });
}
