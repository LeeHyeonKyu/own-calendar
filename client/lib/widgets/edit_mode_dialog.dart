import 'package:flutter/material.dart';

class _ModeOption {
  final String value;
  final String label;
  final String description;

  const _ModeOption(this.value, this.label, this.description);
}

Future<String?> _showModeDialog({
  required BuildContext context,
  required String title,
  required List<_ModeOption> options,
  bool destructive = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: options
            .map(
              (opt) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, opt.value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opt.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: destructive ? Colors.red : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        opt.description,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, null),
          child: const Text('취소'),
        ),
      ],
    ),
  );
}

/// Shows a dialog when editing a recurring event/task instance.
/// Returns null if cancelled, otherwise one of: 'this', 'thisAndFuture', 'all'.
Future<String?> showEditModeDialog(BuildContext context) {
  return _showModeDialog(
    context: context,
    title: '반복 일정 수정',
    options: const [
      _ModeOption('this', '이번만 수정', '이 일정만 변경하고 나머지는 그대로 둡니다'),
      _ModeOption('thisAndFuture', '이후 전부 수정', '이 일정부터 이후 반복 일정을 모두 변경합니다'),
      _ModeOption('all', '전체 수정', '모든 반복 일정을 변경합니다'),
    ],
  );
}

/// Shows a dialog when deleting a recurring event/task instance.
/// Returns null if cancelled, otherwise one of: 'this', 'thisAndFuture', 'all'.
Future<String?> showDeleteModeDialog(BuildContext context) {
  return _showModeDialog(
    context: context,
    title: '반복 일정 삭제',
    destructive: true,
    options: const [
      _ModeOption('this', '이번만 삭제', '이 일정만 삭제하고 나머지는 그대로 둡니다'),
      _ModeOption('thisAndFuture', '이후 전부 삭제', '이 일정부터 이후 반복 일정을 모두 삭제합니다'),
      _ModeOption('all', '전체 삭제', '모든 반복 일정을 삭제합니다'),
    ],
  );
}
