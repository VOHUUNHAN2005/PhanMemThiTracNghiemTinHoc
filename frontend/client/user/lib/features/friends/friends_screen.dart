import 'dart:async';
import 'package:flutter/material.dart';
import 'package:user/core/services/friend_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FriendService _friendService = FriendService();
  final TextEditingController _timCtrl = TextEditingController();
  Timer? _debounce;

  bool _isLoading = false;
  bool _isSearching = false;
  List _searchResults = [];
  List _incomingRequests = [];
  List _outgoingRequests = [];
  List _friends = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _timCtrl.dispose();
    super.dispose();
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg.replaceFirst('Exception: ', '')),
        backgroundColor: isError ? Colors.red : Colors.green.shade700,
      ),
    );
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _friendService.getFriendRequests(),
        _friendService.getFriends(),
      ]);
      final reqData = results[0] as Map;
      final friendList = List.from(results[1] as List);

      if (mounted) {
        setState(() {
          _incomingRequests = List.from(reqData['incoming'] ?? []);
          _outgoingRequests = List.from(reqData['outgoing'] ?? []);
          _friends = friendList;
        });
      }
    } catch (e) {
      _showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    setState(() {});

    if (val.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      try {
        final list = await _friendService.searchUsers(val);
        if (mounted) {
          setState(() => _searchResults = List.from(list));
        }
      } catch (e) {
        _showSnackBar(e.toString(), isError: true);
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  Future<void> _handleSendRequest(int targetId) async {
    try {
      await _friendService.sendRequest(targetId);
      _showSnackBar('Đã gửi lời mời kết bạn!');
      await _loadAllData();
      if (_timCtrl.text.trim().isNotEmpty) {
        _onSearchChanged(_timCtrl.text);
      }
    } catch (e) {
      _showSnackBar(e.toString(), isError: true);
    }
  }

  Future<void> _handleRespond(int maKetBan, bool chapNhan) async {
    try {
      await _friendService.respondRequest(
        maKetBan: maKetBan,
        chapNhan: chapNhan,
      );
      _showSnackBar(
        chapNhan ? 'Đã chấp nhận lời mời kết bạn!' : 'Đã từ chối lời mời.',
      );
      await _loadAllData();
    } catch (e) {
      _showSnackBar(e.toString(), isError: true);
    }
  }

  Future<void> _handleCancelSent(int targetUserId) async {
    try {
      await _friendService.cancelSentRequest(targetUserId);
      _showSnackBar('Đã hủy lời mời kết bạn.');
      await _loadAllData();
    } catch (e) {
      _showSnackBar(e.toString(), isError: true);
    }
  }

  Future<void> _handleUnfriend(int friendUserId, String hoTen) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy kết bạn'),
        content: Text('Bạn có chắc muốn hủy kết bạn với $hoTen không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Đóng'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hủy kết bạn',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _friendService.unfriend(friendUserId);
      _showSnackBar('Đã hủy kết bạn.');
      await _loadAllData();
    } catch (e) {
      _showSnackBar(e.toString(), isError: true);
    }
  }

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

  Widget _buildUserAvatar(String hoTen, String? avatarUrl) {
    final hasImg = avatarUrl != null && avatarUrl.isNotEmpty;
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFF1D5CE5),
      backgroundImage: hasImg ? NetworkImage(avatarUrl) : null,
      child: !hasImg
          ? Text(
              _getInitials(hoTen),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasRequests =
        _incomingRequests.isNotEmpty || _outgoingRequests.isNotEmpty;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 105),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bạn bè',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _timCtrl,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Tìm theo username, họ tên hoặc email',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _timCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _timCtrl.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_isSearching)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_searchResults.isNotEmpty) ...[
                    const Text(
                      'Kết quả tìm kiếm',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ..._searchResults.map((user) {
                      final String hoTen = user['HoTen'] ?? '';
                      final String username = user['TenDangNhap'] ?? '';
                      final String tenHang = user['TenHang'] ?? 'Đồng';
                      final int soCup = user['SoCupHienTai'] ?? 0;
                      final String quanHe = user['QuanHe'] ?? 'CHUA_KET_BAN';

                      Widget actionBtn;
                      if (quanHe == 'BAN_BE') {
                        actionBtn = Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Bạn bè',
                            style: TextStyle(
                              color: Color(0xFF065F46),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        );
                      } else if (quanHe == 'DA_GUI_LOI_MOI') {
                        actionBtn = ElevatedButton(
                          onPressed: () =>
                              _handleCancelSent(user['MaNguoiDung']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFEE2E2),
                            foregroundColor: const Color(0xFFB91C1C),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Hủy lời mời',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      } else if (quanHe == 'CHO_MINH_DUYET' &&
                          user['MaKetBan'] != null) {
                        actionBtn = ElevatedButton(
                          onPressed: () =>
                              _handleRespond(user['MaKetBan'], true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD1FAE5),
                            foregroundColor: const Color(0xFF065F46),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Chấp nhận',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      } else {
                        actionBtn = ElevatedButton(
                          onPressed: () =>
                              _handleSendRequest(user['MaNguoiDung']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDBEAFE),
                            foregroundColor: const Color(0xFF1D5CE5),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Kết bạn',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            _buildUserAvatar(hoTen, user['AnhDaiDien']),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hoTen,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15.5,
                                    ),
                                  ),
                                  Text(
                                    '@$username • Hạng $tenHang • $soCup cúp',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            actionBtn,
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                  ],
                  if (hasRequests) ...[
                    const Text(
                      'Lời mời kết bạn',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ..._incomingRequests.map((req) {
                      final u = req['NguoiDung'] ?? {};
                      final String hoTen = u['HoTen'] ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            _buildUserAvatar(hoTen, u['AnhDaiDien']),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hoTen,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    'Lời mời đến',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  _handleRespond(req['MaKetBan'], true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD1FAE5),
                                foregroundColor: const Color(0xFF065F46),
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                              ),
                              child: const Text(
                                'Chấp nhận',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            ElevatedButton(
                              onPressed: () =>
                                  _handleRespond(req['MaKetBan'], false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFEE2E2),
                                foregroundColor: const Color(0xFFB91C1C),
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                              ),
                              child: const Text(
                                'Từ chối',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    ..._outgoingRequests.map((req) {
                      final u = req['NguoiDung'] ?? {};
                      final String hoTen = u['HoTen'] ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            _buildUserAvatar(hoTen, u['AnhDaiDien']),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hoTen,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    'Lời mời đã gửi',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  _handleCancelSent(u['MaNguoiDung']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFEE2E2),
                                foregroundColor: const Color(0xFFB91C1C),
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              child: const Text(
                                'Hủy lời mời',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    'Danh sách bạn bè (${_friends.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_isLoading && _friends.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_friends.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Center(
                        child: Text(
                          'Bạn chưa có bạn bè nào. Hãy tìm kiếm và kết bạn!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ..._friends.map((f) {
                      final String hoTen = f['HoTen'] ?? '';
                      final String tenHang = f['TenHang'] ?? 'Đồng';
                      final bool isOnline = f['TrangThaiOnline'] == true ||
                          f['TrangThaiOnline'] == 1;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            _buildUserAvatar(hoTen, f['AnhDaiDien']),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hoTen,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    isOnline
                                        ? 'Online • Hạng $tenHang'
                                        : 'Offline • Hạng $tenHang',
                                    style: TextStyle(
                                      color:
                                          isOnline ? Colors.green : Colors.grey,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Hủy kết bạn',
                              onPressed: () =>
                                  _handleUnfriend(f['MaNguoiDung'], hoTen),
                              icon: const Icon(
                                Icons.person_remove_outlined,
                                color: Color(0xFFB91C1C),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}