import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  final ApiService _api = ApiService();
  List<dynamic> _connections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConnections();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadConnections();
    }
  }

  Future<void> _loadConnections() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/google/connections');
      if (res.statusCode == 200) {
        _connections = jsonDecode(res.body);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _connectGoogle() async {
    try {
      final res = await _api.get('/google/auth');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final url = data['url'] as String?;
        if (url == null) return;

        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Google 인증 완료 후 앱으로 돌아와주세요')),
            );
          }
        } else {
          if (mounted) {
            _showOAuthFallbackDialog(url);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('연결 실패: $e')),
        );
      }
    }
  }

  void _showOAuthFallbackDialog(String url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Google Calendar 연결'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('아래 링크를 브라우저에서 열어 인증을 완료해주세요:'),
            const SizedBox(height: 12),
            SelectableText(
              url,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
            child: const Text('브라우저에서 열기'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncGoogle(String connectionId) async {
    final res = await _api.post('/google/sync/$connectionId', {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.statusCode == 200 ? '동기화 완료' : '동기화 실패',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          if (auth.user != null) ...[
            ListTile(
              leading: CircleAvatar(
                child: Text(auth.user!.name[0].toUpperCase()),
              ),
              title: Text(auth.user!.name),
              subtitle: Text(auth.user!.email),
            ),
            const Divider(),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Google Calendar',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_connections.isEmpty)
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Google Calendar 연결'),
              onTap: _connectGoogle,
            )
          else
            ..._connections.map(
              (c) => ListTile(
                leading: const Icon(Icons.sync),
                title: Text(c['email'] ?? 'Google Calendar'),
                subtitle: Text(
                  c['lastSyncAt'] != null ? '마지막 동기화: ${c['lastSyncAt']}' : '동기화 안됨',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _syncGoogle(c['id']),
                ),
              ),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('테마'),
            subtitle: const Text('컬러 테마 및 다크모드 설정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/theme'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.tab),
            title: const Text('탭 편집'),
            subtitle: const Text('하단 네비게이션 탭 순서 및 표시 설정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/tabs'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('로그아웃', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await auth.logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
