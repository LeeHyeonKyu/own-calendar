import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';
import '../models/event.dart';
import '../models/task.dart';
import '../widgets/task_card.dart';

const _eventColor = Color(0xFF5B8DEF);
const _taskColor = Color(0xFFF0A050);
const _doneColor = Color(0xFF4ADE80);
const _relatedColor = Color(0xFFA78BFA);

class WeeklyViewScreen extends StatefulWidget {
  const WeeklyViewScreen({super.key});

  @override
  State<WeeklyViewScreen> createState() => _WeeklyViewScreenState();
}

class _WeeklyViewScreenState extends State<WeeklyViewScreen> {
  late DateTime _weekStart;
  int _subTab = 0; // 0=Timeline, 1=Task
  int? _selectedDayIndex;
  bool _unschedExpanded = true;
  bool _completedExpanded = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday % 7));
    _selectedDayIndex = now.weekday % 7;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  List<DateTime> get _days => List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  Future<void> _loadData() async {
    final weekEnd = _weekStart.add(const Duration(days: 7));
    final provider = context.read<CalendarProvider>();
    await Future.wait([
      provider.loadEvents(start: _weekStart, end: weekEnd),
      provider.loadFamilyEvents(start: _weekStart, end: weekEnd),
      provider.loadTasks(start: _weekStart, end: weekEnd),
    ]);
  }

  void _changeWeek(int delta) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: delta * 7));
      _selectedDayIndex = null;
    });
    _loadData();
  }

  List<EventModel> _eventsForDay(DateTime day, List<EventModel> allEvents) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return allEvents
        .where((e) => e.startTime.isBefore(dayEnd) && e.endTime.isAfter(dayStart))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
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

  @override
  Widget build(BuildContext context) {
    final calProvider = context.watch<CalendarProvider>();
    final days = _days;
    final weekLabel = '${DateFormat('M/d').format(_weekStart)} – ${DateFormat('M/d').format(days.last)}';

    return Scaffold(
      appBar: AppBar(
        title: Text(weekLabel),
        actions: [
          TextButton(
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _weekStart = now.subtract(Duration(days: now.weekday % 7));
                _selectedDayIndex = now.weekday % 7;
              });
              _loadData();
            },
            child: const Text('이번 주'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildWeekHeader(calProvider, days),
          _buildSubTabs(),
          Expanded(
            child: calProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _subTab == 0
                    ? _buildTimelineTab(calProvider, days)
                    : _buildTaskTab(calProvider, days),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekHeader(CalendarProvider calProvider, List<DateTime> days) {
    final today = DateTime.now();
    final allEvents = calProvider.allVisibleEvents;
    final allTasks = calProvider.tasks;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: () => _changeWeek(-1),
          ),
          ...days.asMap().entries.map((entry) {
            final i = entry.key;
            final day = entry.value;
            final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
            final isSelected = _selectedDayIndex == i;
            final dayEvents = _eventsForDay(day, allEvents);
            final dayTasks = _tasksForDay(day, allTasks);

            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedDayIndex = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? _eventColor.withAlpha(20) : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('E', 'ko').format(day),
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: isToday ? _eventColor : null,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isToday ? Colors.white : isSelected ? _eventColor : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (dayEvents.isNotEmpty)
                            Container(width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: const BoxDecoration(color: _eventColor, shape: BoxShape.circle)),
                          if (dayTasks.isNotEmpty)
                            Container(width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: const BoxDecoration(color: _taskColor, shape: BoxShape.circle)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: () => _changeWeek(1),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('Timeline'), icon: Icon(Icons.schedule, size: 16)),
          ButtonSegment(value: 1, label: Text('Task'), icon: Icon(Icons.checklist, size: 16)),
        ],
        selected: {_subTab},
        onSelectionChanged: (v) => setState(() => _subTab = v.first),
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: _subTab == 0 ? _eventColor.withAlpha(25) : _taskColor.withAlpha(25),
          selectedForegroundColor: _subTab == 0 ? _eventColor : _taskColor,
        ),
      ),
    );
  }

  // ─── TIMELINE TAB ───

  Widget _buildTimelineTab(CalendarProvider calProvider, List<DateTime> days) {
    final allEvents = calProvider.allVisibleEvents;
    final allTasks = calProvider.tasks;
    final timeFormat = DateFormat('HH:mm');

    // All-day events row
    final allDayEvents = allEvents.where((e) => e.isAllDay).toList();

    if (_selectedDayIndex != null) {
      // Show selected day detail
      final day = days[_selectedDayIndex!];
      final dayEvents = _eventsForDay(day, allEvents).where((e) => !e.isAllDay).toList();
      final dayTasks = _tasksForDay(day, allTasks);
      final dateStr = DateFormat('M/d (E)', 'ko').format(day);

      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          // All-day events
          if (allDayEvents.any((e) {
            final dayStart = DateTime(day.year, day.month, day.day);
            final dayEnd = dayStart.add(const Duration(days: 1));
            return e.startTime.isBefore(dayEnd) && e.endTime.isAfter(dayStart);
          }))
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Wrap(
                spacing: 4,
                children: allDayEvents.where((e) {
                  final dayStart = DateTime(day.year, day.month, day.day);
                  final dayEnd = dayStart.add(const Duration(days: 1));
                  return e.startTime.isBefore(dayEnd) && e.endTime.isAfter(dayStart);
                }).map((e) => Chip(
                  avatar: const CircleAvatar(backgroundColor: _eventColor, radius: 4),
                  label: Text(e.title, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            ),

          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(dateStr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (dayEvents.isNotEmpty)
                  _countBadge(dayEvents.length, _eventColor),
                const SizedBox(width: 4),
                if (dayTasks.isNotEmpty)
                  _countBadge(dayTasks.length, _taskColor),
              ],
            ),
          ),

          // Events + tasks grouped
          ..._buildDayItems(dayEvents, dayTasks, calProvider),

          if (dayEvents.isEmpty && dayTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('일정 없음', style: TextStyle(color: Colors.grey[400]))),
            ),
          const SizedBox(height: 80),
        ],
      );
    }

    // No day selected — show overview of all 7 days
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text('날짜를 선택하세요', style: TextStyle(color: Colors.grey[400], fontSize: 14),
              textAlign: TextAlign.center),
        ),
        ...days.asMap().entries.map((entry) {
          final day = entry.value;
          final dayEvents = _eventsForDay(day, allEvents);
          final dayTasks = _tasksForDay(day, allTasks);
          if (dayEvents.isEmpty && dayTasks.isEmpty) return const SizedBox();
          final dateStr = DateFormat('E d일', 'ko').format(day);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Row(
                  children: [
                    Text(dateStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    _countBadge(dayEvents.length, _eventColor),
                    const SizedBox(width: 4),
                    _countBadge(dayTasks.length, _taskColor),
                  ],
                ),
              ),
              ...dayEvents.take(2).map((e) => _miniEventRow(e, timeFormat)),
              ...dayTasks.take(2).map((t) => _miniTaskRow(t)),
              if (dayEvents.length + dayTasks.length > 4)
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 2),
                  child: Text('+${dayEvents.length + dayTasks.length - 4}개 더',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                ),
              const Divider(),
            ],
          );
        }),
      ],
    );
  }

  List<Widget> _buildDayItems(List<EventModel> events, List<TaskModel> tasks, CalendarProvider calProvider) {
    final timeFormat = DateFormat('HH:mm');
    final widgets = <Widget>[];

    // Group tasks by event
    final Map<String, List<TaskModel>> eventTaskMap = {};
    final List<TaskModel> standaloneTasks = [];
    for (final t in tasks) {
      if (t.eventId != null) {
        eventTaskMap.putIfAbsent(t.eventId!, () => []).add(t);
      } else {
        standaloneTasks.add(t);
      }
    }

    // Events with nested tasks (time sorted)
    for (final event in events) {
      final nested = eventTaskMap[event.id] ?? [];
      widgets.add(_buildEventCard(event, nested, calProvider, timeFormat));
    }

    // Standalone tasks
    for (final task in standaloneTasks) {
      widgets.add(TaskCard(
        task: task,
        onTap: () => context.push('/task/${task.baseId}/edit'),
        onToggleComplete: () => calProvider.toggleTaskComplete(task.baseId),
      ));
    }

    return widgets;
  }

  Widget _buildEventCard(EventModel event, List<TaskModel> nestedTasks, CalendarProvider calProvider, DateFormat timeFormat) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => context.push('/event/${event.id}/edit'),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: _eventColor, width: 3)),
              ),
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Container(width: 7, height: 7, decoration: const BoxDecoration(color: _eventColor, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(
                          event.isAllDay ? '종일' : '${timeFormat.format(event.startTime)} – ${timeFormat.format(event.endTime)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  if (nestedTasks.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: _relatedColor.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                      child: Text('${nestedTasks.where((t) => t.isDone).length}/${nestedTasks.length}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _relatedColor)),
                    ),
                ],
              ),
            ),
          ),
          if (nestedTasks.isNotEmpty)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(
                  left: const BorderSide(color: _eventColor, width: 3),
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: nestedTasks.map((t) => NestedTaskItem(
                  task: t,
                  onToggleComplete: () => calProvider.toggleTaskComplete(t.baseId),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ─── TASK TAB ───

  Widget _buildTaskTab(CalendarProvider calProvider, List<DateTime> days) {
    final allTasks = calProvider.tasks;
    final allEvents = calProvider.allVisibleEvents;
    final totalTasks = allTasks.length;
    final doneTasks = allTasks.where((t) => t.isDone).length;
    final unscheduled = allTasks.where((t) =>
        t.scheduledDate == null && t.dueDate == null && t.isTodo).toList();
    final completed = allTasks.where((t) => t.isDone).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        // Progress bar
        if (totalTasks > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('$doneTasks / $totalTasks 완료', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('${totalTasks > 0 ? (doneTasks * 100 ~/ totalTasks) : 0}%',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: totalTasks > 0 ? doneTasks / totalTasks : 0,
                    backgroundColor: Theme.of(context).dividerColor,
                    color: _doneColor,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

        // Day sections
        ...days.map((day) {
          final dayTasks = _tasksForDay(day, allTasks).where((t) => !t.isDone).toList();
          final dayEvents = _eventsForDay(day, allEvents);
          if (dayTasks.isEmpty && dayEvents.isEmpty) return const SizedBox();

          final dateStr = DateFormat('E d일', 'ko').format(day);
          final today = DateTime.now();
          final isToday = day.year == today.year && day.month == today.month && day.day == today.day;

          // Group by event
          final Map<String, List<TaskModel>> eventMap = {};
          final List<TaskModel> standalone = [];
          for (final t in dayTasks) {
            if (t.eventId != null) {
              eventMap.putIfAbsent(t.eventId!, () => []).add(t);
            } else {
              standalone.add(t);
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Row(
                  children: [
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: _eventColor, borderRadius: BorderRadius.circular(10)),
                        child: Text(dateStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      )
                    else
                      Text(dateStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (dayEvents.isNotEmpty)
                      _countBadge(dayEvents.length, _eventColor),
                  ],
                ),
              ),
              // Event-nested tasks
              ...eventMap.entries.map((entry) {
                final event = dayEvents.where((e) => e.id == entry.key).firstOrNull;
                if (event == null) return const SizedBox();
                return _buildEventCard(event, entry.value, calProvider, DateFormat('HH:mm'));
              }),
              // Standalone tasks
              ...standalone.map((t) => TaskCard(
                task: t,
                onTap: () => context.push('/task/${t.baseId}/edit'),
                onToggleComplete: () => calProvider.toggleTaskComplete(t.baseId),
              )),
              const Divider(height: 1),
            ],
          );
        }),

        // Unscheduled
        if (unscheduled.isNotEmpty) ...[
          InkWell(
            onTap: () => setState(() => _unschedExpanded = !_unschedExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(_unschedExpanded ? Icons.expand_less : Icons.expand_more, size: 18, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text('이번 주 중', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                  const SizedBox(width: 6),
                  Text('(${unscheduled.length})', style: const TextStyle(fontSize: 11, color: _taskColor)),
                ],
              ),
            ),
          ),
          if (_unschedExpanded)
            ...unscheduled.map((t) => TaskCard(
              task: t,
              onTap: () => context.push('/task/${t.baseId}/edit'),
              onToggleComplete: () => calProvider.toggleTaskComplete(t.baseId),
            )),
        ],

        // Completed (collapsible)
        if (completed.isNotEmpty) ...[
          InkWell(
            onTap: () => setState(() => _completedExpanded = !_completedExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(_completedExpanded ? Icons.expand_less : Icons.expand_more, size: 18, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text('완료됨', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                  const SizedBox(width: 6),
                  Text('(${completed.length})', style: const TextStyle(fontSize: 11, color: _doneColor)),
                ],
              ),
            ),
          ),
          if (_completedExpanded)
            ...completed.map((t) => TaskCard(
              task: t,
              onTap: () => context.push('/task/${t.baseId}/edit'),
              onToggleComplete: () => calProvider.toggleTaskComplete(t.baseId),
            )),
        ],

        const SizedBox(height: 80),
      ],
    );
  }

  // ─── HELPERS ───

  Widget _countBadge(int count, Color color) {
    if (count == 0) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8)),
      child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _miniEventRow(EventModel event, DateFormat timeFormat) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: _eventColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(event.title, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
          Text(event.isAllDay ? '종일' : timeFormat.format(event.startTime),
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _miniTaskRow(TaskModel task) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 14, height: 14,
            decoration: BoxDecoration(
              border: Border.all(color: task.isDone ? _doneColor : _taskColor, width: 1.5),
              borderRadius: BorderRadius.circular(3),
              color: task.isDone ? _doneColor : null,
            ),
            child: task.isDone ? const Icon(Icons.check, size: 9, color: Colors.white) : null,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(task.title, style: TextStyle(
            fontSize: 13,
            decoration: task.isDone ? TextDecoration.lineThrough : null,
            color: task.isDone ? Colors.grey : null,
          ), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

}
