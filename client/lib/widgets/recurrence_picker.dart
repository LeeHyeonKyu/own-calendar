import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/rrule_utils.dart';

/// Result of the [RecurrencePicker] bottom sheet.
class RecurrenceResult {
  /// The built RRULE string (with "RRULE:" prefix), or null for no recurrence.
  final String? rrule;

  /// Legacy field kept for backward compatibility with the server.
  final String recurrenceType;

  /// Legacy field kept for backward compatibility with the server.
  final DateTime? recurrenceEnd;

  const RecurrenceResult({
    required this.rrule,
    required this.recurrenceType,
    required this.recurrenceEnd,
  });
}

enum _EndMode { never, count, until }

/// Bottom sheet content for configuring an event/task recurrence rule.
///
/// Shows quick presets, a weekly day selector, an interval stepper and an
/// end-condition picker, and reports the built RRULE back through
/// [onChanged] when the user taps confirm.
class RecurrencePicker extends StatefulWidget {
  final String? initialRrule;
  final String initialRecurrenceType; // legacy fallback
  final DateTime? initialRecurrenceEnd;
  final DateTime referenceDate; // the event/task start date
  final ValueChanged<RecurrenceResult> onChanged;

  const RecurrencePicker({
    super.key,
    this.initialRrule,
    this.initialRecurrenceType = 'NONE',
    this.initialRecurrenceEnd,
    required this.referenceDate,
    required this.onChanged,
  });

  @override
  State<RecurrencePicker> createState() => _RecurrencePickerState();
}

class _RecurrencePickerState extends State<RecurrencePicker> {
  static const _freqOptions = [
    {'value': 'NONE', 'label': '없음'},
    {'value': 'DAILY', 'label': '매일'},
    {'value': 'WEEKLY', 'label': '매주'},
    {'value': 'MONTHLY', 'label': '매월'},
    {'value': 'YEARLY', 'label': '매년'},
  ];

  late String _freq;
  late Set<String> _byDay;
  late int _interval;
  late _EndMode _endMode;
  late int _count;
  late DateTime _until;

  @override
  void initState() {
    super.initState();
    final parsed = parseRrule(widget.initialRrule);
    if (parsed != null) {
      _freq = parsed.freq;
      _byDay = parsed.byDay.toSet();
      _interval = parsed.interval;
      _count = parsed.count ?? 10;
      _until = parsed.until ?? widget.referenceDate.add(const Duration(days: 30));
      _endMode = parsed.count != null
          ? _EndMode.count
          : (parsed.until != null ? _EndMode.until : _EndMode.never);
    } else {
      _freq = widget.initialRecurrenceType;
      _byDay = {};
      _interval = 1;
      _count = 10;
      _until = widget.initialRecurrenceEnd ??
          widget.referenceDate.add(const Duration(days: 30));
      _endMode =
          widget.initialRecurrenceEnd != null ? _EndMode.until : _EndMode.never;
    }
    if (_freq == 'WEEKLY' && _byDay.isEmpty) {
      _byDay = {weekdayCodes[widget.referenceDate.weekday - 1]};
    }
  }

  String? get _builtRrule {
    return buildRrule(
      freq: _freq,
      interval: _interval,
      byDay: _byDay.toList(),
      count: _endMode == _EndMode.count ? _count : null,
      until: _endMode == _EndMode.until ? _until : null,
    );
  }

  String get _summary => rruleSummaryText(_builtRrule, legacyType: _freq);

  void _selectFreq(String value) {
    setState(() {
      _freq = value;
      if (value == 'WEEKLY' && _byDay.isEmpty) {
        _byDay = {weekdayCodes[widget.referenceDate.weekday - 1]};
      }
    });
  }

  void _toggleDay(String code) {
    setState(() {
      if (_byDay.contains(code)) {
        if (_byDay.length > 1) _byDay.remove(code);
      } else {
        _byDay.add(code);
      }
    });
  }

  void _setWeekdaysPreset() {
    setState(() {
      _byDay = {'MO', 'TU', 'WE', 'TH', 'FR'};
    });
  }

  void _confirm() {
    final rrule = _builtRrule;
    widget.onChanged(
      RecurrenceResult(
        rrule: rrule,
        recurrenceType: _freq == 'NONE' ? 'NONE' : _freq,
        recurrenceEnd: _endMode == _EndMode.until && rrule != null ? _until : null,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isRecurring = _freq != 'NONE';
    final freqUnitLabel = const {
      'DAILY': '일',
      'WEEKLY': '주',
      'MONTHLY': '월',
      'YEARLY': '년',
    }[_freq];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '반복 설정',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _freqOptions.map((opt) {
                  final value = opt['value']!;
                  final selected = _freq == value;
                  return ChoiceChip(
                    label: Text(opt['label']!),
                    selected: selected,
                    onSelected: (_) => _selectFreq(value),
                  );
                }).toList(),
              ),
              if (_freq == 'WEEKLY') ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('반복 요일', style: TextStyle(fontWeight: FontWeight.w500)),
                    TextButton(
                      onPressed: _setWeekdaysPreset,
                      child: const Text('평일'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: weekdayCodes.map((code) {
                    final selected = _byDay.contains(code);
                    return FilterChip(
                      label: Text(weekdayLabels[code]!),
                      selected: selected,
                      onSelected: (_) => _toggleDay(code),
                    );
                  }).toList(),
                ),
              ],
              if (isRecurring) ...[
                const SizedBox(height: 20),
                Text('반복 간격', style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('매'),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _interval > 1
                          ? () => setState(() => _interval--)
                          : null,
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '$_interval',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(() => _interval++),
                    ),
                    Text('$freqUnitLabel마다'),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('종료 조건', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                RadioListTile<_EndMode>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('종료 없음'),
                  value: _EndMode.never,
                  groupValue: _endMode,
                  onChanged: (v) => setState(() => _endMode = v!),
                ),
                RadioListTile<_EndMode>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Row(
                    children: [
                      const Text('N회 반복'),
                      const SizedBox(width: 12),
                      if (_endMode == _EndMode.count) ...[
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          onPressed: _count > 1
                              ? () => setState(() => _count--)
                              : null,
                        ),
                        SizedBox(
                          width: 28,
                          child: Text(
                            '$_count',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          onPressed: () => setState(() => _count++),
                        ),
                        const Text('회'),
                      ],
                    ],
                  ),
                  value: _EndMode.count,
                  groupValue: _endMode,
                  onChanged: (v) => setState(() => _endMode = v!),
                ),
                RadioListTile<_EndMode>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Row(
                    children: [
                      const Text('종료일'),
                      const SizedBox(width: 12),
                      if (_endMode == _EndMode.until)
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _until,
                              firstDate: widget.referenceDate,
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => _until = picked);
                            }
                          },
                          child: Text(DateFormat('yyyy-MM-dd').format(_until)),
                        ),
                    ],
                  ),
                  value: _EndMode.until,
                  groupValue: _endMode,
                  onChanged: (v) => setState(() => _endMode = v!),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.repeat, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_summary)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _confirm,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('확인'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Convenience helper to open the [RecurrencePicker] as a modal bottom sheet.
Future<void> showRecurrencePicker({
  required BuildContext context,
  String? initialRrule,
  String initialRecurrenceType = 'NONE',
  DateTime? initialRecurrenceEnd,
  required DateTime referenceDate,
  required ValueChanged<RecurrenceResult> onChanged,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => RecurrencePicker(
      initialRrule: initialRrule,
      initialRecurrenceType: initialRecurrenceType,
      initialRecurrenceEnd: initialRecurrenceEnd,
      referenceDate: referenceDate,
      onChanged: onChanged,
    ),
  );
}
