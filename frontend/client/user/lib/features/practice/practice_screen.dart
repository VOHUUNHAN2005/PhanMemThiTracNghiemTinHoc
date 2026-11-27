import 'package:flutter/material.dart';
import 'package:user/core/services/practice_service.dart';
import 'package:user/core/widgets/question_image_box.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final PracticeService _service = PracticeService();

  String buoc = 'chude';
  bool _isLoading = false;
  String _searchKeyword = '';

  List _topics = [];
  List _featuredExams = [];
  Map? _selectedTopic;
  List _topicExams = [];

  int? _maLuotLam;
  int? _currentBoDeId;
  String _currentBoDeTitle = '';
  String _currentTopicTitle = '';
  List _questions = [];
  int _currentIndex = 0;
  final Map _selectedAnswers = {};

  Map? _finishResult;

  @override
  void initState() {
    super.initState();
    _loadTopicsAndFeatured();
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

  Future<void> _loadTopicsAndFeatured() async {
    setState(() => _isLoading = true);
    try {
      final topics = await _service.getPracticeTopics();
      List featured = [];
      if (topics.isNotEmpty) {
        final exams = await _service.getExamsByTopic(topics.first['MaChuDe']);
        featured = exams.take(2).map((e) {
          return {
            ...e,
            'TenChuDe': topics.first['TenChuDe'] ?? '',
          };
        }).toList();
      }
      if (mounted) {
        setState(() {
          _topics = topics;
          _featuredExams = featured;
        });
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openTopic(Map topic) async {
    setState(() {
      _selectedTopic = topic;
      _currentTopicTitle = (topic['TenChuDe'] ?? '').toString();
      _isLoading = true;
      buoc = 'bode';
    });
    try {
      final exams = await _service.getExamsByTopic(topic['MaChuDe']);
      if (mounted) setState(() => _topicExams = exams);
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startPractice(int maBoDe, {String? topicName}) async {
    setState(() => _isLoading = true);
    try {
      final session = await _service.startOrResumePractice(maBoDe);
      final List rawQuestions = session['DanhSachCauHoi'] ?? [];
      final List parsed = rawQuestions.map((e) => Map.from(e)).toList();

      _selectedAnswers.clear();
      for (final q in parsed) {
        final List chosen = q['MaDapAnDaChon'] ?? [];
        if (chosen.isNotEmpty) {
          _selectedAnswers[q['MaCauHoi']] = chosen.map((x) => x as int).toSet();
        }
      }

      if (mounted) {
        setState(() {
          _maLuotLam = session['MaLuotLam'];
          _currentBoDeId = maBoDe;
          _currentBoDeTitle = (session['TieuDe'] ?? '').toString();
          if (topicName != null && topicName.isNotEmpty) {
            _currentTopicTitle = topicName;
          } else if (session['TenChuDe'] != null &&
              session['TenChuDe'].toString().isNotEmpty) {
            _currentTopicTitle = session['TenChuDe'].toString();
          }
          _questions = parsed;
          _currentIndex = (session['ViTriCauTiepTheo'] ?? 0)
              .clamp(0, parsed.isEmpty ? 0 : parsed.length - 1);
          buoc = 'lambai';
        });
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelAndRestart({
    int? maLuotLam,
    int? maBoDe,
    String? topicName,
  }) async {
    final targetSessionId = maLuotLam ?? _maLuotLam;
    final targetExamId = maBoDe ?? _currentBoDeId;
    if (targetSessionId == null || targetExamId == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy lượt làm dở'),
        content: const Text(
          'Tiến độ hiện tại của lượt ôn tập này sẽ bị hủy và bạn sẽ bắt đầu lại từ đầu. Bạn có chắc không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ tiến độ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hủy & làm lại'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _service.cancelPractice(targetSessionId);
      _showSnackBar('Đã hủy lượt làm dở, bắt đầu lại từ đầu.', isError: false);
      await _startPractice(
        targetExamId,
        topicName: topicName ?? _currentTopicTitle,
      );
      if (_selectedTopic != null) {
        await _openTopic(_selectedTopic!);
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleOption(Map question, int maDapAn) {
    if (question['DaKiemTra'] == true) return;
    final int maCauHoi = question['MaCauHoi'];
    final bool multi = question['ChoPhepNhieuDapAn'] == true;

    final Set currentSet = Set.from(_selectedAnswers[maCauHoi] ?? {});
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
        _selectedAnswers.remove(maCauHoi);
      } else {
        _selectedAnswers[maCauHoi] = currentSet;
      }
    });
  }

  Future<void> _checkCurrentQuestion() async {
    if (_maLuotLam == null || _questions.isEmpty) return;
    final currentQ = _questions[_currentIndex];
    final int maCauHoi = currentQ['MaCauHoi'];
    final List chosen = (_selectedAnswers[maCauHoi] as Set?)?.toList() ?? [];

    if (chosen.isEmpty) {
      _showSnackBar('Vui lòng chọn ít nhất 1 đáp án trước khi kiểm tra.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await _service.checkQuestion(
        maLuotLam: _maLuotLam!,
        maCauHoi: maCauHoi,
        danhSachMaDapAn: chosen.cast(),
      );

      if (mounted) {
        setState(() {
          currentQ['DaKiemTra'] = true;
          currentQ['LaCauDung'] = res['LaCauDung'];
          currentQ['MaDapAnDaChon'] = res['MaDapAnDaChon'];
          if (res['DapAn'] != null) {
            currentQ['DapAn'] = res['DapAn'];
          }
          if (res['GiaiThich'] != null) {
            currentQ['GiaiThich'] = res['GiaiThich'];
          }
        });
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _countAnsweredQuestions() {
    int count = 0;
    for (final q in _questions) {
      final int qId = q['MaCauHoi'];
      final bool hasSelected =
          (_selectedAnswers[qId] as Set?)?.isNotEmpty ?? false;
      final bool checked = q['DaKiemTra'] == true;
      if (hasSelected || checked) {
        count++;
      }
    }
    return count;
  }

  Future<void> _finishPractice() async {
    if (_maLuotLam == null) return;

    final int answeredCount = _countAnsweredQuestions();
    final int minRequired = _questions.length < 10 ? _questions.length : 10;
    if (answeredCount < minRequired) {
      _showSnackBar(
        'Bạn mới làm $answeredCount/$minRequired câu tối thiểu. Vui lòng làm ít nhất $minRequired câu trước khi nộp bài!',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      for (final q in _questions) {
        final int qId = q['MaCauHoi'];
        final Set? selected = _selectedAnswers[qId] as Set?;
        if (q['DaKiemTra'] != true && (selected?.isNotEmpty ?? false)) {
          try {
            await _service.checkQuestion(
              maLuotLam: _maLuotLam!,
              maCauHoi: qId,
              danhSachMaDapAn: selected!.toList().cast(),
            );
          } catch (_) {}
        }
      }

      final result = await _service.finishPractice(_maLuotLam!);
      if (mounted) {
        setState(() {
          _finishResult = result;
          buoc = 'ketqua';
        });
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDifficulty(dynamic rawMucDo) {
    final str = (rawMucDo ?? '').toString().trim().toUpperCase();
    if (str == 'DE' || str == 'DỄ' || str == 'EASY') return 'Dễ';
    if (str == 'KHO' || str == 'KHÓ' || str == 'HARD') return 'Khó';
    if (str == 'TRUNG_BINH' || str == 'TRUNG BÌNH' || str == 'MEDIUM') {
      return 'Trung bình';
    }
    return str.isEmpty ? 'Trung bình' : rawMucDo.toString();
  }

  Color _difficultyColor(String diffLabel) {
    if (diffLabel == 'Dễ') return const Color(0xFF059669);
    if (diffLabel == 'Khó') return const Color(0xFFDC2626);
    return const Color(0xFFD97706);
  }

  Color _difficultyBg(String diffLabel) {
    if (diffLabel == 'Dễ') return const Color(0xFFD1FAE5);
    if (diffLabel == 'Khó') return const Color(0xFFFEE2E2);
    return const Color(0xFFFEF3C7);
  }

  String _getTopicBadge(String tenChuDe) {
    final lower = tenChuDe.toLowerCase();
    if (lower.contains('văn phòng')) return 'Wd';
    if (lower.contains('mạng')) return 'Net';
    if (lower.contains('c++') || lower.contains('lập trình')) return 'C++';
    if (lower.contains('dữ liệu') || lower.contains('sql')) return 'DB';
    final words = tenChuDe.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return 'IT';
    return words.first
        .substring(0, words.first.length >= 3 ? 3 : words.first.length)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (buoc == 'ketqua') {
      final int soCauDung = _finishResult?['SoCauDung'] ?? 0;
      final int tongSoCau = _finishResult?['TongSoCau'] ?? _questions.length;
      final int soCauSai = (tongSoCau - soCauDung).clamp(0, tongSoCau);
      final double tyLeDung = tongSoCau > 0 ? (soCauDung / tongSoCau) : 0.0;
      final bool isPassed = _finishResult?['DatYeuCau'] != null
          ? _finishResult!['DatYeuCau'] == true
          : (tyLeDung >= 0.7);

      return SafeArea(
        child: Center(
          child: SizedBox(
            width: 390,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 130,
                    height: 130,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isPassed
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isPassed
                            ? const Color(0xFFD1FAE5)
                            : const Color(0xFFFEE2E2),
                        width: 8,
                      ),
                    ),
                    child: Text(
                      '$soCauDung/$tongSoCau',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isPassed
                          ? const Color(0xFFD1FAE5)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isPassed ? 'ĐÃ ĐẠT' : 'CHƯA ĐẠT',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isPassed
                            ? const Color(0xFF065F46)
                            : const Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Hoàn thành bài ôn tập',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    _currentBoDeTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '$soCauDung',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const Text(
                                'Câu đúng',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '$soCauSai',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const Text(
                                'Câu sai',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _currentBoDeId != null
                          ? () => _startPractice(_currentBoDeId!)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D5CE5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Làm lại bộ đề',
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
                        _loadTopicsAndFeatured();
                        setState(() => buoc = 'chude');
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1D5CE5)),
                        foregroundColor: const Color(0xFF1D5CE5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Về danh sách chủ đề',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (buoc == 'lambai' && _questions.isNotEmpty) {
      final int tongSoCau = _questions.length;
      final currentQ = _questions[_currentIndex];
      final int maCauHoi = currentQ['MaCauHoi'];
      final bool daKiemTra = currentQ['DaKiemTra'] == true;
      final bool laCauDung = currentQ['LaCauDung'] == true;
      final String? giaiThich = currentQ['GiaiThich']?.toString();
      final bool multi = currentQ['ChoPhepNhieuDapAn'] == true;
      final String questionTypeLabel = (currentQ['TenLoaiCauHoi'] ??
              (multi ? 'Nhiều đáp án' : 'Một đáp án'))
          .toString();
      final String difficultyLabel =
          _formatDifficulty(currentQ['MucDo'] ?? currentQ['DoKho']);
      final List answers = currentQ['DapAn'] ?? [];
      final Set selectedSet = (_selectedAnswers[maCauHoi] as Set?) ?? {};
      final int answeredCount = _countAnsweredQuestions();
      final int minRequired = tongSoCau < 10 ? tongSoCau : 10;

      final String headerTitle = _currentTopicTitle.isNotEmpty
          ? _currentTopicTitle
          : _currentBoDeTitle;

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 105),
          child: Center(
            child: SizedBox(
              width: 390,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          _loadTopicsAndFeatured();
                          setState(() => buoc = 'chude');
                        },
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              headerTitle,
                              softWrap: true,
                              style: const TextStyle(
                                fontSize: 16.5,
                                height: 1.25,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            if (_currentTopicTitle.isNotEmpty &&
                                _currentBoDeTitle.isNotEmpty &&
                                _currentBoDeTitle.toLowerCase() !=
                                    _currentTopicTitle.toLowerCase()) ...[
                              const SizedBox(height: 2),
                              Text(
                                _currentBoDeTitle,
                                softWrap: true,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Câu ${_currentIndex + 1} / $tongSoCau',
                          style: const TextStyle(
                            color: Color(0xFF1D5CE5),
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _isLoading ? null : () => _cancelAndRestart(),
                      icon: const Icon(Icons.restart_alt, size: 16),
                      label: const Text(
                        'Hủy lượt & làm lại',
                        style: TextStyle(fontSize: 12.5),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (_currentIndex + 1) / tongSoCau,
                      minHeight: 7,
                      backgroundColor: const Color(0xFFDBEAFE),
                      color: const Color(0xFF1D5CE5),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0E7FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                questionTypeLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _difficultyBg(difficultyLabel),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Độ khó: $difficultyLabel',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _difficultyColor(difficultyLabel),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          currentQ['NoiDung'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.5,
                            height: 1.4,
                          ),
                        ),
                        if (multi) ...[
                          const SizedBox(height: 6),
                          const Text(
                            '(Chọn nhiều đáp án)',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF1D5CE5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        QuestionImageBox(
                          rawImageUrl: currentQ['HinhAnhUrl'] ??
                              currentQ['HinhAnh'] ??
                              currentQ['hinh_anh_url'],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...answers.map((ans) {
                    final int maDapAn = ans['MaDapAn'];
                    final bool isSelected = selectedSet.contains(maDapAn);
                    final bool? isCorrectAns = ans['LaDapAnDung'];

                    Color borderColor = isSelected
                        ? const Color(0xFF1D5CE5)
                        : Colors.transparent;
                    Color tileBg = Colors.white;

                    if (daKiemTra) {
                      if (isCorrectAns == true) {
                        borderColor = Colors.green;
                        tileBg = const Color(0xFFECFDF5);
                      } else if (isSelected && isCorrectAns == false) {
                        borderColor = Colors.red;
                        tileBg = const Color(0xFFFEF2F2);
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: tileBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor, width: 1.6),
                      ),
                      child: CheckboxListTile(
                        value: isSelected,
                        title: Text(ans['NoiDung'] ?? ''),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: daKiemTra
                            ? null
                            : (_) => _toggleOption(currentQ, maDapAn),
                      ),
                    );
                  }),
                  if (daKiemTra) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: laCauDung
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: laCauDung
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            laCauDung
                                ? 'Chính xác! Câu hỏi đã được khóa.'
                                : 'Chưa chính xác — Đã hiển thị đáp án đúng và khóa câu hỏi.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: laCauDung
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF991B1B),
                            ),
                          ),
                          if (giaiThich != null &&
                              giaiThich.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              giaiThich.trim(),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _checkCurrentQuestion,
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text(
                          'Kiểm tra đáp án câu này',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF059669),
                          side: const BorderSide(color: Color(0xFF059669)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _currentIndex > 0
                              ? () => setState(() => _currentIndex--)
                              : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFF1D5CE5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Câu trước',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _currentIndex < tongSoCau - 1
                              ? () => setState(() => _currentIndex++)
                              : null,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: const Color(0xFF1D5CE5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Câu sau',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _finishPractice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: answeredCount >= minRequired
                            ? const Color(0xFF1D5CE5)
                            : Colors.grey.shade500,
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
                          : Text(
                              'Nộp bài (Đã làm $answeredCount/$minRequired câu tối thiểu)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (buoc == 'bode' && _selectedTopic != null) {
      final topicName = _selectedTopic!['TenChuDe'] ?? '';
      final filteredExams = _topicExams.where((e) {
        if (_searchKeyword.isEmpty) return true;
        return (e['TieuDe'] ?? '')
            .toString()
            .toLowerCase()
            .contains(_searchKeyword.toLowerCase());
      }).toList();

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 105),
          child: Center(
            child: SizedBox(
              width: 390,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => setState(() {
                          _searchKeyword = '';
                          buoc = 'chude';
                        }),
                      ),
                      Expanded(
                        child: Text(
                          topicName,
                          softWrap: true,
                          style: const TextStyle(
                            fontSize: 20,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => _searchKeyword = v),
                    decoration: const InputDecoration(
                      hintText: 'Tìm bộ đề',
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
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
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
                          'Chưa có bộ đề ôn tập nào trong chủ đề này.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ...filteredExams.map((exam) {
                      final int soCau = exam['SoLuongCauHoi'] ?? 0;
                      final dynamic rawLuotLamDo = exam['MaLuotDangLam'];
                      final bool dangLamDo = rawLuotLamDo != null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        'Chủ đề: $topicName • $soCau câu',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => _startPractice(
                                    exam['MaBoDe'],
                                    topicName: topicName.toString(),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: dangLamDo
                                        ? const Color(0xFFFEF3C7)
                                        : const Color(0xFFD1FAE5),
                                    foregroundColor: dangLamDo
                                        ? const Color(0xFF92400E)
                                        : const Color(0xFF065F46),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    dangLamDo ? 'Tiếp tục' : 'Bắt đầu',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (dangLamDo) ...[
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () => _cancelAndRestart(
                                            maLuotLam: rawLuotLamDo is int
                                                ? rawLuotLamDo
                                                : int.tryParse(
                                                    rawLuotLamDo.toString(),
                                                  ),
                                            maBoDe: exam['MaBoDe'],
                                            topicName: topicName.toString(),
                                          ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 28),
                                  ),
                                  child: const Text(
                                    'Hủy lượt làm dở',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final filteredTopics = _topics.where((t) {
      if (_searchKeyword.isEmpty) return true;
      return (t['TenChuDe'] ?? '')
          .toString()
          .toLowerCase()
          .contains(_searchKeyword.toLowerCase());
    }).toList();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadTopicsAndFeatured,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 105),
          child: Center(
            child: SizedBox(
              width: 390,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ôn tập',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => _searchKeyword = v),
                    decoration: const InputDecoration(
                      hintText: 'Tìm chủ đề, bộ đề...',
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
                  if (_isLoading && _topics.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredTopics.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.0,
                      ),
                      itemBuilder: (context, index) {
                        final topic = filteredTopics[index];
                        final String tenChuDe = topic['TenChuDe'] ?? '';
                        final int tongBoDe = topic['TongSoBoDe'] ?? 0;

                        return GestureDetector(
                          onTap: () {
                            _searchKeyword = '';
                            _openTopic(topic);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1D5CE5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getTopicBadge(tenChuDe),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      tenChuDe,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.5,
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$tongBoDe bộ đề',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  if (_featuredExams.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Đề nổi bật • ${_featuredExams.first['TenChuDe']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._featuredExams.map((exam) {
                      final int soCau = exam['SoLuongCauHoi'] ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    exam['TieuDe'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${exam['TenChuDe']} • $soCau câu',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _startPractice(
                                exam['MaBoDe'],
                                topicName:
                                    (exam['TenChuDe'] ?? '').toString(),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDBEAFE),
                                foregroundColor: const Color(0xFF1D5CE5),
                                elevation: 0,
                              ),
                              child: const Text('Làm bài'),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}