import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/event_card.dart';
import '../themes/spacing.dart';

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
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final start = _currentMonth;
      final end = DateTime(_currentMonth.year, _currentMonth.month + 1);
      final res = await _api.get(
        '/follows/${widget.followeeId}/events'
        '?start=${start.toIso8601String()}&end=${end.toIso8601String()}',
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        _events = list.map((j) => EventModel.fromJson(j)).toList();
        _events.sort((a, b) => a.startTime.compareTo(b.startTime));
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _loadEvents();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _loadEvents();
  }

  /// Group events by date for section-style display.
  Map<String, List<EventModel>> _groupByDate() {
    final grouped = <String, List<EventModel>>{};
    final dateFmt = DateFormat('yyyy-MM-dd');
    for (final event in _events) {
      final key = dateFmt.format(event.startTime);
      grouped.putIfAbsent(key, () => []).add(event);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('yyyy년 M월').format(_currentMonth);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.followeeName}의 일정'),
      ),
      body: Column(
        children: [
          // Month navigation
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg,
              vertical: Spacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousMonth,
                ),
                Text(
                  monthLabel,
                  style: TextStyle(
                    fontSize: AppTypography.h2,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),

          // Events list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? _buildEmptyState(cs)
                    : _buildEventsList(cs),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.event_busy, size: 64, color: cs.outlineVariant),
          const SizedBox(height: Spacing.lg),
          Text(
            '이 달에 공개된 일정이 없습니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTypography.body,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(ColorScheme cs) {
    final grouped = _groupByDate();
    final sortedDates = grouped.keys.toList()..sort();
    final dateLabelFmt = DateFormat('M월 d일 (E)', 'ko_KR');

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final dateKey = sortedDates[index];
          final events = grouped[dateKey]!;
          final date = DateTime.parse(dateKey);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: Spacing.lg,
                  bottom: Spacing.sm,
                ),
                child: Text(
                  dateLabelFmt.format(date),
                  style: TextStyle(
                    fontSize: AppTypography.h3,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              ...events.map((event) => EventCard(event: event)),
            ],
          );
        },
      ),
    );
  }
}
