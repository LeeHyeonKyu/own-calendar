import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/calendar_provider.dart';
import '../services/api_service.dart';
import '../widgets/event_card.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _family;
  List<dynamic> _members = [];
  bool _isLoading = true;
  bool _hasFamily = false;
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFamily();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadFamily() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/family');
      if (res.statusCode == 200) {
        _family = jsonDecode(res.body);
        _hasFamily = true;
        final membersRes = await _api.get('/family/members');
        if (membersRes.statusCode == 200) {
          _members = jsonDecode(membersRes.body);
        }
        if (mounted) {
          final now = DateTime.now();
          final start = DateTime(now.year, now.month, now.day);
          final end = start.add(const Duration(days: 7));
          await context.read<CalendarProvider>().loadFamilyEvents(
            start: start,
            end: end,
          );
        }
      } else {
        _hasFamily = false;
      }
    } catch (_) {
      _hasFamily = false;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _createFamily() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final res = await _api.post('/family', {'name': name});
    if (res.statusCode == 201) {
      _nameController.clear();
      _loadFamily();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('가족 그룹 생성 실패')),
        );
      }
    }
  }

  Future<void> _joinFamily() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    final res = await _api.post('/family/join', {'code': code});
    if (res.statusCode == 200) {
      _codeController.clear();
      _loadFamily();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('합류 실패. 코드를 확인하세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('가족')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasFamily) {
      return Scaffold(
        appBar: AppBar(title: const Text('가족')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.family_restroom,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                '가족 그룹이 없습니다',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '그룹 이름',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _createFamily,
                child: const Text('가족 그룹 만들기'),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: '초대 코드',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _joinFamily,
                child: const Text('코드로 합류'),
              ),
            ],
          ),
        ),
      );
    }

    final calProvider = context.watch<CalendarProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_family?['name'] ?? '가족'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFamily,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_family?['code'] != null) ...[
              Card(
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
                            const Text(
                              '초대 코드',
                              style: TextStyle(fontSize: 12),
                            ),
                            Text(
                              _family!['code'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              '구성원',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._members.map(
              (m) => ListTile(
                leading: CircleAvatar(
                  child: Text(
                    (m['user']?['name'] ?? '?')[0].toUpperCase(),
                  ),
                ),
                title: Text(m['user']?['name'] ?? ''),
                subtitle: Text(m['role'] ?? ''),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '가족 일정 (이번 주)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (calProvider.familyEvents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '가족 일정이 없습니다',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              )
            else
              ...calProvider.familyEvents.map(
                (event) => EventCard(event: event),
              ),
          ],
        ),
      ),
    );
  }
}
