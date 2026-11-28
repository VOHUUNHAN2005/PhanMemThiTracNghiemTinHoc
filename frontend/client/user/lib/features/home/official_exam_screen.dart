import 'dart:async';
import 'package:flutter/material.dart';
import 'package:user/core/constants/api_constants.dart';
import 'package:user/core/services/favorite_review_service.dart';
import 'package:user/core/services/official_exam_service.dart';
import 'package:user/features/history/attempt_detail_screen.dart';

class OfficialExamScreen extends StatefulWidget {
  final int? initialExamId;
  const OfficialExamScreen({super.key, this.initialExamId});

  @override
  State<OfficialExamScreen> createState() => _OfficialExamScreenState();
}

class _OfficialExamScreenState extends State<OfficialExamScreen>
    with WidgetsBindingObserver {
  static const int _graceSeconds = 5;

  static const Map<int, String> _difficultyLabels = {
    1: 'Rất dễ',
    2: 'Dễ',
    3: 'Trung bình',
    4: 'Khó',
    5: 'Siêu khó',
  };

  final OfficialExamService _service = OfficialExamService();
  final FavoriteReviewService _favReviewService = FavoriteReviewService();

  String buoc = 'danhsach';
  bool _isLoading = false;
  bool _isFinalizing = false;
  bool _isCheatLocked = false;
  bool dongY = true;
  String _violationReason =
      'Chủ động thoát màn hình thi giữa chừng';

  List<dynamic> _allExams = [];
  Set<int> _favoriteExamIds = {};
  String _searchKeyword = '';
  Map<String, dynamic>? _selectedExam;

  // Đánh giá độ khó & góp ý
  Map<String, dynamic>? _reviewSummary;
  int _selectedDifficultyStar = 3;
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmittingReview = false;

  int? _maLuotLam;
  String _currentExamTitle = '';
  List<dynamic> _questions = [];
  final Map<int, Set<int>> _userAnswers = {};
  int cauHienTai = 1;

  Timer? _countdownTimer;
  DateTime? _deadlineUtc;
  int _remainingSeconds = 0;
  int _initialSeconds = 0;

  Map<String, dynamic>? _submitResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchExams();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((buoc == 'phongthi' || buoc == 'xacnhan') &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden)) {
      _handleCheatAndLockAccount('Ẩn app / chuyển tab khi thi');
    }
  }

  Future<void> _handleCheatAndLockAccount(String reason) async {
    if (_isFinalizing || (buoc != 'phongthi' && buoc != 'xacnhan')) {
      return;
    }
    _isFinalizing = true;
    _countdownTimer?.cancel();

    final attemptId = _maLuotLam;
    if (attemptId != null) {
      try {
        await _service.reportCheat(maLuotLam: attemptId, lyDo: reason);
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isCheatLocked = true;
        _violationReason =
            'Gian lận (ẩn app / chuyển tab) — Hủy bài & khóa vĩnh viễn tài khoản';
        buoc = 'bihuy';
      });
    }
    _isFinalizing = false;
  }

  Future<void> _handleImmediateAbortOnExit() async {
    if (_isFinalizing || (buoc != 'phongthi' && buoc != 'xacnhan')) {
      return;
    }
    _isFinalizing = true;
    _countdownTimer?.cancel();

    final attemptId = _maLuotLam;
    if (attemptId != null) {
      try {
        await _service.abortExam(attemptId);
      } catch (e) {
        _showSnackBar(e.toString());
      }
    }

    if (mounted) {
      setState(() {
        _isCheatLocked = false;
        _violationReason =
            'Chủ động thoát màn hình thi giữa chừng';
        buoc = 'bihuy';
      });
    }
    _isFinalizing = false;
  }

  void _showSnackBar(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg.replaceFirst('Exception: ', '')),
        backgroundColor: isError ? Colors.red : Colors.green.shade700,
      ),
    );
  }

  Future<void> _fetchExams() async {
    setState(() => _isLoading = true);
    try {
      final rawList = await _service.getAllOfficialExams();
      final list = (rawList as List)
          .whereType()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      Set<int> favIds = {};
      try {
        final favData = await _favReviewService.getMyFavoritesGroupedByTopic();
        final rawIds = (favData['favorite_exam_ids'] as List?) ?? [];
        favIds = rawIds.map((e) => (e as num).toInt()).toSet();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _allExams = list;
          _favoriteExamIds = favIds;
          if (widget.initialExamId != null && _selectedExam == null) {
            final matched = list.where(
              (e) =>
                  int.tryParse(e['MaBoDe'].toString()) == widget.initialExamId,
            );
            if (matched.isNotEmpty) {
              final target = matched.first;
              if (target['DaDat'] == true || target['DaDat'] == 1) {
                _showSnackBar(
                  'Bạn đã vượt qua đề thi này rồi, không thể thi lại nữa.',
                );
              } else {
                _openExamRules(target);
              }
            }
          }
        });
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite(int maBoDe) async {
    final wasFav = _favoriteExamIds.contains(maBoDe);
    setState(() {
      if (wasFav) {
        _favoriteExamIds.remove(maBoDe);
      } else {
        _favoriteExamIds.add(maBoDe);
      }
    });

    try {
      final res = await _favReviewService.toggleFavoriteExam(maBoDe);
      _showSnackBar(
        (res['message'] ?? 'Đã cập nhật yêu thích').toString(),
        isError: false,
      );
    } catch (e) {
      // Hoàn tác nếu lỗi mạng
      if (mounted) {
        setState(() {
          if (wasFav) {
            _favoriteExamIds.add(maBoDe);
          } else {
            _favoriteExamIds.remove(maBoDe);
          }
        });
        _showSnackBar(e.toString());
      }
    }
  }

  Future<void> _loadReviewSummary(int maBoDe) async {
    try {
      final summary =
          await _favReviewService.getOfficialExamReviewSummary(maBoDe);
      if (mounted) {
        setState(() {
          _reviewSummary = summary;
          final myReview = summary['DanhGiaCuaToi'] as Map<String, dynamic>?;
          if (myReview != null) {
            _selectedDifficultyStar =
                (myReview['SoSao'] as num?)?.toInt() ?? 3;
            _feedbackController.text = (myReview['GopY'] ?? '').toString();
          } else {
            _selectedDifficultyStar = 3;
            _feedbackController.clear();
          }
        });
      }
    } catch (_) {}
  }

  void _openExamRules(Map<String, dynamic> exam) {
    setState(() {
      _selectedExam = exam;
      _reviewSummary = null;
      dongY = true;
      buoc = 'quydinh';
    });
    final maBoDe = (exam['MaBoDe'] as num).toInt();
    _loadReviewSummary(maBoDe);
  }

  Future<void> _submitDifficultyReview() async {
    final selected = _selectedExam;
    if (selected == null || _isSubmittingReview) return;

    final int maBoDe = (selected['MaBoDe'] as num).toInt();
    setState(() => _isSubmittingReview = true);

    try {
      final res = await _favReviewService.submitOfficialExamReview(
        maBoDe: maBoDe,
        soSao: _selectedDifficultyStar,
        gopY: _feedbackController.text,
      );
      _showSnackBar(
        (res['message'] ?? 'Đã gửi đánh giá thành công!').toString(),
        isError: false,
      );
      await _loadReviewSummary(maBoDe);
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
  }

  DateTime _computeDeadlineFromSession(Map<String, dynamic> session) {
    final rawDeadline = session['ThoiGianHetHanUTC']?.toString();
    if (rawDeadline != null && rawDeadline.isNotEmpty) {
      final parsed = DateTime.tryParse(rawDeadline);
      if (parsed != null) {
        return parsed.toUtc().add(const Duration(seconds: _graceSeconds));
      }
    }
    final rawSeconds = session['ThoiGianConLaiGiay'];
    final int seconds = rawSeconds is int
        ? rawSeconds
        : int.tryParse(rawSeconds?.toString() ?? '') ?? 0;
    return DateTime.now().toUtc().add(
      Duration(seconds: (seconds > 0 ? seconds : 0) + _graceSeconds),
    );
  }

  Future<void> _startExam() async {
    final selected = _selectedExam;
    if (selected == null) return;
    setState(() => _isLoading = true);
    try {
      final session = Map<String, dynamic>.from(
        (await _service.startExam(selected['MaBoDe'] as int)) as Map,
      );
      final List rawQuestions =
          (session['DanhSachCauHoi'] as List?) ?? const [];
      final deadline = _computeDeadlineFromSession(session);
      final remaining = deadline
          .difference(DateTime.now().toUtc())
          .inSeconds
          .clamp(0, 86400);

      if (!mounted) return;
      setState(() {
        _maLuotLam = session['MaLuotLam'] as int?;
        _currentExamTitle = (session['TieuDe'] ?? selected['TieuDe'] ?? '')
            .toString();
        _questions = List<dynamic>.from(rawQuestions);
        _userAnswers.clear();
        cauHienTai = 1;
        _isFinalizing = false;
        _isCheatLocked = false;
        _deadlineUtc = deadline;
        _remainingSeconds = remaining;
        _initialSeconds = remaining;
        buoc = 'phongthi';
      });
      _startTimer();
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final deadline = _deadlineUtc;
      final left = deadline != null
          ? deadline.difference(DateTime.now().toUtc()).inSeconds
          : _remainingSeconds - 1;

      if (left <= 0) {
        timer.cancel();
        if (mounted) {
          setState(() => _remainingSeconds = 0);
        }
        _submitExam(autoTimeUp: true);
      } else if (mounted) {
        setState(() => _remainingSeconds = left);
      }
    });
  }

  Future<void> _toggleAnswer(Map<String, dynamic> question, int maDapAn) async {
    if (_maLuotLam == null) return;
    final int maCauHoi = question['MaCauHoi'] as int;
    final bool multi = question['ChoPhepNhieuDapAn'] == true;

    final Set<int> currentSet = Set<int>.from(
      _userAnswers[maCauHoi] ?? const {},
    );
    if (multi) {
      if (currentSet.contains(maDapAn)) {
        currentSet.remove(maDapAn);
      } else {
        currentSet.add(maDapAn);
      }
    } else {
      if (currentSet.contains(maDapAn)) {
        currentSet.clear();
      } else {
        currentSet
          ..clear()
          ..add(maDapAn);
      }
    }

    setState(() {
      if (currentSet.isEmpty) {
        _userAnswers.remove(maCauHoi);
      } else {
        _userAnswers[maCauHoi] = currentSet;
      }
    });

    try {
      await _service.saveAnswer(
        maLuotLam: _maLuotLam!,
        maCauHoi: maCauHoi,
        danhSachMaDapAn: currentSet.toList(),
      );
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }

  Future<void> _submitExam({bool autoTimeUp = false}) async {
    if (_maLuotLam == null || _isLoading || _isFinalizing) return;
    _countdownTimer?.cancel();
    setState(() => _isLoading = true);

    try {
      final result = Map<String, dynamic>.from(
        (await _service.submitExam(_maLuotLam!)) as Map,
      );
      if (mounted) {
        setState(() {
          _submitResult = result;
          buoc = 'ketqua';
        });
      }
      if (_selectedExam != null) {
        await _loadReviewSummary((_selectedExam!['MaBoDe'] as num).toInt());
      }
      if (autoTimeUp) {
        _showSnackBar('Hết giờ! Hệ thống đã tự động nộp bài.', isError: false);
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatClock(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final m = (safe ~/ 60).toString().padLeft(2, '0');
    final s = (safe % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _resolveImageUrl(dynamic rawUrl) {
    final url = (rawUrl ?? '').toString().trim();
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('/')) {
      return '${ApiConstants.baseUrl}$url';
    }
    return '${ApiConstants.baseUrl}/$url';
  }

  void _showZoomImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (buoc == 'bihuy') {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FE),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: 390,
                child: Column(
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEE2E2),
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '!',
                        style: TextStyle(
                          color: Color(0xFFB91C1C),
                          fontSize: 54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _isCheatLocked
                            ? 'BÀI THI BỊ HỦY • TÀI KHOẢN BỊ KHÓA VĨNH VIỄN'
                            : 'BÀI THI BỊ HỦY (HUY_GIAN_LAN)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '0 điểm • 0 cúp',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Lý do'),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _violationReason,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Bộ đề'),
                              Flexible(
                                child: Text(
                                  _currentExamTitle,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _isCheatLocked
                            ? 'Phát hiện hành vi gian lận (ẩn app hoặc chuyển tab tra cứu). Bài thi bị hủy và tài khoản của bạn đã bị khóa vĩnh viễn.'
                            : 'Bạn đã chủ động thoát màn hình thi giữa chừng. Lượt thi bị hủy ngay lập tức(0 điểm, 0 cúp).',
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          _fetchExams();
                          setState(() => buoc = 'danhsach');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D5CE5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Về danh sách đề thi',
                          style: TextStyle(fontWeight: FontWeight.bold),
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

    if (buoc == 'ketqua') {
      final bool daDat = _submitResult?['DaDat'] == true;
      final double diemSo = ((_submitResult?['DiemSo'] ?? 0) as num).toDouble();
      final int soCauDung = ((_submitResult?['SoCauDung'] ?? 0) as num).toInt();
      final int tongSoCau =
          ((_submitResult?['TongSoCau'] ?? _questions.length) as num).toInt();
      final int soCauSai = (tongSoCau - soCauDung).clamp(0, tongSoCau);
      final int cupNhanDuoc = ((_submitResult?['CupNhanDuoc'] ?? 0) as num)
          .toInt();
      final String trangThai = (_submitResult?['TrangThai'] ?? '').toString();
      final int spentMinutes = ((_initialSeconds - _remainingSeconds) / 60)
          .ceil()
          .clamp(1, 999);
      final bool alreadyReviewed = _reviewSummary?['DanhGiaCuaToi'] != null;

      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FE),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: 390,
                child: Column(
                  children: [
                    Container(
                      width: 130,
                      height: 130,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: daDat
                            ? const Color(0xFF1D5CE5)
                            : const Color(0xFFDC2626),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: daDat
                              ? const Color(0xFFBBF7D0)
                              : const Color(0xFFFECACA),
                          width: 8,
                        ),
                      ),
                      child: Text(
                        diemSo.toStringAsFixed(1).replaceAll('.', ','),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: daDat
                            ? const Color(0xFFD1FAE5)
                            : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        trangThai == 'HET_GIO'
                            ? (daDat ? 'HẾT GIỜ • ĐẠT' : 'HẾT GIỜ • CHƯA ĐẠT')
                            : (daDat ? 'ĐẠT' : 'CHƯA ĐẠT'),
                        style: TextStyle(
                          color: daDat
                              ? const Color(0xFF065F46)
                              : const Color(0xFFB91C1C),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (cupNhanDuoc > 0) ...[
                          const Icon(
                            Icons.emoji_events,
                            color: Colors.amber,
                            size: 26,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          '+$cupNhanDuoc cúp',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: cupNhanDuoc > 0
                                ? const Color(0xFF065F46)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                    if (_currentExamTitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _currentExamTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Số câu đúng'),
                              Text(
                                '$soCauDung / $tongSoCau',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Số câu sai'),
                              Text(
                                '$soCauSai',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Thời gian làm bài'),
                              Text(
                                '$spentMinutes phút',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // CARD ĐÁNH GIÁ ĐỘ KHÓ (5 MỨC) & GÓP Ý RIÊNG CHO ADMIN
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFDBEAFE),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.speed_rounded,
                                color: Color(0xFF1D5CE5),
                                size: 22,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Đánh giá độ khó & Góp ý đề thi',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Mức độ khó được tính trung bình cho đề thi. Nội dung góp ý chỉ hiển thị riêng cho Quản trị viên.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(5, (i) {
                              final int level = i + 1;
                              final bool selected =
                                  _selectedDifficultyStar == level;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(
                                    () => _selectedDifficultyStar = level,
                                  ),
                                  child: Container(
                                    margin: EdgeInsets.only(
                                      right: i < 4 ? 6 : 0,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? const Color(0xFF1D5CE5)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          '$level',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: selected
                                                ? Colors.white
                                                : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _difficultyLabels[level]!,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: selected
                                                ? Colors.white
                                                : const Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _feedbackController,
                            maxLines: 3,
                            maxLength: 500,
                            decoration: InputDecoration(
                              hintText:
                                  'Báo lỗi câu hỏi, sai đáp án hoặc sự cố kỹ thuật cho Admin (không bắt buộc)...',
                              hintStyle: const TextStyle(fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              counterText: '',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: _isSubmittingReview
                                  ? null
                                  : _submitDifficultyReview,
                              icon: _isSubmittingReview
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded, size: 18),
                              label: Text(
                                alreadyReviewed
                                    ? 'Cập nhật đánh giá & góp ý'
                                    : 'Gửi đánh giá & góp ý',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_maLuotLam != null) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AttemptDetailScreen(
                                  maLuotLam: _maLuotLam!,
                                  fallbackTitle: _currentExamTitle,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text(
                            'Xem chi tiết bài làm',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1D5CE5),
                            side: const BorderSide(color: Color(0xFF1D5CE5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          _fetchExams();
                          setState(() => buoc = 'danhsach');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D5CE5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Về danh sách đề thi',
                          style: TextStyle(fontWeight: FontWeight.bold),
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

    if (buoc == 'xacnhan') {
      final int tongSoCau = _questions.length;
      final int daTraLoi = _userAnswers.length;
      final List<int> chuaTraLoiNumbers = [];
      for (int i = 0; i < _questions.length; i++) {
        final q = Map<String, dynamic>.from(_questions[i] as Map);
        final qId = q['MaCauHoi'] as int;
        if (!_userAnswers.containsKey(qId)) {
          chuaTraLoiNumbers.add(i + 1);
        }
      }

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _handleImmediateAbortOnExit();
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF4F7FE),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: 390,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _currentExamTitle.isNotEmpty
                                  ? _currentExamTitle
                                  : 'Thi chính thức',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _formatClock(_remainingSeconds),
                              style: const TextStyle(
                                color: Color(0xFFB91C1C),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Xác nhận nộp bài?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Đã trả lời'),
                                Text(
                                  '$daTraLoi / $tongSoCau',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 22),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Chưa trả lời'),
                                Text(
                                  '${chuaTraLoiNumbers.length} câu',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (chuaTraLoiNumbers.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: chuaTraLoiNumbers
                                .map(
                                  (soCau) => GestureDetector(
                                    onTap: () => setState(() {
                                      cauHienTai = soCau;
                                      buoc = 'phongthi';
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$soCau',
                                        style: const TextStyle(
                                          color: Color(0xFFB91C1C),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _submitExam(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D5CE5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Xác nhận nộp bài',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton(
                          onPressed: () => setState(() => buoc = 'phongthi'),
                          child: const Text('Quay lại làm bài'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (buoc == 'phongthi' && _questions.isNotEmpty) {
      final int tongSoCau = _questions.length;
      final currentQ = Map<String, dynamic>.from(
        _questions[(cauHienTai - 1).clamp(0, tongSoCau - 1)] as Map,
      );
      final int maCauHoi = currentQ['MaCauHoi'] as int;
      final List answers = (currentQ['DapAn'] as List?) ?? const [];
      final Set<int> selectedSet = _userAnswers[maCauHoi] ?? const <int>{};
      final String questionImgUrl = _resolveImageUrl(
        currentQ['HinhAnhUrl'] ??
            currentQ['HinhAnh'] ??
            currentQ['hinh_anh_url'],
      );
      const labels = ['A', 'B', 'C', 'D', 'E', 'F'];

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _handleImmediateAbortOnExit();
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF4F7FE),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: SizedBox(
                  width: 390,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.exit_to_app,
                              color: Colors.redAccent,
                            ),
                            tooltip: 'Thoát phòng thi (Hủy lượt thi)',
                            onPressed: _handleImmediateAbortOnExit,
                          ),
                          Expanded(
                            child: Text(
                              _currentExamTitle.isNotEmpty
                                  ? _currentExamTitle
                                  : 'Thi chính thức',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _formatClock(_remainingSeconds),
                              style: const TextStyle(
                                color: Color(0xFFB91C1C),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Câu $cauHienTai / $tongSoCau',
                        style: const TextStyle(color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: cauHienTai / tongSoCau,
                          minHeight: 7,
                          backgroundColor: const Color(0xFFDBEAFE),
                          color: const Color(0xFF1D5CE5),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (currentQ['NoiDung'] ?? '').toString(),
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (currentQ['ChoPhepNhieuDapAn'] == true) ...[
                              const SizedBox(height: 6),
                              const Text(
                                '(Câu hỏi có thể chọn nhiều đáp án)',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF1D5CE5),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (questionImgUrl.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () =>
                                    _showZoomImageDialog(questionImgUrl),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    questionImgUrl,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(answers.length, (idx) {
                        final ans = Map<String, dynamic>.from(
                          answers[idx] as Map,
                        );
                        final int maDapAn = ans['MaDapAn'] as int;
                        final bool isSelected = selectedSet.contains(maDapAn);
                        final String prefix = idx < labels.length
                            ? '${labels[idx]}. '
                            : '';

                        return GestureDetector(
                          onTap: () => _toggleAnswer(currentQ, maDapAn),
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF1D5CE5)
                                    : Colors.transparent,
                                width: 1.8,
                              ),
                            ),
                            child: Text(
                              '$prefix${ans['NoiDung'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bảng điều hướng câu hỏi',
                              style: TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: List.generate(tongSoCau, (i) {
                                final int soCau = i + 1;
                                final q = Map<String, dynamic>.from(
                                  _questions[i] as Map,
                                );
                                final int qId = q['MaCauHoi'] as int;
                                final bool dangChon = soCau == cauHienTai;
                                final bool daLam = _userAnswers.containsKey(
                                  qId,
                                );

                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => cauHienTai = soCau),
                                  child: Container(
                                    width: 32,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: dangChon
                                          ? const Color(0xFF1D5CE5)
                                          : (daLam
                                                ? const Color(0xFFDBEAFE)
                                                : const Color(0xFFF1F5F9)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$soCau',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: dangChon
                                            ? Colors.white
                                            : (daLam
                                                  ? const Color(0xFF1D5CE5)
                                                  : Colors.black54),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () => setState(() {
                                  cauHienTai = cauHienTai < tongSoCau
                                      ? cauHienTai + 1
                                      : 1;
                                }),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1D5CE5),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Câu tiếp theo',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () => setState(() => buoc = 'xacnhan'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF1D5CE5),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Nộp bài',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (buoc == 'quydinh' && _selectedExam != null) {
      final exam = _selectedExam!;
      final int maBoDe = (exam['MaBoDe'] as num).toInt();
      final bool isFav = _favoriteExamIds.contains(maBoDe);
      final int phut = ((exam['ThoiGianLamBai'] ?? 45) as num).toInt();
      final int soCau = ((exam['SoLuongCauHoi'] ?? 30) as num).toInt();
      final String diemSan = (exam['DiemDatToiThieu'] ?? 5.0)
          .toString()
          .replaceAll('.', ',');

      final double? avgDiff =
          (_reviewSummary?['DiemDoKhoTrungBinh'] as num?)?.toDouble();
      final String? diffLabel =
          _reviewSummary?['NhanDoKhoTrungBinh']?.toString();
      final int totalReviews =
          (_reviewSummary?['TongLuotDanhGia'] as num?)?.toInt() ?? 0;

      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FE),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: SizedBox(
                width: 390,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: _isLoading
                              ? null
                              : () => setState(() => buoc = 'danhsach'),
                        ),
                        const Expanded(
                          child: Text(
                            'Quy định trước khi thi',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: isFav ? 'Bỏ yêu thích' : 'Thêm yêu thích',
                          onPressed: () => _toggleFavorite(maBoDe),
                          icon: Icon(
                            isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFav
                                ? const Color(0xFFE11D48)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (exam['TieuDe'] ?? '').toString(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Thời gian'),
                              Text(
                                '$phut phút (+5s bù trễ)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Số câu'),
                              Text(
                                '$soCau câu',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Điểm sàn đạt'),
                              Text(
                                diemSan,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Độ khó đánh giá'),
                              Text(
                                avgDiff != null && diffLabel != null
                                    ? '$avgDiff/5 • $diffLabel ($totalReviews)'
                                    : 'Chưa có đánh giá',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: avgDiff != null
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Chủ động thoát màn hình thi giữa chừng sẽ hủy lượt thi ngay lập tức (0 điểm, 0 cúp). Ẩn app hoặc chuyển tab sẽ hủy bài và khóa vĩnh viễn tài khoản.',
                        style: TextStyle(
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Tôi đã đọc và đồng ý quy định'),
                      value: dongY,
                      onChanged: (v) => setState(() => dongY = v ?? false),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: (dongY && !_isLoading) ? _startExam : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D5CE5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Bắt đầu thi',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
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

    final filteredExams = _allExams.where((rawExam) {
      if (_searchKeyword.isEmpty) return true;
      final e = Map<String, dynamic>.from(rawExam as Map);
      final title = (e['TieuDe'] ?? '').toString().toLowerCase();
      final topic = (e['TenChuDe'] ?? '').toString().toLowerCase();
      final kw = _searchKeyword.toLowerCase();
      return title.contains(kw) || topic.contains(kw);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchExams,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Center(
              child: SizedBox(
                width: 390,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text(
                          'Thi chính thức',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (val) => setState(() => _searchKeyword = val),
                      decoration: const InputDecoration(
                        hintText: 'Tìm bộ đề đang mở',
                        prefixIcon: Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading && _allExams.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (filteredExams.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Center(
                          child: Text(
                            'Chưa có đề thi chính thức nào đang mở.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ...filteredExams.map((rawExam) {
                        final exam = Map<String, dynamic>.from(rawExam as Map);
                        final int maBoDe = (exam['MaBoDe'] as num).toInt();
                        final bool isFav = _favoriteExamIds.contains(maBoDe);
                        final String title =
                            (exam['TieuDe'] ?? 'Đề thi chính thức').toString();
                        final String topic = (exam['TenChuDe'] ?? '')
                            .toString();
                        final int phut = ((exam['ThoiGianLamBai'] ?? 45) as num)
                            .toInt();
                        final int soCau = ((exam['SoLuongCauHoi'] ?? 30) as num)
                            .toInt();

                        return GestureDetector(
                          onTap: () => _openExamRules(exam),
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (topic.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          topic,
                                          style: const TextStyle(
                                            color: Color(0xFF1D5CE5),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(
                                        '$phut phút • $soCau câu',
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: isFav
                                      ? 'Bỏ yêu thích'
                                      : 'Thêm yêu thích',
                                  onPressed: () => _toggleFavorite(maBoDe),
                                  icon: Icon(
                                    isFav
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: isFav
                                        ? const Color(0xFFE11D48)
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Color(0xFF94A3B8),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}