import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';
import '../models/task.dart';
import '../utils/rrule_utils.dart';
import '../widgets/recurrence_picker.dart';
import '../widgets/edit_mode_dialog.dart';

class TaskFormScreen extends StatefulWidget {
  final String? taskId;
  final DateTime? initialDate;
  final String? initialEventId;

  const TaskFormScreen({super.key, this.taskId, this.initialDate, this.initialEventId});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime? _dueDate;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  String _priority = 'NONE';
  String _recurrenceType = 'NONE';
  DateTime? _recurrenceEnd;
  String? _rrule;
  String? _selectedCalendarId;
  String? _selectedEventId;
  bool _isLoading = false;
  TaskModel? _originalTask;

  bool get isEditing => widget.taskId != null;
  bool get _isEditingInstance => _originalTask?.isVirtualInstance ?? false;

  @override
  void initState() {
    super.initState();
    _scheduledDate = widget.initialDate;
    _selectedEventId = widget.initialEventId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCalendars();
      if (isEditing) _loadTask();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadCalendars() async {
    final provider = context.read<CalendarProvider>();
    if (provider.calendars.isEmpty) {
      await provider.loadCalendars();
    }
    if (mounted && provider.calendars.isNotEmpty && _selectedCalendarId == null) {
      setState(() {
        _selectedCalendarId = provider.calendars.first.id;
      });
    }
  }

  Future<void> _loadTask() async {
    final provider = context.read<CalendarProvider>();
    final task = provider.tasks.where((t) => t.id == widget.taskId).firstOrNull;
    if (task != null) {
      setState(() {
        _originalTask = task;
        _titleController.text = task.title;
        _descController.text = task.description ?? '';
        _dueDate = task.dueDate;
        _scheduledDate = task.scheduledDate;
        if (task.scheduledTime != null) {
          final parts = task.scheduledTime!.split(':');
          _scheduledTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
        _priority = task.priority;
        _recurrenceType = task.recurrenceType;
        _recurrenceEnd = task.recurrenceEnd;
        _rrule = task.rrule;
        _selectedCalendarId = task.calendarId;
        _selectedEventId = task.eventId;
      });
    }
  }

  Future<void> _pickDate(String field) async {
    final initial = field == 'due' ? _dueDate : _scheduledDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (field == 'due') {
          _dueDate = picked;
        } else {
          _scheduledDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _scheduledTime = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCalendarId == null) return;

    String? editMode;
    if (isEditing && _isEditingInstance) {
      editMode = await showEditModeDialog(context);
      if (editMode == null) return; // cancelled
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    final data = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      'priority': _priority,
      'recurrenceType': _recurrenceType,
      'recurrenceEnd': _recurrenceEnd?.toIso8601String(),
      'rrule': _rrule,
      'calendarId': _selectedCalendarId,
      'eventId': _selectedEventId,
    };

    if (_dueDate != null) {
      data['dueDate'] = _dueDate!.toIso8601String();
    }
    if (_scheduledDate != null) {
      data['scheduledDate'] = _scheduledDate!.toIso8601String();
    }
    if (_scheduledTime != null) {
      data['scheduledTime'] =
          '${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}';
    }

    final provider = context.read<CalendarProvider>();
    bool success;
    if (isEditing) {
      success = await provider.updateTask(
        widget.taskId!,
        data,
        editMode: editMode,
        instanceDate: _isEditingInstance ? _originalTask?.instanceDateString : null,
      );
    } else {
      success = await provider.createTask(data);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했습니다')),
        );
      }
    }
  }

  Future<void> _delete() async {
    if (!isEditing) return;

    String? editMode;
    if (_isEditingInstance) {
      editMode = await showDeleteModeDialog(context);
      if (editMode == null) return; // cancelled
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Task 삭제'),
          content: const Text('이 Task를 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    final success = await context.read<CalendarProvider>().deleteTask(
      widget.taskId!,
      editMode: editMode,
      instanceDate: _isEditingInstance ? _originalTask?.instanceDateString : null,
    );
    if (success && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final calProvider = context.watch<CalendarProvider>();
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Task 수정' : '새 Task'),
        actions: [
          if (isEditing)
            IconButton(icon: const Icon(Icons.delete), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '할 일',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? '할 일을 입력하세요' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: '설명',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _priority,
              decoration: const InputDecoration(
                labelText: '우선순위',
                border: OutlineInputBorder(),
              ),
              items: TaskModel.priorityLabels.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Color(TaskModel.priorityColors[e.key]!),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(e.value),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _priority = v);
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('마감일'),
              subtitle: Text(_dueDate != null ? dateFormat.format(_dueDate!) : '없음'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_dueDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _dueDate = null),
                    ),
                  const Icon(Icons.calendar_today),
                ],
              ),
              onTap: () => _pickDate('due'),
            ),
            ListTile(
              title: const Text('예정일'),
              subtitle: Text(_scheduledDate != null ? dateFormat.format(_scheduledDate!) : '없음'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_scheduledDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _scheduledDate = null),
                    ),
                  const Icon(Icons.calendar_today),
                ],
              ),
              onTap: () => _pickDate('scheduled'),
            ),
            ListTile(
              title: const Text('예정 시간'),
              subtitle: Text(_scheduledTime != null
                  ? '${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}'
                  : '없음'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_scheduledTime != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _scheduledTime = null),
                    ),
                  const Icon(Icons.access_time),
                ],
              ),
              onTap: _pickTime,
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              leading: const Icon(Icons.repeat),
              title: const Text('반복'),
              subtitle: Text(
                rruleSummaryText(_rrule, legacyType: _recurrenceType, legacyEnd: _recurrenceEnd),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showRecurrencePicker(
                  context: context,
                  initialRrule: _rrule,
                  initialRecurrenceType: _recurrenceType,
                  initialRecurrenceEnd: _recurrenceEnd,
                  referenceDate: _scheduledDate ?? _dueDate ?? DateTime.now(),
                  onChanged: (result) {
                    setState(() {
                      _rrule = result.rrule;
                      _recurrenceType = result.recurrenceType;
                      _recurrenceEnd = result.recurrenceEnd;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            // Event 연결
            DropdownButtonFormField<String?>(
              value: _selectedEventId,
              decoration: const InputDecoration(
                labelText: 'Event 연결 (선택)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('없음')),
                ...calProvider.events.map(
                  (e) => DropdownMenuItem(
                    value: e.id,
                    child: Text(e.title, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _selectedEventId = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCalendarId,
              decoration: const InputDecoration(
                labelText: '캘린더',
                border: OutlineInputBorder(),
              ),
              items: calProvider.calendars
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCalendarId = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _save,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEditing ? '수정' : '저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
