import 'dart:async';
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
const _overdueColor = Color(0xFFEF6B6B);
const _nowColor = Color(0xFFEF6B6B);
const _relatedColor = Color(0xFFA78BFA);

class DailyViewScreen extends StatefulWidget {
  final DateTime? initialDate;
  const DailyViewScreen({super.key, this.initialDate});

  @override
  State<DailyViewScreen> createState() => _DailyViewScreenState();
}

class _DailyViewScreenState extends State<DailyViewScreen> {
  late DateTime _selectedDate;
  int _subTab = 0; // 0=Timeline, 1=Task
  bool _unschedExpanded = true;
  bool _completedExpanded = false;
  Timer? _nowTimer;
  final ScrollController _timelineScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
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
    _timelineScroll.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final end = start.add(const Duration(days: 1));
    final provider = context.read<CalendarProvider>();
    await Future.wait([
      provider.loadEvents(start: start, end: end),
      provider.loadFamilyEvents(start: start, end: end),
      provider.loadTasks(start: start, end: end),
    ]);
  }

  void _scrollToNow() {
    final now = DateTime.now();
    if (_selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day) {
      final offset = (now.hour - 1).clamp(0, 23) * 64.0;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_timelineScroll.hasClients) {
          _timelineScroll.animateTo(offset,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut);
        }
      });
    }
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  // Build week date strip
  List<DateTime> get _weekDates {
    final start = _selectedDate.subtract(Duration(days: _selectedDate.weekday % 7));
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final calProvider = context.watch<CalendarProvider>();
    final dateStr = DateFormat('M월 d일 (E)', 'ko').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(dateStr),
        actions: [
          if (!_isToday)
            TextButton(
              onPressed: () {
                setState(() => _selectedDate = DateTime.now());
                _loadData();
                _scrollToNow();
              },
              child: const Text('오늘'),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildWeekStrip(),
          _buildSubTabs(),
          Expanded(
            child: calProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _subTab == 0
                    ? _buildTimeline(calProvider)
                    : _buildTaskList(calProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStrip() {
    final today = DateTime.now();
    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: 7,
        itemBuilder: (context, i) {
          final day = _weekDates[i];
          final isSelected = day.day == _selectedDate.day &&
              day.month == _selectedDate.month;
          final isToday = day.day == today.day &&
              day.month == today.month &&
              day.year == today.year;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = day);
              _loadData();
            },
            child: Container(
              width: 48,
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _eventColor.withAlpha(30) : null,
                border: isToday ? Border.all(color: _eventColor, width: 1.5) : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E', 'ko').format(day),
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? _eventColor : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? _eventColor : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
          selectedBackgroundColor: _subTab == 0
              ? _eventColor.withAlpha(25)
              : _taskColor.withAlpha(25),
          selectedForegroundColor: _subTab == 0 ? _eventColor : _taskColor,
        ),
      ),
    );
  }

  // ─── TIMELINE TAB ───

  Widget _buildTimeline(CalendarProvider calProvider) {
    final dayStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final allEvents = calProvider.allVisibleEvents
        .where((e) => e.startTime.isBefore(dayEnd) && e.endTime.isAfter(dayStart))
        .toList();
    final allTasks = calProvider.tasks.where((t) {
      final date = t.scheduledDate ?? t.dueDate;
      if (date == null) return t.isTodo;
      return !date.isBefore(dayStart) && date.isBefore(dayEnd);
    }).toList();
    final unscheduled = allTasks.where((t) =>
        t.scheduledTime == null && t.dueDate == null && t.scheduledDate == null && t.isTodo).toList();

    return ListView(
      controller: _timelineScroll,
      children: [
        if (unscheduled.isNotEmpty) _buildUnscheduledZone(unscheduled, calProvider),
        ..._buildTimelineSlots(allEvents, allTasks, calProvider),
      ],
    );
  }

  Widget _buildUnscheduledZone(List<TaskModel> tasks, CalendarProvider calProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _unschedExpanded = !_unschedExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _unschedExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18, color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text('시간 미정', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: _taskColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${tasks.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _taskColor)),
                  ),
                ],
              ),
            ),
          ),
          if (_unschedExpanded)
            ...tasks.map((t) => Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: _buildStandaloneTask(t, calProvider, dashed: true),
            )),
        ],
      ),
    );
  }

  List<Widget> _buildTimelineSlots(
      List<EventModel> events, List<TaskModel> tasks, CalendarProvider calProvider) {
    final now = DateTime.now();
    final isToday = _isToday;
    final widgets = <Widget>[];

    // Build hour -> items map
    final Map<int, List<Widget>> hourItems = {};
    for (int h = 0; h < 24; h++) {
      hourItems[h] = [];
    }

    // Place events
    for (final event in events) {
      final hour = event.startTime.hour;
      final nestedTasks = tasks.where((t) => t.eventId == event.id).toList();
      hourItems[hour]!.add(_buildEventCard(event, nestedTasks, calProvider));
    }

    // Place standalone tasks with scheduled time
    for (final task in tasks) {
      if (task.eventId != null) continue;
      if (task.scheduledTime == null) continue;
      final parts = task.scheduledTime!.split(':');
      if (parts.length < 2) continue;
      final hour = int.tryParse(parts[0]) ?? 0;
      hourItems[hour]!.add(_buildStandaloneTask(task, calProvider));
    }

    // Find first/last active hours
    int firstHour = 7;
    int lastHour = 19;
    for (int h = 0; h < 24; h++) {
      if (hourItems[h]!.isNotEmpty) {
        if (h < firstHour) firstHour = h;
        if (h > lastHour) lastHour = h;
      }
    }
    if (isToday && now.hour > lastHour) lastHour = now.hour + 1;
    if (isToday && now.hour < firstHour) firstHour = now.hour;
    firstHour = firstHour.clamp(0, 23);
    lastHour = (lastHour + 1).clamp(firstHour + 1, 24);

    for (int h = firstHour; h < lastHour; h++) {
      final items = hourItems[h]!;

      // Now marker
      if (isToday && now.hour == h) {
        final minuteFraction = now.minute / 60.0;
        widgets.add(
          Stack(
            clipBehavior: Clip.none,
            children: [
              _buildHourRow(h, items),
              Positioned(
                top: 28 + (minuteFraction * 64),
                left: 0, right: 0,
                child: _buildNowLine(now),
              ),
            ],
          ),
        );
      } else {
        widgets.add(_buildHourRow(h, items));
      }
    }

    return widgets;
  }

  Widget _buildHourRow(int hour, List<Widget> items) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 46,
          child: Padding(
            padding: const EdgeInsets.only(top: 2, right: 8),
            child: Text(
              hour.toString().padLeft(2, '0'),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey[500],
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor.withAlpha(80)),
                left: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
            child: items.isEmpty
                ? const SizedBox()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: items,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildNowLine(DateTime now) {
    return Row(
      children: [
        const SizedBox(width: 42),
        Container(
          width: 8, height: 8,
          decoration: const BoxDecoration(color: _nowColor, shape: BoxShape.circle),
        ),
        Expanded(child: Container(height: 2, color: _nowColor)),
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 8),
          child: Text(
            DateFormat('HH:mm').format(now),
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _nowColor),
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(EventModel event, List<TaskModel> nestedTasks, CalendarProvider calProvider) {
    final timeFormat = DateFormat('HH:mm');
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
                  const _Dot(color: _eventColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(
                          event.isAllDay
                              ? '종일'
                              : '${timeFormat.format(event.startTime)} – ${timeFormat.format(event.endTime)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  if (nestedTasks.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _relatedColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${nestedTasks.where((t) => t.isDone).length}/${nestedTasks.length}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _relatedColor),
                      ),
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

  Widget _buildStandaloneTask(TaskModel task, CalendarProvider calProvider, {bool dashed = false}) {
    return TaskCard(
      task: task,
      onTap: () => context.push('/task/${task.baseId}/edit'),
      onToggleComplete: () => calProvider.toggleTaskComplete(task.baseId),
    );
  }

  // ─── TASK TAB ───

  Widget _buildTaskList(CalendarProvider calProvider) {
    final dayStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final allTasks = calProvider.tasks.where((t) {
      final date = t.scheduledDate ?? t.dueDate;
      if (date == null) return t.isTodo;
      return !date.isBefore(dayStart) && date.isBefore(dayEnd);
    }).toList();
    final overdue = allTasks.where((t) => t.isOverdue).toList();
    final eventLinked = allTasks.where((t) => t.hasEvent && !t.isDone && !t.isOverdue).toList();
    final standalone = allTasks.where((t) => !t.hasEvent && t.hasTime && !t.isDone && !t.isOverdue).toList();
    final unscheduled = allTasks.where((t) => !t.hasTime && !t.hasDueDate && t.scheduledDate == null && !t.isDone && !t.isOverdue && !t.hasEvent).toList();
    final completed = allTasks.where((t) => t.isDone).toList();
    final totalTasks = allTasks.length;
    final doneTasks = completed.length;

    // Group event-linked tasks by event
    final Map<String, List<TaskModel>> eventTaskMap = {};
    for (final t in eventLinked) {
      eventTaskMap.putIfAbsent(t.eventId!, () => []).add(t);
    }
    final events = calProvider.allVisibleEvents;

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
                    Text('$doneTasks / $totalTasks 완료',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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

        // Overdue
        if (overdue.isNotEmpty) ...[
          _sectionHeader('기한 초과', overdue.length, _overdueColor),
          ...overdue.map((t) => TaskCard(
            task: t,
            onTap: () => context.push('/task/${t.baseId}/edit'),
            onToggleComplete: () => calProvider.toggleTaskComplete(t.baseId),
          )),
        ],

        // Event-linked
        if (eventTaskMap.isNotEmpty) ...[
          _sectionHeader('Event 연결', eventLinked.length, _relatedColor),
          ...eventTaskMap.entries.map((entry) {
            final event = events.where((e) => e.id == entry.key).firstOrNull;
            if (event == null) return const SizedBox();
            return _buildEventCard(event, entry.value, calProvider);
          }),
        ],

        // Standalone timed
        if (standalone.isNotEmpty) ...[
          _sectionHeader('독립 Task', standalone.length, _taskColor),
          ...standalone.map((t) => TaskCard(
            task: t,
            onTap: () => context.push('/task/${t.baseId}/edit'),
            onToggleComplete: () => calProvider.toggleTaskComplete(t.baseId),
          )),
        ],

        // Unscheduled
        if (unscheduled.isNotEmpty) ...[
          _sectionHeader('시간 미정', unscheduled.length, Colors.grey),
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
                  Icon(_completedExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text('완료됨', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                  const SizedBox(width: 6),
                  Text('(${completed.length})', style: TextStyle(fontSize: 11, color: _doneColor)),
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

  Widget _sectionHeader(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Container(width: 3, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          const SizedBox(width: 6),
          Text('$count', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 7, height: 7,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
