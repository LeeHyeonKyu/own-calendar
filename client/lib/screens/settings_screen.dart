import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  List<dynamic> _naverConnections = [];
  bool _isLoading = true;
  int? _defaultReminder;
  String? _latestVersion;
  String? _downloadUrl;
  String? _altStoreSource;
  bool _updateAvailable = false;

  static const _currentVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

  String? _widgetKey;
  bool _widgetKeyLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConnections();
    _loadDefaultReminder();
    _checkVersion();
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
        final all = jsonDecode(res.body) as List<dynamic>;
        _connections = all.where((c) => c['provider'] != 'naver').toList();
        _naverConnections = all.where((c) => c['provider'] == 'naver').toList();
      }
    } catch (_) {}
    // Also try loading naver-specific connections
    try {
      final res = await _api.get('/naver/connections');
      if (res.statusCode == 200) {
        _naverConnections = jsonDecode(res.body) as List<dynamic>;
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadDefaultReminder() async {
    try {
      final res = await _api.get('/user-settings');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() => _defaultReminder = data['defaultReminderMinutes'] as int?);
        }
      }
    } catch (_) {}
  }

  Future<void> _checkVersion() async {
    try {
      final res = await _api.get('/version');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final latest = data['latestVersion'] as String?;
        if (mounted && latest != null && latest != _currentVersion && _currentVersion != 'dev') {
          setState(() {
            _latestVersion = latest;
            _downloadUrl = data['downloadUrl'] as String?;
            _altStoreSource = data['altStoreSource'] as String?;
            _updateAvailable = true;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _connectGoogle() async {
    try {
      final res = await _api.get('/google/auth');
      if (res.statusCode == 503) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google Calendar 연동이 아직 설정되지 않았습니다. 관리자에게 문의해주세요.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }
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

  Future<void> _disconnectGoogle(String connectionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Google Calendar 연결 해제'),
        content: const Text('연결을 해제하시겠습니까? 가져온 일정은 유지됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('해제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _api.delete('/google/connections/$connectionId');
      _loadConnections();
    }
  }

  Future<void> _connectNaver() async {
    final naverId = TextEditingController();
    final password = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Naver Calendar 연결'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Naver 계정 정보를 입력해주세요.'),
            const SizedBox(height: 12),
            TextField(
              controller: naverId,
              decoration: const InputDecoration(
                labelText: 'Naver ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '비밀번호 (앱 비밀번호)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              'naverId': naverId.text.trim(),
              'password': password.text,
            }),
            child: const Text('연결'),
          ),
        ],
      ),
    );

    if (result == null || result['naverId']!.isEmpty || result['password']!.isEmpty) return;

    try {
      final res = await _api.post('/naver/connect', result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.statusCode == 200 ? '연결 완료' : '연결 실패')),
        );
        _loadConnections();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('연결 실패: $e')),
        );
      }
    }
  }

  Future<void> _syncNaver(String connectionId) async {
    final res = await _api.post('/naver/sync/$connectionId', {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.statusCode == 200 ? '동기화 완료' : '동기화 실패')),
      );
    }
  }

  Future<void> _disconnectNaver(String connectionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Naver Calendar 연결 해제'),
        content: const Text('연결을 해제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('해제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _api.delete('/naver/connections/$connectionId');
      _loadConnections();
    }
  }

  Future<void> _updateDefaultReminder(int? minutes) async {
    setState(() => _defaultReminder = minutes);
    try {
      await _api.put('/user-settings', {'defaultReminderMinutes': minutes ?? 10});
    } catch (_) {}
  }

  Future<void> _generateWidgetKey() async {
    setState(() => _widgetKeyLoading = true);
    try {
      final key = await _api.createWidgetKey();
      setState(() => _widgetKey = key);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위젯 키 생성에 실패했습니다.')),
        );
      }
    } finally {
      setState(() => _widgetKeyLoading = false);
    }
  }

  static const _reminderOptions = <int?, String>{
    null: '끄기',
    0: '정시',
    5: '5분 전',
    10: '10분 전',
    15: '15분 전',
    30: '30분 전',
    60: '1시간 전',
  };

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
          if (_updateAvailable && _latestVersion != null)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.system_update, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '새 버전 $_latestVersion 사용 가능',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (_altStoreSource != null)
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _altStoreSource!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('AltStore 소스 URL이 복사되었습니다')),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('AltStore 소스'),
                          ),
                        if (_downloadUrl != null)
                          TextButton.icon(
                            onPressed: () async {
                              final uri = Uri.parse(_downloadUrl!);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('GitHub 릴리즈'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
              (c) {
                final syncStatus = c['syncStatus'] as String? ?? 'ok';
                final lastError = c['lastSyncError'] as String?;
                final isExpired = syncStatus == 'token_expired';
                final isError = syncStatus == 'error';

                IconData statusIcon;
                Color statusColor;
                String subtitle;
                if (isExpired) {
                  statusIcon = Icons.key_off;
                  statusColor = Colors.red;
                  subtitle = '재연결 필요';
                } else if (isError) {
                  statusIcon = Icons.warning_amber;
                  statusColor = Colors.orange;
                  subtitle = lastError ?? '동기화 오류';
                } else {
                  statusIcon = Icons.check_circle;
                  statusColor = Colors.green;
                  subtitle = c['lastSyncedAt'] != null
                      ? '마지막 동기화: ${c['lastSyncedAt']}'
                      : '동기화 안됨';
                }

                return ListTile(
                  leading: Icon(statusIcon, color: statusColor),
                  title: Text(c['calendar']?['name'] ?? c['externalId'] ?? 'Google Calendar'),
                  subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isExpired)
                        TextButton(
                          onPressed: _connectGoogle,
                          child: const Text('재연결'),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () => _syncGoogle(c['id']),
                        ),
                      IconButton(
                        icon: const Icon(Icons.link_off, size: 20),
                        onPressed: () => _disconnectGoogle(c['id']),
                      ),
                    ],
                  ),
                );
              },
            ),
          if (_connections.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('다른 Google 계정 추가'),
              onTap: _connectGoogle,
            ),
          const Divider(),
          // ── Naver Calendar (Feature 009) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Naver Calendar',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          if (_naverConnections.isEmpty)
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Naver Calendar 연결'),
              subtitle: const Text('ID/비밀번호로 CalDAV 연결'),
              onTap: _connectNaver,
            )
          else
            ..._naverConnections.map(
              (c) => ListTile(
                leading: const Icon(Icons.sync),
                title: Text(c['externalId'] ?? 'Naver Calendar'),
                subtitle: Text(
                  c['lastSyncedAt'] != null ? '마지막 동기화: ${c['lastSyncedAt']}' : '동기화 안됨',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => _syncNaver(c['id']),
                    ),
                    IconButton(
                      icon: const Icon(Icons.link_off, size: 20),
                      onPressed: () => _disconnectNaver(c['id']),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(),
          // ── Default Alarm (Feature 010) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '기본 알림 설정',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('기본 알림'),
            subtitle: Text(_reminderOptions[_defaultReminder] ?? '10분 전'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final selected = await showDialog<int?>(
                context: context,
                builder: (ctx) => SimpleDialog(
                  title: const Text('기본 알림 시간'),
                  children: _reminderOptions.entries.map((entry) {
                    return SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, entry.key ?? -1),
                      child: Row(
                        children: [
                          if (entry.key == _defaultReminder)
                            const Icon(Icons.check, size: 18)
                          else
                            const SizedBox(width: 18),
                          const SizedBox(width: 8),
                          Text(entry.value),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
              if (selected != null) {
                _updateDefaultReminder(selected == -1 ? null : selected);
              }
            },
          ),
          const Divider(),
          // ── Theme (Feature 020) ──
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('테마'),
            subtitle: const Text('컬러 테마 및 다크모드 설정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/theme'),
          ),
          const Divider(),
          // ── Category (Feature 017) ──
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('카테고리 관리'),
            subtitle: const Text('이벤트/할일 카테고리 설정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/categories'),
          ),
          const Divider(),
          // ── Holidays (Feature 013) ──
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('공휴일'),
            subtitle: const Text('국가별 공휴일 표시 설정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/holidays'),
          ),
          const Divider(),
          // ── Tab Settings (Feature 015) ──
          ListTile(
            leading: const Icon(Icons.tab),
            title: const Text('탭 편집'),
            subtitle: const Text('하단 네비게이션 탭 순서 및 표시 설정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/tabs'),
          ),
          const Divider(),
          // ── Import (Feature 008) ──
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('ICS 파일 Import'),
            subtitle: const Text('캘린더 파일로 일정 가져오기'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/import'),
          ),
          const Divider(),
          // ── Widget Key (Feature 021) ──
          ListTile(
            leading: const Icon(Icons.widgets_outlined),
            title: const Text('위젯 설정'),
            subtitle: _widgetKey != null
                ? Text('${_widgetKey!.substring(0, 8)}••••', style: const TextStyle(fontFamily: 'monospace'))
                : const Text('위젯 키를 생성하여 iOS 위젯에서 일정을 확인하세요'),
            trailing: _widgetKeyLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : _widgetKey != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _widgetKey!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('위젯 키가 복사되었습니다.\n위젯을 길게 누른 후 편집에서 붙여넣기 하세요.'),
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 20),
                            onPressed: _generateWidgetKey,
                          ),
                        ],
                      )
                    : null,
            onTap: _widgetKey == null ? _generateWidgetKey : null,
          ),
          if (_widgetKey != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 8),
              child: Text(
                '1. 위의 키를 복사합니다\n'
                '2. 홈 화면에서 위젯을 길게 누릅니다\n'
                '3. "위젯 편집"을 선택합니다\n'
                '4. 위젯 키 필드에 붙여넣기합니다',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
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
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '버전: $_currentVersion',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
