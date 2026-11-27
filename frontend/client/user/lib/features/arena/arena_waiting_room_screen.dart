import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:user/core/services/arena_service.dart';
import 'package:user/features/arena/arena_match_screen.dart';

typedef JsonMap = Map<String, dynamic>;

class ArenaWaitingRoomScreen extends StatefulWidget {
  final JsonMap initialLobby;

  const ArenaWaitingRoomScreen({
    super.key,
    required this.initialLobby,
  });

  @override
  State<ArenaWaitingRoomScreen> createState() => _ArenaWaitingRoomScreenState();
}

class _ArenaWaitingRoomScreenState extends State<ArenaWaitingRoomScreen> {
  late JsonMap _lobby;
  StreamSubscription<JsonMap>? _wsSub;
  int _myId = 0;
  bool _hasNavigated = false;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _lobby = JsonMap.from(widget.initialLobby);
    _initUserAndSocket();
  }

  Future<void> _initUserAndSocket() async {
    await ArenaService.ensureConnected();
    final profile = await ArenaService.getCurrentUserProfile();
    if (!mounted) return;
    setState(() => _myId = profile['id'] ?? 0);

    _wsSub = ArenaService.events.listen((msg) {
      if (!mounted || _hasNavigated) return;
      final event = msg['event']?.toString() ?? '';
      final data =
          (msg['data'] is Map) ? JsonMap.from(msg['data']) : JsonMap();

      if (event == 'ROOM_LOBBY_UPDATED') {
        setState(() => _lobby = data);
      } else if (event == 'MATCH_COUNTDOWN') {
        _hasNavigated = true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ArenaMatchScreen(
              maPhong: int.tryParse(
                    (data['MaPhong'] ?? _lobby['MaPhong']).toString(),
                  ) ??
                  0,
              isTournament:
                  (data['LoaiPhong'] ?? _lobby['LoaiPhong']) == 'GIAI_DAU_NN',
              tenChuDe:
                  (data['TenChuDe'] ?? _lobby['TenChuDe'] ?? '').toString(),
              initialCountdownData: data,
            ),
          ),
        );
      } else if (event == 'KICKED_FROM_ROOM') {
        _hasNavigated = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn đã bị chủ phòng mời ra khỏi phòng.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        Navigator.pop(context);
      } else if (event == 'ROOM_CLOSED') {
        _hasNavigated = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text((data['message'] ?? 'Phòng đã đóng.').toString()),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      } else if (event == 'ERROR') {
        setState(() => _isStarting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text((data['message'] ?? 'Lỗi phòng chờ').toString()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    });
  }

  Future<void> _leaveRoom() async {
    if (!_hasNavigated) {
      await ArenaService.sendAction('LEAVE_ROOM');
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _showInviteFriendsSheet() async {
    final friends = await ArenaService.getRealFriends();
    if (!mounted) return;
    final String code = (_lobby['MaCodePhong'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Mời bạn bè vào phòng',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mã phòng: $code',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              if (friends.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Bạn chưa có bạn bè nào.\nHãy chia sẻ mã phòng 6 ký tự cho bạn bè nhập nhé!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: friends.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final f = friends[index];
                      final int friendId = f['maNguoiDung'] ?? 0;
                      final String friendName = f['hoTen'].toString();
                      final String friendRank = f['tenHang'].toString();
                      final bool isOnline = f['isOnline'] == true;

                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFDBEAFE),
                          child: Text(
                            friendName.isNotEmpty
                                ? friendName[0].toUpperCase()
                                : 'B',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                        title: Text(
                          friendName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Hạng: $friendRank • ${isOnline ? "Trực tuyến" : "Ngoại tuyến"}',
                        ),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            try {
                              await ArenaService.inviteFriend(friendId);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Đã gửi lời mời tới $friendName!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceFirst('Exception: ', ''),
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Mời'),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isTournament = _lobby['LoaiPhong'] == 'GIAI_DAU_NN';
    final String tenChuDe = (_lobby['TenChuDe'] ?? '').toString();
    final String maCodePhong = (_lobby['MaCodePhong'] ?? '').toString();
    final int maChuPhong =
        int.tryParse((_lobby['MaChuPhong'] ?? 0).toString()) ?? 0;
    final bool isHost = _myId != 0 && _myId == maChuPhong;
    final bool canStart = _lobby['DuDieuKienBatDau'] == true;
    final List players = (_lobby['NguoiChoi'] is List)
        ? List.from(_lobby['NguoiChoi'])
        : [];

    bool myReady = false;
    for (final p in players) {
      if (p is Map &&
          int.tryParse((p['MaNguoiDung'] ?? 0).toString()) == _myId) {
        myReady = p['SanSang'] == true;
        break;
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveRoom();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEEF2FF),
        appBar: AppBar(
          backgroundColor: const Color(0xFF172554),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _leaveRoom,
          ),
          title: Text(
            isTournament ? 'Phòng Chờ Giải Đấu' : 'Phòng Chờ 1vs1',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          actions: [
            if (isHost)
              IconButton(
                onPressed: _showInviteFriendsSheet,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                tooltip: 'Mời bạn bè',
              ),
          ],
        ),
        body: Center(
          child: SizedBox(
            width: 410,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        Text(
                          tenChuDe,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isTournament
                              ? '50 câu hỏi • Thi tốc độ độc lập'
                              : '20 câu hỏi • Đấu trực tiếp từng câu',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 14),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: maCodePhong));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Đã sao chép mã phòng: $maCodePhong'),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'MÃ PHÒNG: ',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  maCodePhong,
                                  style: const TextStyle(
                                    color: Color(0xFFFBBF24),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.copy_rounded,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Người chơi trong phòng (${players.length})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          canStart ? 'Sẵn sàng bắt đầu' : 'Đang chờ sẵn sàng',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: players.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final p = JsonMap.from(players[index]);
                        final int pid =
                            int.tryParse((p['MaNguoiDung'] ?? 0).toString()) ??
                                0;
                        final String name =
                            (p['HoTen'] ?? 'Người chơi').toString();
                        final String rank = (p['TenHang'] ?? 'Đồng').toString();
                        final bool isRoomHost = p['LaChuPhong'] == true;
                        final bool isReady = p['SanSang'] == true;
                        final bool isMe = pid == _myId;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: isMe
                                ? Border.all(
                                    color: const Color(0xFF2563EB),
                                    width: 1.5,
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: isRoomHost
                                    ? const Color(0xFFFEF3C7)
                                    : const Color(0xFFDBEAFE),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'P',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: isRoomHost
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF1D4ED8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            isMe ? '$name (Bạn)' : name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        if (isRoomHost) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Chủ phòng',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFB45309),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Hạng: $rank • ${p['SoCupHienTai'] ?? 0} Cúp',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isHost && !isMe)
                                IconButton(
                                  onPressed: () async {
                                    try {
                                      await ArenaService.kickPlayer(pid);
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            e.toString().replaceFirst(
                                                  'Exception: ',
                                                  '',
                                                ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.remove_circle_outline_rounded,
                                    color: Colors.redAccent,
                                  ),
                                  tooltip: 'Mời ra khỏi phòng',
                                ),
                              Icon(
                                isReady
                                    ? Icons.check_circle_rounded
                                    : Icons.hourglass_bottom_rounded,
                                color: isReady
                                    ? const Color(0xFF10B981)
                                    : Colors.orange,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (isHost)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _showInviteFriendsSheet,
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text('Mời bạn bè'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1E3A8A),
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (canStart && !_isStarting)
                                ? () {
                                    setState(() => _isStarting = true);
                                    ArenaService.sendAction('START_ROOM');
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade400,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              _isStarting
                                  ? 'ĐANG BẮT ĐẦU...'
                                  : (canStart
                                      ? 'BẮT ĐẦU TRẬN ĐẤU'
                                      : 'CHỜ NGƯỜI CHƠI SẴN SÀNG...'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          ArenaService.sendAction(
                            'SET_READY',
                            {'SanSang': !myReady},
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: myReady
                              ? const Color(0xFF64748B)
                              : const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          myReady ? 'HỦY SẴN SÀNG' : 'SẴN SÀNG THI ĐẤU',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}