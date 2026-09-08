import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';
import '../models/event.dart';
import '../models/task.dart';
import '../widgets/task_card.dart';

void showCategoryFilterDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          final calProvider = ctx.watch<CalendarProvider>();
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Text(
                        '카테고리 필터',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => calProvider.selectAllCategories(),
                        child: const Text('전체 선택'),
                      ),
                    ],
                  ),
                ),
                ...EventModel.categoryLabels.entries.map(
                  (e) => CheckboxListTile(
                    value: calProvider.selectedCategories.contains(e.key),
                    onChanged: (_) => calProvider.toggleCategory(e.key),
                    secondary: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Color(EventModel.categoryColors[e.key]!),
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(e.value),
                    dense: true,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
    },
  );
}

class MonthlyViewScreen extends StatefulWidget {
  final DateTime? initialMonth;

  const MonthlyViewScreen({super.key, this.initialMonth});

  @override
  State<MonthlyViewScreen> createState() => _MonthlyViewScreenState();
}

class _MonthlyViewScreenState extends State<MonthlyViewScreen> {
  late DateTime _currentMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final m = widget.initialMonth ?? DateTime.now();
    _currentMonth = DateTime(m.year, m.month);
    final now = DateTime.now();
    if (m.year == now.year && m.month == now.month) {
      _selectedDay = DateTime(now.year, now.month, now.day);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final start = _currentMonth;
    final end = DateTime(_currentMonth.year, _currentMonth.month + 1);
    final provider = context.read<CalendarProvider>();
    await provider.loadEvents(start: start, end: end);
    await provider.loadFamilyEvents(start: start, end: end);
    await provider.loadTasks(start: start, end: end);
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _selectedDay = null;
    });
    _loadData();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _selectedDay = null;
    });
    _loadData();
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

  List<TaskModel> _tasksForDay(DateTime day, List<TaskModel> allTasks) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return allTasks.where((t) {
      final date = t.scheduledDate ?? t.dueDate;
      if (date == null) return false;
      return !date.isBefore(dayStart) && date.isBefore(dayEnd);
    }).toList();
  }

  Widget _buildDayDetailPanel(CalendarProvider calProvider, List<EventModel> allEvents, List<TaskModel> allTasks) {
    final day = _selectedDay!;
    final dayEvents = _eventsForDay(day, allEvents);
    final dayTasks = _tasksForDay(day, allTasks);
    final dateStr = DateFormat('M월 d일 (E)', 'ko').format(day);

    dayEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

    // Group tasks: event-related vs standalone
    final Map<String, List<TaskModel>> eventTaskMap = {};
    final List<TaskModel> standaloneTasks = [];
    for (final task in dayTasks) {
      if (task.eventId != null) {
        eventTaskMap.putIfAbsent(task.eventId!, () => []).add(task);
      } else {
        standaloneTasks.add(task);
      }
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(dateStr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (dayEvents.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B8DEF).withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${dayEvents.length}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF5B8DEF)),
                    ),
                  ),
                if (dayTasks.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0A050).withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${dayTasks.length}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFF0A050)),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: (dayEvents.isEmpty && dayTasks.isEmpty)
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_available, size: 40, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text('일정이 없습니다', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      // Events with nested tasks
                      ...dayEvents.map((event) {
                        final nestedTasks = eventTaskMap[event.id] ?? [];
                        return _EventCardWithTasks(
                          event: event,
                          tasks: nestedTasks,
                          onEventTap: () => context.push('/event/${event.id}/edit'),
                          onTaskToggle: (taskId) => calProvider.toggleTaskComplete(taskId),
                          parseColor: _parseColor,
                        );
                      }),
                      // Standalone tasks
                      ...standaloneTasks.map((task) => TaskCard(
                        task: task,
                        onTap: () => context.push('/task/${task.baseId}/edit'),
                        onToggleComplete: () => calProvider.toggleTaskComplete(task.baseId),
                      )),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calProvider = context.watch<CalendarProvider>();
    final allEvents = calProvider.allVisibleEvents;
    final allTasks = calProvider.tasks;
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
            icon: Icon(
              calProvider.isAllCategoriesSelected
                  ? Icons.filter_list
                  : Icons.filter_list_off,
            ),
            tooltip: '카테고리 필터',
            onPressed: () => showCategoryFilterDialog(context),
          ),
          IconButton(
            icon: Icon(
              calProvider.showFamilyEvents ? Icons.people : Icons.people_outline,
            ),
            tooltip: calProvider.showFamilyEvents ? '가족 일정 숨기기' : '가족 일정 보기',
            onPressed: () => calProvider.toggleFamilyEvents(),
          ),
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
                    _loadData();
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
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: List.generate(rows, (row) {
                  return Row(
                    children: List.generate(7, (col) {
                      final cellIndex = row * 7 + col;
                      final dayNum = cellIndex - startWeekday + 1;

                      if (dayNum < 1 || dayNum > totalDays) {
                        return const Expanded(child: SizedBox(height: 48));
                      }

                      final day = DateTime(
                        _currentMonth.year,
                        _currentMonth.month,
                        dayNum,
                      );
                      final isToday = day.year == today.year &&
                          day.month == today.month &&
                          day.day == today.day;
                      final isSelected = _selectedDay != null &&
                          day.year == _selectedDay!.year &&
                          day.month == _selectedDay!.month &&
                          day.day == _selectedDay!.day;
                      final dayEvents = _eventsForDay(day, allEvents);
                      final dayTasks = _tasksForDay(day, allTasks);
                      final hasEvents = dayEvents.isNotEmpty;
                      final hasTasks = dayTasks.isNotEmpty;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedDay = day);
                          },
                          onDoubleTap: () {
                            context.go('/daily?date=${day.toIso8601String()}');
                          },
                          child: Container(
                            height: 48,
                            margin: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primaryContainer.withAlpha(80)
                                  : null,
                              borderRadius: BorderRadius.circular(6),
                              border: isToday
                                  ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5)
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: isToday
                                      ? BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary,
                                          shape: BoxShape.circle,
                                        )
                                      : null,
                                  child: Text(
                                    '$dayNum',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
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
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (hasEvents)
                                      Container(
                                        width: 5,
                                        height: 5,
                                        margin: const EdgeInsets.symmetric(horizontal: 1),
                                        decoration: BoxDecoration(
                                          color: isToday ? Colors.white : const Color(0xFF5B8DEF),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    if (hasTasks)
                                      Container(
                                        width: 5,
                                        height: 5,
                                        margin: const EdgeInsets.symmetric(horizontal: 1),
                                        decoration: BoxDecoration(
                                          color: isToday ? Colors.white70 : const Color(0xFFF0A050),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                }),
              ),
            ),
            const SizedBox(height: 4),
            // Selected day detail panel
            if (_selectedDay != null)
              Expanded(child: _buildDayDetailPanel(calProvider, allEvents, allTasks)),
            if (_selectedDay == null)
              const Expanded(child: SizedBox()),
          ],
        ],
      ),
    );
  }
}

class _EventCardWithTasks extends StatelessWidget {
  final EventModel event;
  final List<TaskModel> tasks;
  final VoidCallback? onEventTap;
  final Function(String taskId) onTaskToggle;
  final Color Function(String?) parseColor;

  const _EventCardWithTasks({
    required this.event,
    required this.tasks,
    this.onEventTap,
    required this.onTaskToggle,
    required this.parseColor,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onEventTap,
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: const Color(0xFF5B8DEF), width: 3)),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF5B8DEF),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.isAllDay
                              ? '종일'
                              : '${timeFormat.format(event.startTime)} – ${timeFormat.format(event.endTime)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  if (tasks.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA78BFA).withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Task ${tasks.where((t) => t.isDone).length}/${tasks.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFA78BFA),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (tasks.isNotEmpty)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(
                  left: const BorderSide(color: Color(0xFF5B8DEF), width: 3),
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: tasks
                    .map((task) => NestedTaskItem(
                          task: task,
                          onToggleComplete: () => onTaskToggle(task.baseId),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
