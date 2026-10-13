import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';
import '../widgets/event_card.dart';
import '../themes/spacing.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final provider = context.read<CalendarProvider>();
    await provider.loadCalendars();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    await provider.loadEvents(start: todayStart, end: todayEnd);
    await provider.loadGroupEvents(start: todayStart, end: todayEnd);
  }

  @override
  Widget build(BuildContext context) {
    final calProvider = context.watch<CalendarProvider>();
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy년 M월 d일 (E)', 'ko').format(now);

    final allEvents = [...calProvider.events, ...calProvider.groupEvents];
    allEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Own Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: EdgeInsets.all(Spacing.lg),
          children: [
            Text(
              dateStr,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: Spacing.xs),
            Text(
              '오늘',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: Spacing.lg),
            if (calProvider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (allEvents.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: Spacing.xxxl),
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_available,
                        size: 64,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      SizedBox(height: Spacing.lg),
                      Text(
                        '오늘 일정이 없습니다',
                        style: TextStyle(
                          fontSize: AppTypography.h3,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...allEvents.map(
                (event) => EventCard(
                  event: event,
                  onTap: () => context.push('/event/${event.id}/edit'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
