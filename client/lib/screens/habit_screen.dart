import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/task.dart';
import '../services/api_service.dart';
import '../themes/spacing.dart';

/// Habit stats returned by the habit-stats API.
class HabitStats {
  final int streak;
  final List<WeekDay> weekSummary;
  final List<MonthDay> monthGrid;
  final int achievementRate;
  final int scheduledCount;
  final int completedCount;

  HabitStats({
    required this.streak,
    required this.weekSummary,
    required this.monthGrid,
    required this.achievementRate,
    required this.scheduledCount,
    required this.completedCount,
  });

  factory HabitStats.fromJson(Map<String, dynamic> json) {
    return HabitStats(
      streak: json['streak'] ?? 0,
      weekSummary: (json['weekSummary'] as List<dynamic>?)
              ?.map((w) => WeekDay.fromJson(Map<String, dynamic>.from(w as Map)))
              .toList() ??
          [],
      monthGrid: (json['monthGrid'] as List<dynamic>?)
              ?.map((d) => MonthDay.fromJson(Map<String, dynamic>.from(d as Map)))
              .toList() ??
          [],
      achievementRate: json['achievementRate'] ?? 0,
      scheduledCount: json['scheduledCount'] ?? 0,
      completedCount: json['completedCount'] ?? 0,
    );
  }
}

class WeekDay {
  final String day;
  final String date;
  final bool scheduled;
  final bool completed;
  final bool future;

  WeekDay({
    required this.day,
    required this.date,
    required this.scheduled,
    required this.completed,
    required this.future,
  });

  factory WeekDay.fromJson(Map<String, dynamic> json) {
    return WeekDay(
      day: json['day'] ?? '',
      date: json['date'] ?? '',
      scheduled: json['scheduled'] ?? false,
      completed: json['completed'] ?? false,
      future: json['future'] ?? false,
    );
  }
}

class MonthDay {
  final int day;
  final String date;
  final bool scheduled;
  final bool completed;
  final bool future;

  MonthDay({
    required this.day,
    required this.date,
    required this.scheduled,
    required this.completed,
    required this.future,
  });

  factory MonthDay.fromJson(Map<String, dynamic> json) {
    return MonthDay(
      day: json['day'] ?? 1,
      date: json['date'] ?? '',
      scheduled: json['scheduled'] ?? false,
      completed: json['completed'] ?? false,
      future: json['future'] ?? false,
    );
  }
}

class HabitScreen extends StatefulWidget {
  const HabitScreen({super.key});

  @override
  State<HabitScreen> createState() => _HabitScreenState();
}

class _HabitScreenState extends State<HabitScreen> {
  final ApiService _api = ApiService();
  List<TaskModel> _habits = [];
  final Map<String, HabitStats> _statsCache = {};
  bool _isLoading = true;
  String? _expandedHabitId;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      // Load habits for a wide range to include all recurring habits
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      final res = await _api.get(
        '/tasks?isHabit=true&includeDone=true'
        '&start=${start.toUtc().toIso8601String()}'
        '&end=${end.toUtc().toIso8601String()}',
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        // De-duplicate by baseId (recurring tasks expand into multiple instances)
        final seen = <String>{};
        final habits = <TaskModel>[];
        for (final json in list) {
          final task = TaskModel.fromJson(json);
          final baseId = task.baseId;
          if (!seen.contains(baseId)) {
            seen.add(baseId);
            habits.add(task);
          }
        }
        setState(() => _habits = habits);
        // Load stats for each habit
        await _loadAllStats();
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadAllStats() async {
    final now = DateTime.now();
    final futures = _habits.map((h) => _loadStats(h.baseId, now.year, now.month));
    await Future.wait(futures);
  }

  Future<void> _loadStats(String taskId, int year, int month) async {
    try {
      final res = await _api.get('/tasks/$taskId/habit-stats?year=$year&month=$month');
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _statsCache[taskId] = HabitStats.fromJson(json);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadMonthStats(String taskId, DateTime month) async {
    await _loadStats(taskId, month.year, month.month);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('습관'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '새 습관',
            onPressed: () async {
              await context.push('/task/new?isHabit=true');
              _loadHabits();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _habits.isEmpty
              ? _buildEmptyState(cs)
              : RefreshIndicator(
                  onRefresh: _loadHabits,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.lg,
                      vertical: Spacing.md,
                    ),
                    itemCount: _habits.length,
                    itemBuilder: (context, index) {
                      final habit = _habits[index];
                      final stats = _statsCache[habit.baseId];
                      final isExpanded = _expandedHabitId == habit.baseId;
                      return _buildHabitCard(habit, stats, isExpanded, cs);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.self_improvement, size: 64, color: cs.outline),
          const SizedBox(height: Spacing.lg),
          Text(
            '아직 추적 중인 습관이 없습니다',
            style: TextStyle(
              fontSize: AppTypography.h3,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            '반복 Task를 습관으로 등록하면\n여기서 추적할 수 있습니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTypography.body,
              color: cs.outline,
            ),
          ),
          const SizedBox(height: Spacing.xl),
          FilledButton.icon(
            onPressed: () async {
              await context.push('/task/new?isHabit=true');
              _loadHabits();
            },
            icon: const Icon(Icons.add),
            label: const Text('새 습관 만들기'),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitCard(
    TaskModel habit,
    HabitStats? stats,
    bool isExpanded,
    ColorScheme cs,
  ) {
    final categoryColor = habit.categoryColor != null
        ? Color(int.parse(habit.categoryColor!.replaceFirst('#', '0xFF')))
        : cs.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            if (_expandedHabitId == habit.baseId) {
              _expandedHabitId = null;
            } else {
              _expandedHabitId = habit.baseId;
              _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
              if (stats == null) {
                _loadStats(habit.baseId, _selectedMonth.year, _selectedMonth.month);
              }
            }
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Row(
                children: [
                  // Category color indicator
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: Spacing.md),
                  // Habit info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.title,
                          style: TextStyle(
                            fontSize: AppTypography.h3,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        if (habit.rruleSummary.isNotEmpty)
                          Text(
                            habit.rruleSummary,
                            style: TextStyle(
                              fontSize: AppTypography.bodySmall,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Streak badge
                  if (stats != null && stats.streak > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md,
                        vertical: Spacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_fire_department,
                              size: 18, color: cs.primary),
                          const SizedBox(width: Spacing.xs),
                          Text(
                            '${stats.streak}',
                            style: TextStyle(
                              fontSize: AppTypography.h3,
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: Spacing.sm),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),

            // Week summary (always visible)
            if (stats != null) _buildWeekSummary(stats, cs),

            // Expanded: monthly grid
            if (isExpanded && stats != null) ...[
              const Divider(height: 1),
              _buildMonthGrid(habit, stats, cs),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeekSummary(HabitStats stats, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: stats.weekSummary.map((wd) {
          Color bgColor;
          Color textColor;
          if (wd.completed) {
            bgColor = const Color(0xFF4ADE80);
            textColor = Colors.white;
          } else if (wd.future) {
            bgColor = cs.surfaceContainerHighest.withValues(alpha: 0.5);
            textColor = cs.onSurfaceVariant;
          } else if (wd.scheduled) {
            bgColor = const Color(0xFFEF6B6B).withValues(alpha: 0.3);
            textColor = cs.onSurfaceVariant;
          } else {
            bgColor = cs.surfaceContainerHighest.withValues(alpha: 0.3);
            textColor = cs.onSurfaceVariant;
          }

          return Column(
            children: [
              Text(
                wd.day,
                style: TextStyle(
                  fontSize: AppTypography.caption,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: wd.completed
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          wd.date.split('-').last,
                          style: TextStyle(
                            fontSize: AppTypography.caption,
                            color: textColor,
                          ),
                        ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthGrid(TaskModel habit, HabitStats stats, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month - 1,
                    );
                  });
                  _loadMonthStats(habit.baseId, _selectedMonth);
                },
              ),
              Text(
                '${_selectedMonth.year}년 ${_selectedMonth.month}월',
                style: TextStyle(
                  fontSize: AppTypography.h3,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month + 1,
                    );
                  });
                  _loadMonthStats(habit.baseId, _selectedMonth);
                },
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),

          // Achievement rate
          Row(
            children: [
              Text(
                '달성률 ${stats.achievementRate}%',
                style: TextStyle(
                  fontSize: AppTypography.body,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                '(${stats.completedCount}/${stats.scheduledCount})',
                style: TextStyle(
                  fontSize: AppTypography.bodySmall,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),

          // Day of week headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['일', '월', '화', '수', '목', '금', '토'].map((d) {
              return SizedBox(
                width: 36,
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: AppTypography.caption,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: Spacing.xs),

          // Calendar grid
          _buildCalendarGrid(stats, cs),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(HabitStats stats, ColorScheme cs) {
    if (stats.monthGrid.isEmpty) {
      return const SizedBox.shrink();
    }

    // Determine which day of week the month starts on
    final firstDate = DateTime.parse(stats.monthGrid.first.date);
    final startDow = firstDate.weekday % 7; // 0=Sun, 1=Mon, ...

    final cells = <Widget>[];
    // Add empty cells for days before the 1st
    for (int i = 0; i < startDow; i++) {
      cells.add(const SizedBox(width: 36, height: 36));
    }

    for (final md in stats.monthGrid) {
      Color bgColor;
      Color textColor = cs.onSurface;

      if (md.completed) {
        bgColor = const Color(0xFF4ADE80);
        textColor = Colors.white;
      } else if (md.future) {
        bgColor = Colors.transparent;
        textColor = cs.onSurfaceVariant.withValues(alpha: 0.5);
      } else if (md.scheduled) {
        // Missed
        bgColor = const Color(0xFFEF6B6B).withValues(alpha: 0.3);
      } else {
        bgColor = Colors.transparent;
      }

      cells.add(
        SizedBox(
          width: 36,
          height: 36,
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Center(
              child: md.completed
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(
                      '${md.day}',
                      style: TextStyle(
                        fontSize: AppTypography.caption,
                        color: textColor,
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 0,
      runSpacing: 0,
      children: cells,
    );
  }
}
