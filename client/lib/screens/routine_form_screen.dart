import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/routine_provider.dart';
import '../models/routine.dart';

const _routineColor = Color(0xFF8B5CF6);

class RoutineFormScreen extends StatefulWidget {
  final String? routineId;
  const RoutineFormScreen({super.key, this.routineId});

  @override
  State<RoutineFormScreen> createState() => _RoutineFormScreenState();
}

class _RoutineFormScreenState extends State<RoutineFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  TimeOfDay? _time;
  Set<int> _selectedDays = {1, 2, 3, 4, 5, 6, 0}; // default: every day
  String? _selectedGroupId;
  bool _isLoading = false;

  bool get isEditing => widget.routineId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGroups();
      if (isEditing) _loadRoutine();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    final provider = context.read<RoutineProvider>();
    await provider.loadGroups();
  }

  Future<void> _loadRoutine() async {
    final provider = context.read<RoutineProvider>();
    final routine = provider.routines
        .where((r) => r.id == widget.routineId)
        .firstOrNull;
    if (routine != null) {
      setState(() {
        _nameController.text = routine.name;
        if (routine.time != null) {
          final parts = routine.time!.split(':');
          _time = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
        _selectedDays = routine.repeatDays.toSet();
        _selectedGroupId = routine.groupId;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  void _setPreset(String preset) {
    setState(() {
      switch (preset) {
        case 'everyday':
          _selectedDays = {0, 1, 2, 3, 4, 5, 6};
          break;
        case 'weekdays':
          _selectedDays = {1, 2, 3, 4, 5};
          break;
        case 'weekends':
          _selectedDays = {0, 6};
          break;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('반복 요일을 선택하세요')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final data = <String, dynamic>{
      'name': _nameController.text.trim(),
      'time': _time != null
          ? '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}'
          : null,
      'repeatDays': _selectedDays.toList()..sort(),
      'groupId': _selectedGroupId,
    };

    final provider = context.read<RoutineProvider>();
    bool success;
    if (isEditing) {
      success = await provider.updateRoutine(widget.routineId!, data);
    } else {
      success = await provider.createRoutine(data);
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
        title: const Text('루틴 삭제'),
        content: const Text('이 루틴을 삭제하시겠습니까?'),
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
      final success =
          await context.read<RoutineProvider>().deleteRoutine(widget.routineId!);
      if (success && mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RoutineProvider>();

    // Day labels starting from Monday for display, with Sunday at end
    // but internally: 0=Sun, 1=Mon, ..., 6=Sat
    const displayOrder = [1, 2, 3, 4, 5, 6, 0]; // Mon-Sun

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '루틴 수정' : '새 루틴'),
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
            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '루틴 이름',
                border: OutlineInputBorder(),
                hintText: '예: 물 한잔, 스트레칭, 독서',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '루틴 이름을 입력하세요' : null,
            ),
            const SizedBox(height: 16),

            // Time picker
            ListTile(
              title: const Text('시간'),
              subtitle: Text(_time != null
                  ? '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}'
                  : '없음'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_time != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _time = null),
                    ),
                  const Icon(Icons.access_time),
                ],
              ),
              onTap: _pickTime,
            ),
            const SizedBox(height: 16),

            // Repeat days
            Text(
              '반복 요일',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),

            // Preset chips
            Wrap(
              spacing: 8,
              children: [
                _presetChip('매일', 'everyday',
                    _selectedDays.length == 7),
                _presetChip('평일', 'weekdays',
                    _selectedDays.containsAll({1, 2, 3, 4, 5}) &&
                        _selectedDays.length == 5),
                _presetChip('주말', 'weekends',
                    _selectedDays.containsAll({0, 6}) &&
                        _selectedDays.length == 2),
              ],
            ),
            const SizedBox(height: 8),

            // Day chips
            Wrap(
              spacing: 6,
              children: displayOrder.map((day) {
                final isSelected = _selectedDays.contains(day);
                return FilterChip(
                  label: Text(RoutineModel.dayLabelsKo[day]),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedDays.add(day);
                      } else {
                        _selectedDays.remove(day);
                      }
                    });
                  },
                  selectedColor: _routineColor.withAlpha(30),
                  checkmarkColor: _routineColor,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Group selector
            DropdownButtonFormField<String?>(
              value: _selectedGroupId,
              decoration: const InputDecoration(
                labelText: '그룹 (선택)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('없음')),
                ...provider.groups.map(
                  (g) => DropdownMenuItem(
                    value: g.id,
                    child: Text(g.name),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _selectedGroupId = v),
            ),
            const SizedBox(height: 8),

            // New group button
            TextButton.icon(
              onPressed: _showCreateGroupDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('새 그룹 만들기'),
            ),
            const SizedBox(height: 24),

            // Save button
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

  Widget _presetChip(String label, String preset, bool isActive) {
    return ActionChip(
      label: Text(label),
      backgroundColor: isActive ? _routineColor.withAlpha(25) : null,
      side: isActive
          ? const BorderSide(color: _routineColor, width: 1.5)
          : null,
      onPressed: () => _setPreset(preset),
    );
  }

  void _showCreateGroupDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 그룹'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '그룹 이름',
            hintText: '예: 아침 루틴, 운동',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final provider = context.read<RoutineProvider>();
              final success = await provider.createGroup({'name': name});
              if (success && mounted) {
                // Select the newly created group
                final newGroup = provider.groups.lastOrNull;
                if (newGroup != null) {
                  setState(() => _selectedGroupId = newGroup.id);
                }
              }
            },
            child: const Text('만들기'),
          ),
        ],
      ),
    );
  }
}
