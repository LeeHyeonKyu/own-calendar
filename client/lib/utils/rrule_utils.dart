/// Lightweight utilities for building and reading RFC 5545 RRULE strings
/// on the client side. This is only used for UI display and for
/// constructing the `rrule` string sent to the server — actual recurrence
/// expansion always happens server-side.
library;

class ParsedRrule {
  final String freq; // DAILY, WEEKLY, MONTHLY, YEARLY
  final int interval;
  final List<String> byDay; // MO, TU, WE, TH, FR, SA, SU
  final int? count;
  final DateTime? until;

  const ParsedRrule({
    required this.freq,
    this.interval = 1,
    this.byDay = const [],
    this.count,
    this.until,
  });

  @override
  String toString() =>
      'ParsedRrule(freq: $freq, interval: $interval, byDay: $byDay'
      '${count != null ? ', count: $count' : ''}'
      '${until != null ? ', until: $until' : ''}'
      ')';
}

const weekdayCodes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

const weekdayLabels = {
  'MO': '월',
  'TU': '화',
  'WE': '수',
  'TH': '목',
  'FR': '금',
  'SA': '토',
  'SU': '일',
};

const weekdayFullLabels = {
  'MO': '월요일',
  'TU': '화요일',
  'WE': '수요일',
  'TH': '목요일',
  'FR': '금요일',
  'SA': '토요일',
  'SU': '일요일',
};

const _freqLabels = {
  'DAILY': '일',
  'WEEKLY': '주',
  'MONTHLY': '월',
  'YEARLY': '년',
};

const legacyRecurrenceLabels = {
  'NONE': '없음',
  'DAILY': '매일',
  'WEEKLY': '매주',
  'MONTHLY': '매월',
  'YEARLY': '매년',
};

/// Parses an RRULE string (with or without the leading "RRULE:") into its
/// components. Returns null when the string is empty or has no FREQ.
ParsedRrule? parseRrule(String? rrule) {
  if (rrule == null || rrule.trim().isEmpty) return null;
  var body = rrule.trim();
  if (body.startsWith('RRULE:')) {
    body = body.substring('RRULE:'.length);
  }

  String? freq;
  int interval = 1;
  List<String> byDay = [];
  int? count;
  DateTime? until;

  for (final part in body.split(';')) {
    final idx = part.indexOf('=');
    if (idx == -1) continue;
    final key = part.substring(0, idx).toUpperCase();
    final value = part.substring(idx + 1);
    switch (key) {
      case 'FREQ':
        freq = value.toUpperCase();
        break;
      case 'INTERVAL':
        interval = int.tryParse(value) ?? 1;
        break;
      case 'BYDAY':
        byDay = value
            .split(',')
            .map((e) => e.trim().toUpperCase())
            .where((e) => e.isNotEmpty)
            .toList();
        break;
      case 'COUNT':
        count = int.tryParse(value);
        break;
      case 'UNTIL':
        until = _parseUntil(value);
        break;
    }
  }

  if (freq == null || freq.isEmpty) return null;
  return ParsedRrule(
    freq: freq,
    interval: interval < 1 ? 1 : interval,
    byDay: byDay,
    count: count,
    until: until,
  );
}

DateTime? _parseUntil(String value) {
  try {
    if (value.length == 8) {
      return DateTime(
        int.parse(value.substring(0, 4)),
        int.parse(value.substring(4, 6)),
        int.parse(value.substring(6, 8)),
      );
    }
    final cleaned = value.endsWith('Z')
        ? value.substring(0, value.length - 1)
        : value;
    final parts = cleaned.split('T');
    final datePart = parts[0];
    final timePart = parts.length > 1 ? parts[1] : '000000';
    return DateTime.utc(
      int.parse(datePart.substring(0, 4)),
      int.parse(datePart.substring(4, 6)),
      int.parse(datePart.substring(6, 8)),
      timePart.length >= 2 ? int.parse(timePart.substring(0, 2)) : 0,
      timePart.length >= 4 ? int.parse(timePart.substring(2, 4)) : 0,
      timePart.length >= 6 ? int.parse(timePart.substring(4, 6)) : 0,
    ).toLocal();
  } catch (_) {
    return null;
  }
}

/// Formats a [DateTime] as an RRULE UNTIL value: YYYYMMDDTHHMMSSZ.
String formatUntil(DateTime date) {
  final utc = date.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}${two(utc.day)}'
      'T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}

/// Builds an RRULE string (including the "RRULE:" prefix) from the given
/// components. Returns null when [freq] is null/empty/"NONE" (no recurrence).
String? buildRrule({
  required String? freq,
  int interval = 1,
  List<String> byDay = const [],
  int? count,
  DateTime? until,
}) {
  if (freq == null || freq.isEmpty || freq == 'NONE') return null;

  final buffer = StringBuffer('RRULE:FREQ=$freq');
  if (interval > 1) {
    buffer.write(';INTERVAL=$interval');
  }
  if (freq == 'WEEKLY' && byDay.isNotEmpty) {
    final ordered = weekdayCodes.where((d) => byDay.contains(d)).toList();
    buffer.write(';BYDAY=${ordered.join(',')}');
  }
  if (count != null && count > 0) {
    buffer.write(';COUNT=$count');
  } else if (until != null) {
    buffer.write(';UNTIL=${formatUntil(until)}');
  }
  return buffer.toString();
}

String _fmtDate(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

/// Produces a short human-readable Korean summary for an RRULE string,
/// falling back to the legacy `recurrenceType`/`recurrenceEnd` fields when
/// no rrule is present.
String rruleSummaryText(
  String? rrule, {
  String legacyType = 'NONE',
  DateTime? legacyEnd,
}) {
  final parsed = parseRrule(rrule);
  if (parsed == null) {
    if (legacyType == 'NONE') return '반복 없음';
    var text = legacyRecurrenceLabels[legacyType] ?? '반복';
    if (legacyEnd != null) {
      text += ' · ${_fmtDate(legacyEnd)}까지';
    }
    return text;
  }

  final freqLabel = _freqLabels[parsed.freq] ?? parsed.freq;
  String text;
  if (parsed.freq == 'WEEKLY' && parsed.byDay.isNotEmpty) {
    final days = weekdayCodes
        .where((d) => parsed.byDay.contains(d))
        .map((d) => weekdayLabels[d])
        .join(', ');
    text = parsed.interval > 1
        ? '매 ${parsed.interval}주마다 $days요일'
        : '매주 $days요일';
  } else {
    text = parsed.interval > 1 ? '매 ${parsed.interval}$freqLabel마다' : '매$freqLabel';
  }

  if (parsed.count != null) {
    text += ' · ${parsed.count}회';
  } else if (parsed.until != null) {
    text += ' · ${_fmtDate(parsed.until!)}까지';
  }

  return text;
}

/// Common recurrence presets keyed by a short id, mapping to an RRULE
/// string (without any COUNT/UNTIL/INTERVAL customization).
const Map<String, String> rrulePresets = {
  'DAILY': 'RRULE:FREQ=DAILY',
  'WEEKLY': 'RRULE:FREQ=WEEKLY',
  'WEEKDAYS': 'RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR',
  'MONTHLY': 'RRULE:FREQ=MONTHLY',
  'YEARLY': 'RRULE:FREQ=YEARLY',
};
