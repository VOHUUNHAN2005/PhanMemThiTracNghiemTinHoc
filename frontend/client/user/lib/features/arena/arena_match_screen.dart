import 'dart:async';
import 'package:flutter/material.dart';
import 'package:user/core/services/arena_service.dart';
import 'package:user/core/widgets/question_image_box.dart';
import 'package:user/features/arena/arena_result_screen.dart';

typedef JsonMap = Map<String, dynamic>;

class ArenaMatchScreen extends StatefulWidget {
  final int maPhong;
  final bool isTournament;
  final String tenChuDe;
  final JsonMap? initialCountdownData;

  const ArenaMatchScreen({
    super.key,
    required this.maPhong,
    required this.isTournament,
    required this.tenChuDe,
    this.initialCountdownData,
  });

  @override
  State<ArenaMatchScreen> createState() => _ArenaMatchScreenState();
}

class _ArenaMatchScreenState extends State<ArenaMatchScreen>
    with WidgetsBindingObserver {
  StreamSubscription<JsonMap>? _wsSub;
  Timer? _timer;

  bool _isCountingDown = true;
  int _preMatchCountdown = 5;
  int _questionTimeLeft = 15;

  int _myUserId = 0;
  String _myPlayerName = 'Bạn';
  String _opponentName = 'Đối thủ';

  int _myCorrect = 0;
  int _myWrong = 0;
  int _opponentCorrect = 0;
  int _opponentWrong = 0;

  JsonMap? _currentQuestion;
  final Set<int> _selectedAnswerIds = {};
  List<int> _correctAnswerIds = [];
  bool _isLockedAnswer = false;
  bool _isWaitingOthersInTournament = false;
  String _waitingMessage = '';
  bool _hasFinished = false;

  List<JsonMap> _liveTournamentBoard = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initMatch();
  }

  Future<void> _initMatch() async {
    await ArenaService.ensureConnected();
    final profile = await ArenaService.getCurrentUserProfile();
    if (!mounted) return;

    final int myId = profile['id'] ?? 0;
    final String myName = (profile['name'] ?? 'Bạn').toString();

    String oppName = 'Đối thủ';
    int startSec = 5;
    if (widget.initialCountdownData != null) {
      startSec = int.tryParse(
            (widget.initialCountdownData!['CountdownSeconds'] ?? 5).toString(),
          ) ??
          5;
      final players = widget.initialCountdownData!['NguoiChoi'];
      if (players is List) {
        for (final p in players) {
          if (p is Map &&
              int.tryParse((p['MaNguoiDung'] ?? 0).toString()) != myId) {
            oppName = (p['HoTen'] ?? 'Đối thủ').toString();
            break;
          }
        }
      }
    }

    setState(() {
      _myUserId = myId;
      _myPlayerName = myName;
      _opponentName = oppName;
      _preMatchCountdown = startSec;
    });

    _startPreMatchCountdown();
    _listenWebSocket();
  }

  void _listenWebSocket() {
    _wsSub?.cancel();
    _wsSub = ArenaService.events.listen((msg) {
      if (!mounted || _hasFinished) return;
      final event = msg['event']?.toString() ?? '';
      final data =
          (msg['data'] is Map) ? JsonMap.from(msg['data']) : JsonMap();

      if (event == 'NEW_QUESTION') {
        _timer?.cancel();
        final int sec =
            int.tryParse((data['ThoiGianGiay'] ?? 15).toString()) ?? 15;
        setState(() {
          _isCountingDown = false;
          _isWaitingOthersInTournament = false;
          _currentQuestion = data;
          _selectedAnswerIds.clear();
          _correctAnswerIds = [];
          _isLockedAnswer = false;
          _questionTimeLeft = sec;
        });
        _startQuestionCountdown(sec);
      } else if (event == 'ANSWER_RESULT') {
        final List rawCorrect = data['DanhSachMaDapAnDung'] is List
            ? List.from(data['DanhSachMaDapAnDung'])
            : [];
        setState(() {
          _isLockedAnswer = true;
          _correctAnswerIds =
              rawCorrect.map((e) => int.tryParse(e.toString()) ?? 0).toList();
          _myCorrect =
              int.tryParse((data['SoCauDung'] ?? _myCorrect).toString()) ??
                  _myCorrect;
          _myWrong = int.tryParse((data['SoCauSai'] ?? _myWrong).toString()) ??
              _myWrong;
        });
      } else if (event == 'OPPONENT_SCORE_UPDATED') {
        setState(() {
          _opponentCorrect = int.tryParse(
                (data['SoCauDung'] ?? _opponentCorrect).toString(),
              ) ??
              _opponentCorrect;
          _opponentWrong =
              int.tryParse((data['SoCauSai'] ?? _opponentWrong).toString()) ??
                  _opponentWrong;
        });
      } else if (event == 'QUESTION_ENDED') {
        final List rawCorrect = data['DanhSachMaDapAnDung'] is List
            ? List.from(data['DanhSachMaDapAnDung'])
            : [];
        final List board = data['BangDiemHienTai'] is List
            ? List.from(data['BangDiemHienTai'])
            : [];
        int myC = _myCorrect;
        int myW = _myWrong;
        int oppC = _opponentCorrect;
        int oppW = _opponentWrong;

        for (final item in board) {
          if (item is Map) {
            final uid = int.tryParse((item['MaNguoiDung'] ?? 0).toString()) ?? 0;
            if (uid == _myUserId) {
              myC = int.tryParse((item['SoCauDung'] ?? myC).toString()) ?? myC;
              myW = int.tryParse((item['SoCauSai'] ?? myW).toString()) ?? myW;
            } else {
              oppC =
                  int.tryParse((item['SoCauDung'] ?? oppC).toString()) ?? oppC;
              oppW = int.tryParse((item['SoCauSai'] ?? oppW).toString()) ?? oppW;
            }
          }
        }

        setState(() {
          _isLockedAnswer = true;
          _correctAnswerIds =
              rawCorrect.map((e) => int.tryParse(e.toString()) ?? 0).toList();
          _myCorrect = myC;
          _myWrong = myW;
          _opponentCorrect = oppC;
          _opponentWrong = oppW;
        });
      } else if (event == 'TOURNAMENT_LIVE_BOARD') {
        final List rawBoard = data['BangXepHang'] is List
            ? List.from(data['BangXepHang'])
            : [];
        final List<JsonMap> parsed = [];
        for (final e in rawBoard) {
          if (e is Map) {
            parsed.add(JsonMap.from(e));
          }
        }
        for (final row in parsed) {
          if (int.tryParse((row['MaNguoiDung'] ?? 0).toString()) == _myUserId) {
            _myCorrect =
                int.tryParse((row['SoCauDung'] ?? _myCorrect).toString()) ??
                    _myCorrect;
            final daLam = int.tryParse((row['DaLam'] ?? 0).toString()) ?? 0;
            _myWrong = (daLam - _myCorrect).clamp(0, 999);
          }
        }
        setState(() => _liveTournamentBoard = parsed);
      } else if (event == 'PLAYER_COMPLETED_ALL') {
        _timer?.cancel();
        setState(() {
          _isWaitingOthersInTournament = true;
          _waitingMessage = (data['ThongBao'] ??
                  'Bạn đã hoàn thành 50 câu! Đang chờ các thí sinh khác...')
              .toString();
          _myCorrect =
              int.tryParse((data['SoCauDung'] ?? _myCorrect).toString()) ??
                  _myCorrect;
          _myWrong = int.tryParse((data['SoCauSai'] ?? _myWrong).toString()) ??
              _myWrong;
        });
      } else if (event == 'MATCH_FINISHED') {
        _hasFinished = true;
        _timer?.cancel();
        final int resolvedPhong =
            int.tryParse((data['MaPhong'] ?? widget.maPhong).toString()) ??
                widget.maPhong;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ArenaResultScreen(
              maPhong: resolvedPhong,
              isTournament: widget.isTournament,
              tenChuDe: widget.tenChuDe,
              myUserId: _myUserId,
              matchResultData: data,
            ),
          ),
        );
      } else if (event == 'ACCOUNT_LOCKED_CHEAT') {
        _hasFinished = true;
        _timer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (data['message'] ?? 'Tài khoản bị khóa do vi phạm quy chế!')
                  .toString(),
            ),
            backgroundColor: Colors.red.shade900,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  void _startPreMatchCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_preMatchCountdown > 1) {
        setState(() => _preMatchCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  void _startQuestionCountdown(int seconds) {
    _timer?.cancel();
    _questionTimeLeft = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_questionTimeLeft > 1) {
        setState(() => _questionTimeLeft--);
      } else {
        timer.cancel();
        setState(() => _isLockedAnswer = true);
      }
    });
  }

  Future<void> _submitAnswer(List<int> answerIds) async {
    if (_isLockedAnswer || _currentQuestion == null) return;
    final int maCauHoi =
        int.tryParse((_currentQuestion!['MaCauHoi'] ?? 0).toString()) ?? 0;
    if (maCauHoi <= 0) return;

    setState(() => _isLockedAnswer = true);
    await ArenaService.sendAction('SUBMIT_ANSWER', {
      'MaCauHoi': maCauHoi,
      'DanhSachMaDapAn': answerIds,
    });
  }

  Future<void> _confirmForfeit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Xác nhận rời trận?'),
        content: const Text(
          'Nếu rời trận giữa chừng, bạn sẽ bị xử thua (0 Cúp). Bạn có chắc chắn muốn thoát?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tiếp tục thi'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Bỏ cuộc'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ArenaService.sendAction('LEAVE_ROOM');
      if (mounted && !_hasFinished) {
        _hasFinished = true;
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_hasFinished &&
        !_isCountingDown &&
        state == AppLifecycleState.paused) {
      ArenaService.sendAction('CHEAT_DETECTED', {
        'LyDo': 'Thí sinh thoát/chuyển ứng dụng khi đang thi đấu',
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _wsSub?.cancel();
    super.dispose();
  }

  void _showLiveLeaderboardSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bảng xếp hạng trực tiếp (Live)',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (_liveTournamentBoard.isEmpty)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFBBF24),
                  child: Text('1'),
                ),
                title: Text(
                  '$_myPlayerName (Bạn)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: Text(
                  '$_myCorrect đúng',
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _liveTournamentBoard.length,
                  itemBuilder: (_, idx) {
                    final p = _liveTournamentBoard[idx];
                    final bool isMe =
                        int.tryParse((p['MaNguoiDung'] ?? 0).toString()) ==
                            _myUserId;
                    final String pName = (p['HoTen'] ?? 'Thí sinh').toString();
                    final int pCorrect =
                        int.tryParse((p['SoCauDung'] ?? 0).toString()) ?? 0;
                    final int daLam =
                        int.tryParse((p['DaLam'] ?? 0).toString()) ?? 0;
                    final int tong =
                        int.tryParse((p['TongSoCau'] ?? 50).toString()) ?? 50;
                    final int timeMs = int.tryParse(
                          (p['TongThoiGianTraLoiMs'] ?? 0).toString(),
                        ) ??
                        0;
                    final String timeSec = (timeMs / 1000.0).toStringAsFixed(1);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: idx == 0
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFFE2E8F0),
                        child: Text('${p['ThuHangTamThoi'] ?? idx + 1}'),
                      ),
                      title: Text(
                        isMe ? '$pName (Bạn)' : pName,
                        style: TextStyle(
                          fontWeight:
                              isMe ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        'Tiến độ: $daLam/$tong câu • Thời gian: ${timeSec}s',
                      ),
                      trailing: Text(
                        '$pCorrect đúng',
                        style: const TextStyle(
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmForfeit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEEF2FF),
        body: _isCountingDown ? _buildPreMatchView() : _buildBattleView(),
      ),
    );
  }

  Widget _buildPreMatchView() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF172554), Color(0xFF1E3A8A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'TRẬN ĐẤU SẮP BẮT ĐẦU',
            style: TextStyle(
              color: Color(0xFFFBBF24),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.tenChuDe,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 36),
          Container(
            width: 120,
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(color: const Color(0xFFFBBF24), width: 3),
            ),
            child: Text(
              '$_preMatchCountdown',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 54,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 36),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Lưu ý: Không thoát ứng dụng hoặc chuyển cửa sổ trong suốt quá trình thi đấu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattleView() {
    if (_isWaitingOthersInTournament) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  _waitingMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Đáp án sẽ được mở khóa ngay khi toàn bộ thí sinh hoàn thành.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _showLiveLeaderboardSheet,
                  icon: const Icon(Icons.leaderboard_rounded),
                  label: const Text('Xem Bảng xếp hạng trực tiếp'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_currentQuestion == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final q = _currentQuestion!;
    final int thuTuCau = int.tryParse((q['ThuTuCau'] ?? 1).toString()) ?? 1;
    final int tongSoCau = int.tryParse((q['TongSoCau'] ?? 50).toString()) ?? 50;
    final String noiDung = (q['NoiDung'] ?? '').toString();
    final bool multiChoice = q['ChoPhepNhieuDapAn'] == true;
    final List options = q['DapAn'] is List ? List.from(q['DapAn']) : [];

    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: Color(0xFF172554),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: widget.isTournament
                ? _buildTournamentTopBar()
                : _build1vs1TopBar(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: SizedBox(
                  width: 390,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDBEAFE),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Câu $thuTuCau / $tongSoCau',
                                    style: const TextStyle(
                                      color: Color(0xFF1E3A8A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                                if (multiChoice)
                                  const Text(
                                    'Chọn nhiều đáp án',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              noiDung,
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                                height: 1.45,
                              ),
                            ),
                            QuestionImageBox(
                              rawImageUrl: q['HinhAnhUrl'] ??
                                  q['HinhAnh'] ??
                                  q['hinh_anh_url'],
                              maxHeight: 200,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      ...List.generate(options.length, (i) {
                        final opt = JsonMap.from(options[i]);
                        final int maDapAn =
                            int.tryParse((opt['MaDapAn'] ?? 0).toString()) ?? 0;
                        final String optText = (opt['NoiDung'] ?? '').toString();
                        final labels = ['A', 'B', 'C', 'D', 'E', 'F'];
                        final bool isSelected =
                            _selectedAnswerIds.contains(maDapAn);

                        Color cardColor = Colors.white;
                        Color borderColor = isSelected
                            ? const Color(0xFF2563EB)
                            : Colors.grey.shade200;

                        if (_isLockedAnswer) {
                          if (_correctAnswerIds.contains(maDapAn)) {
                            cardColor = const Color(0xFFDCFCE7);
                            borderColor = const Color(0xFF16A34A);
                          } else if (isSelected) {
                            cardColor = const Color(0xFFFEE2E2);
                            borderColor = const Color(0xFFDC2626);
                          }
                        }

                        return GestureDetector(
                          onTap: () {
                            if (_isLockedAnswer) return;
                            if (multiChoice) {
                              setState(() {
                                if (isSelected) {
                                  _selectedAnswerIds.remove(maDapAn);
                                } else {
                                  _selectedAnswerIds.add(maDapAn);
                                }
                              });
                            } else {
                              setState(() {
                                _selectedAnswerIds
                                  ..clear()
                                  ..add(maDapAn);
                              });
                              _submitAnswer([maDapAn]);
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: borderColor,
                                width: 1.8,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 15,
                                  backgroundColor: isSelected
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFFE0E7FF),
                                  child: Text(
                                    labels[i % labels.length],
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF1E3A8A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    optText,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      if (multiChoice && !_isLockedAnswer) ...[
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _selectedAnswerIds.isEmpty
                                ? null
                                : () => _submitAnswer(
                                      _selectedAnswerIds.toList(),
                                    ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'CHỐT ĐÁP ÁN',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _build1vs1TopBar() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _myPlayerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '✓ $_myCorrect',
                    style: const TextStyle(
                      color: Color(0xFF4ADE80),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '✕ $_myWrong',
                    style: const TextStyle(
                      color: Color(0xFFF87171),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                _questionTimeLeft <= 5 ? Colors.red : const Color(0xFF2563EB),
            border: Border.all(color: const Color(0xFFFBBF24), width: 2),
          ),
          child: Text(
            '$_questionTimeLeft',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _opponentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '✓ $_opponentCorrect',
                    style: const TextStyle(
                      color: Color(0xFF4ADE80),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '✕ $_opponentWrong',
                    style: const TextStyle(
                      color: Color(0xFFF87171),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTournamentTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Giải đấu Phòng',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              'Đúng: $_myCorrect • Sai: $_myWrong',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                _questionTimeLeft <= 5 ? Colors.red : const Color(0xFF2563EB),
            border: Border.all(color: const Color(0xFFFBBF24), width: 2),
          ),
          child: Text(
            '$_questionTimeLeft',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _showLiveLeaderboardSheet,
          icon: const Icon(Icons.leaderboard_rounded, size: 16),
          label: const Text(
            'BXH Live',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFBBF24),
            foregroundColor: const Color(0xFF1E293B),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}