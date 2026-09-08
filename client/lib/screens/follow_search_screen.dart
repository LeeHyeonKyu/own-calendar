import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/follow.dart';
import '../services/api_service.dart';

class FollowSearchScreen extends StatefulWidget {
  const FollowSearchScreen({super.key});

  @override
  State<FollowSearchScreen> createState() => _FollowSearchScreenState();
}

class _FollowSearchScreenState extends State<FollowSearchScreen> {
  final ApiService _api = ApiService();
  final _searchController = TextEditingController();
  List<UserSearchResult> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final res = await _api.get(
        '/follows/search?q=${Uri.encodeComponent(query)}',
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        _results = list.map((j) => UserSearchResult.fromJson(j)).toList();
      }
    } catch (_) {}

    if (mounted) setState(() => _isSearching = false);
  }

  Future<void> _sendFollowRequest(String userId) async {
    final res = await _api.post('/follows', {'followeeId': userId});
    if (res.statusCode == 201) {
      // Refresh the search results to update the status
      _search();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('팔로우 요청을 보냈습니다')),
        );
      }
    } else {
      if (mounted) {
        final body = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['error'] ?? '요청 실패')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 검색'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: '이름 또는 이메일로 검색',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
              autofocus: true,
            ),
          ),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else if (_hasSearched && _results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                '검색 결과가 없습니다',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final user = _results[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(user.name[0].toUpperCase()),
                    ),
                    title: Text(user.name),
                    subtitle: Text(user.email),
                    trailing: _buildFollowButton(user),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFollowButton(UserSearchResult user) {
    if (user.followStatus == 'ACCEPTED') {
      return const Chip(label: Text('팔로잉'));
    }
    if (user.followStatus == 'PENDING') {
      return const Chip(label: Text('요청 중'));
    }
    return FilledButton.tonal(
      onPressed: () => _sendFollowRequest(user.id),
      child: const Text('팔로우'),
    );
  }
}
