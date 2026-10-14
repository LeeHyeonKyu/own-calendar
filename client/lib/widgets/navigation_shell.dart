import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/calendar_provider.dart';
import '../themes/spacing.dart';

/// A single tab entry in the bottom navigation bar.
class TabItem {
  final String id;
  final IconData icon;
  final String label;
  final String route;

  const TabItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.route,
  });

  /// Look up a TabItem by its id from [allTabs]. Returns null if not found.
  static TabItem? fromId(String id) {
    for (final tab in allTabs) {
      if (tab.id == id) return tab;
    }
    return null;
  }
}

/// Full registry of all possible tabs.
const List<TabItem> allTabs = [
  TabItem(id: 'monthly', icon: Icons.calendar_month, label: '월별', route: '/'),
  TabItem(id: 'daily', icon: Icons.today, label: '일별', route: '/daily'),
  TabItem(id: 'weekly', icon: Icons.view_week, label: '주별', route: '/weekly'),
  TabItem(id: 'yearly', icon: Icons.calendar_today, label: '연별', route: '/yearly'),
  TabItem(id: 'habit', icon: Icons.self_improvement, label: '습관', route: '/habits'),
  TabItem(id: 'group', icon: Icons.group, label: '그룹', route: '/groups'),
  TabItem(id: 'settings', icon: Icons.settings, label: '설정', route: '/settings'),
];

/// Default visible tab IDs (5 tabs).
const List<String> defaultVisibleTabIds = [
  'monthly',
  'daily',
  'weekly',
  'habit',
  'group',
  'settings',
];

/// SharedPreferences key for persisted tab configuration.
const String tabConfigPrefsKey = 'nav_visible_tabs';

/// Global notifier that signals the NavigationShell to reload tab config.
/// Increment its value after saving new tab settings.
final ValueNotifier<int> tabConfigVersion = ValueNotifier<int>(0);

/// Centralized bottom navigation shell that wraps all main screens.
///
/// Provides a single NavigationBar and FAB used by every screen within
/// the ShellRoute, eliminating per-screen nav bar duplication.
class NavigationShell extends StatefulWidget {
  final GoRouterState state;
  final Widget child;

  const NavigationShell({
    super.key,
    required this.state,
    required this.child,
  });

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  List<String> _visibleTabIds = List.from(defaultVisibleTabIds);

  @override
  void initState() {
    super.initState();
    _loadTabConfig();
    tabConfigVersion.addListener(_loadTabConfig);
  }

  @override
  void dispose() {
    tabConfigVersion.removeListener(_loadTabConfig);
    super.dispose();
  }

  Future<void> _loadTabConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(tabConfigPrefsKey);
    if (saved != null && saved.length >= 2 && saved.length <= 6) {
      // Migrate legacy 'family' tab ID to 'group'
      var migrated = saved.map((id) => id == 'family' ? 'group' : id).toList();
      if (!migrated.contains('group')) {
        final settingsIdx = migrated.indexOf('settings');
        if (settingsIdx >= 0) {
          migrated.insert(settingsIdx, 'group');
        } else {
          migrated.add('group');
        }
      }
      // Keep only IDs that exist in the registry
      final validIds = migrated.where(
        (id) => allTabs.any((t) => t.id == id),
      ).toList();
      if (validIds.length >= 2) {
        if (mounted) setState(() => _visibleTabIds = validIds);
        return;
      }
    }
  }

  List<TabItem> get _visibleTabs {
    return _visibleTabIds
        .map((id) => allTabs.firstWhere((t) => t.id == id))
        .toList();
  }

  int get _currentIndex {
    final location = widget.state.matchedLocation;
    final tabs = _visibleTabs;
    for (int i = 0; i < tabs.length; i++) {
      if (tabs[i].route == location) return i;
    }
    // Current route not in visible tabs -- default to 0
    return 0;
  }

  void _onTabTapped(int index) {
    final tab = _visibleTabs[index];
    context.go(tab.route);
  }

  void _showCreateSheet() {
    final date = context.read<CalendarProvider>().selectedDate;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.event, color: cs.primary),
                  title: const Text('새 Event'),
                  subtitle: const Text('일정, 약속, 기념일'),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/event/new?date=${date.toIso8601String()}');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.check_box_outlined, color: AppColors.taskPending),
                  title: const Text('새 Task'),
                  subtitle: const Text('할 일, 체크리스트'),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/task/new?date=${date.toIso8601String()}');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _visibleTabs;
    final currentIndex = _currentIndex;

    return Scaffold(
      body: widget.child,
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateSheet,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: _onTabTapped,
        destinations: tabs
            .map((tab) => NavigationDestination(
                  icon: Icon(tab.icon),
                  label: tab.label,
                ))
            .toList(),
      ),
    );
  }
}
