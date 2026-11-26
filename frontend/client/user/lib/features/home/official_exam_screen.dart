import 'dart:async';
import 'package:flutter/material.dart';
import 'package:user/core/constants/api_constants.dart';
import 'package:user/core/services/official_exam_service.dart';

class OfficialExamScreen extends StatefulWidget {
  const OfficialExamScreen({super.key});

  @override
  State createState() => _OfficialExamScreenState();
}

class _OfficialExamScreenState extends State<OfficialExamScreen>
    with WidgetsBindingObserver {
  final OfficialExamService _service = OfficialExamService();

  String buoc = 'danhsach';
  bool _isLoading = false;
  bool dongY = true;

  List _allExams = [];
  String _searchKeyword = '';
  Map? _selectedExam;

  int? _maLuotLam;
  String _currentExamTitle = '';
  List _questions = [];
  final Map _userAnswers = {};
  int cauHienTai = 1;

  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  int _initialSeconds = 0;
  int _exitCount = 0;
  static const int _maxExitAllowed = 3;
  bool _showExitWarning = false;

  Map? _submitResult;

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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((buoc == 'phongthi' || buoc == 'xacnhan') &&
        state == AppLifecycleState.paused) {
      _handleScreenExitViolation();
    }
  }

  Future<void> _handleScreenExitViolation() async {
    _exitCount++;
    if (_exitCount > _maxExitAllowed) {
      _countdownTimer?.cancel();
      if (_maLuotLam != null) {
        await _service.abortExam(_maLuotLam!);
      }
      if (mounted) {
        setState(() => buoc = 'bihuy');
      }
    } else if (mounted) {
      setState(() => _showExitWarning = true);
    }
  }

  void _showSnackBar(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green.shade700,
      ),
    );
  }

  Future<void> _fetchExams() async {
    setState(() => _isLoading = true);
    try {
      final list = await _service.getAllOfficialExams();
      if (mounted) setState(() => _allExams = list);
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startExam() async {
    if (_selectedExam == null) return;
    setState(() => _isLoading = true);
    try {
      final session = await _service.startExam(_selectedExam!['MaBoDe']);
      final List rawQuestions = session['DanhSachCauHoi'] ?? [];
      final seconds = session['ThoiGianConLaiGiay'] ?? 0;

      setState(() {
        _maLuotLam = session['MaLuotLam'];
        _currentExamTitle =
            (session['TieuDe'] ?? _selectedExam?['TieuDe'] ?? '').toString();
        _questions = rawQuestions.map((e) => Map.from(e)).toList();
        _userAnswers.clear();
        cauHienTai = 1;
        _exitCount = 0;
        _showExitWarning = false;
        _remainingSeconds = seconds;
        _initialSeconds = seconds;
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
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _submitExam(autoTimeUp: true);
      } else if (mounted) {
        setState(() => _remainingSeconds--);
      }
    });
  }

  Future<void> _toggleAnswer(
    Map question,
    int maDapAn,
  ) async {
    if (_maLuotLam == null) return;
    final int maCauHoi = question['MaCauHoi'];
    final bool multi = question['ChoPhepNhieuDapAn'] == true;

    final Set currentSet = Set.from(_userAnswers[maCauHoi] ?? {});
    if (multi) {
      if (currentSet.contains(maDapAn)) {
        currentSet.remove(maDapAn);
      } else {
        currentSet.add(maDapAn);
      }
    } else {
      currentSet
        ..clear()
        ..add(maDapAn);
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
        danhSachMaDapAn: currentSet.toList().cast(),
      );
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }

  Future<void> _submitExam({bool autoTimeUp = false}) async {
    if (_maLuotLam == null || _isLoading) return;
    _countdownTimer?.cancel();
    setState(() => _isLoading = true);

    try {
      final result = await _service.submitExam(_maLuotLam!);
      if (mounted) {
        setState(() {
          _submitResult = result;
          buoc = 'ketqua';
        });
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
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
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
                      child: const Text(
                        'BÀI THI BỊ HỦY',
                        style: TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '0 điểm • Không nhận cúp',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
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
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Lý do'),
                              Text(
                                'Thoát màn hình quá số lần',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Số lần thoát'),
                              Text(
                                '$_exitCount / $_maxExitAllowed',
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
                      child: const Text(
                        'Hệ thống chống gian lận đã ghi nhận bài thi này. Kết quả sẽ hiển thị là Bị hủy trong lịch sử.',
                        style: TextStyle(
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
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D5CE5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Về trang chủ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          _fetchExams();
                          setState(() => buoc = 'danhsach');
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1D5CE5)),
                          foregroundColor: const Color(0xFF1D5CE5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Xem danh sách đề thi',
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
      final double diemSo = (_submitResult?['DiemSo'] ?? 0).toDouble();
      final int soCauDung = _submitResult?['SoCauDung'] ?? 0;
      final int tongSoCau = _submitResult?['TongSoCau'] ?? _questions.length;
      final int soCauSai = (tongSoCau - soCauDung).clamp(0, tongSoCau);
      final int rawCup = _submitResult?['CupNhanDuoc'] ?? 0;
      final int cupNhanDuoc = rawCup > 0 ? rawCup : (daDat ? 100 : 0);
      final int spentMinutes =
          ((_initialSeconds - _remainingSeconds) / 60).ceil().clamp(1, 999);

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
                        daDat ? 'ĐẠT' : 'CHƯA ĐẠT',
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
                        if (daDat) ...[
                          const Icon(
                            Icons.emoji_events,
                            color: Colors.amber,
                            size: 26,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          daDat ? '+$cupNhanDuoc cúp' : '+0 cúp',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: daDat
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
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Lần thoát màn hình'),
                              Text(
                                '$_exitCount / $_maxExitAllowed',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D5CE5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Về trang chủ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          _fetchExams();
                          setState(() => buoc = 'danhsach');
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1D5CE5)),
                          foregroundColor: const Color(0xFF1D5CE5),
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
      final List chuaTraLoiNumbers = [];
      for (int i = 0; i < _questions.length; i++) {
        final qId = _questions[i]['MaCauHoi'];
        if (!_userAnswers.containsKey(qId)) {
          chuaTraLoiNumbers.add(i + 1);
        }
      }

      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FE),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: 390,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Thi chính thức',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (_currentExamTitle.isNotEmpty)
                                Text(
                                  _currentExamTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF475569),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
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
                          const Divider(height: 22),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Thoát màn hình'),
                              Text(
                                '$_exitCount / $_maxExitAllowed',
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Câu chưa trả lời (bấm để quay lại câu đó)',
                              style: TextStyle(color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: chuaTraLoiNumbers
                                  .map(
                                    (soCau) => GestureDetector(
                                      onTap: () => setState(() {
                                        cauHienTai = soCau as int;
                                        buoc = 'phongthi';
                                      }),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEE2E2),
                                          borderRadius:
                                              BorderRadius.circular(10),
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
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Sau khi nộp bài, bạn không thể sửa đáp án.',
                        style: TextStyle(
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
                                'Nộp bài',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => setState(() => buoc = 'phongthi'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1D5CE5)),
                          foregroundColor: const Color(0xFF1D5CE5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Quay lại làm bài',
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

    if (buoc == 'phongthi' && _questions.isNotEmpty) {
      final int tongSoCau = _questions.length;
      final currentQ = _questions[(cauHienTai - 1).clamp(0, tongSoCau - 1)];
      final int maCauHoi = currentQ['MaCauHoi'];
      final List answers = currentQ['DapAn'] ?? [];
      final Set selectedSet = (_userAnswers[maCauHoi] as Set?) ?? {};
      final labels = ['A', 'B', 'C', 'D', 'E', 'F'];
      final String questionImgUrl = _resolveImageUrl(
        currentQ['HinhAnhUrl'] ?? currentQ['HinhAnh'],
      );

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            setState(() => buoc = 'xacnhan');
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentExamTitle.isNotEmpty
                                      ? _currentExamTitle
                                      : 'Thi chính thức',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Câu $cauHienTai / $tongSoCau',
                            style: const TextStyle(color: Color(0xFF475569)),
                          ),
                          Text(
                            'Thoát màn hình: $_exitCount / $_maxExitAllowed',
                            style: const TextStyle(color: Color(0xFF475569)),
                          ),
                        ],
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
                      if (_showExitWarning) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Cảnh báo: bạn vừa rời khỏi màn hình thi. Còn ${_maxExitAllowed - _exitCount} lần.',
                            style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
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
                              currentQ['NoiDung'] ?? '',
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
                                onTap: () => _showZoomImageDialog(questionImgUrl),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    questionImgUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.grey,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Không tải được hình ảnh câu hỏi.',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(answers.length, (idx) {
                        final ans = answers[idx];
                        final int maDapAn = ans['MaDapAn'];
                        final bool isSelected = selectedSet.contains(maDapAn);
                        final String prefix =
                            idx < labels.length ? '${labels[idx]}. ' : '';

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
                                final int qId = _questions[i]['MaCauHoi'];
                                final bool dangChon = soCau == cauHienTai;
                                final bool daLam =
                                    _userAnswers.containsKey(qId);

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
                              onPressed: () =>
                                  setState(() => buoc = 'xacnhan'),
                              style: OutlinedButton.styleFrom(
                                side:
                                    const BorderSide(color: Color(0xFF1D5CE5)),
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
      final int phut = exam['ThoiGianLamBai'] ?? 45;
      final int soCau = exam['SoLuongCauHoi'] ?? 30;
      final String diemSan =
          (exam['DiemDatToiThieu'] ?? 5.0).toString().replaceAll('.', ',');

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
                        const Text(
                          'Quy định trước khi thi',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Đang mở',
                              style: TextStyle(
                                color: Color(0xFF1D5CE5),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            exam['TieuDe'] ?? '',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Thời gian'),
                              Text(
                                '$phut phút',
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
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Thang điểm'),
                              Text(
                                '10',
                                style: TextStyle(fontWeight: FontWeight.bold),
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
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Số lần thoát màn hình tối đa'),
                              Text(
                                '3 lần',
                                style: TextStyle(fontWeight: FontWeight.bold),
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
                        'Rời hoặc chuyển tab quá 3 lần, bài thi sẽ bị hủy và không được tính điểm.',
                        style: TextStyle(
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Đạt điểm sàn: +100 cúp. Không hiển thị đáp án trong lúc thi.',
                        style: TextStyle(color: Color(0xFF475569)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Tôi đã đọc và đồng ý quy định'),
                      value: dongY,
                      onChanged: (v) => setState(() => dongY = v!),
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

    final filteredExams = _allExams.where((e) {
      if (_searchKeyword.isEmpty) return true;
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
                      ...filteredExams.map((exam) {
                        final bool daDat = exam['DaDat'] == true;
                        final int phut = exam['ThoiGianLamBai'] ?? 0;
                        final int soCau = exam['SoLuongCauHoi'] ?? 0;
                        final String diemSan = (exam['DiemDatToiThieu'] ?? 5.0)
                            .toString()
                            .replaceAll('.', ',');

                        return GestureDetector(
                          onTap: () {
                            if (daDat) {
                              _showSnackBar(
                                'Bạn đã vượt qua đề thi này rồi, không thể thi lại.',
                                isError: false,
                              );
                              return;
                            }
                            setState(() {
                              _selectedExam = exam;
                              dongY = true;
                              buoc = 'quydinh';
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
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
                                        exam['TieuDe'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$phut phút • $soCau câu • Điểm sàn $diemSan',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: daDat
                                        ? const Color(0xFFDBEAFE)
                                        : const Color(0xFFD1FAE5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    daDat ? 'Đã thi • Đạt' : 'Đang mở',
                                    style: TextStyle(
                                      color: daDat
                                          ? const Color(0xFF1D5CE5)
                                          : const Color(0xFF065F46),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
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