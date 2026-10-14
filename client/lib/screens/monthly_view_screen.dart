import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';
import '../models/event.dart';
import '../models/task.dart';
import '../widgets/task_card.dart';
import '../themes/spacing.dart';

void showCategoryFilterDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          final calProvider = ctx.watch<CalendarProvider>();
          final categories = calProvider.categories;
          final hiddenIds = calProvider.hiddenCategoryIds;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, Spacing.sm),
                  child: Row(
                    children: [
                      Text(
                        '카테고리 필터',
                        style: TextStyle(fontSize: AppTypography.h2, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => calProvider.showAllCategories(),
                        child: const Text('전체 선택'),
                      ),
                    ],
                  ),
                ),
                ...categories.map(
                  (cat) => CheckboxListTile(
                    value: !hiddenIds.contains(cat.id),
                    onChanged: (_) => calProvider.toggleCategoryVisibility(cat.id),
                    secondary: Container(
                      width: Spacing.lg,
                      height: Spacing.lg,
                      decoration: BoxDecoration(
                        color: cat.colorValue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(cat.displayName),
                    dense: true,
                  ),
                ),
                CheckboxListTile(
                  value: !calProvider.hideUncategorized,
                  onChanged: (_) => calProvider.toggleUncategorized(),
                  secondary: Container(
                    width: Spacing.lg,
                    height: Spacing.lg,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: const Text('미분류'),
                  dense: true,
                ),
                SizedBox(height: Spacing.sm),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedDay != null) {
        context.read<CalendarProvider>().setSelectedDate(_selectedDay!);
      }
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final start = _currentMonth;
    final end = DateTime(_currentMonth.year, _currentMonth.month + 1);
    final provider = context.read<CalendarProvider>();
    await provider.loadCategories();
    await provider.loadEvents(start: start, end: end);
    await provider.loadGroupEvents(start: start, end: end);
    await provider.loadTasks(start: start, end: end);
    await provider.loadHolidays(_currentMonth.year, month: _currentMonth.month);
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

  /// Get up to 3 unique calendar colors from a day's events.
  List<Color> _uniqueEventColors(List<EventModel> dayEvents) {
    final seen = <int>{};
    final colors = <Color>[];
    for (final event in dayEvents) {
      final color = _parseColor(event.calendarColor);
      if (seen.add(color.toARGB32()) && colors.length < 3) {
        colors.add(color);
      }
    }
    return colors;
  }

  Widget _buildDayDetailPanel(CalendarProvider calProvider, List<EventModel> allEvents, List<TaskModel> allTasks) {
    final day = _selectedDay!;
    final dayEvents = _eventsForDay(day, allEvents);
    final dayTasks = _tasksForDay(day, allTasks);
    final dayHolidays = calProvider.holidaysForDay(day);
    final dateStr = DateFormat('M월 d일 (E)', 'ko').format(day);
    final theme = Theme.of(context);

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
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.sm),
            child: Row(
              children: [
                Text(dateStr, style: TextStyle(fontSize: AppTypography.h3, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (dayEvents.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      '${dayEvents.length}',
                      style: TextStyle(fontSize: AppTypography.caption, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                    ),
                  ),
                if (dayTasks.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.taskPending.withAlpha(25),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      '${dayTasks.length}',
                      style: TextStyle(fontSize: AppTypography.caption, fontWeight: FontWeight.w600, color: AppColors.taskPending),
                    ),
                  ),
              ],
            ),
          ),
          if (dayHolidays.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
              color: AppColors.sundayText.withAlpha(20),
              child: Row(
                children: [
                  Icon(Icons.celebration, size: 14, color: AppColors.sundayText),
                  SizedBox(width: Spacing.xs),
                  Expanded(
                    child: Text(
                      dayHolidays.map((h) => h.name).join(', '),
                      style: TextStyle(
                        fontSize: AppTypography.bodySmall,
                        fontWeight: FontWeight.w600,
                        color: AppColors.sundayText,
                      ),
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
                        Icon(Icons.event_available, size: 40, color: theme.colorScheme.outlineVariant),
                        SizedBox(height: Spacing.sm),
                        Text('일정이 없습니다', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.symmetric(horizontal: Spacing.md),
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
    final theme = Theme.of(context);

    // Calculate grid
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = firstDay.weekday % 7; // 0=Sun
    final totalDays = lastDay.day;
    final totalCells = startWeekday + totalDays;
    final rows = (totalCells / 7).ceil();

    // Previous month info for filling leading cells
    final prevMonthLastDay = DateTime(_currentMonth.year, _currentMonth.month, 0);
    final prevMonthDays = prevMonthLastDay.day;

    // Next month starts at day 1
    // (used to fill trailing cells)

    return Scaffold(
      appBar: AppBar(
        title: const Text('Own Calendar'),
        actions: [
          IconButton(
            icon: Icon(
              calProvider.isAllCategoriesVisible
                  ? Icons.filter_list
                  : Icons.filter_list_off,
            ),
            tooltip: '카테고리 필터',
            onPressed: () => showCategoryFilterDialog(context),
          ),
          IconButton(
            icon: Icon(
              calProvider.showGroupEvents ? Icons.people : Icons.people_outline,
            ),
            tooltip: calProvider.showGroupEvents ? '그룹 일정 숨기기' : '그룹 일정 보기',
            onPressed: () => calProvider.toggleGroupEvents(),
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
            padding: EdgeInsets.symmetric(vertical: Spacing.sm),
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
                    style: theme.textTheme.titleLarge?.copyWith(
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
            padding: EdgeInsets.symmetric(horizontal: Spacing.xs),
            child: Row(
              children: ['일', '월', '화', '수', '목', '금', '토']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: TextStyle(
                              fontSize: AppTypography.bodySmall,
                              fontWeight: FontWeight.w600,
                              color: d == '일'
                                  ? AppColors.sundayText
                                  : d == '토'
                                      ? AppColors.saturdayText
                                      : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          SizedBox(height: Spacing.xs),
          // Calendar grid
          if (calProvider.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Spacing.xs),
              child: Column(
                children: List.generate(rows, (row) {
                  return Row(
                    children: List.generate(7, (col) {
                      final cellIndex = row * 7 + col;
                      final dayNum = cellIndex - startWeekday + 1;

                      // Non-current-month days: show at 40% opacity
                      if (dayNum < 1) {
                        // Previous month trailing days
                        final prevDay = prevMonthDays + dayNum;
                        return Expanded(
                          child: Container(
                            height: Spacing.xxxl,
                            padding: EdgeInsets.all(Spacing.sm),
                            child: Opacity(
                              opacity: 0.4,
                              child: Center(
                                child: Text(
                                  '$prevDay',
                                  style: TextStyle(
                                    fontSize: AppTypography.dayNumber,
                                    fontWeight: FontWeight.w500,
                                    color: col == 0
                                        ? AppColors.sundayText
                                        : col == 6
                                            ? AppColors.saturdayText
                                            : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      if (dayNum > totalDays) {
                        // Next month leading days
                        final nextDay = dayNum - totalDays;
                        return Expanded(
                          child: Container(
                            height: Spacing.xxxl,
                            padding: EdgeInsets.all(Spacing.sm),
                            child: Opacity(
                              opacity: 0.4,
                              child: Center(
                                child: Text(
                                  '$nextDay',
                                  style: TextStyle(
                                    fontSize: AppTypography.dayNumber,
                                    fontWeight: FontWeight.w500,
                                    color: col == 0
                                        ? AppColors.sundayText
                                        : col == 6
                                            ? AppColors.saturdayText
                                            : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
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
                      final dayHolidays = calProvider.holidaysForDay(day);
                      final isHoliday = dayHolidays.isNotEmpty;
                      final hasEvents = dayEvents.isNotEmpty;
                      final hasTasks = dayTasks.isNotEmpty;
                      final eventColors = _uniqueEventColors(dayEvents);

                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedDay = day);
                            context.read<CalendarProvider>().setSelectedDate(day);
                          },
                          onDoubleTap: () {
                            context.go('/daily?date=${day.toIso8601String()}');
                          },
                          child: Container(
                            height: Spacing.xxxl,
                            margin: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary.withAlpha(25)
                                  : null,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Date number with today circle
                                Container(
                                  width: isToday ? AppColors.todayCircleSize : null,
                                  height: isToday ? AppColors.todayCircleSize : null,
                                  alignment: Alignment.center,
                                  decoration: isToday
                                      ? BoxDecoration(
                                          color: theme.colorScheme.primary,
                                          shape: BoxShape.circle,
                                        )
                                      : null,
                                  child: Text(
                                    '$dayNum',
                                    style: TextStyle(
                                      fontSize: AppTypography.dayNumber,
                                      fontWeight: FontWeight.w500,
                                      color: isToday
                                          ? Colors.white
                                          : isHoliday
                                              ? AppColors.sundayText
                                              : col == 0
                                                  ? AppColors.sundayText
                                                  : col == 6
                                                      ? AppColors.saturdayText
                                                      : null,
                                    ),
                                  ),
                                ),
                                if (isHoliday) ...[
                                  Text(
                                    dayHolidays.first.name,
                                    style: const TextStyle(
                                      fontSize: 8,
                                      color: AppColors.sundayText,
                                      fontWeight: FontWeight.w500,
                                      height: 1.1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ] else ...[
                                  const SizedBox(height: 2),
                                  // Event indicator dots (up to 3 unique colors) + task dot
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (hasEvents)
                                        ...eventColors.map((color) => Container(
                                              width: 5,
                                              height: 5,
                                              margin: const EdgeInsets.symmetric(horizontal: 1),
                                              decoration: BoxDecoration(
                                                color: isToday ? Colors.white : color,
                                                shape: BoxShape.circle,
                                              ),
                                            )),
                                      if (hasTasks)
                                        Container(
                                          width: 5,
                                          height: 5,
                                          margin: const EdgeInsets.symmetric(horizontal: 1),
                                          decoration: BoxDecoration(
                                            color: isToday ? Colors.white70 : AppColors.taskPending,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
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
            SizedBox(height: Spacing.xs),
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
    final eventColor = parseColor(event.calendarColor);
    final theme = Theme.of(context);

    return Container(
      margin: EdgeInsets.only(bottom: Spacing.sm),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: eventColor.withAlpha(38), // ~15% opacity (255 * 0.15 ≈ 38)
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border(left: BorderSide(color: eventColor, width: 3)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onEventTap,
            child: Padding(
              padding: EdgeInsets.all(Spacing.md),
              child: Row(
                children: [
                  Container(
                    width: Spacing.sm,
                    height: Spacing.sm,
                    decoration: BoxDecoration(
                      color: eventColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: Spacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: TextStyle(fontSize: AppTypography.eventTitle, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.isAllDay
                              ? '종일'
                              : '${timeFormat.format(event.startTime)} – ${timeFormat.format(event.endTime)}',
                          style: TextStyle(fontSize: AppTypography.eventTime, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (tasks.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.relatedBadge.withAlpha(25),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(
                        'Task ${tasks.where((t) => t.isDone).length}/${tasks.length}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.relatedBadge,
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
                  left: BorderSide(color: eventColor, width: 3),
                  top: BorderSide(color: theme.dividerColor),
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: 6),
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
