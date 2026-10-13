import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';
import '../models/task.dart';
import '../services/api_service.dart';
import '../themes/spacing.dart';

class HabitScreen extends StatefulWidget {
  const HabitScreen({super.key});

  @override
  State<HabitScreen> createState() => _HabitScreenState();
}

class _HabitScreenState extends State<HabitScreen> {
  final ApiService _api = ApiService();
  late DateTime _today;
  Map<String, _HabitStats> _statsMap = {};
  bool _statsLoading = false;
  String? _selectedHabitId; // null = all habits combined

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final start = DateTime(_today.year, _today.month, _today.day);
    final end = start.add(const Duration(days: 1));
    final provider = context.read<CalendarProvider>();
    await Future.wait([
      provider.loadTasks(start: start, end: end),
      provider.loadCategories(),
    ]);
    if (mounted) _loadStats();
  }

  List<TaskModel> get _habits {
    return context.read<CalendarProvider>().tasks.where((t) => t.isHabit).toList();
  }

  Future<void> _loadStats() async {
    final habits = _habits;
    if (habits.isEmpty) return;
    setState(() => _statsLoading = true);
    final newStatsMap = <String, _HabitStats>{};
    for (final habit in habits) {
      try {
        final res = await _api.get(
          '/tasks/${habit.baseId}/habit-stats?year=${_today.year}&month=${_today.month}',
        );
        if (res.statusCode == 200) {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          newStatsMap[habit.baseId] = _HabitStats.fromJson(json);
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _statsMap = newStatsMap;
        _statsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final calProvider = context.watch<CalendarProvider>();
    final habits = calProvider.tasks.where((t) => t.isHabit).toList();
    final dateStr = DateFormat('M월 d일 (E)', 'ko').format(_today);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final doneCount = habits.where((h) => h.isDone).length;
    final totalCount = habits.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('습관'),
        actions: [
          TextButton(
            onPressed: () {
              final now = DateTime.now();
              setState(() => _today = DateTime(now.year, now.month, now.day));
              _loadData();
            },
            child: Text(dateStr),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/task/new?isHabit=true&date=${_today.toIso8601String()}');
        },
        child: const Icon(Icons.add),
      ),
      body: habits.isEmpty
          ? _buildEmptyState(cs)
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                children: [
                  // Progress bar
                  _buildProgressBar(doneCount, totalCount, cs),
                  const SizedBox(height: Spacing.sm),
                  // Today's habits checklist
                  ...habits.map((habit) => _buildHabitRow(habit, calProvider, cs)),
                  const SizedBox(height: Spacing.lg),
                  // Weekly summary
                  if (_statsMap.isNotEmpty) ...[
                    _buildSectionHeader('주간 요약', cs),
                    const SizedBox(height: Spacing.sm),
                    _buildWeeklySummary(habits, cs),
                    const SizedBox(height: Spacing.lg),
                    // Monthly heatmap
                    _buildSectionHeader('${_today.month}월 히트맵', cs),
                    const SizedBox(height: Spacing.sm),
                    _buildHabitSelector(habits, cs),
                    const SizedBox(height: Spacing.sm),
                    _buildMonthlyHeatmap(habits, cs),
                  ],
                  if (_statsLoading)
                    const Padding(
                      padding: EdgeInsets.all(Spacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.self_improvement, size: 64, color: cs.outlineVariant),
          const SizedBox(height: Spacing.md),
          Text(
            '등록된 습관이 없습니다',
            style: TextStyle(
              fontSize: AppTypography.h3,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            '+ 버튼으로 습관을 추가하세요',
            style: TextStyle(
              fontSize: AppTypography.bodySmall,
              color: cs.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(int done, int total, ColorScheme cs) {
    final pct = total > 0 ? (done * 100 ~/ total) : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.md),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$done / $total 완료',
                style: const TextStyle(
                  fontSize: AppTypography.bodySmall,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: AppTypography.bodySmall,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: total > 0 ? done / total : 0,
              backgroundColor: cs.surfaceContainerHighest,
              color: AppColors.taskDone,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitRow(TaskModel habit, CalendarProvider calProvider, ColorScheme cs) {
    final stats = _statsMap[habit.baseId];
    final streak = stats?.streak ?? 0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: Spacing.xs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: habit.isDone ? 0.55 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => context.push('/task/${habit.baseId}/edit'),
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Row(
                  children: [
                    // Checkbox
                    GestureDetector(
                      onTap: () {
                        calProvider.toggleTaskComplete(
                          habit.baseId,
                          instanceDate: habit.instanceDateString,
                        );
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: habit.isDone ? AppColors.taskDone : cs.outline,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          color: habit.isDone ? AppColors.taskDone : null,
                        ),
                        child: habit.isDone
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    // Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habit.title,
                            style: TextStyle(
                              fontSize: AppTypography.body,
                              fontWeight: FontWeight.w500,
                              decoration: habit.isDone ? TextDecoration.lineThrough : null,
                              color: habit.isDone ? cs.outline : null,
                            ),
                          ),
                          if (habit.hasTime)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                habit.scheduledTime!,
                                style: TextStyle(
                                  fontSize: AppTypography.bodySmall,
                                  color: AppColors.taskPending,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Streak badge
                    if (streak > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.tertiary.withAlpha(25),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '\u{1F525}',
                              style: TextStyle(fontSize: AppTypography.bodySmall),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '$streak일',
                              style: TextStyle(
                                fontSize: AppTypography.bodySmall,
                                fontWeight: FontWeight.w600,
                                color: cs.tertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Checklist sub-items
            if (habit.hasChecklist) _buildChecklistSection(habit, calProvider, cs),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistSection(TaskModel habit, CalendarProvider calProvider, ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, color: cs.outlineVariant.withAlpha(80)),
        Padding(
          padding: const EdgeInsets.only(
            left: Spacing.lg,
            right: Spacing.md,
            top: Spacing.xs,
            bottom: Spacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(habit.checklist!.length, (i) {
              final item = habit.checklist![i];
              return Padding(
                padding: EdgeInsets.only(left: item.indent * 20.0, top: 2, bottom: 2),
                child: Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        final updated = List<ChecklistItem>.from(habit.checklist!);
                        updated[i] = updated[i].copyWith(done: !updated[i].done);
                        final checklistJson = updated.map((e) => e.toJson()).toList();
                        calProvider.updateTask(
                          habit.baseId,
                          {'checklist': checklistJson},
                          editMode: habit.isVirtualInstance ? 'this' : null,
                          instanceDate: habit.instanceDateString,
                        );
                      },
                      child: SizedBox(
                        width: 48,
                        height: 32,
                        child: Center(
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: item.done ? AppColors.taskDone : cs.outline,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(3),
                              color: item.done ? AppColors.taskDone : null,
                            ),
                            child: item.done
                                ? const Icon(Icons.check, size: 10, color: Colors.white)
                                : null,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.text,
                        style: TextStyle(
                          fontSize: AppTypography.eventTitle,
                          decoration: item.done ? TextDecoration.lineThrough : null,
                          color: item.done ? cs.outline : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm),
      child: Text(
        title,
        style: TextStyle(
          fontSize: AppTypography.h3,
          fontWeight: FontWeight.bold,
          color: cs.onSurface,
        ),
      ),
    );
  }

  Widget _buildWeeklySummary(List<TaskModel> habits, ColorScheme cs) {
    final dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with day labels
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    '',
                    style: TextStyle(fontSize: AppTypography.bodySmall),
                  ),
                ),
                ...dayLabels.map((label) => Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: AppTypography.caption,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )),
              ],
            ),
            const SizedBox(height: Spacing.xs),
            // One row per habit
            ...habits.map((habit) {
              final stats = _statsMap[habit.baseId];
              final weekSummary = stats?.weekSummary ?? [];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        habit.title,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: AppTypography.bodySmall,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    ...List.generate(7, (i) {
                      // weekSummary should have 7 entries: Mon-Sun
                      String status = '-';
                      if (weekSummary.length > i) {
                        status = weekSummary[i]; // 'done', 'missed', 'na'
                      }
                      return Expanded(
                        child: Center(
                          child: _weekDot(status, cs),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _weekDot(String status, ColorScheme cs) {
    if (status == 'na') {
      return const SizedBox(width: 12, height: 12);
    }
    final isDone = status == 'done';
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone ? AppColors.taskDone : null,
        border: isDone
            ? null
            : Border.all(color: cs.outlineVariant, width: 1.5),
      ),
    );
  }

  Widget _buildHabitSelector(List<TaskModel> habits, ColorScheme cs) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('전체', _selectedHabitId == null, () {
            setState(() => _selectedHabitId = null);
          }, cs),
          const SizedBox(width: Spacing.sm),
          ...habits.map((h) => Padding(
                padding: const EdgeInsets.only(right: Spacing.sm),
                child: _filterChip(h.title, _selectedHabitId == h.baseId, () {
                  setState(() => _selectedHabitId = h.baseId);
                }, cs),
              )),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap, ColorScheme cs) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withAlpha(25) : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: selected ? Border.all(color: cs.primary) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTypography.bodySmall,
            fontWeight: FontWeight.w600,
            color: selected ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyHeatmap(List<TaskModel> habits, ColorScheme cs) {
    final year = _today.year;
    final month = _today.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final totalDays = lastDay.day;
    final startWeekday = firstDay.weekday % 7; // 0=Sun

    // Build grid data from stats
    // For combined view or single habit
    final Map<int, double> dayCompletionRate = {};
    if (_selectedHabitId != null) {
      final stats = _statsMap[_selectedHabitId];
      if (stats != null) {
        for (final entry in stats.monthGrid.entries) {
          final day = int.tryParse(entry.key);
          if (day != null) {
            dayCompletionRate[day] = entry.value ? 1.0 : 0.0;
          }
        }
      }
    } else {
      // Combined: average completion across all habits
      for (int d = 1; d <= totalDays; d++) {
        int done = 0;
        int applicable = 0;
        for (final habit in habits) {
          final stats = _statsMap[habit.baseId];
          if (stats == null) continue;
          final dayStr = d.toString();
          if (stats.monthGrid.containsKey(dayStr)) {
            applicable++;
            if (stats.monthGrid[dayStr] == true) done++;
          }
        }
        if (applicable > 0) {
          dayCompletionRate[d] = done / applicable;
        }
      }
    }

    final dayLabels = ['일', '월', '화', '수', '목', '금', '토'];
    final totalCells = startWeekday + totalDays;
    final rows = (totalCells / 7).ceil();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          children: [
            // Day headers
            Row(
              children: dayLabels.map((label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: AppTypography.caption,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )).toList(),
            ),
            const SizedBox(height: Spacing.xs),
            // Grid
            ...List.generate(rows, (row) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: List.generate(7, (col) {
                    final cellIndex = row * 7 + col;
                    final dayNum = cellIndex - startWeekday + 1;
                    if (dayNum < 1 || dayNum > totalDays) {
                      return Expanded(child: SizedBox(height: 28));
                    }
                    final isToday = dayNum == _today.day &&
                        month == _today.month &&
                        year == _today.year;
                    final rate = dayCompletionRate[dayNum];
                    return Expanded(
                      child: Center(
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            color: _heatmapColor(rate, cs),
                            border: isToday
                                ? Border.all(color: cs.primary, width: 2)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: AppTypography.caption,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                              color: rate != null && rate > 0.5
                                  ? Colors.white
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
            const SizedBox(height: Spacing.sm),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendItem('미완료', _heatmapColor(0.0, cs), cs),
                const SizedBox(width: Spacing.md),
                _legendItem('부분', _heatmapColor(0.5, cs), cs),
                const SizedBox(width: Spacing.md),
                _legendItem('완료', _heatmapColor(1.0, cs), cs),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _heatmapColor(double? rate, ColorScheme cs) {
    if (rate == null) return cs.surfaceContainerHighest.withAlpha(60);
    if (rate <= 0) return cs.primary.withAlpha(30);
    if (rate < 1.0) return cs.primary.withAlpha(100);
    return cs.primary.withAlpha(200);
  }

  Widget _legendItem(String label, Color color, ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: AppTypography.caption,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Parsed habit stats from the server.
class _HabitStats {
  final int streak;
  final List<String> weekSummary; // 7 entries: 'done', 'missed', 'na'
  final Map<String, bool> monthGrid; // day number string -> completed

  _HabitStats({
    required this.streak,
    required this.weekSummary,
    required this.monthGrid,
  });

  factory _HabitStats.fromJson(Map<String, dynamic> json) {
    return _HabitStats(
      streak: json['streak'] ?? 0,
      weekSummary: (json['weekSummary'] as List?)?.cast<String>() ?? [],
      monthGrid: (json['monthGrid'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v == true),
          ) ??
          {},
    );
  }
}
