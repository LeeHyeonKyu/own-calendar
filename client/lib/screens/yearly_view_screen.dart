import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';
import '../models/event.dart';

class YearlyViewScreen extends StatefulWidget {
  const YearlyViewScreen({super.key});

  @override
  State<YearlyViewScreen> createState() => _YearlyViewScreenState();
}

class _YearlyViewScreenState extends State<YearlyViewScreen> {
  late int _currentYear;

  @override
  void initState() {
    super.initState();
    _currentYear = DateTime.now().year;
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final start = DateTime(_currentYear);
    final end = DateTime(_currentYear + 1);
    await context.read<CalendarProvider>().loadEvents(start: start, end: end);
  }

  int _eventCountForDay(DateTime day, List<EventModel> allEvents) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return allEvents
        .where((e) => e.startTime.isBefore(dayEnd) && e.endTime.isAfter(dayStart))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final calProvider = context.watch<CalendarProvider>();
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('연별 보기'),
      ),
      body: Column(
        children: [
          // Year navigation
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() => _currentYear--);
                    _loadEvents();
                  },
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _currentYear = today.year);
                    _loadEvents();
                  },
                  child: Text(
                    '$_currentYear년',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() => _currentYear++);
                    _loadEvents();
                  },
                ),
              ],
            ),
          ),
          // 12 months grid
          if (calProvider.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 12,
                itemBuilder: (context, monthIndex) {
                  final month = monthIndex + 1;
                  final monthLabel = DateFormat('M월', 'ko')
                      .format(DateTime(_currentYear, month));
                  final firstDay = DateTime(_currentYear, month, 1);
                  final lastDay = DateTime(_currentYear, month + 1, 0);
                  final startWeekday = firstDay.weekday % 7;
                  final totalDays = lastDay.day;
                  final isCurrentMonth = _currentYear == today.year &&
                      month == today.month;

                  return GestureDetector(
                    onTap: () => context.push('/?month=${DateTime(_currentYear, month).toIso8601String()}'),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isCurrentMonth
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.withAlpha(50),
                          width: isCurrentMonth ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          // Month header
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: isCurrentMonth
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : Colors.grey[100],
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(7),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                monthLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrentMonth
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          // Weekday headers
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: ['일', '월', '화', '수', '목', '금', '토']
                                  .map((d) => Expanded(
                                        child: Center(
                                          child: Text(
                                            d,
                                            style: TextStyle(
                                              fontSize: 7,
                                              color: d == '일'
                                                  ? Colors.red[300]
                                                  : d == '토'
                                                      ? Colors.blue[300]
                                                      : Colors.grey[500],
                                            ),
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                          // Day grid
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Column(
                                children: List.generate(
                                  ((startWeekday + totalDays) / 7).ceil(),
                                  (row) {
                                    return Expanded(
                                      child: Row(
                                        children: List.generate(7, (col) {
                                          final cellIndex = row * 7 + col;
                                          final dayNum =
                                              cellIndex - startWeekday + 1;

                                          if (dayNum < 1 || dayNum > totalDays) {
                                            return const Expanded(
                                              child: SizedBox(),
                                            );
                                          }

                                          final day = DateTime(
                                            _currentYear,
                                            month,
                                            dayNum,
                                          );
                                          final isToday =
                                              day.year == today.year &&
                                                  day.month == today.month &&
                                                  day.day == today.day;
                                          final eventCount = _eventCountForDay(
                                            day,
                                            calProvider.events,
                                          );

                                          return Expanded(
                                            child: Container(
                                              margin: const EdgeInsets.all(0.5),
                                              decoration: BoxDecoration(
                                                color: isToday
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                    : eventCount > 0
                                                        ? Theme.of(context)
                                                            .colorScheme
                                                            .primaryContainer
                                                            .withAlpha(120)
                                                        : null,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '$dayNum',
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    color: isToday
                                                        ? Colors.white
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    );
                                  },
                                ),
                              ),
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
