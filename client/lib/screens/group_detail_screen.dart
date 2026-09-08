import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/group.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/event_card.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _group;
  List<GroupMember> _members = [];
  List<EventModel> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/groups/${widget.groupId}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _group = data;
        if (data['members'] != null) {
          _members = (data['members'] as List)
              .map((m) => GroupMember.fromJson(m))
              .toList();
        }
      }

      // Load group events for this week
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 7));
      final eventsRes = await _api.get(
        '/groups/${widget.groupId}/calendars'
        '?start=${start.toIso8601String()}&end=${end.toIso8601String()}',
      );
      if (eventsRes.statusCode == 200) {
        final data = jsonDecode(eventsRes.body) as List;
        _events = [];
        for (final member in data) {
          if (member['calendars'] != null) {
            for (final cal in member['calendars']) {
              if (cal['events'] != null) {
                for (final evt in cal['events']) {
                  evt['calendar'] = {
                    'name': cal['name'],
                    'color': cal['color'],
                  };
                  _events.add(EventModel.fromJson(evt));
                }
              }
            }
          }
        }
        _events.sort((a, b) => a.startTime.compareTo(b.startTime));
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('초대 코드가 복사되었습니다')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('그룹')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('그룹')),
        body: const Center(child: Text('그룹을 찾을 수 없습니다')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_group!['name'] ?? '그룹'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadGroup,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Invite code card
            if (_group!['code'] != null)
              Card(
                child: InkWell(
                  onTap: () => _copyCode(_group!['code']),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.vpn_key),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '초대 코드 (탭하여 복사)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                _group!['code'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.copy, size: 20),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Members section
            Text(
              '구성원 (${_members.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._members.map(
              (m) => ListTile(
                leading: CircleAvatar(
                  child: Text(m.name[0].toUpperCase()),
                ),
                title: Text(m.name),
                subtitle: Text(
                  '${m.email} / ${m.role == 'OWNER' ? '관리자' : '멤버'}',
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Group events section
            Text(
              '그룹 일정 (이번 주)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_events.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '그룹 일정이 없습니다',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              )
            else
              ..._events.map(
                (event) => EventCard(event: event),
              ),
          ],
        ),
      ),
    );
  }
}
