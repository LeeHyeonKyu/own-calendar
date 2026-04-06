import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';
import '../widgets/event_card.dart';

class DailyViewScreen extends StatefulWidget {
  final DateTime? initialDate;

  const DailyViewScreen({super.key, this.initialDate});

  @override
  State<DailyViewScreen> createState() => _DailyViewScreenState();
}

class _DailyViewScreenState extends State<DailyViewScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEvents());
  }

  Future<void> _loadEvents() async {
    final start = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final end = start.add(const Duration(days: 1));
    await context.read<CalendarProvider>().loadEvents(start: start, end: end);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    final calProvider = context.watch<CalendarProvider>();
    final dateStr = DateFormat('yyyy년 M월 d일 (E)', 'ko').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('일별 보기'),
      ),
      body: Column(
        children: [
          InkWell(
            onTap: _pickDate,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        _selectedDate = _selectedDate.subtract(
                          const Duration(days: 1),
                        );
                      });
                      _loadEvents();
                    },
                  ),
                  Text(
                    dateStr,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() {
                        _selectedDate = _selectedDate.add(
                          const Duration(days: 1),
                        );
                      });
                      _loadEvents();
                    },
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: calProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : calProvider.events.isEmpty
                    ? Center(
                        child: Text(
                          '일정이 없습니다',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: calProvider.events.length,
                        itemBuilder: (context, index) {
                          final event = calProvider.events[index];
                          return EventCard(
                            event: event,
                            onTap: () =>
                                context.push('/event/${event.id}/edit'),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/event/new?date=${_selectedDate.toIso8601String()}'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
