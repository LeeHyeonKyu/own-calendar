import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../themes/spacing.dart';

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

  Color get _statusColor {
    if (task.isDone) return AppColors.taskDone;
    if (task.isOverdue) return AppColors.taskOverdue;
    return AppColors.taskPending;
  }

  Color get _borderColor {
    if (task.priority != 'NONE') return Color(task.priorityColorValue);
    return _statusColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: Spacing.xs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Opacity(
          opacity: task.isDone ? 0.55 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
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
                const SizedBox(width: Spacing.sm),
                GestureDetector(
                  onTap: onToggleComplete,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _statusColor,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(3),
                      color: task.isDone ? AppColors.taskDone : null,
                    ),
                    child: task.isDone
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: AppTypography.body,
                          fontWeight: FontWeight.w500,
                          decoration: task.isDone ? TextDecoration.lineThrough : null,
                          color: task.isDone ? cs.outline : null,
                        ),
                      ),
                      const SizedBox(height: Spacing.xs),
                      Row(
                        children: [
                          if (task.hasTime) ...[
                            Text(
                              task.scheduledTime!,
                              style: TextStyle(
                                fontSize: AppTypography.bodySmall,
                                color: AppColors.taskPending,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: Spacing.sm),
                          ],
                          if (task.hasDueDate)
                            _DueTag(task: task),
                          if (task.hasEvent) ...[
                            if (task.hasDueDate) const SizedBox(width: Spacing.sm),
                            _RelatedBadge(eventTitle: task.eventTitle ?? ''),
                          ],
                          if (task.isRecurring) ...[
                            const SizedBox(width: Spacing.sm),
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
      color = AppColors.taskOverdue;
      label = '기한 초과';
    } else if (task.isDueToday) {
      color = AppColors.taskPending;
      label = '오늘 마감';
    } else {
      color = Theme.of(context).colorScheme.outline;
      label = DateFormat('M/d 마감').format(task.dueDate!);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(AppRadius.sm),
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
    final outlineColor = Theme.of(context).colorScheme.outline;
    // Keep the inline badge short (e.g. "매주 월, 수요일"); the full
    // summary (with the end condition) is available via the tooltip.
    final shortSummary = summary.split(' · ').first;
    return Tooltip(
      message: summary,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat, size: 12, color: outlineColor),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              shortSummary,
              style: TextStyle(fontSize: 10, color: outlineColor),
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
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.relatedBadge.withAlpha(25),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('↗ ', style: TextStyle(fontSize: 9, color: AppColors.relatedBadge)),
          Text(
            eventTitle,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.relatedBadge,
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
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: Spacing.xs),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggleComplete,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                border: Border.all(
                  color: task.isDone ? AppColors.taskDone : AppColors.taskPending,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(3),
                color: task.isDone ? AppColors.taskDone : null,
              ),
              child: task.isDone
                  ? const Icon(Icons.check, size: 10, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontSize: AppTypography.eventTitle,
                decoration: task.isDone ? TextDecoration.lineThrough : null,
                color: task.isDone ? cs.outline : null,
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
