import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';
import '../providers/category_provider.dart';
import '../models/event.dart';
import '../utils/rrule_utils.dart';
import '../widgets/recurrence_picker.dart';
import '../widgets/edit_mode_dialog.dart';
import '../themes/spacing.dart';

class EventFormScreen extends StatefulWidget {
  final String? eventId;
  final DateTime? initialDate;
  final EventModel? template;

  const EventFormScreen({super.key, this.eventId, this.initialDate, this.template});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _tagController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _attendeeController = TextEditingController();
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  bool _isAllDay = false;
  bool _isPrivate = false;
  String _category = 'PERSONAL';
  List<String> _tags = [];
  String _recurrenceType = 'NONE';
  DateTime? _recurrenceEnd;
  String? _rrule;
  String? _selectedCalendarId;
  bool _isLoading = false;
  EventModel? _originalEvent;
  int? _reminderMinutes = 10;
  String? _categoryId;
  List<Map<String, dynamic>> _attendees = [];
  bool _showMetadata = false;

  bool get isEditing => widget.eventId != null;
  bool get _isEditingInstance => _originalEvent?.isVirtualInstance ?? false;

  @override
  void initState() {
    super.initState();
    final base = widget.initialDate ?? DateTime.now();
    _startDate = base;
    _startTime = TimeOfDay(hour: base.hour + 1, minute: 0);
    _endDate = base;
    _endTime = TimeOfDay(hour: base.hour + 2, minute: 0);

    if (widget.template != null) {
      _applyTemplate(widget.template!);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCalendars();
      _loadCategories();
      if (isEditing) _loadEvent();
    });
  }

  /// Pre-fills all form fields from a template event (used by the duplicate
  /// action). Reads every field the form exposes so the user sees an exact
  /// copy of the source event in a new-event form.
  void _applyTemplate(EventModel template) {
    _titleController.text = template.title;
    _descController.text = template.description ?? '';
    _startDate = template.startTime;
    _startTime = TimeOfDay.fromDateTime(template.startTime);
    _endDate = template.endTime;
    _endTime = TimeOfDay.fromDateTime(template.endTime);
    _isAllDay = template.isAllDay;
    _isPrivate = template.isPrivate;
    _category = template.category;
    _tags = List.from(template.tags);
    _recurrenceType = template.recurrenceType;
    _recurrenceEnd = template.recurrenceEnd;
    _rrule = template.rrule;
    _selectedCalendarId = template.calendarId;
    _locationController.text = template.location ?? '';
    _notesController.text = template.notes ?? '';
    _attendees = List.from(template.attendees);
    _reminderMinutes = template.reminderMinutes;
    _categoryId = template.categoryId;
    _showMetadata = template.location != null ||
        template.notes != null ||
        template.attendees.isNotEmpty;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _tagController.dispose();
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

  Future<void> _loadCategories() async {
    final provider = context.read<CategoryProvider>();
    if (provider.categories.isEmpty) {
      await provider.loadCategories();
    }
    if (mounted && !isEditing) {
      // For new events, default to the isDefault category
      final defaultCat = provider.defaultCategory;
      if (defaultCat != null && _categoryId == null) {
        setState(() {
          _categoryId = defaultCat.id;
        });
      }
    }
  }

  Future<void> _loadEvent() async {
    final provider = context.read<CalendarProvider>();
    final events = provider.allVisibleEvents;
    final event = events.where((e) => e.id == widget.eventId).firstOrNull;
    if (event != null) {
      setState(() {
        _originalEvent = event;
        _titleController.text = event.title;
        _descController.text = event.description ?? '';
        _startDate = event.startTime;
        _startTime = TimeOfDay.fromDateTime(event.startTime);
        _endDate = event.endTime;
        _endTime = TimeOfDay.fromDateTime(event.endTime);
        _isAllDay = event.isAllDay;
        _isPrivate = event.isPrivate;
        _category = event.category;
        _tags = List.from(event.tags);
        _recurrenceType = event.recurrenceType;
        _recurrenceEnd = event.recurrenceEnd;
        _rrule = event.rrule;
        _selectedCalendarId = event.calendarId;
        _locationController.text = event.location ?? '';
        _notesController.text = event.notes ?? '';
        _attendees = List.from(event.attendees);
        _reminderMinutes = event.reminderMinutes;
        _categoryId = event.categoryId;
        _showMetadata = event.location != null ||
            event.notes != null ||
            event.attendees.isNotEmpty;
      });
    }
  }

  DateTime _combine(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _reminderLabel(int? minutes) {
    if (minutes == null) return '끄기';
    if (minutes == 0) return '정시';
    if (minutes == 60) return '1시간 전';
    return '$minutes분 전';
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

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
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

    final startDt = _isAllDay
        ? DateTime(_startDate.year, _startDate.month, _startDate.day)
        : _combine(_startDate, _startTime);
    final endDt = _isAllDay
        ? DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59)
        : _combine(_endDate, _endTime);

    if (endDt.isBefore(startDt)) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('종료 시간이 시작 시간보다 빠릅니다')),
      );
      return;
    }

    final data = {
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'startTime': startDt.toUtc().toIso8601String(),
      'endTime': endDt.toUtc().toIso8601String(),
      'isAllDay': _isAllDay,
      'isPrivate': _isPrivate,
      'category': _category,
      'tags': _tags,
      'recurrenceType': _recurrenceType,
      'recurrenceEnd': _recurrenceEnd?.toUtc().toIso8601String(),
      'rrule': _rrule,
      'calendarId': _selectedCalendarId,
      'location': _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'attendees': _attendees.isEmpty ? null : _attendees,
      'reminderMinutes': _reminderMinutes,
      'categoryId': _categoryId,
    };

    final provider = context.read<CalendarProvider>();
    try {
      bool success;
      if (isEditing) {
        success = await provider.updateEvent(
          widget.eventId!,
          data,
          editMode: editMode,
          instanceDate: _isEditingInstance ? _originalEvent?.instanceDateString : null,
        );
      } else {
        success = await provider.createEvent(data);
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
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }

  Future<void> _delete() async {
    if (!isEditing) return;

    if (_isEditingInstance) {
      // Recurring-instance deletion: show the existing mode dialog.
      final editMode = await showDeleteModeDialog(context);
      if (editMode == null) return; // cancelled

      if (!mounted) return;
      final success = await context.read<CalendarProvider>().deleteEvent(
        widget.eventId!,
        editMode: editMode,
        instanceDate: _originalEvent?.instanceDateString,
      );
      if (success && mounted) context.pop();
    } else {
      // Non-recurring single event: deferred delete with undo (#114).
      // No confirmation dialog -- pop immediately, show SnackBar with undo.
      final provider = context.read<CalendarProvider>();
      final eventId = widget.eventId!;

      // Capture ScaffoldMessenger before pop -- after pop, this widget's
      // context is no longer mounted and lookups on it would fail.
      final messenger = ScaffoldMessenger.of(context);

      provider.deleteEventDeferred(eventId);

      if (!mounted) return;
      context.pop();

      // Show SnackBar on the ScaffoldMessenger that persists after pop
      // (attached to MaterialApp, not to this screen's Scaffold).
      messenger.showSnackBar(
        SnackBar(
          content: const Text('일정을 삭제했습니다'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: '실행 취소',
            onPressed: () {
              provider.undoDelete(eventId);
            },
          ),
        ),
      );
    }
  }

  /// Reads the current form values (including any unsaved edits the user
  /// made) and opens a new-event form pre-filled with those values via
  /// pushReplacement. For recurring instances, the recurrence rule is
  /// stripped so the duplicate becomes a single event.
  void _duplicateEvent() {
    final template = EventModel(
      id: '',
      title: _titleController.text,
      description: _descController.text.isEmpty ? null : _descController.text,
      startTime: _combine(_startDate, _startTime),
      endTime: _combine(_endDate, _endTime),
      isAllDay: _isAllDay,
      isPrivate: _isPrivate,
      category: _category,
      tags: List.from(_tags),
      // If editing a recurring instance, strip the recurrence rule so the
      // duplicate becomes a single (non-recurring) event.
      recurrenceType: _isEditingInstance ? 'NONE' : _recurrenceType,
      recurrenceEnd: _isEditingInstance ? null : _recurrenceEnd,
      rrule: _isEditingInstance ? null : _rrule,
      calendarId: _selectedCalendarId ?? '',
      location: _locationController.text.isEmpty
          ? null
          : _locationController.text,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      attendees: List.from(_attendees),
      reminderMinutes: _reminderMinutes,
      categoryId: _categoryId,
    );
    context.pushReplacement('/event/new', extra: template);
  }

  @override
  Widget build(BuildContext context) {
    final calProvider = context.watch<CalendarProvider>();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '일정 수정' : '새 일정'),
        actions: [
          if (isEditing) ...[
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: '복제',
              onPressed: _duplicateEvent,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _delete,
            ),
          ],
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
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '제목을 입력하세요' : null,
            ),
            const SizedBox(height: Spacing.lg),
            // Category chips (feature 017 completion)
            Builder(
              builder: (context) {
                final catProvider = context.watch<CategoryProvider>();
                final cats = catProvider.categories;
                if (cats.isEmpty) return const SizedBox.shrink();
                return Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.xs,
                  children: cats.map((cat) {
                    final isSelected = _categoryId == cat.id;
                    return ChoiceChip(
                      avatar: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: cat.colorValue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      label: Text(
                        cat.emoji != null && cat.emoji!.isNotEmpty
                            ? '${cat.emoji} ${cat.name}'
                            : cat.name,
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _categoryId = cat.id);
                        }
                      },
                    );
                  }).toList(),
                );
              },
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
            // Tags
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      labelText: '태그',
                      hintText: '태그 입력 후 추가',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                IconButton.filled(
                  onPressed: _addTag,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: Spacing.sm),
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.xs,
                children: _tags
                    .map(
                      (tag) => Chip(
                        label: Text(tag),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () =>
                            setState(() => _tags.remove(tag)),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: Spacing.lg),
            SwitchListTile(
              title: const Text('종일'),
              value: _isAllDay,
              onChanged: (v) => setState(() => _isAllDay = v),
            ),
            const SizedBox(height: Spacing.sm),
            ListTile(
              title: const Text('시작'),
              subtitle: Text(
                _isAllDay
                    ? dateFormat.format(_startDate)
                    : '${dateFormat.format(_startDate)} ${timeFormat.format(_combine(_startDate, _startTime))}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                await _pickDate(true);
                if (!_isAllDay && mounted) await _pickTime(true);
              },
            ),
            ListTile(
              title: const Text('종료'),
              subtitle: Text(
                _isAllDay
                    ? dateFormat.format(_endDate)
                    : '${dateFormat.format(_endDate)} ${timeFormat.format(_combine(_endDate, _endTime))}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                await _pickDate(false);
                if (!_isAllDay && mounted) await _pickTime(false);
              },
            ),
            const SizedBox(height: Spacing.sm),
            SwitchListTile(
              title: const Text('비공개'),
              value: _isPrivate,
              onChanged: (v) => setState(() => _isPrivate = v),
            ),
            const SizedBox(height: Spacing.lg),
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
                  referenceDate: _startDate,
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
            // ── Reminder (Feature 010) ──
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('알림'),
              subtitle: Text(_reminderLabel(_reminderMinutes)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final options = <int?, String>{
                  null: '끄기',
                  0: '정시',
                  5: '5분 전',
                  10: '10분 전',
                  15: '15분 전',
                  30: '30분 전',
                  60: '1시간 전',
                };
                final selected = await showDialog<int?>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: const Text('알림 시간'),
                    children: options.entries.map((entry) {
                      return SimpleDialogOption(
                        onPressed: () => Navigator.pop(ctx, entry.key ?? -1),
                        child: Text(entry.value),
                      );
                    }).toList(),
                  ),
                );
                if (selected != null) {
                  setState(() => _reminderMinutes = selected == -1 ? null : selected);
                }
              },
            ),
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
            DropdownButtonFormField<String>(
              value: _selectedCalendarId,
              decoration: const InputDecoration(
                labelText: '캘린더',
                border: OutlineInputBorder(),
              ),
              items: calProvider.calendars
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name),
                    ),
                  )
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
