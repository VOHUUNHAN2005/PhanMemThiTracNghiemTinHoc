import 'package:admin/services/admin_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/admin_ui_kit.dart';
import 'exam_questions_screen.dart';

class ManageExamsScreen extends StatefulWidget {
  const ManageExamsScreen({super.key});

  @override
  State createState() => _ManageExamsScreenState();
}

class _ManageExamsScreenState extends State {
  final _api = AdminApiService();

  List _exams = [];
  List _topics = [];
  int? _filterTopicId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getExams(loaiBoDe: 'THI_CHINH_THUC', maChuDe: _filterTopicId),
        _api.getTopics(),
      ]);
      if (!mounted) return;
      setState(() {
        _exams = List.from(results[0]);
        _topics = List.from(results[1]);
      });
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future _openExamFeedbacksDialog(Map exam) async {
    final int maBoDe = exam['MaBoDe'];
    Map<String, dynamic>? feedbackData;
    bool loading = true;
    bool initialized = false;

    await showModernModal(
      context: context,
      title: 'Đánh giá độ khó & Góp ý thí sinh',
      subtitle: '${exam['TieuDe'] ?? ''}',
      icon: Icons.rate_review_rounded,
      accentColor: const Color(0xFFD97706),
      width: 720,
      confirmText: 'Đóng',
      bodyBuilder: (ctx, setModalState) {
        if (!initialized) {
          initialized = true;
          Future.microtask(() async {
            try {
              final res = await _api.getExamFeedbacks(maBoDe);
              setModalState(() {
                feedbackData = res;
                loading = false;
              });
            } catch (e) {
              setModalState(() => loading = false);
              _showSnack(e.toString(), isError: true);
            }
          });
        }

        if (loading) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final items = List.from(feedbackData?['items'] ?? []);
        final avgDiff = feedbackData?['DiemDoKhoTrungBinh'];
        final total = feedbackData?['TongDanhGia'] ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.speed_rounded, color: Color(0xFFD97706)),
                  const SizedBox(width: 10),
                  Text(
                    avgDiff != null
                        ? 'Độ khó trung bình: $avgDiff / 5.0 ($total lượt đánh giá)'
                        : 'Chưa có thí sinh nào đánh giá đề thi này.',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text('Chưa có góp ý hoặc báo lỗi nào cho bộ đề này.'),
                ),
              )
            else
              ...items.map((fb) {
                final String gopY = (fb['GopY'] ?? '').toString().trim();
                final int star = (fb['SoSao'] as num?)?.toInt() ?? 3;
                final String label = (fb['NhanMucDo'] ?? '').toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: gopY.isNotEmpty
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${fb['HoTen'] ?? 'Thí sinh'} (${fb['Email'] ?? ''})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Mức $star/5 • $label',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (gopY.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Góp ý / Báo lỗi: $gopY',
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 4),
                        const Text(
                          '(Chỉ chấm mức độ khó, không kèm nội dung góp ý)',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        );
      },
      onConfirm: () async => true,
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);
    String label = 'Bản nháp';

    if (status == 'CONG_KHAI') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
      label = 'Đang mở thi';
    } else if (status == 'AN') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
      label = 'Đã đóng / Ẩn';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style:
              TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Future _openAutoGenerateDialog() async {
    if (_topics.isEmpty) {
      _showSnack('Vui lòng tạo Chủ đề và thêm câu hỏi vào Ngân hàng trước.',
          isError: true);
      return;
    }

    int selectedTopicId = _filterTopicId ?? _topics.first['MaChuDe'];
    final prefixCtrl = TextEditingController();
    final numExamsCtrl = TextEditingController(text: '5');
    final easyCtrl = TextEditingController(text: '10');
    final medCtrl = TextEditingController(text: '6');
    final hardCtrl = TextEditingController(text: '4');
    final durationCtrl = TextEditingController(text: '30');
    final passScoreCtrl = TextEditingController(text: '5.0');
    String selectedStatus = 'CONG_KHAI';

    Map getSelectedTopic() {
      return _topics.firstWhere(
        (t) => t['MaChuDe'] == selectedTopicId,
        orElse: () =>
            {'SoCauDe': 0, 'SoCauTrungBinh': 0, 'SoCauKho': 0, 'TenChuDe': ''},
      );
    }

    final saved = await showModernModal(
      context: context,
      title: 'Sinh Đề thi Chính thức Tự động',
      subtitle:
          'Bốc ngẫu nhiên độc lập từng đề theo ma trận Dễ / Trung bình / Khó để trộn đề thi',
      icon: Icons.auto_awesome_rounded,
      accentColor: const Color(0xFF4F46E5),
      width: 600,
      confirmText: 'Bắt đầu sinh đề thi',
      bodyBuilder: (ctx, setModalState) {
        final topic = getSelectedTopic();
        final availEasy = (topic['SoCauDe'] ?? 0) as int;
        final availMed = (topic['SoCauTrungBinh'] ?? 0) as int;
        final availHard = (topic['SoCauKho'] ?? 0) as int;

        final numExams = int.tryParse(numExamsCtrl.text.trim()) ?? 0;
        final perEasy = int.tryParse(easyCtrl.text.trim()) ?? 0;
        final perMed = int.tryParse(medCtrl.text.trim()) ?? 0;
        final perHard = int.tryParse(hardCtrl.text.trim()) ?? 0;
        final totalPerExam = perEasy + perMed + perHard;

        final okEasy = availEasy >= perEasy;
        final okMed = availMed >= perMed;
        final okHard = availHard >= perHard;
        final validNumExams = numExams >= 1 && numExams <= 50;
        final allEnough =
            okEasy && okMed && okHard && validNumExams && totalPerExam > 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            modernDropdownField(
              value: selectedTopicId,
              label: 'Chọn Chủ đề nguồn *',
              prefixIcon: Icons.layers_outlined,
              items: _topics.map((t) {
                return buildModernDropdownItem(
                  value: t['MaChuDe'],
                  text:
                      '${t['TenChuDe']} (Kho: ${t['SoCauDe'] ?? 0} Dễ · ${t['SoCauTrungBinh'] ?? 0} TB · ${t['SoCauKho'] ?? 0} Khó)',
                  icon: Icons.layers_rounded,
                  iconColor: const Color(0xFF4F46E5),
                );
              }).toList(),
              onChanged: (val) =>
                  setModalState(() => selectedTopicId = val as int),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: allEnough
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: allEnough
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFECACA),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        allEnough
                            ? Icons.check_circle_rounded
                            : Icons.warning_amber_rounded,
                        size: 18,
                        color: allEnough
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          !validNumExams
                              ? 'Số mã đề mỗi lần sinh phải từ 1 đến 50 đề.'
                              : totalPerExam <= 0
                                  ? 'Mỗi mã đề thi phải có ít nhất 1 câu hỏi.'
                                  : allEnough
                                      ? 'Kho đủ điều kiện! Sẽ bốc ngẫu nhiên $numExams đề thi ($totalPerExam câu/đề).'
                                      : 'Kho câu hỏi chưa đủ định mức cho 1 đề thi:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: allEnough
                                ? const Color(0xFF15803D)
                                : const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Dễ: Cần $perEasy / Kho $availEasy ${okEasy ? "✅" : "(Thiếu ${perEasy - availEasy})"}   '
                    '• TB: Cần $perMed / Kho $availMed ${okMed ? "✅" : "(Thiếu ${perMed - availMed})"}   '
                    '• Khó: Cần $perHard / Kho $availHard ${okHard ? "✅" : "(Thiếu ${perHard - availHard})"}',
                    style: const TextStyle(
                        fontSize: 12.5, color: Color(0xFF334155)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: prefixCtrl,
                    maxLength: 100,
                    decoration: modernInputDecoration(
                      label: 'Tiền tố tên đề thi (Tùy chọn)',
                      hint: 'VD: Đề thi ${topic['TenChuDe']}',
                      prefixIcon: Icons.title_rounded,
                    ).copyWith(counterText: ''),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: numExamsCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    onChanged: (_) => setModalState(() {}),
                    decoration: modernInputDecoration(
                      label: 'Số mã đề (1-50) *',
                      hint: '5',
                      prefixIcon: Icons.copy_all_rounded,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Ma trận độ khó cho MỖI mã đề thi:',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: easyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    onChanged: (_) => setModalState(() {}),
                    decoration: modernInputDecoration(
                      label: 'Số câu Dễ / đề',
                      prefixIcon: Icons.signal_cellular_alt_1_bar_rounded,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: medCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    onChanged: (_) => setModalState(() {}),
                    decoration: modernInputDecoration(
                      label: 'Số câu TB / đề',
                      prefixIcon: Icons.signal_cellular_alt_2_bar_rounded,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: hardCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    onChanged: (_) => setModalState(() {}),
                    decoration: modernInputDecoration(
                      label: 'Số câu Khó / đề',
                      prefixIcon: Icons.signal_cellular_alt_rounded,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: durationCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: modernInputDecoration(
                      label: 'Thời gian (1-300 phút) *',
                      hint: '30',
                      prefixIcon: Icons.timer_outlined,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: passScoreCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d{0,2}(\.\d{0,2})?$')),
                    ],
                    decoration: modernInputDecoration(
                      label: 'Điểm đạt (0 - 10) *',
                      hint: '5.0',
                      prefixIcon: Icons.grade_outlined,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: modernDropdownField(
                    value: selectedStatus,
                    label: 'Trạng thái',
                    prefixIcon: Icons.visibility_outlined,
                    items: [
                      buildModernDropdownItem(
                        value: 'CONG_KHAI',
                        text: 'Mở thi ngay',
                        icon: Icons.public_rounded,
                        iconColor: const Color(0xFF16A34A),
                      ),
                      buildModernDropdownItem(
                        value: 'NHAP',
                        text: 'Bản nháp',
                        icon: Icons.edit_note_rounded,
                        iconColor: const Color(0xFF64748B),
                      ),
                    ],
                    onChanged: (val) =>
                        setModalState(() => selectedStatus = val as String),
                  ),
                ),
              ],
            ),
          ],
        );
      },
      onConfirm: () async {
        final numExams = int.tryParse(numExamsCtrl.text.trim());
        final perEasy = int.tryParse(easyCtrl.text.trim()) ?? 0;
        final perMed = int.tryParse(medCtrl.text.trim()) ?? 0;
        final perHard = int.tryParse(hardCtrl.text.trim()) ?? 0;
        final duration = int.tryParse(durationCtrl.text.trim());
        final passScore = double.tryParse(passScoreCtrl.text.trim());

        if (numExams == null || numExams < 1 || numExams > 50) {
          _showSnack('Số mã đề phải là số nguyên từ 1 đến 50.', isError: true);
          return false;
        }
        if (perEasy + perMed + perHard < 1) {
          _showSnack('Tổng số câu mỗi đề phải có ít nhất 1 câu.',
              isError: true);
          return false;
        }
        if (duration == null || duration < 1 || duration > 300) {
          _showSnack('Thời gian làm bài phải từ 1 đến 300 phút.',
              isError: true);
          return false;
        }
        if (passScore == null || passScore < 0 || passScore > 10) {
          _showSnack('Điểm đạt phải là số hợp lệ từ 0 đến 10.', isError: true);
          return false;
        }

        final topic = getSelectedTopic();
        if ((topic['SoCauDe'] ?? 0) < perEasy ||
            (topic['SoCauTrungBinh'] ?? 0) < perMed ||
            (topic['SoCauKho'] ?? 0) < perHard) {
          _showSnack(
              'Kho câu hỏi của chủ đề này không đủ định mức cho 1 đề thi.',
              isError: true);
          return false;
        }

        try {
          final res = await _api.autoGenerateExams({
            'MaChuDe': selectedTopicId,
            'LoaiBoDe': 'THI_CHINH_THUC',
            'TienToTieuDe': prefixCtrl.text.trim(),
            'SoLuongDe': numExams,
            'SoCauDe': perEasy,
            'SoCauTrungBinh': perMed,
            'SoCauKho': perHard,
            'ThoiGianLamBai': duration,
            'DiemDatToiThieu': passScore,
            'TrangThai': selectedStatus,
          });
          _showSnack(res['message'] ?? 'Đã sinh đề thi thành công.');
          return true;
        } catch (e) {
          _showSnack(e.toString(), isError: true);
          return false;
        }
      },
    );

    if (saved == true) _loadData();
  }

  Future _openExamFormDialog({Map? exam}) async {
    final isEdit = exam != null;
    final titleCtrl =
        TextEditingController(text: isEdit ? (exam['TieuDe'] ?? '') : '');
    final descCtrl =
        TextEditingController(text: isEdit ? (exam['MoTa'] ?? '') : '');
    final durationCtrl = TextEditingController(
      text: isEdit ? (exam['ThoiGianLamBai'] ?? 45).toString() : '45',
    );
    final passScoreCtrl = TextEditingController(
      text: isEdit ? (exam['DiemDatToiThieu'] ?? 5.0).toString() : '5.0',
    );

    int? selectedTopicId = isEdit ? exam['MaChuDe'] : _filterTopicId;
    String selectedStatus = isEdit ? (exam['TrangThai'] ?? 'NHAP') : 'NHAP';

    final saved = await showModernModal(
      context: context,
      title: isEdit
          ? 'Cập nhật Đề thi Chính thức'
          : 'Tạo Đề thi Chính thức thủ công',
      subtitle:
          'Đề thi tính giờ làm bài, chấm điểm xếp hạng và lưu kết quả chính thức',
      icon: Icons.assignment_turned_in_rounded,
      accentColor: const Color(0xFF2563EB),
      width: 560,
      confirmText: isEdit ? 'Lưu thay đổi' : 'Tạo đề thi',
      bodyBuilder: (ctx, setModalState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: titleCtrl,
            maxLength: 150,
            decoration: modernInputDecoration(
              label: 'Tên kỳ thi / Đề thi * (Tối thiểu 3 ký tự)',
              hint: 'VD: Kỳ thi Chứng chỉ Tin học Ứng dụng - Đợt 1',
              prefixIcon: Icons.title_rounded,
            ).copyWith(counterText: ''),
          ),
          const SizedBox(height: 16),
          modernDropdownField(
            value: selectedTopicId,
            label: 'Phạm vi chủ đề',
            prefixIcon: Icons.layers_outlined,
            items: [
              buildModernDropdownItem(
                value: null,
                text: 'Đề thi tổng hợp (Nhiều chủ đề)',
                icon: Icons.apps_rounded,
                iconColor: const Color(0xFF7C3AED),
              ),
              ..._topics.map((t) => buildModernDropdownItem(
                    value: t['MaChuDe'],
                    text: t['TenChuDe'] ?? '',
                    icon: Icons.layers_rounded,
                    iconColor: const Color(0xFF2563EB),
                  )),
            ],
            onChanged: (val) =>
                setModalState(() => selectedTopicId = val as int?),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: modernInputDecoration(
                    label: 'Thời gian (1-300 phút) *',
                    hint: 'VD: 45',
                    prefixIcon: Icons.timer_outlined,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: passScoreCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d{0,2}(\.\d{0,2})?$')),
                  ],
                  decoration: modernInputDecoration(
                    label: 'Điểm đạt (0 - 10) *',
                    hint: '5.0',
                    prefixIcon: Icons.grade_outlined,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          modernDropdownField(
            value: selectedStatus,
            label: 'Trạng thái phát hành',
            prefixIcon: Icons.publish_rounded,
            items: [
              buildModernDropdownItem(
                value: 'NHAP',
                text: 'Bản nháp (Chưa cho thí sinh thấy)',
                icon: Icons.edit_note_rounded,
                iconColor: const Color(0xFF64748B),
              ),
              buildModernDropdownItem(
                value: 'CONG_KHAI',
                text: 'Công khai (Mở thi chính thức)',
                icon: Icons.public_rounded,
                iconColor: const Color(0xFF16A34A),
              ),
              buildModernDropdownItem(
                value: 'AN',
                text: 'Ẩn / Đóng đề thi',
                icon: Icons.visibility_off_outlined,
                iconColor: const Color(0xFFDC2626),
              ),
            ],
            onChanged: (val) =>
                setModalState(() => selectedStatus = val as String),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: descCtrl,
            maxLines: 3,
            maxLength: 500,
            decoration: modernInputDecoration(
              label: 'Quy chế / Mô tả đề thi',
              hint: 'Nhập quy định phòng thi hoặc lưu ý cho thí sinh...',
              prefixIcon: Icons.notes_rounded,
            ).copyWith(counterText: ''),
          ),
        ],
      ),
      onConfirm: () async {
        final title = titleCtrl.text.trim();
        if (title.length < 3) {
          _showSnack('Tên đề thi phải có ít nhất 3 ký tự.', isError: true);
          return false;
        }

        final duration = int.tryParse(durationCtrl.text.trim());
        if (duration == null || duration < 1 || duration > 300) {
          _showSnack('Thời gian làm bài phải từ 1 đến 300 phút.',
              isError: true);
          return false;
        }

        final passScore = double.tryParse(passScoreCtrl.text.trim());
        if (passScore == null || passScore < 0 || passScore > 10) {
          _showSnack('Điểm đạt phải là số hợp lệ từ 0 đến 10.', isError: true);
          return false;
        }

        final payload = {
          'TieuDe': title,
          'MoTa': descCtrl.text.trim(),
          'LoaiBoDe': 'THI_CHINH_THUC',
          'MaChuDe': selectedTopicId,
          'ThoiGianLamBai': duration,
          'DiemDatToiThieu': passScore,
          'TrangThai': selectedStatus,
        };

        try {
          if (isEdit) {
            await _api.updateExam(exam['MaBoDe'], payload);
            _showSnack('Đã cập nhật đề thi chính thức.');
          } else {
            await _api.createExam(payload);
            _showSnack('Đã tạo đề thi chính thức mới.');
          }
          return true;
        } catch (e) {
          _showSnack(e.toString(), isError: true);
          return false;
        }
      },
    );

    if (saved == true) _loadData();
  }

  Future _confirmDeleteExam(Map exam) async {
    final confirm = await showModernConfirmDialog(
      context: context,
      title: 'Xóa đề thi chính thức?',
      message: 'Chỉ có thể xóa đề thi chưa có lượt thi nào của thí sinh.',
      highlightText: exam['TieuDe'] ?? '',
      confirmText: 'Xóa đề thi',
    );

    if (confirm != true) return;

    try {
      await _api.deleteExam(exam['MaBoDe']);
      _showSnack('Đã xóa đề thi.');
      _loadData();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 260,
                child: modernFilterDropdown(
                  value: _filterTopicId,
                  hint: 'Tất cả chủ đề',
                  icon: Icons.filter_list_rounded,
                  items: [
                    buildModernDropdownItem(
                      value: null,
                      text: 'Tất cả chủ đề',
                      icon: Icons.apps_rounded,
                      iconColor: const Color(0xFF475569),
                    ),
                    ..._topics.map((t) => buildModernDropdownItem(
                          value: t['MaChuDe'],
                          text: t['TenChuDe'] ?? '',
                          icon: Icons.layers_rounded,
                          iconColor: const Color(0xFF2563EB),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() => _filterTopicId = val as int?);
                    _loadData();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Tổng: ${_exams.length} đề thi',
                style: const TextStyle(
                    color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Tải lại',
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onPressed: _openAutoGenerateDialog,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('Sinh đề tự động'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onPressed: () => _openExamFormDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Tạo thủ công'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _exams.isEmpty
                      ? const Center(
                          child: Text('Chưa có đề thi chính thức nào.'))
                      : AdminScrollableTable(
                          child: DataTable(
                            columnSpacing: 20,
                            headingRowColor: WidgetStateProperty.all(
                                const Color(0xFFF8FAFC)),
                            columns: const [
                              DataColumn(label: Text('Mã')),
                              DataColumn(label: Text('Tên Đề thi')),
                              DataColumn(label: Text('Chủ đề')),
                              DataColumn(label: Text('Thời gian')),
                              DataColumn(label: Text('Cơ cấu câu hỏi')),
                              DataColumn(label: Text('Điểm đạt')),
                              DataColumn(label: Text('Trạng thái')),
                              DataColumn(label: Text('Thao tác')),
                              DataColumn(label: Text('Độ khó & Góp ý')),
                            ],
                            rows: _exams.map((e) {
                              final de = e['SoCauDe'] ?? 0;
                              final tb = e['SoCauTrungBinh'] ?? 0;
                              final kho = e['SoCauKho'] ?? 0;

                              return DataRow(
                                cells: [
                                  DataCell(Text('#${e['MaBoDe']}')),
                                  DataCell(
                                    SizedBox(
                                      width: 210,
                                      child: Text(
                                        e['TieuDe'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 140,
                                      child: Text(
                                        e['TenChuDe'] ?? 'Tổng hợp',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                      Text('${e['ThoiGianLamBai'] ?? 0} phút')),
                                  DataCell(
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${e['SoCauHoi'] ?? 0} câu',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          '$de Dễ · $tb TB · $kho Khó',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                      Text('${e['DiemDatToiThieu']} điểm')),
                                  DataCell(_buildStatusBadge(e['TrangThai'])),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Soạn câu hỏi',
                                          icon: const Icon(
                                            Icons.quiz_outlined,
                                            size: 20,
                                            color: Color(0xFF2563EB),
                                          ),
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ExamQuestionsScreen(
                                                        exam: e),
                                              ),
                                            );
                                            _loadData();
                                          },
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          tooltip: 'Sửa thông tin đề thi',
                                          icon: const Icon(Icons.edit_outlined,
                                              color: Color(0xFF2563EB)),
                                          onPressed: () =>
                                              _openExamFormDialog(exam: e),
                                        ),
                                        IconButton(
                                          tooltip: 'Xóa đề thi',
                                          icon: const Icon(Icons.delete_outline,
                                              color: Color(0xFFDC2626)),
                                          onPressed: () =>
                                              _confirmDeleteExam(e),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _openExamFeedbacksDialog(e),
                                      icon: const Icon(
                                          Icons.rate_review_outlined,
                                          size: 16,
                                          color: Color(0xFFD97706)),
                                      label: Text(
                                        e['DiemDoKhoTrungBinh'] != null
                                            ? '${e['DiemDoKhoTrungBinh']}/5 (${e['SoDanhGia'] ?? 0})'
                                            : 'Chưa có (${e['SoDanhGia'] ?? 0})',
                                        style: const TextStyle(fontSize: 12.5),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
