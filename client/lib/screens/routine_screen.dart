import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/routine_provider.dart';
import '../models/routine.dart';

const _routineColor = Color(0xFF8B5CF6); // purple accent
const _doneColor = Color(0xFF4ADE80);

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  int _tabIndex = 0; // 0=Today, 1=Yesterday
  final Set<String> _collapsedGroups = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  DateTime get _displayDate {
    final now = DateTime.now();
    if (_tabIndex == 1) {
      return now.subtract(const Duration(days: 1));
    }
    return now;
  }

  Future<void> _loadData() async {
    final provider = context.read<RoutineProvider>();
    await Future.wait([
      provider.loadRoutines(date: _displayDate),
      provider.loadGroups(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RoutineProvider>();
    final dateStr = DateFormat('M월 d일 (E)', 'ko').format(_displayDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('루틴'),
      ),
      body: Column(
        children: [
          // Date tabs: Today / Yesterday
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('오늘')),
                      ButtonSegment(value: 1, label: Text('어제')),
                    ],
                    selected: {_tabIndex},
                    onSelectionChanged: (v) {
                      setState(() => _tabIndex = v.first);
                      _loadData();
                    },
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: _routineColor.withAlpha(25),
                      selectedForegroundColor: _routineColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Date label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Progress
          if (provider.totalCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '${provider.completedCount} / ${provider.totalCount} 완료',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(
                        '${provider.totalCount > 0 ? (provider.completedCount * 100 ~/ provider.totalCount) : 0}%',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: provider.totalCount > 0
                          ? provider.completedCount / provider.totalCount
                          : 0,
                      backgroundColor: Theme.of(context).dividerColor,
                      color: _doneColor,
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          // Routine list
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.routines.isEmpty
                    ? _buildEmptyState()
                    : _buildRoutineList(provider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/routine/new'),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 2,
        onDestinationSelected: (index) {
          switch (index) {
            case 0: context.go('/'); break;
            case 1: context.push('/daily'); break;
            case 2: break;
            case 3: context.push('/weekly'); break;
            case 4: context.push('/family'); break;
            case 5: context.push('/settings'); break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month), label: '월별'),
          NavigationDestination(icon: Icon(Icons.today), label: '일별'),
          NavigationDestination(icon: Icon(Icons.repeat), label: '루틴'),
          NavigationDestination(icon: Icon(Icons.view_week), label: '주별'),
          NavigationDestination(icon: Icon(Icons.family_restroom), label: '가족'),
          NavigationDestination(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.repeat, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _tabIndex == 0 ? '오늘 예정된 루틴이 없습니다' : '어제 예정된 루틴이 없습니다',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.push('/routine/new'),
            child: const Text('루틴 추가'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineList(RoutineProvider provider) {
    final grouped = provider.groupedRoutines;
    final groupOrder = provider.groups;

    // Build ordered sections: grouped first, then ungrouped
    final sections = <Widget>[];

    // Grouped routines
    for (final group in groupOrder) {
      final routines = grouped[group.id];
      if (routines == null || routines.isEmpty) continue;
      sections.add(_buildGroupSection(group.id, group.name, routines, provider));
    }

    // Ungrouped routines
    final ungrouped = grouped[null];
    if (ungrouped != null && ungrouped.isNotEmpty) {
      sections.addAll(ungrouped.map((r) => _buildRoutineTile(r, provider)));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        ...sections,
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildGroupSection(
    String groupId,
    String groupName,
    List<RoutineModel> routines,
    RoutineProvider provider,
  ) {
    final isCollapsed = _collapsedGroups.contains(groupId);
    final done = routines.where((r) => r.completed).length;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isCollapsed) {
                  _collapsedGroups.remove(groupId);
                } else {
                  _collapsedGroups.add(groupId);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    isCollapsed ? Icons.expand_more : Icons.expand_less,
                    size: 18,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    groupName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: _routineColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$done/${routines.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _routineColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isCollapsed)
            ...routines.map((r) => _buildRoutineTile(r, provider)),
        ],
      ),
    );
  }

  Widget _buildRoutineTile(RoutineModel routine, RoutineProvider provider) {
    return InkWell(
      onTap: () => context.push('/routine/${routine.id}/edit'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Checkbox
            GestureDetector(
              onTap: () => provider.toggleComplete(routine.id),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: routine.completed ? _doneColor : Colors.transparent,
                  border: Border.all(
                    color: routine.completed ? _doneColor : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: routine.completed
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            // Name + time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routine.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      decoration: routine.completed
                          ? TextDecoration.lineThrough
                          : null,
                      color: routine.completed ? Colors.grey[400] : null,
                    ),
                  ),
                  if (routine.hasTime)
                    Text(
                      routine.time!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
            // Repeat days badge
            Text(
              routine.repeatDaysLabel,
              style: TextStyle(
                fontSize: 11,
                color: _routineColor.withAlpha(180),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
