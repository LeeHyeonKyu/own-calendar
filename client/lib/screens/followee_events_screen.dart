import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../services/api_service.dart';

class FolloweeEventsScreen extends StatefulWidget {
  final String followeeId;
  final String followeeName;

  const FolloweeEventsScreen({
    super.key,
    required this.followeeId,
    required this.followeeName,
  });

  @override
  State<FolloweeEventsScreen> createState() => _FolloweeEventsScreenState();
}

class _FolloweeEventsScreenState extends State<FolloweeEventsScreen> {
  final ApiService _api = ApiService();
  List<EventModel> _events = [];
  bool _isLoading = true;
  late DateTime _rangeStart;
  late DateTime _rangeEnd;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _rangeStart = DateTime(now.year, now.month, 1);
    _rangeEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get(
        '/follows/${widget.followeeId}/events'
        '?start=${_rangeStart.toIso8601String()}'
        '&end=${_rangeEnd.toIso8601String()}',
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        _events = list.map((j) => EventModel.fromJson(j)).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _changeMonth(int delta) {
    setState(() {
      _rangeStart = DateTime(_rangeStart.year, _rangeStart.month + delta, 1);
      _rangeEnd = DateTime(_rangeStart.year, _rangeStart.month + 1, 0, 23, 59, 59);
    });
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('yyyy년 M월', 'ko').format(_rangeStart);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.followeeName}의 일정'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  monthLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              '이 기간에 공개된 일정이 없습니다',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadEvents,
                        child: _buildEventList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    final grouped = <String, List<EventModel>>{};
    for (final event in _events) {
      final key = DateFormat('M/d (E)', 'ko').format(event.startTime.toLocal());
      grouped.putIfAbsent(key, () => []).add(event);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final dateKey = grouped.keys.elementAt(index);
        final dayEvents = grouped[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                dateKey,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...dayEvents.map((event) {
              final calColor = event.categoryColor ?? event.calendarColor ?? '#4A90D9';
              final color = Color(int.parse('FF${calColor.replaceFirst('#', '')}', radix: 16));
              final timeStr = event.isAllDay
                  ? '종일'
                  : '${DateFormat('HH:mm').format(event.startTime.toLocal())} – ${DateFormat('HH:mm').format(event.endTime.toLocal())}';

              return Card(
                child: ListTile(
                  leading: Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  title: Text(event.title),
                  subtitle: Text(timeStr),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
