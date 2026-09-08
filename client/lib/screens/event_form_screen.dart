import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';
import '../models/event.dart' show EventModel, Attendee;

class EventFormScreen extends StatefulWidget {
  final String? eventId;
  final DateTime? initialDate;

  const EventFormScreen({super.key, this.eventId, this.initialDate});

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
  final _attendeeNameController = TextEditingController();
  final _attendeeEmailController = TextEditingController();
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
  List<Attendee> _attendees = [];
  bool _metadataExpanded = false;
  String? _selectedCalendarId;
  bool _isLoading = false;

  bool get isEditing => widget.eventId != null;

  @override
  void initState() {
    super.initState();
    final base = widget.initialDate ?? DateTime.now();
    _startDate = base;
    _startTime = TimeOfDay(hour: base.hour + 1, minute: 0);
    _endDate = base;
    _endTime = TimeOfDay(hour: base.hour + 2, minute: 0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCalendars();
      if (isEditing) _loadEvent();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _tagController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _attendeeNameController.dispose();
    _attendeeEmailController.dispose();
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

  Future<void> _loadEvent() async {
    final provider = context.read<CalendarProvider>();
    final events = provider.allVisibleEvents;
    final event = events.where((e) => e.id == widget.eventId).firstOrNull;
    if (event != null) {
      setState(() {
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
        _locationController.text = event.location ?? '';
        _notesController.text = event.notes ?? '';
        _attendees = List.from(event.attendees);
        _metadataExpanded = event.hasMetadata;
        _selectedCalendarId = event.calendarId;
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

  void _addAttendee() {
    final name = _attendeeNameController.text.trim();
    if (name.isEmpty) return;
    final email = _attendeeEmailController.text.trim();
    setState(() {
      _attendees.add(Attendee(name: name, email: email.isEmpty ? null : email));
      _attendeeNameController.clear();
      _attendeeEmailController.clear();
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

    setState(() => _isLoading = true);

    final startDt = _isAllDay
        ? DateTime(_startDate.year, _startDate.month, _startDate.day)
        : _combine(_startDate, _startTime);
    final endDt = _isAllDay
        ? DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59)
        : _combine(_endDate, _endTime);

    final data = {
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'startTime': startDt.toIso8601String(),
      'endTime': endDt.toIso8601String(),
      'isAllDay': _isAllDay,
      'isPrivate': _isPrivate,
      'category': _category,
      'tags': _tags,
      'recurrenceType': _recurrenceType,
      'recurrenceEnd': _recurrenceEnd?.toIso8601String(),
      'location': _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'attendees': _attendees.isEmpty
          ? null
          : _attendees.map((a) => a.toJson()).toList(),
      'calendarId': _selectedCalendarId,
    };

    final provider = context.read<CalendarProvider>();
    bool success;
    if (isEditing) {
      success = await provider.updateEvent(widget.eventId!, data);
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
  }

  Future<void> _delete() async {
    if (!isEditing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일정 삭제'),
        content: const Text('이 일정을 삭제하시겠습니까?'),
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
    if (confirmed == true && mounted) {
      final success = await context.read<CalendarProvider>().deleteEvent(
        widget.eventId!,
      );
      if (success && mounted) context.pop();
    }
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
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _delete,
            ),
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
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '제목을 입력하세요' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: '카테고리',
                border: OutlineInputBorder(),
              ),
              items: EventModel.categoryLabels.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Color(EventModel.categoryColors[e.key]!),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(e.value),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
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
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addTag,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
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
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('종일'),
              value: _isAllDay,
              onChanged: (v) => setState(() => _isAllDay = v),
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('비공개'),
              value: _isPrivate,
              onChanged: (v) => setState(() => _isPrivate = v),
            ),
            const SizedBox(height: 8),
            // Metadata section (collapsible)
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  InkWell(
                    onTap: () => setState(() => _metadataExpanded = !_metadataExpanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            _metadataExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 20,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '상세 정보',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          if (_attendees.isNotEmpty || _locationController.text.isNotEmpty || _notesController.text.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(Icons.check_circle, size: 16, color: Colors.green[400]),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_metadataExpanded) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _locationController,
                            decoration: const InputDecoration(
                              labelText: '장소',
                              prefixIcon: Icon(Icons.location_on_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Attendees
                          Text('참여자', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                          const SizedBox(height: 8),
                          if (_attendees.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: _attendees.map((a) => Chip(
                                avatar: const CircleAvatar(
                                  child: Icon(Icons.person, size: 14),
                                ),
                                label: Text(a.email != null && a.email!.isNotEmpty
                                    ? '${a.name} (${a.email})'
                                    : a.name),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () => setState(() => _attendees.remove(a)),
                              )).toList(),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _attendeeNameController,
                                  decoration: const InputDecoration(
                                    labelText: '이름',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  onSubmitted: (_) => _addAttendee(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _attendeeEmailController,
                                  decoration: const InputDecoration(
                                    labelText: '이메일 (선택)',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  onSubmitted: (_) => _addAttendee(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                onPressed: _addAttendee,
                                icon: const Icon(Icons.person_add, size: 20),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: '메모',
                              prefixIcon: Icon(Icons.notes_outlined),
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _recurrenceType,
              decoration: const InputDecoration(
                labelText: '반복',
                border: OutlineInputBorder(),
              ),
              items: EventModel.recurrenceLabels.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Row(
                        children: [
                          if (e.key != 'NONE')
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.repeat, size: 16),
                            ),
                          Text(e.value),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _recurrenceType = v);
              },
            ),
            if (_recurrenceType != 'NONE') ...[
              const SizedBox(height: 8),
              ListTile(
                title: const Text('반복 종료일'),
                subtitle: Text(
                  _recurrenceEnd != null
                      ? DateFormat('yyyy-MM-dd').format(_recurrenceEnd!)
                      : '없음 (무한 반복)',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_recurrenceEnd != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _recurrenceEnd = null),
                      ),
                    const Icon(Icons.calendar_today),
                  ],
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _recurrenceEnd ?? _startDate.add(const Duration(days: 30)),
                    firstDate: _startDate,
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() => _recurrenceEnd = picked);
                  }
                },
              ),
            ],
            const SizedBox(height: 16),
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
