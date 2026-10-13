import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';
import '../models/event.dart';

const _hourHeight = 60.0;
// ignore: unused_element
const _timeGutterWidth = 48.0;
const _nowColor = Color(0xFFEA4335);
const _gridLineColor = Color(0xFFE0E0E0);
const _gridLineDarkColor = Color(0xFF424242);

final _defaultEventColors = [
  const Color(0xFF4285F4),
  const Color(0xFF0B8043),
  const Color(0xFF8E24AA),
  const Color(0xFFD50000),
  const Color(0xFFF4511E),
  const Color(0xFF039BE5),
  const Color(0xFF616161),
  const Color(0xFF33B679),
];

class WeeklyViewScreen extends StatefulWidget {
  const WeeklyViewScreen({super.key});

  @override
  State<WeeklyViewScreen> createState() => _WeeklyViewScreenState();
}

class _WeeklyViewScreenState extends State<WeeklyViewScreen> {
  late DateTime _weekStart;
  Timer? _nowTimer;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday % 7));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _scrollToNow();
    });
    _nowTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nowTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  List<DateTime> get _days =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  Future<void> _loadData() async {
    final weekEnd = _weekStart.add(const Duration(days: 7));
    final provider = context.read<CalendarProvider>();
    await Future.wait([
      provider.loadEvents(start: _weekStart, end: weekEnd),
      provider.loadGroupEvents(start: _weekStart, end: weekEnd),
    ]);
  }

  void _changeWeek(int delta) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: delta * 7));
    });
    _loadData();
  }

  void _goToThisWeek() {
    final now = DateTime.now();
    setState(() {
      _weekStart = now.subtract(Duration(days: now.weekday % 7));
    });
    _loadData();
    _scrollToNow();
  }

  void _scrollToNow() {
    final now = DateTime.now();
    final targetOffset = (now.hour - 1).clamp(0, 23) * _hourHeight;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<EventModel> _eventsForDay(DateTime day, List<EventModel> allEvents) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return allEvents
        .where((e) =>
            !e.isAllDay &&
            e.startTime.isBefore(dayEnd) &&
            e.endTime.isAfter(dayStart))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<EventModel> _allDayEventsForDay(
      DateTime day, List<EventModel> allEvents) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return allEvents
        .where((e) =>
            e.isAllDay &&
            e.startTime.isBefore(dayEnd) &&
            e.endTime.isAfter(dayStart))
        .toList();
  }

  Color _eventColor(EventModel event) {
    if (event.calendarColor != null) {
      final hex = event.calendarColor!.replaceFirst('#', '');
      if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
    }
    final colorValue = EventModel.categoryColors[event.category];
    if (colorValue != null) return Color(colorValue);
    return _defaultEventColors[event.title.hashCode.abs() % _defaultEventColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final calProvider = context.watch<CalendarProvider>();
    final days = _days;
    final now = DateTime.now();
    final monthLabel = DateFormat('yyyy년 M월').format(_weekStart);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(monthLabel),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _goToThisWeek,
            child: const Text('오늘'),
          ),
        ],
      ),
      body: calProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildDayHeaders(days, now, isDark),
                _buildAllDayRow(days, calProvider.allVisibleEvents),
                Expanded(
                  child: _buildTimeGrid(days, calProvider.allVisibleEvents, now, isDark),
                ),
              ],
            ),
    );
  }

  Widget _buildDayHeaders(List<DateTime> days, DateTime now, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? _gridLineDarkColor : _gridLineColor,
          ),
        ),
      ),
      child: Row(
        children: [
          // Gutter
          SizedBox(
            width: _timeGutterWidth,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.chevron_left, size: 18),
                onPressed: () => _changeWeek(-1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ),
          ),
          // Day columns
          ...days.map((day) {
            final isToday = day.year == now.year &&
                day.month == now.month &&
                day.day == now.day;
            final isSunday = day.weekday == DateTime.sunday;
            final isSaturday = day.weekday == DateTime.saturday;

            return Expanded(
              child: GestureDetector(
                onTap: () => context.go('/daily', extra: day),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('E', 'ko').format(day),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isToday
                              ? _nowColor
                              : isSunday
                                  ? Colors.red[400]
                                  : isSaturday
                                      ? Colors.blue[400]
                                      : Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isToday ? _nowColor : null,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.w500,
                            color: isToday ? Colors.white : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          // Right arrow
          SizedBox(
            width: 32,
            child: IconButton(
              icon: const Icon(Icons.chevron_right, size: 18),
              onPressed: () => _changeWeek(1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllDayRow(List<DateTime> days, List<EventModel> allEvents) {
    final hasAnyAllDay = days.any((d) => _allDayEventsForDay(d, allEvents).isNotEmpty);
    if (!hasAnyAllDay) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 60),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? _gridLineDarkColor
                : _gridLineColor,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _timeGutterWidth,
            child: Center(
              child: Text(
                '종일',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ),
          ),
          ...days.map((day) {
            final dayAllDay = _allDayEventsForDay(day, allEvents);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: dayAllDay.take(2).map((event) {
                    final color = _eventColor(event);
                    return GestureDetector(
                      onTap: () =>
                          context.push('/event/${event.baseId}/edit'),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 1),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          }),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildTimeGrid(
      List<DateTime> days, List<EventModel> allEvents, DateTime now, bool isDark) {
    final gridColor = isDark ? _gridLineDarkColor : _gridLineColor;
    return SingleChildScrollView(
      controller: _scrollController,
      child: SizedBox(
        height: 24 * _hourHeight,
        child: Row(
          children: [
            // Time gutter
            SizedBox(
              width: _timeGutterWidth,
              height: 24 * _hourHeight,
              child: Stack(
                children: List.generate(24, (hour) {
                  return Positioned(
                    top: hour * _hourHeight - 6,
                    left: 0,
                    right: 4,
                    child: Text(
                      hour == 0 ? '' : '${hour.toString().padLeft(2, '0')}:00',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.right,
                    ),
                  );
                }),
              ),
            ),
            // Day columns
            ...days.asMap().entries.map((entry) {
              final day = entry.value;
              final dayEvents = _eventsForDay(day, allEvents);
              final isToday = day.year == now.year &&
                  day.month == now.month &&
                  day.day == now.day;

              return Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                final colWidth = constraints.maxWidth;
                return Stack(
                  children: [
                    // Hour lines
                    ...List.generate(24, (hour) {
                      return Positioned(
                        top: hour * _hourHeight,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 1,
                          color: gridColor.withAlpha(hour == 0 ? 0 : 180),
                        ),
                      );
                    }),
                    // Half-hour lines
                    ...List.generate(24, (hour) {
                      return Positioned(
                        top: hour * _hourHeight + _hourHeight / 2,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 1,
                          color: gridColor.withAlpha(60),
                        ),
                      );
                    }),
                    // Left border
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      child: Container(width: 0.5, color: gridColor),
                    ),
                    // Today column highlight
                    if (isToday)
                      Positioned.fill(
                        child: Container(
                          color: _nowColor.withAlpha(8),
                        ),
                      ),
                    // Now line
                    if (isToday)
                      Positioned(
                        top: (now.hour + now.minute / 60.0) * _hourHeight,
                        left: 0,
                        right: 0,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: -4,
                              top: -4,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: _nowColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Container(height: 1.5, color: _nowColor),
                          ],
                        ),
                      ),
                    // Tap to create
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapUp: (details) {
                          final hour =
                              (details.localPosition.dy / _hourHeight).floor();
                          final tapTime = DateTime(
                              day.year, day.month, day.day, hour.clamp(0, 23));
                          context.push('/event/new', extra: tapTime);
                        },
                      ),
                    ),
                    // Event blocks
                    ..._layoutEventBlocks(dayEvents, day, colWidth),
                  ],
                );
                }),
              );
            }),
            const SizedBox(width: 32),
          ],
        ),
      ),
    );
  }

  List<Widget> _layoutEventBlocks(
      List<EventModel> events, DateTime day, double colWidth) {
    if (events.isEmpty) return [];

    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final groups = _resolveOverlaps(events, dayStart);
    final widgets = <Widget>[];

    for (final group in groups) {
      final columnCount = group.length;
      final slotWidth = (colWidth - 2) / columnCount;

      for (var col = 0; col < columnCount; col++) {
        for (final event in group[col]) {
          final startMinutes = event.startTime.isBefore(dayStart)
              ? 0.0
              : (event.startTime.hour * 60 + event.startTime.minute).toDouble();
          final endMinutes = event.endTime.isAfter(dayEnd)
              ? 24 * 60.0
              : (event.endTime.hour * 60 + event.endTime.minute).toDouble();
          final top = startMinutes / 60.0 * _hourHeight;
          final height = ((endMinutes - startMinutes) / 60.0 * _hourHeight)
              .clamp(20.0, 24 * _hourHeight);
          final left = col * slotWidth + 1;
          final color = _eventColor(event);

          widgets.add(
            Positioned(
              top: top,
              left: left,
              width: slotWidth - 1,
              height: height,
              child: GestureDetector(
                onTap: () => context.push('/event/${event.baseId}/edit'),
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withAlpha(220),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.white.withAlpha(180),
                      width: 0.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.2,
                        ),
                        maxLines: height > 40 ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (height > 35)
                        Text(
                          DateFormat('HH:mm').format(event.startTime),
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white.withAlpha(200),
                          ),
                        ),
                      if (height > 55 && event.description != null)
                        Text(
                          event.description!,
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white.withAlpha(180),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    return widgets;
  }

  /// Groups overlapping events into columns.
  /// Returns list of groups, each group is a list of columns,
  /// each column is a list of non-overlapping events.
  List<List<List<EventModel>>> _resolveOverlaps(
      List<EventModel> events, DateTime dayStart) {
    if (events.isEmpty) return [];

    final sorted = List<EventModel>.from(events)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final groups = <List<List<EventModel>>>[];
    var currentGroup = <List<EventModel>>[
      [sorted.first]
    ];
    var groupEnd = sorted.first.endTime;

    for (var i = 1; i < sorted.length; i++) {
      final event = sorted[i];
      if (event.startTime.isBefore(groupEnd)) {
        // Overlaps — find a column or create one
        var placed = false;
        for (final column in currentGroup) {
          if (!event.startTime.isBefore(column.last.endTime)) {
            column.add(event);
            placed = true;
            break;
          }
        }
        if (!placed) {
          currentGroup.add([event]);
        }
        if (event.endTime.isAfter(groupEnd)) {
          groupEnd = event.endTime;
        }
      } else {
        groups.add(currentGroup);
        currentGroup = [
          [event]
        ];
        groupEnd = event.endTime;
      }
    }
    groups.add(currentGroup);

    return groups;
  }
}
