import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/group.dart';
import '../models/follow.dart';
import '../models/event_invite.dart';
import '../services/api_service.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  // Groups state
  List<GroupModel> _groups = [];
  bool _isLoadingGroups = true;

  // Follow state
  List<FollowModel> _following = [];
  List<FollowModel> _followers = [];
  List<FollowModel> _pendingRequests = [];
  List<EventInviteModel> _pendingInvites = [];
  bool _isLoadingFollow = true;

  // Create/Join controllers
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadGroups(), _loadFollowData()]);
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoadingGroups = true);
    try {
      final res = await _api.get('/groups');
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        _groups = list.map((j) => GroupModel.fromJson(j)).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingGroups = false);
  }

  Future<void> _loadFollowData() async {
    setState(() => _isLoadingFollow = true);
    try {
      final results = await Future.wait([
        _api.get('/follows/following'),
        _api.get('/follows/followers'),
        _api.get('/follows/pending'),
        _api.get('/invites?status=PENDING'),
      ]);

      if (results[0].statusCode == 200) {
        final list = jsonDecode(results[0].body) as List;
        _following = list.map((j) => FollowModel.fromJson(j)).toList();
      }
      if (results[1].statusCode == 200) {
        final list = jsonDecode(results[1].body) as List;
        _followers = list.map((j) => FollowModel.fromJson(j)).toList();
      }
      if (results[2].statusCode == 200) {
        final list = jsonDecode(results[2].body) as List;
        _pendingRequests = list.map((j) => FollowModel.fromJson(j)).toList();
      }
      if (results[3].statusCode == 200) {
        final list = jsonDecode(results[3].body) as List;
        _pendingInvites =
            list.map((j) => EventInviteModel.fromJson(j)).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingFollow = false);
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final res = await _api.post('/groups', {'name': name});
    if (res.statusCode == 201) {
      _nameController.clear();
      _loadGroups();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('그룹 생성 실패')),
        );
      }
    }
  }

  Future<void> _joinGroup() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    final res = await _api.post('/groups/join', {'code': code});
    if (res.statusCode == 200) {
      _codeController.clear();
      _loadGroups();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('합류 실패. 코드를 확인하세요.')),
        );
      }
    }
  }

  Future<void> _acceptFollow(String followId) async {
    final res = await _api.post('/follows/$followId/accept', {});
    if (res.statusCode == 200) {
      _loadFollowData();
    }
  }

  Future<void> _rejectFollow(String followId) async {
    final res = await _api.post('/follows/$followId/reject', {});
    if (res.statusCode == 200) {
      _loadFollowData();
    }
  }

  Future<void> _unfollow(String followeeId) async {
    final res = await _api.delete('/follows/$followeeId');
    if (res.statusCode == 204) {
      _loadFollowData();
    }
  }

  Future<void> _acceptInvite(String inviteId) async {
    final res = await _api.post('/invites/$inviteId/accept', {});
    if (res.statusCode == 200) {
      _loadFollowData();
    }
  }

  Future<void> _declineInvite(String inviteId) async {
    final res = await _api.post('/invites/$inviteId/decline', {});
    if (res.statusCode == 200) {
      _loadFollowData();
    }
  }

  void _showCreateGroupDialog() {
    _nameController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 그룹 만들기'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '그룹 이름',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (_) {
            Navigator.pop(ctx);
            _createGroup();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _createGroup();
            },
            child: const Text('만들기'),
          ),
        ],
      ),
    );
  }

  void _showJoinGroupDialog() {
    _codeController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('코드로 합류'),
        content: TextField(
          controller: _codeController,
          decoration: const InputDecoration(
            labelText: '초대 코드',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (_) {
            Navigator.pop(ctx);
            _joinGroup();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _joinGroup();
            },
            child: const Text('합류'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('그룹 & 팔로우'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search),
            tooltip: '사용자 검색',
            onPressed: () => context.push('/follow/search'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: '그룹',
              icon: Badge(
                isLabelVisible: _groups.isNotEmpty,
                label: Text('${_groups.length}'),
                child: const Icon(Icons.group),
              ),
            ),
            Tab(
              text: '팔로우',
              icon: Badge(
                isLabelVisible: _pendingRequests.isNotEmpty,
                label: Text('${_pendingRequests.length}'),
                child: const Icon(Icons.people),
              ),
            ),
            Tab(
              text: '초대',
              icon: Badge(
                isLabelVisible: _pendingInvites.isNotEmpty,
                label: Text('${_pendingInvites.length}'),
                child: const Icon(Icons.mail),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGroupsTab(),
          _buildFollowTab(),
          _buildInvitesTab(),
        ],
      ),
    );
  }

  Widget _buildGroupsTab() {
    if (_isLoadingGroups) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadGroups,
      child: _groups.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 80),
                Icon(Icons.group_add, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  '참여 중인 그룹이 없습니다',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _showCreateGroupDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('그룹 만들기'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _showJoinGroupDialog,
                  icon: const Icon(Icons.login),
                  label: const Text('코드로 합류'),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ..._groups.map((group) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(group.name[0]),
                        ),
                        title: Text(group.name),
                        subtitle: Text(
                          '${group.type} / ${group.memberCount}명 / ${group.isOwner ? "관리자" : "멤버"}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/groups/${group.id}'),
                      ),
                    )),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _showCreateGroupDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('새 그룹'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showJoinGroupDialog,
                        icon: const Icon(Icons.login),
                        label: const Text('코드 합류'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildFollowTab() {
    if (_isLoadingFollow) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadFollowData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Pending requests section
          if (_pendingRequests.isNotEmpty) ...[
            Text(
              '받은 팔로우 요청',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._pendingRequests.map((req) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(req.user.name[0].toUpperCase()),
                    ),
                    title: Text(req.user.name),
                    subtitle: Text(req.user.email),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () => _acceptFollow(req.id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _rejectFollow(req.id),
                        ),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 24),
          ],

          // Following section
          Text(
            '팔로잉 (${_following.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_following.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '팔로우한 사용자가 없습니다',
                style: TextStyle(color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._following.map((f) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(f.user.name[0].toUpperCase()),
                    ),
                    title: Text(f.user.name),
                    subtitle: Text(f.user.email),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.calendar_month),
                          tooltip: '일정 보기',
                          onPressed: () => context.push(
                            '/follow/${f.user.id}/events?name=${Uri.encodeComponent(f.user.name)}',
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showUnfollowConfirm(f.user),
                          child: const Text('언팔로우'),
                        ),
                      ],
                    ),
                  ),
                )),

          const SizedBox(height: 24),

          // Followers section
          Text(
            '팔로워 (${_followers.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_followers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '팔로워가 없습니다',
                style: TextStyle(color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._followers.map((f) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(f.user.name[0].toUpperCase()),
                    ),
                    title: Text(f.user.name),
                    subtitle: Text(f.user.email),
                  ),
                )),
        ],
      ),
    );
  }

  void _showUnfollowConfirm(FollowUser user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('언팔로우'),
        content: Text('${user.name}님을 언팔로우하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _unfollow(user.id);
            },
            child: const Text('언팔로우', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitesTab() {
    if (_isLoadingFollow) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadFollowData,
      child: _pendingInvites.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 100),
                Icon(Icons.mail_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  '받은 초대가 없습니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ..._pendingInvites.map((invite) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invite.event?.title ?? '일정',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (invite.event?.createdBy != null)
                              Text(
                                '${invite.event!.createdBy!.name}님이 초대',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            if (invite.event != null)
                              Text(
                                _formatEventTime(invite.event!),
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      _declineInvite(invite.id),
                                  child: const Text('거절'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: () =>
                                      _acceptInvite(invite.id),
                                  child: const Text('수락'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )),
              ],
            ),
    );
  }

  String _formatEventTime(InviteEvent event) {
    if (event.isAllDay) {
      return '${event.startTime.month}/${event.startTime.day} 종일';
    }
    final sh = event.startTime.hour.toString().padLeft(2, "0");
    final sm = event.startTime.minute.toString().padLeft(2, "0");
    final eh = event.endTime.hour.toString().padLeft(2, "0");
    final em = event.endTime.minute.toString().padLeft(2, "0");
    return '${event.startTime.month}/${event.startTime.day} $sh:$sm - $eh:$em';
  }
}
