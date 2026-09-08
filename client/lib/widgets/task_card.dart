import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onTap;
  final VoidCallback? onToggleComplete;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onToggleComplete,
  });

  static const _taskColor = Color(0xFFF0A050);
  static const _doneColor = Color(0xFF4ADE80);
  static const _overdueColor = Color(0xFFEF6B6B);

  Color get _borderColor {
    if (task.isDone) return _doneColor;
    if (task.isOverdue) return _overdueColor;
    return _taskColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: task.isDone ? 0.55 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onToggleComplete,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _borderColor,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(5),
                      color: task.isDone ? _doneColor : null,
                    ),
                    child: task.isDone
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          decoration: task.isDone ? TextDecoration.lineThrough : null,
                          color: task.isDone ? theme.colorScheme.outline : null,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (task.hasTime) ...[
                            Text(
                              task.scheduledTime!,
                              style: TextStyle(
                                fontSize: 12,
                                color: _taskColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (task.hasDueDate)
                            _DueTag(task: task),
                          if (task.hasEvent) ...[
                            if (task.hasDueDate) const SizedBox(width: 6),
                            _RelatedBadge(eventTitle: task.eventTitle ?? ''),
                          ],
                          if (task.isRecurring) ...[
                            const SizedBox(width: 6),
                            Flexible(child: _RecurrenceBadge(summary: task.rruleSummary)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (task.priority != 'NONE')
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Color(task.priorityColorValue),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DueTag extends StatelessWidget {
  final TaskModel task;
  const _DueTag({required this.task});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;

    if (task.isOverdue) {
      color = const Color(0xFFEF6B6B);
      label = '기한 초과';
    } else if (task.isDueToday) {
      color = const Color(0xFFF0A050);
      label = '오늘 마감';
    } else {
      color = Colors.grey;
      label = DateFormat('M/d 마감').format(task.dueDate!);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _RecurrenceBadge extends StatelessWidget {
  final String summary;
  const _RecurrenceBadge({required this.summary});

  @override
  Widget build(BuildContext context) {
    // Keep the inline badge short (e.g. "매주 월, 수요일"); the full
    // summary (with the end condition) is available via the tooltip.
    final shortSummary = summary.split(' · ').first;
    return Tooltip(
      message: summary,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat, size: 12, color: Colors.grey[500]),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              shortSummary,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedBadge extends StatelessWidget {
  final String eventTitle;
  const _RelatedBadge({required this.eventTitle});

  @override
  Widget build(BuildContext context) {
    if (eventTitle.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFA78BFA).withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('↗ ', style: TextStyle(fontSize: 9, color: Color(0xFFA78BFA))),
          Text(
            eventTitle,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFFA78BFA),
            ),
          ),
        ],
      ),
    );
  }
}

class NestedTaskItem extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onToggleComplete;

  const NestedTaskItem({
    super.key,
    required this.task,
    this.onToggleComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggleComplete,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                border: Border.all(
                  color: task.isDone ? const Color(0xFF4ADE80) : const Color(0xFFF0A050),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(3),
                color: task.isDone ? const Color(0xFF4ADE80) : null,
              ),
              child: task.isDone
                  ? const Icon(Icons.check, size: 10, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontSize: 13,
                decoration: task.isDone ? TextDecoration.lineThrough : null,
                color: task.isDone ? Colors.grey : null,
              ),
            ),
          ),
          if (task.hasDueDate)
            _DueTag(task: task),
        ],
      ),
    );
  }
}
