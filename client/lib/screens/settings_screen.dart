import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _connections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConnections();
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
    final res = await _api.get('/google/auth');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final url = data['url'];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('브라우저에서 인증해주세요: $url'),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
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
