import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';
import '../models/task.dart';
import '../utils/rrule_utils.dart';
import '../widgets/recurrence_picker.dart';
import '../widgets/edit_mode_dialog.dart';
import '../widgets/checklist_editor.dart';
import '../themes/spacing.dart';

class TaskFormScreen extends StatefulWidget {
  final String? taskId;
  final DateTime? initialDate;
  final String? initialEventId;
  final bool initialIsHabit;

  const TaskFormScreen({
    super.key,
    this.taskId,
    this.initialDate,
    this.initialEventId,
    this.initialIsHabit = false,
  });

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _attendeeController = TextEditingController();
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
  List<Map<String, dynamic>> _attendees = [];
  List<ChecklistItem> _checklist = [];
  bool _showChecklist = false;
  bool _showMetadata = false;
  bool _isHabit = false;

  bool get isEditing => widget.taskId != null;
  bool get _isEditingInstance => _originalTask?.isVirtualInstance ?? false;

  @override
  void initState() {
    super.initState();
    _scheduledDate = widget.initialDate;
    _selectedEventId = widget.initialEventId;
    _isHabit = widget.initialIsHabit;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCalendars();
      if (isEditing) _loadTask();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _attendeeController.dispose();
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
        _locationController.text = task.location ?? '';
        _notesController.text = task.notes ?? '';
        _attendees = List.from(task.attendees);
        _checklist = task.checklist
                ?.map((c) => c.copyWith())
                .toList() ??
            [];
        _showChecklist = _checklist.isNotEmpty;
        _showMetadata = task.location != null ||
            task.notes != null ||
            task.attendees.isNotEmpty;
        _isHabit = task.isHabit;
      });
    }
  }

  void _addAttendee() {
    final text = _attendeeController.text.trim();
    if (text.isEmpty) return;
    final isEmail = text.contains('@');
    setState(() {
      _attendees.add({
        if (isEmail) 'email': text else 'name': text,
      });
      _attendeeController.clear();
    });
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

    // Habits require a recurrence rule
    if (_isHabit && _rrule == null && _recurrenceType == 'NONE') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('습관은 반복 설정이 필수입니다')),
      );
      return;
    }

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
      'recurrenceEnd': _recurrenceEnd?.toUtc().toIso8601String(),
      'rrule': _rrule,
      'calendarId': _selectedCalendarId,
      'eventId': _selectedEventId,
      'location': _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'attendees': _attendees.isEmpty ? null : _attendees,
      'checklist': _checklist.isEmpty
          ? null
          : _checklist.map((c) => c.toJson()).toList(),
      'isHabit': _isHabit,
    };

    if (_dueDate != null) {
      data['dueDate'] = _dueDate!.toUtc().toIso8601String();
    }
    if (_scheduledDate != null) {
      data['scheduledDate'] = _scheduledDate!.toUtc().toIso8601String();
    }
    if (_scheduledTime != null) {
      data['scheduledTime'] =
          '${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}';
    }

    final provider = context.read<CalendarProvider>();
    try {
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
    } catch (e, st) {
      debugPrint('Task save error: $e\n$st');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), duration: const Duration(seconds: 10)),
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
              child: Text('삭제', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
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
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '할 일',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? '할 일을 입력하세요' : null,
            ),
            const SizedBox(height: Spacing.lg),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: '설명',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: Spacing.lg),
            SwitchListTile(
              title: const Text('습관으로 추적'),
              subtitle: const Text('반복 Task를 습관으로 등록하여 streak과 달성률을 추적합니다'),
              secondary: const Icon(Icons.self_improvement),
              value: _isHabit,
              onChanged: (v) => setState(() => _isHabit = v),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            const SizedBox(height: Spacing.lg),
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
                              margin: const EdgeInsets.only(right: Spacing.sm),
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
            const SizedBox(height: Spacing.lg),
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
            const SizedBox(height: Spacing.sm),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
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
            const SizedBox(height: Spacing.lg),
            // ── Checklist section (Feature 130) ──
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              leading: const Icon(Icons.checklist),
              title: const Text('체크리스트'),
              subtitle: Text(_checklist.isEmpty
                  ? '탭하여 추가'
                  : '${_checklist.fold<int>(0, (sum, c) => sum + c.checkedCount)}/${_checklist.fold<int>(0, (sum, c) => sum + c.totalCount)}개 완료'),
              trailing: Icon(_showChecklist ? Icons.expand_less : Icons.expand_more),
              onTap: () => setState(() => _showChecklist = !_showChecklist),
            ),
            if (_showChecklist) ...[
              const SizedBox(height: Spacing.md),
              ChecklistEditor(
                items: _checklist,
                onChanged: (items) => setState(() => _checklist = items),
              ),
            ],
            const SizedBox(height: Spacing.lg),
            // ── Metadata section (Feature 018) ──
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              leading: const Icon(Icons.info_outline),
              title: const Text('추가 정보'),
              subtitle: Text(_showMetadata ? '장소, 메모, 참여자' : '탭하여 펼치기'),
              trailing: Icon(_showMetadata ? Icons.expand_less : Icons.expand_more),
              onTap: () => setState(() => _showMetadata = !_showMetadata),
            ),
            if (_showMetadata) ...[
              const SizedBox(height: Spacing.md),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: '장소',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: Spacing.md),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: '메모',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: Spacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _attendeeController,
                      decoration: const InputDecoration(
                        labelText: '참여자',
                        hintText: '이름 또는 이메일',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_add_outlined),
                      ),
                      onSubmitted: (_) => _addAttendee(),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  IconButton.filled(
                    onPressed: _addAttendee,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              if (_attendees.isNotEmpty) ...[
                const SizedBox(height: Spacing.sm),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.xs,
                  children: _attendees.map((a) {
                    final display = a['name'] ?? a['email'] ?? '';
                    return Chip(
                      label: Text(display),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => _attendees.remove(a)),
                    );
                  }).toList(),
                ),
              ],
            ],
            const SizedBox(height: Spacing.lg),
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
            const SizedBox(height: Spacing.lg),
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
            const SizedBox(height: Spacing.xl),
            FilledButton(
              onPressed: _isLoading ? null : _save,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
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
