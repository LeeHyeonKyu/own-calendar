import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../themes/spacing.dart';

class EventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback? onTap;

  const EventCard({super.key, required this.event, this.onTap});

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.blue;
    try {
      final colorStr = hex.replaceFirst('#', '');
      return Color(int.parse('FF$colorStr', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(event.calendarColor);
    final timeFormat = DateFormat('HH:mm');
    final cs = Theme.of(context).colorScheme;

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
        child: Container(
          decoration: BoxDecoration(
            color: color.withAlpha(38),
            border: Border(left: BorderSide(color: color, width: 3)),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: TextStyle(
                        fontSize: AppTypography.eventTitle,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      event.isAllDay
                          ? '종일'
                          : '${timeFormat.format(event.startTime)} - ${timeFormat.format(event.endTime)}',
                      style: TextStyle(
                        fontSize: AppTypography.eventTime,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (event.calendarName != null)
                      Text(
                        event.calendarName!,
                        style: TextStyle(
                          fontSize: AppTypography.eventTime,
                          color: cs.outline,
                        ),
                      ),
                    if (event.isRecurring)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.repeat, size: 11, color: cs.outline),
                            const SizedBox(width: 3),
                            Text(
                              event.rruleSummary,
                              style: TextStyle(
                                fontSize: AppTypography.eventTime,
                                color: cs.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (event.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: Spacing.xs),
                        child: Wrap(
                          spacing: Spacing.xs,
                          children: event.tags
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: AppTypography.caption,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
              if (event.isRecurring)
                Padding(
                  padding: const EdgeInsets.only(right: Spacing.xs),
                  child: Tooltip(
                    message: event.rruleSummary,
                    child: Icon(Icons.repeat, size: 16, color: cs.outline),
                  ),
                ),
              if (event.isPrivate)
                Icon(Icons.lock, size: 16, color: cs.outlineVariant),
            ],
          ),
        ),
      ),
    );
  }
}
