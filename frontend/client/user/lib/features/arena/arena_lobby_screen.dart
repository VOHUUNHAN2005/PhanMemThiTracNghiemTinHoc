import 'dart:async';
import 'package:flutter/material.dart';
import 'package:user/core/services/arena_service.dart';
import 'package:user/features/arena/arena_match_screen.dart';
import 'package:user/features/arena/arena_waiting_room_screen.dart';

typedef JsonMap = Map<String, dynamic>;

class ArenaLobbyScreen extends StatefulWidget {
  const ArenaLobbyScreen({super.key});

  @override
  State<ArenaLobbyScreen> createState() => _ArenaLobbyScreenState();
}

class _ArenaLobbyScreenState extends State<ArenaLobbyScreen> {
  final TextEditingController _roomCodeController = TextEditingController();
  int _selectedMode = 0; // 0: Đối kháng 1vs1, 1: Giải đấu Phòng

  List<JsonMap> _topics = [];
  List<JsonMap> _openRooms = [];
  final Map<int, JsonMap> _tournamentMetaByRoomId = {};
  bool _isLoadingTopics = true;
  bool _isLoadingRooms = false;
  bool _isSearchingRandom = false;
  bool _isShowingInviteDialog = false;

  StreamSubscription<JsonMap>? _wsSub;
  Timer? _roomsRefreshTimer;

  @override
  void initState() {
    super.initState();
    _initArena();
  }

  Future<void> _initArena() async {
    await ArenaService.ensureConnected();
    _listenWebSocket();
    await Future.wait([
      _loadTopics(),
      _loadOpenRooms(),
    ]);
    _roomsRefreshTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _loadOpenRooms(),
    );
  }

  void _listenWebSocket() {
    _wsSub?.cancel();
    _wsSub = ArenaService.events.listen((msg) {
      if (!mounted) return;
      final event = msg['event']?.toString() ?? '';
      final data = (msg['data'] is Map)
          ? JsonMap.from(msg['data'])
          : <String, dynamic>{};

      if (event == 'SEARCHING_1VS1') {
        setState(() => _isSearchingRandom = true);
      } else if (event == 'SEARCH_1VS1_CANCELLED') {
        setState(() => _isSearchingRandom = false);
      } else if (event == 'MATCH_COUNTDOWN' && _isSearchingRandom) {
        setState(() => _isSearchingRandom = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArenaMatchScreen(
              maPhong: int.tryParse((data['MaPhong'] ?? 0).toString()) ?? 0,
              isTournament: data['LoaiPhong'] == 'GIAI_DAU_NN',
              tenChuDe: (data['TenChuDe'] ?? 'Đối kháng 1vs1').toString(),
              initialCountdownData: data,
            ),
          ),
        );
      } else if (event == 'ROOM_INVITE_RECEIVED' && !_isShowingInviteDialog) {
        _showInviteDialog(data);
      } else if (event == 'ERROR') {
        if (_isSearchingRandom) {
          setState(() => _isSearchingRandom = false);
        }
        final text = (data['message'] ?? 'Có lỗi xảy ra').toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text), backgroundColor: Colors.redAccent),
        );
      }
    });
  }

  void _showInviteDialog(JsonMap inv) {
    _isShowingInviteDialog = true;
    final nguoiMoi = (inv['NguoiMoi'] is Map)
        ? JsonMap.from(inv['NguoiMoi'])
        : <String, dynamic>{};
    final String fromName = (nguoiMoi['HoTen'] ?? 'Một người chơi').toString();
    final String code = (inv['MaCodePhong'] ?? '').toString();
    final String tenChuDe = (inv['TenChuDe'] ?? '').toString();
    final bool isTourney = inv['LoaiPhong'] == 'GIAI_DAU_NN';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          isTourney ? 'Lời mời tham gia Giải đấu' : 'Lời mời thách đấu 1vs1',
        ),
        content: Text(
          '$fromName mời bạn vào phòng $code ($tenChuDe)',
        ),
        actions: [
          TextButton(
            onPressed: () {
              _isShowingInviteDialog = false;
              Navigator.pop(ctx);
            },
            child: const Text('Từ chối', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              _isShowingInviteDialog = false;
              Navigator.pop(ctx);
              try {
                final lobby = await ArenaService.joinRoom(
                  maPhong: int.tryParse((inv['MaPhong'] ?? 0).toString()),
                  matKhauPhong: inv['MatKhauPhong']?.toString(),
                );
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ArenaWaitingRoomScreen(initialLobby: lobby),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Chấp nhận'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadTopics() async {
    final data = await ArenaService.getArenaTopics();
    if (!mounted) return;
    setState(() {
      _topics = data;
      _isLoadingTopics = false;
    });
  }

  Future<void> _loadOpenRooms() async {
    if (_isLoadingRooms) return;
    _isLoadingRooms = true;
    final rooms = await ArenaService.getOpenRooms(loaiPhong: 'GIAI_DAU_NN');
    _isLoadingRooms = false;
    if (!mounted) return;
    setState(() => _openRooms = rooms);
  }

  @override
  void dispose() {
    _roomsRefreshTimer?.cancel();
    _wsSub?.cancel();
    if (_isSearchingRandom) {
      ArenaService.sendAction('CANCEL_FIND_1VS1');
    }
    _roomCodeController.dispose();
    super.dispose();
  }

  void _showTopicPicker({
    required bool isRandomMatchmaking,
  }) {
    final pwdController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Chọn Chủ đề thi đấu',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isRandomMatchmaking
                                  ? 'Chế độ 1vs1: 20 câu • Thắng +50 Cúp'
                                  : 'Tạo phòng 1vs1 riêng & mời bạn bè',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF64748B),
                        ),
                        tooltip: 'Đóng',
                      ),
                    ],
                  ),
                  if (!isRandomMatchmaking) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: pwdController,
                      decoration: InputDecoration(
                        hintText: 'Mật khẩu phòng (để trống nếu công khai)',
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (_isLoadingTopics)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_topics.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Chưa có chủ đề nào khả dụng từ máy chủ.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 330),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _topics.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final topic = _topics[index];
                          final int maChuDe =
                              int.tryParse((topic['ma_chu_de'] ?? 0).toString()) ??
                                  0;
                          final String tenChuDe =
                              (topic['ten_chu_de'] ?? '').toString();

                          return Material(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                Navigator.pop(ctx);
                                if (isRandomMatchmaking) {
                                  setState(() => _isSearchingRandom = true);
                                  await ArenaService.sendAction(
                                    'FIND_1VS1',
                                    {'MaChuDe': maChuDe},
                                  );
                                } else {
                                  try {
                                    final lobby = await ArenaService.createRoom(
                                      loaiPhong: 'DOI_KHANG_1VS1',
                                      maChuDe: maChuDe,
                                      matKhauPhong: pwdController.text,
                                    );
                                    if (!mounted) return;
                                    Navigator.push(
                                      this.context,
                                      MaterialPageRoute(
                                        builder: (_) => ArenaWaitingRoomScreen(
                                          initialLobby: lobby,
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(this.context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          e.toString().replaceFirst(
                                                'Exception: ',
                                                '',
                                              ),
                                        ),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Color(0xFFDBEAFE),
                                      child: Icon(
                                        Icons.folder_rounded,
                                        color: Color(0xFF1D4ED8),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        tenChuDe,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14.5,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 15,
                                      color: Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreateTournamentModal() async {
    if (_topics.isEmpty && !_isLoadingTopics) {
      await _loadTopics();
    }
    if (!mounted) return;

    final titleController = TextEditingController();
    final passwordController = TextEditingController();
    final rulesController = TextEditingController();

    int selectedTopicId = _topics.isNotEmpty
        ? (int.tryParse((_topics.first['ma_chu_de'] ?? 0).toString()) ?? 0)
        : 0;
    String visibilityMode = 'PUBLIC'; // PUBLIC | PRIVATE
    String? errorText;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.white,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460, maxHeight: 680),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.emoji_events_rounded,
                              color: Color(0xFF6D28D9),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tạo Phòng Giải Đấu (50 Câu)',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  '50 câu ngẫu nhiên • 15–30s/câu • Top 1 (+100 Cúp)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.pop(ctx),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: titleController,
                              decoration: InputDecoration(
                                labelText:
                                    'Tên giải đấu * (Tối thiểu 3 ký tự)',
                                hintText: 'VD: Giải đấu Tin học Văn phòng mở rộng',
                                prefixIcon: const Icon(
                                  Icons.title_rounded,
                                  size: 20,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Chủ đề thi đấu (Yêu cầu kho >= 50 câu hoạt động)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (_isLoadingTopics)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            else if (_topics.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Chưa tải được danh sách chủ đề từ máy chủ.',
                                  style: TextStyle(
                                    color: Color(0xFFB91C1C),
                                    fontSize: 12.5,
                                  ),
                                ),
                              )
                            else
                              DropdownButtonFormField<int>(
                                initialValue: selectedTopicId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                ),
                                items: _topics.map((t) {
                                  final id = int.tryParse(
                                          (t['ma_chu_de'] ?? 0).toString()) ??
                                      0;
                                  final name = (t['ten_chu_de'] ?? '').toString();
                                  return DropdownMenuItem<int>(
                                    value: id,
                                    child: Text(
                                      name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setModalState(() => selectedTopicId = val);
                                  }
                                },
                              ),
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFC7D2FE),
                                ),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Thể lệ Giải đấu chuẩn:',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '• Bộ đề 50 câu hỏi độc lập (15s Dễ / 20s TB / 30s Khó).\n'
                                    '• Hoàn thành > 30% (>= 16 câu) để nhận Cúp: Top 1 (+100), Top 2 (+70), Top 3 (+50), Top 4+ (+25).',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF334155),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Chế độ phòng thi đấu',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: visibilityMode,
                              isExpanded: true,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'PUBLIC',
                                  child: Text(
                                    'Công khai (Ai có mã / mở phòng đều vào được)',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'PRIVATE',
                                  child: Text(
                                    'Riêng tư (Yêu cầu mật khẩu phòng)',
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() => visibilityMode = val);
                                }
                              },
                            ),
                            if (visibilityMode == 'PRIVATE') ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: passwordController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: 'Mật khẩu phòng *',
                                  hintText: 'Nhập mật khẩu để vào phòng',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 20,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            TextField(
                              controller: rulesController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Ghi chú / Quy chế thêm (tùy chọn)',
                                hintText: 'VD: Dành cho nhóm lớp CNTT K20',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                            ),
                            if (errorText != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  errorText!,
                                  style: const TextStyle(
                                    color: Color(0xFFB91C1C),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.pop(ctx),
                            child: const Text('Hủy'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    final title = titleController.text.trim();
                                    if (title.length < 3) {
                                      setModalState(() {
                                        errorText =
                                            'Vui lòng nhập tên giải đấu tối thiểu 3 ký tự.';
                                      });
                                      return;
                                    }
                                    if (selectedTopicId <= 0) {
                                      setModalState(() {
                                        errorText =
                                            'Vui lòng chọn chủ đề thi đấu.';
                                      });
                                      return;
                                    }
                                    final pwd = passwordController.text.trim();
                                    if (visibilityMode == 'PRIVATE' &&
                                        pwd.isEmpty) {
                                      setModalState(() {
                                        errorText =
                                            'Vui lòng nhập mật khẩu cho phòng riêng tư.';
                                      });
                                      return;
                                    }

                                    setModalState(() {
                                      isSubmitting = true;
                                      errorText = null;
                                    });

                                    try {
                                      final lobby =
                                          await ArenaService.createRoom(
                                        loaiPhong: 'GIAI_DAU_NN',
                                        maChuDe: selectedTopicId,
                                        matKhauPhong:
                                            visibilityMode == 'PRIVATE'
                                                ? pwd
                                                : null,
                                      );

                                      final roomId = int.tryParse(
                                            (lobby['MaPhong'] ??
                                                    lobby['maPhong'] ??
                                                    0)
                                                .toString(),
                                          ) ??
                                          0;

                                      final meta = <String, dynamic>{
                                        'tenGiaiDau': title,
                                        'soCau': 50,
                                        'quyChe': rulesController.text.trim(),
                                      };

                                      if (roomId > 0 && mounted) {
                                        setState(() {
                                          _tournamentMetaByRoomId[roomId] =
                                              meta;
                                        });
                                      }

                                      final enrichedLobby = <String, dynamic>{
                                        ...lobby,
                                        'TenGiaiDau': title,
                                        'SoCau': 50,
                                        'QuyChe': rulesController.text.trim(),
                                      };

                                      if (!ctx.mounted) return;
                                      Navigator.pop(ctx);

                                      if (!mounted) return;
                                      Navigator.push(
                                        this.context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ArenaWaitingRoomScreen(
                                            initialLobby: enrichedLobby,
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      setModalState(() {
                                        isSubmitting = false;
                                        errorText = e
                                            .toString()
                                            .replaceFirst('Exception: ', '');
                                      });
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Tạo giải đấu',
                                    style: TextStyle(fontWeight: FontWeight.w800),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleJoinByCodeOrRoom({
    int? maPhong,
    String? maCodePhong,
    bool hasPassword = false,
  }) async {
    String? pwd;
    if (hasPassword) {
      pwd = await _askPasswordDialog();
      if (pwd == null) return;
    }

    try {
      final lobby = await ArenaService.joinRoom(
        maPhong: maPhong,
        maCodePhong: maCodePhong,
        matKhauPhong: pwd,
      );
      if (!mounted) return;
      final resolvedId = maPhong ??
          int.tryParse((lobby['MaPhong'] ?? lobby['maPhong'] ?? 0).toString()) ??
          0;
      final extraMeta = _tournamentMetaByRoomId[resolvedId];
      final enrichedLobby = extraMeta != null
          ? <String, dynamic>{
              ...lobby,
              'TenGiaiDau': extraMeta['tenGiaiDau'],
              'SoCau': extraMeta['soCau'],
              'QuyChe': extraMeta['quyChe'],
            }
          : lobby;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArenaWaitingRoomScreen(initialLobby: enrichedLobby),
        ),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (!hasPassword && msg.toLowerCase().contains('mật khẩu') && mounted) {
        final retryPwd = await _askPasswordDialog();
        if (retryPwd != null && mounted) {
          try {
            final lobby = await ArenaService.joinRoom(
              maPhong: maPhong,
              maCodePhong: maCodePhong,
              matKhauPhong: retryPwd,
            );
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ArenaWaitingRoomScreen(initialLobby: lobby),
              ),
            );
            return;
          } catch (e2) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e2.toString().replaceFirst('Exception: ', '')),
                backgroundColor: Colors.redAccent,
              ),
            );
            return;
          }
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<String?> _askPasswordDialog() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Nhập mật khẩu phòng'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Mật khẩu phòng'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2FF),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 16,
                20,
                24,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF172554), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: Center(
                child: SizedBox(
                  width: 390,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.sports_esports_rounded,
                            color: Color(0xFFFBBF24),
                            size: 28,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Đấu Trường Trực Tuyến',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Thách đấu thời gian thực • Leo hạng & nhận Cúp thưởng',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildModeTab(
                                index: 0,
                                title: 'Đối kháng 1vs1',
                                subtitle: '20 câu • +50 Cúp',
                              ),
                            ),
                            Expanded(
                              child: _buildModeTab(
                                index: 1,
                                title: 'Giải đấu Phòng',
                                subtitle: '50 câu • Top 1 +100 Cúp',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Center(
                child: SizedBox(
                  width: 390,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildJoinByCodeCard(),
                      const SizedBox(height: 18),
                      if (_selectedMode == 0)
                        _build1vs1Section()
                      else
                        _buildTournamentSection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required int index,
    required String title,
    required String subtitle,
  }) {
    final bool isSelected = _selectedMode == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF1E3A8A) : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? const Color(0xFF2563EB) : Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinByCodeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vào nhanh bằng Mã phòng (6 ký tự)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _roomCodeController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'VD: A8K92P',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  final code = _roomCodeController.text.trim().toUpperCase();
                  if (code.length < 4) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng nhập mã phòng hợp lệ'),
                      ),
                    );
                    return;
                  }
                  _handleJoinByCodeOrRoom(maCodePhong: code);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Vào phòng',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _build1vs1Section() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFFFBBF24),
                  size: 36,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isSearchingRandom
                    ? 'Đang tìm đối thủ xứng tầm...'
                    : 'Ghép Đối Thủ Ngẫu Nhiên',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '20 câu hỏi • 15-30s/câu • Thắng nhận +50 Cúp',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (_isSearchingRandom) ...[
                const CircularProgressIndicator(color: Color(0xFFFBBF24)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      ArenaService.sendAction('CANCEL_FIND_1VS1');
                      setState(() => _isSearchingRandom = false);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'HỦY TÌM TRẬN',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showTopicPicker(
                      isRandomMatchmaking: true,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFBBF24),
                      foregroundColor: const Color(0xFF1E293B),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'TÌM TRẬN NGAY',
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showTopicPicker(
              isRandomMatchmaking: false,
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Tạo phòng 1vs1 riêng & Mời bạn bè'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E3A8A),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTournamentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showCreateTournamentModal,
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: const Text('Tạo Phòng Giải Đấu (50 Câu)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6D28D9),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Phòng Giải đấu đang mở',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            IconButton(
              onPressed: _loadOpenRooms,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Làm mới',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_openRooms.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Hiện chưa có phòng giải đấu nào đang chờ.\nHãy bấm nút phía trên để tạo phòng giải đấu mới!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          )
        else
          ..._openRooms.map((room) {
            final bool coMatKhau = room['CoMatKhau'] == true;
            final int maPhong =
                int.tryParse((room['MaPhong'] ?? 0).toString()) ?? 0;
            final String chuPhong = (room['ChuPhong'] ?? 'Chủ phòng').toString();
            final int soNguoi =
                int.tryParse((room['SoNguoiHienTai'] ?? 1).toString()) ?? 1;
            final extra = _tournamentMetaByRoomId[maPhong];
            final String displayTitle =
                (extra?['tenGiaiDau']?.toString().isNotEmpty == true)
                    ? extra!['tenGiaiDau'].toString()
                    : (room['TenChuDe'] ?? '').toString();
            final String topicName = (room['TenChuDe'] ?? '').toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: Color(0xFF6D28D9),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            if (coMatKhau) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.lock_rounded,
                                size: 15,
                                color: Color(0xFFD97706),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '50 câu • $topicName • Chủ phòng: $chuPhong • $soNguoi người đang chờ',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => _handleJoinByCodeOrRoom(
                      maPhong: maPhong,
                      hasPassword: coMatKhau,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6D28D9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Vào',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}