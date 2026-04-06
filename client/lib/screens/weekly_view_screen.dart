import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';
import '../models/event.dart';

class WeeklyViewScreen extends StatefulWidget {
  const WeeklyViewScreen({super.key});

  @override
  State<WeeklyViewScreen> createState() => _WeeklyViewScreenState();
}

class _WeeklyViewScreenState extends State<WeeklyViewScreen> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday % 7));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEvents());
  }

  Future<void> _loadEvents() async {
    final weekEnd = _weekStart.add(const Duration(days: 7));
    await context.read<CalendarProvider>().loadEvents(
      start: _weekStart,
      end: weekEnd,
    );
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.blue;
    try {
      final colorStr = hex.replaceFirst('#', '');
      return Color(int.parse('FF$colorStr', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  List<EventModel> _eventsForDay(DateTime day) {
    final provider = context.read<CalendarProvider>();
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return provider.events
        .where((e) => e.startTime.isBefore(dayEnd) && e.endTime.isAfter(dayStart))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final calProvider = context.watch<CalendarProvider>();
    final days = List.generate(
      7,
      (i) => _weekStart.add(Duration(days: i)),
    );
    final today = DateTime.now();
    final weekLabel =
        '${DateFormat('M/d').format(_weekStart)} - ${DateFormat('M/d').format(days.last)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('주별 보기'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _weekStart = _weekStart.subtract(const Duration(days: 7));
                    });
                    _loadEvents();
                  },
                ),
                Text(weekLabel, style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _weekStart = _weekStart.add(const Duration(days: 7));
                    });
                    _loadEvents();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (calProvider.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                itemCount: 7,
                itemBuilder: (context, index) {
                  final day = days[index];
                  final isToday = day.year == today.year &&
                      day.month == today.month &&
                      day.day == today.day;
                  final dayEvents = _eventsForDay(day);

                  return InkWell(
                    onTap: () => context.push('/daily'),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isToday
                            ? Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withAlpha(80)
                            : null,
                        border: const Border(
                          bottom: BorderSide(color: Colors.black12),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 56,
                            child: Column(
                              children: [
                                Text(
                                  DateFormat('E', 'ko').format(day),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isToday
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isToday
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: dayEvents.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      '일정 없음',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 13,
                                      ),
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: dayEvents
                                        .map(
                                          (e) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: _parseColor(
                                                      e.calendarColor,
                                                    ),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    e.title,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  e.isAllDay
                                                      ? '종일'
                                                      : DateFormat('HH:mm')
                                                          .format(e.startTime),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[500],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
