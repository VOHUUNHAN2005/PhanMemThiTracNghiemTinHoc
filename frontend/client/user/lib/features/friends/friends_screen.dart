import 'dart:async';
import 'package:flutter/material.dart';
import 'package:user/core/services/friend_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FriendService _friendService = FriendService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  Timer? _realtimeTimer;

  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;
  String _searchQuery = '';

  List<dynamic> _friends = [];
  List<dynamic> _incomingRequests = [];
  List<dynamic> _outgoingRequests = [];
  List<dynamic> _searchResults = [];

  final Set<int> _sentUserIds = <int>{};
  final Set<int> _sendingUserIds = <int>{};
  final Set<int> _cancelingUserIds = <int>{};
  final Set<int> _removingFriendIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadData();

    _realtimeTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !_isLoading) {
        _refreshSilent();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _realtimeTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshSilent() async {
    try {
      final results = await Future.wait([
        _friendService.getFriends(),
        _friendService.getFriendRequests(),
      ]);
      final reqMap = _asMap(results[1]);
      final rawIncoming = (reqMap['incoming'] as List?) ?? const [];
      final rawOutgoing = (reqMap['outgoing'] as List?) ?? const [];

      if (mounted) {
        setState(() {
          _friends = results[0] as List<dynamic>;
          _incomingRequests = List<dynamic>.from(rawIncoming);
          _outgoingRequests = List<dynamic>.from(rawOutgoing);
          _syncSentUserIds();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _friendService.getFriends(),
        _friendService.getFriendRequests(),
      ]);

      final reqMap = _asMap(results[1]);
      final rawIncoming = (reqMap['incoming'] as List?) ?? const [];
      final rawOutgoing = (reqMap['outgoing'] as List?) ?? const [];

      if (mounted) {
        setState(() {
          _friends = results[0] as List<dynamic>;
          _incomingRequests = List<dynamic>.from(rawIncoming);
          _outgoingRequests = List<dynamic>.from(rawOutgoing);
          _syncSentUserIds();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _cleanError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _syncSentUserIds() {
    _sentUserIds.clear();
    for (final raw in _outgoingRequests) {
      final map = _unwrapUserMap(raw);
      final id = _extractUserId(map);
      if (id > 0) _sentUserIds.add(id);
    }
  }

  String _cleanError(Object e) => e.toString().replaceFirst('Exception: ', '');

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _unwrapUserMap(dynamic rawItem) {
    final map = _asMap(rawItem);
    for (final key in [
      'user',
      'friend',
      'profile',
      'target_user',
      'receiver',
      'sender',
      'nguoi_dung',
      'NguoiDung',
    ]) {
      final nested = map[key];
      if (nested is Map) {
        return {...Map<String, dynamic>.from(nested), ...map};
      }
    }
    return map;
  }

  int _extractUserId(Map<String, dynamic> item) {
    final raw =
        item['MaNguoiDung'] ??
        item['ma_nguoi_dung'] ??
        item['target_user_id'] ??
        item['receiver_id'] ??
        item['sender_id'] ??
        item['friend_id'] ??
        item['user_id'] ??
        item['UserId'] ??
        item['id'] ??
        0;
    if (raw is int) return raw;
    return int.tryParse(raw.toString()) ?? 0;
  }

  bool _isUserOnline(Map<String, dynamic> item) {
    final raw =
        item['is_online'] ??
        item['IsOnline'] ??
        item['online'] ??
        item['Online'] ??
        item['TrangThaiOnline'] ??
        item['trang_thai_online'];
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final v = raw.trim().toLowerCase();
      return v == 'true' || v == '1' || v == 'online' || v == 'dang_online';
    }

    final status = (item['TrangThai'] ?? item['trang_thai'] ?? item['status'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (status != null) {
      if (status == 'online' || status == 'truc_tuyen' || status == 'active') {
        return true;
      }
      if (status == 'offline' || status == 'ngoai_tuyen') {
        return false;
      }
    }
    return false;
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      _performSearch('');
      return;
    }

    setState(() {
      _searchQuery = trimmed;
      _isSearching = true;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      _performSearch(trimmed);
    });
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (mounted) {
      setState(() {
        _searchQuery = trimmed;
        if (trimmed.isEmpty) {
          _searchResults = [];
          _isSearching = false;
        } else {
          _isSearching = true;
        }
      });
    }

    if (trimmed.isEmpty) return;

    try {
      final list = await _friendService.searchUsers(trimmed);
      if (mounted && _searchQuery == trimmed) {
        setState(() {
          _searchResults = list;
        });
      }
    } catch (e) {
      if (mounted && _searchQuery == trimmed) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_cleanError(e))));
      }
    } finally {
      if (mounted && _searchQuery == trimmed) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _handleSendRequest(int targetUserId) async {
    if (targetUserId <= 0 ||
        _sendingUserIds.contains(targetUserId) ||
        _sentUserIds.contains(targetUserId)) {
      return;
    }

    setState(() => _sendingUserIds.add(targetUserId));
    try {
      await _friendService.sendRequest(targetUserId);
      if (mounted) {
        setState(() => _sentUserIds.add(targetUserId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi lời mời kết bạn.')),
        );
      }
      await _refreshSilent();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_cleanError(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _sendingUserIds.remove(targetUserId));
      }
    }
  }

  Future<void> _handleCancelSentRequest(int targetUserId, String name) async {
    if (targetUserId <= 0 || _cancelingUserIds.contains(targetUserId)) return;

    setState(() => _cancelingUserIds.add(targetUserId));
    try {
      await _friendService.cancelSentRequest(targetUserId);
      if (mounted) {
        setState(() => _sentUserIds.remove(targetUserId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã hủy lời mời kết bạn tới $name.')),
        );
      }
      await _refreshSilent();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_cleanError(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _cancelingUserIds.remove(targetUserId));
      }
    }
  }

  Future<void> _handleRespond(dynamic reqItem, bool accept) async {
    final map = _asMap(reqItem);
    final int requestId =
        (map['MaKetBan'] ?? map['id'] ?? map['request_id'] ?? 0) as int;
    if (requestId <= 0) return;

    try {
      await _friendService.respondRequest(
        maKetBan: requestId,
        chapNhan: accept,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept ? 'Đã chấp nhận lời mời kết bạn.' : 'Đã từ chối lời mời.',
            ),
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_cleanError(e))));
      }
    }
  }

  Future<void> _handleUnfriend(int friendUserId, String friendName) async {
    if (friendUserId <= 0 || _removingFriendIds.contains(friendUserId)) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy kết bạn'),
        content: Text('Bạn có chắc muốn hủy kết bạn với "$friendName" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hủy kết bạn'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _removingFriendIds.add(friendUserId));
    try {
      await _friendService.unfriend(friendUserId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã hủy kết bạn với $friendName.')),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_cleanError(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _removingFriendIds.remove(friendUserId));
      }
    }
  }

  Future<void> _openProfile(
    int userId, {
    String? initialName,
    bool isFriend = false,
    bool? initialOnline,
  }) async {
    if (userId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy ID người dùng.')),
      );
      return;
    }

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FriendProfileScreen(
          targetUserId: userId,
          initialName: initialName,
          isFriend: isFriend,
          initialOnline: initialOnline,
        ),
      ),
    );

    if (changed == true && mounted) {
      await _loadData();
    }
  }

  Widget _buildAvatarWithStatus(bool isOnline) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const CircleAvatar(
          backgroundColor: Color(0xFF1D5CE5),
          child: Icon(Icons.person, color: Colors.white),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isOnline
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF94A3B8),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendCard(dynamic rawItem) {
    final item = _unwrapUserMap(rawItem);
    final int userId = _extractUserId(item);
    final String name =
        (item['HoTen'] ??
                item['ho_ten'] ??
                item['TenDangNhap'] ??
                item['ten_dang_nhap'] ??
                'Người dùng')
            .toString();
    final bool online = _isUserOnline(item);
    final bool isRemoving = _removingFriendIds.contains(userId);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.only(
          left: 14,
          right: 8,
          top: 4,
          bottom: 4,
        ),
        leading: _buildAvatarWithStatus(online),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          online ? 'online' : 'offline',
          style: TextStyle(
            fontSize: 12,
            color: online ? const Color(0xFF16A34A) : const Color(0xFF64748B),
            fontWeight: online ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: isRemoving || userId <= 0
                  ? null
                  : () => _handleUnfriend(userId, name),
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: isRemoving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.redAccent,
                      ),
                    )
                  : const Icon(Icons.person_remove_outlined, size: 18),
              label: const Text(
                'Hủy kết bạn',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
          ],
        ),
        onTap: () => _openProfile(
          userId,
          initialName: name,
          isFriend: true,
          initialOnline: online,
        ),
      ),
    );
  }

  Widget _buildRequestCard(dynamic rawItem) {
    final item = _unwrapUserMap(rawItem);
    final int userId = _extractUserId(item);
    final String name =
        (item['HoTen'] ??
                item['ho_ten'] ??
                item['TenDangNhap'] ??
                item['ten_dang_nhap'] ??
                'Người dùng')
            .toString();

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF1D5CE5),
          child: Icon(Icons.person, color: Colors.white),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        subtitle: const Text(
          'Lời mời kết bạn',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              tooltip: 'Chấp nhận',
              onPressed: () => _handleRespond(item, true),
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.redAccent),
              tooltip: 'Từ chối',
              onPressed: () => _handleRespond(item, false),
            ),
          ],
        ),
        onTap: () => _openProfile(userId, initialName: name, isFriend: false),
      ),
    );
  }

  Widget _buildSearchResultCard(dynamic rawItem) {
    final item = _unwrapUserMap(rawItem);
    final int userId = _extractUserId(item);
    final String name =
        (item['HoTen'] ??
                item['ho_ten'] ??
                item['TenDangNhap'] ??
                item['ten_dang_nhap'] ??
                'Người dùng')
            .toString();
    final String username = (item['TenDangNhap'] ?? item['ten_dang_nhap'] ?? '')
        .toString();
    final bool online = _isUserOnline(item);
    final bool isSent = _sentUserIds.contains(userId);
    final bool isSending = _sendingUserIds.contains(userId);
    final bool isCanceling = _cancelingUserIds.contains(userId);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: _buildAvatarWithStatus(online),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          username.isNotEmpty
              ? '@$username · ${online ? 'online' : 'offline'}'
              : (online ? 'online' : 'offline'),
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        trailing: isSent
            ? OutlinedButton(
                onPressed: isCanceling || userId <= 0
                    ? null
                    : () => _handleCancelSentRequest(userId, name),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: isCanceling
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.redAccent,
                        ),
                      )
                    : const Text('Hủy lời mời', style: TextStyle(fontSize: 12)),
              )
            : ElevatedButton(
                onPressed: isSending || userId <= 0
                    ? null
                    : () => _handleSendRequest(userId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Thêm'),
              ),
        onTap: () => _openProfile(
          userId,
          initialName: name,
          isFriend: false,
          initialOnline: online,
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: _performSearch,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Tìm tên hoặc tên đăng nhập để kết bạn...',
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF1E3A8A)),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF64748B)),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                ),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: Color(0xFF1E3A8A)),
                tooltip: 'Tìm kiếm',
                onPressed: () => _performSearch(_searchController.text),
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasNothing = _friends.isEmpty && _incomingRequests.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFEEF2FF),
      appBar: AppBar(
        title: const Text('Bạn bè'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSearchBox(),
                  const SizedBox(height: 12),
                  if (_searchQuery.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Gợi ý thí sinh',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                    if (_isSearching)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_searchResults.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Không tìm thấy thí sinh phù hợp.',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      )
                    else
                      ..._searchResults.map(
                        (user) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildSearchResultCard(user),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                  if (_error != null) ...[
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_incomingRequests.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Lời mời kết bạn',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                    ..._incomingRequests.map(
                      (req) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildRequestCard(req),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_friends.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Bạn bè',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                    ..._friends.map(
                      (friend) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildFriendCard(friend),
                      ),
                    ),
                  ] else if (hasNothing && _searchQuery.isEmpty) ...[
                    const SizedBox(height: 100),
                    const Center(
                      child: Text(
                        'Chưa có bạn bè hoặc lời mời kết bạn nào.',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class FriendProfileScreen extends StatefulWidget {
  final int targetUserId;
  final String? initialName;
  final bool isFriend;
  final bool? initialOnline;

  const FriendProfileScreen({
    super.key,
    required this.targetUserId,
    this.initialName,
    this.isFriend = false,
    this.initialOnline,
  });

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  final FriendService _friendService = FriendService();
  bool _isLoading = true;
  bool _isRemoving = false;
  String? _error;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Map<String, dynamic> _normalizeProfile(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    for (final key in ['data', 'profile', 'user', 'nguoi_dung', 'NguoiDung']) {
      final inner = map[key];
      if (inner is Map) {
        return {...Map<String, dynamic>.from(inner), ...map};
      }
    }
    return map;
  }

  bool _resolveOnline() {
    final p = _profile;
    if (p != null) {
      final raw =
          p['is_online'] ??
          p['IsOnline'] ??
          p['online'] ??
          p['Online'] ??
          p['TrangThaiOnline'] ??
          p['trang_thai_online'];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        final v = raw.trim().toLowerCase();
        if (v == 'true' || v == '1' || v == 'online' || v == 'dang_online') {
          return true;
        }
        if (v == 'false' || v == '0' || v == 'offline' || v == 'ngoai_tuyen') {
          return false;
        }
      }
    }
    return widget.initialOnline ?? false;
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _friendService.getFriendProfile(widget.targetUserId);
      if (mounted) {
        setState(() => _profile = _normalizeProfile(data));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUnfriendInProfile(String name) async {
    if (_isRemoving) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy kết bạn'),
        content: Text('Bạn có chắc muốn hủy kết bạn với "$name" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hủy kết bạn'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRemoving = true);
    try {
      await _friendService.unfriend(widget.targetUserId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Đã hủy kết bạn với $name.')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_cleanError(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _isRemoving = false);
      }
    }
  }

  String _cleanError(Object e) => e.toString().replaceFirst('Exception: ', '');

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'US';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts[parts.length - 2][0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hoTen =
        (_profile?['HoTen'] ??
                _profile?['ho_ten'] ??
                widget.initialName ??
                'Hồ sơ')
            .toString();
    final username =
        (_profile?['TenDangNhap'] ?? _profile?['ten_dang_nhap'] ?? '')
            .toString();
    final tenHang = (_profile?['TenHang'] ?? _profile?['ten_hang'] ?? 'Đồng')
        .toString();
    final soCup =
        _profile?['SoCupHienTai'] ?? _profile?['so_cup_hien_tai'] ?? 0;
    final soTranThang =
        _profile?['SoTranThang'] ?? _profile?['so_tran_thang'] ?? 0;
    final diemTrungBinh =
        _profile?['DiemTrungBinh'] ?? _profile?['diem_trung_binh'];
    final avatarUrl = (_profile?['AnhDaiDien'] ?? _profile?['anh_dai_dien'])
        ?.toString();
    final hasImg = avatarUrl != null && avatarUrl.trim().isNotEmpty;
    final online = _resolveOnline();

    return Scaffold(
      appBar: AppBar(title: Text(hoTen)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadProfile,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: const Color(0xFF1D5CE5),
                      backgroundImage: hasImg ? NetworkImage(avatarUrl) : null,
                      child: !hasImg
                          ? Text(
                              _getInitials(hoTen),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      hoTen,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      online ? 'online' : 'offline',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: online
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  if (username.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        '@$username',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text(
                              'Hạng',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tenHang,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text(
                              'Số cúp',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$soCup',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text(
                              'Thắng',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$soTranThang',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (diemTrungBinh != null)
                          Column(
                            children: [
                              const Text(
                                'Điểm TB',
                                style: TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$diemTrungBinh',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (widget.isFriend) ...[
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _isRemoving
                          ? null
                          : () => _handleUnfriendInProfile(hoTen),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _isRemoving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.redAccent,
                              ),
                            )
                          : const Icon(Icons.person_remove_outlined),
                      label: const Text('Hủy kết bạn'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
