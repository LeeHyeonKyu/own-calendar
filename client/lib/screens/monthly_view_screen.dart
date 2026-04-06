import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';
import '../models/event.dart';

class MonthlyViewScreen extends StatefulWidget {
  const MonthlyViewScreen({super.key});

  @override
  State<MonthlyViewScreen> createState() => _MonthlyViewScreenState();
}

class _MonthlyViewScreenState extends State<MonthlyViewScreen> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final start = _currentMonth;
    final end = DateTime(_currentMonth.year, _currentMonth.month + 1);
    await context.read<CalendarProvider>().loadEvents(start: start, end: end);
    await context.read<CalendarProvider>().loadFamilyEvents(start: start, end: end);
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _loadEvents();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _loadEvents();
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

  List<EventModel> _eventsForDay(DateTime day, List<EventModel> allEvents) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return allEvents
        .where((e) => e.startTime.isBefore(dayEnd) && e.endTime.isAfter(dayStart))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final calProvider = context.watch<CalendarProvider>();
    final allEvents = [...calProvider.events, ...calProvider.familyEvents];
    final today = DateTime.now();
    final monthLabel = DateFormat('yyyy년 M월', 'ko').format(_currentMonth);

    // Calculate grid
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = firstDay.weekday % 7; // 0=Sun
    final totalDays = lastDay.day;
    final totalCells = startWeekday + totalDays;
    final rows = (totalCells / 7).ceil();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Own Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Month navigation
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousMonth,
                ),
                GestureDetector(
                  onTap: () {
                    // Tap month label to go to today's month
                    setState(() {
                      _currentMonth = DateTime(today.year, today.month);
                    });
                    _loadEvents();
                  },
                  child: Text(
                    monthLabel,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),
          // Weekday headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: ['일', '월', '화', '수', '목', '금', '토']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: d == '일'
                                  ? Colors.red[400]
                                  : d == '토'
                                      ? Colors.blue[400]
                                      : Colors.grey[600],
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 4),
          // Calendar grid
          if (calProvider.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: List.generate(rows, (row) {
                    return Expanded(
                      child: Row(
                        children: List.generate(7, (col) {
                          final cellIndex = row * 7 + col;
                          final dayNum = cellIndex - startWeekday + 1;

                          if (dayNum < 1 || dayNum > totalDays) {
                            return const Expanded(child: SizedBox());
                          }

                          final day = DateTime(
                            _currentMonth.year,
                            _currentMonth.month,
                            dayNum,
                          );
                          final isToday = day.year == today.year &&
                              day.month == today.month &&
                              day.day == today.day;
                          final dayEvents = _eventsForDay(day, allEvents);

                          return Expanded(
                            child: GestureDetector(
                              onTap: () => context.push('/daily'),
                              child: Container(
                                margin: const EdgeInsets.all(1),
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withAlpha(100)
                                      : null,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isToday
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey.withAlpha(30),
                                    width: isToday ? 1.5 : 0.5,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: isToday
                                              ? BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                  shape: BoxShape.circle,
                                                )
                                              : null,
                                          child: Text(
                                            '$dayNum',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isToday
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: isToday
                                                  ? Colors.white
                                                  : col == 0
                                                      ? Colors.red[400]
                                                      : col == 6
                                                          ? Colors.blue[400]
                                                          : null,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Event indicators
                                      ...dayEvents.take(3).map(
                                            (e) => Container(
                                              margin: const EdgeInsets.only(
                                                top: 1,
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _parseColor(e.calendarColor)
                                                    .withAlpha(180),
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                              child: Text(
                                                e.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                      if (dayEvents.length > 3)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 1),
                                          child: Text(
                                            '+${dayEvents.length - 3}',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/event/new'),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              break; // already here
            case 1:
              context.push('/daily');
              break;
            case 2:
              context.push('/weekly');
              break;
            case 3:
              context.push('/yearly');
              break;
            case 4:
              context.push('/family');
              break;
            case 5:
              context.push('/settings');
              break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month), label: '월별'),
          NavigationDestination(icon: Icon(Icons.today), label: '일별'),
          NavigationDestination(icon: Icon(Icons.view_week), label: '주별'),
          NavigationDestination(icon: Icon(Icons.calendar_today), label: '연별'),
          NavigationDestination(icon: Icon(Icons.family_restroom), label: '가족'),
          NavigationDestination(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}
