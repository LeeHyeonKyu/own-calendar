import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/navigation_shell.dart';

/// Screen for customizing the bottom navigation tabs.
///
/// Users can show/hide tabs and reorder them via drag-and-drop.
/// Constraints: minimum 2, maximum 6 visible tabs.
class TabSettingsScreen extends StatefulWidget {
  const TabSettingsScreen({super.key});

  @override
  State<TabSettingsScreen> createState() => _TabSettingsScreenState();
}

class _TabSettingsScreenState extends State<TabSettingsScreen> {
  /// Currently visible tab IDs, in display order.
  List<String> _visibleIds = [];

  /// All available tab IDs, including hidden ones.
  List<String> get _allIds => allTabs.map((t) => t.id).toList();

  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(tabConfigPrefsKey);
    if (saved != null && saved.length >= 2) {
      final valid = saved.where((id) => allTabs.any((t) => t.id == id)).toList();
      if (valid.length >= 2) {
        setState(() {
          _visibleIds = valid;
          _isLoading = false;
        });
        return;
      }
    }
    setState(() {
      _visibleIds = List.from(defaultVisibleTabIds);
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(tabConfigPrefsKey, _visibleIds);
    // Signal the NavigationShell to reload its tab configuration.
    tabConfigVersion.value++;
    setState(() => _hasChanges = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('탭 설정이 저장되었습니다'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _toggleTab(String id) {
    setState(() {
      if (_visibleIds.contains(id)) {
        // Don't allow fewer than 2 visible tabs
        if (_visibleIds.length <= 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('최소 2개의 탭이 필요합니다')),
          );
          return;
        }
        _visibleIds.remove(id);
      } else {
        // Don't allow more than 6 visible tabs
        if (_visibleIds.length >= 6) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('최대 6개까지 탭을 추가할 수 있습니다')),
          );
          return;
        }
        _visibleIds.add(id);
      }
      _hasChanges = true;
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _visibleIds.removeAt(oldIndex);
      _visibleIds.insert(newIndex, item);
      _hasChanges = true;
    });
  }

  Future<void> _resetToDefault() async {
    setState(() {
      _visibleIds = List.from(defaultVisibleTabIds);
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('탭 편집')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Hidden tabs: all tabs not in visibleIds
    final hiddenIds = _allIds.where((id) => !_visibleIds.contains(id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('탭 편집'),
        actions: [
          TextButton(
            onPressed: _resetToDefault,
            child: const Text('초기화'),
          ),
          TextButton(
            onPressed: _hasChanges ? _save : null,
            child: const Text('저장'),
          ),
        ],
      ),
      body: ListView(
        children: [
          // Section: Visible tabs (reorderable)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  '표시 중인 탭',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const Spacer(),
                Text(
                  '${_visibleIds.length}/6',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '길게 눌러 순서를 변경하세요',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ),
          const SizedBox(height: 8),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _visibleIds.length,
            onReorder: _onReorder,
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) => Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: child,
                ),
                child: child,
              );
            },
            itemBuilder: (context, index) {
              final id = _visibleIds[index];
              final tab = TabItem.fromId(id);
              if (tab == null) return const SizedBox(key: ValueKey('unknown'));

              return ListTile(
                key: ValueKey(id),
                leading: Icon(tab.icon),
                title: Text(tab.label),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: true,
                      onChanged: (_) => _toggleTab(id),
                    ),
                    const Icon(Icons.drag_handle, color: Colors.grey),
                  ],
                ),
              );
            },
          ),

          // Section: Hidden tabs
          if (hiddenIds.isNotEmpty) ...[
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '숨겨진 탭',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ),
            ...hiddenIds.map((id) {
              final tab = TabItem.fromId(id);
              if (tab == null) return const SizedBox();

              return ListTile(
                leading: Icon(tab.icon, color: Colors.grey[400]),
                title: Text(
                  tab.label,
                  style: TextStyle(color: Colors.grey[500]),
                ),
                trailing: Switch(
                  value: false,
                  onChanged: (_) => _toggleTab(id),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
