import 'package:admin/services/admin_api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../widgets/admin_ui_kit.dart';

class ManageQuestionBankScreen extends StatefulWidget {
  const ManageQuestionBankScreen({super.key});

  @override
  State createState() => _ManageQuestionBankScreenState();
}

class _ManageQuestionBankScreenState extends State {
  final _api = AdminApiService();
  final _searchCtrl = TextEditingController();

  List _questions = [];
  List _topics = [];
  List _questionTypes = [];

  int? _filterTopicId;
  String? _filterDifficulty;
  String? _filterStatus;

  Map _summary = {'Tong': 0, 'De': 0, 'TrungBinh': 0, 'Kho': 0};
  int _total = 0;
  int _page = 1;
  final int _limit = 30;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future _initLoad() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getTopics(),
        _api.getQuestionTypes(),
        _api.getQuestions(
          maChuDe: _filterTopicId,
          mucDo: _filterDifficulty,
          trangThai: _filterStatus,
          search: _searchCtrl.text,
          page: _page,
          limit: _limit,
        ),
      ]);
      if (!mounted) return;
      final qData = Map.from(results[2]);
      setState(() {
        _topics = List.from(results[0]);
        _questionTypes = List.from(results[1]);
        _questions = List.from(qData['items'] ?? []);
        _summary = Map.from(
            qData['summary'] ?? {'Tong': 0, 'De': 0, 'TrungBinh': 0, 'Kho': 0});
        _total = qData['total'] ?? 0;
      });
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future _loadQuestions({bool resetPage = false}) async {
    if (resetPage) _page = 1;
    setState(() => _isLoading = true);
    try {
      final qData = await _api.getQuestions(
        maChuDe: _filterTopicId,
        mucDo: _filterDifficulty,
        trangThai: _filterStatus,
        search: _searchCtrl.text,
        page: _page,
        limit: _limit,
      );
      if (!mounted) return;
      setState(() {
        _questions = List.from(qData['items'] ?? []);
        _summary = Map.from(
            qData['summary'] ?? {'Tong': 0, 'De': 0, 'TrungBinh': 0, 'Kho': 0});
        _total = qData['total'] ?? 0;
      });
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  Widget _buildDifficultyBadge(String? code) {
    switch (code) {
      case 'DE':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Dễ',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF15803D)),
          ),
        );
      case 'KHO':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Khó',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFDC2626)),
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Trung bình',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB45309)),
          ),
        );
    }
  }

  Widget _buildKpiCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$count câu',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          subtitle,
                          style: TextStyle(
                              fontSize: 12,
                              color: color,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future _openQuestionDialog({Map? question}) async {
    if (_topics.isEmpty || _questionTypes.isEmpty) {
      _showSnack('Cần có ít nhất 1 Chủ đề và 1 Loại câu hỏi trong hệ thống.',
          isError: true);
      return;
    }

    final isEdit = question != null;
    final contentCtrl =
        TextEditingController(text: isEdit ? (question['NoiDung'] ?? '') : '');

    int selectedTopicId = isEdit
        ? (question['MaChuDe'] ?? _topics.first['MaChuDe'])
        : (_filterTopicId ?? _topics.first['MaChuDe']);

    int selectedTypeId = isEdit
        ? (question['MaLoaiCauHoi'] ?? _questionTypes.first['MaLoaiCauHoi'])
        : _questionTypes.first['MaLoaiCauHoi'];

    String selectedDifficulty = isEdit
        ? (question['MucDo'] ?? 'TRUNG_BINH')
        : (_filterDifficulty ?? 'TRUNG_BINH');
    String selectedStatus =
        isEdit ? (question['TrangThai'] ?? 'HOAT_DONG') : 'HOAT_DONG';
    String? imageUrl = isEdit ? question['HinhAnhUrl'] : null;
    bool isUploadingImg = false;

    final List answerCtrls = [];
    final List answerCorrects = [];

    if (isEdit &&
        question['DapAn'] != null &&
        (question['DapAn'] as List).isNotEmpty) {
      for (final a in (question['DapAn'] as List)) {
        answerCtrls.add(TextEditingController(text: a['NoiDung'] ?? ''));
        answerCorrects.add(a['LaDapAnDung'] == true);
      }
    } else {
      for (int i = 0; i < 4; i++) {
        answerCtrls.add(TextEditingController());
        answerCorrects.add(i == 0);
      }
    }

    bool allowMultiAnswer(int typeId) {
      final found = _questionTypes.firstWhere(
        (t) => t['MaLoaiCauHoi'] == typeId,
        orElse: () => {'ChoPhepNhieuDapAn': false},
      );
      return found['ChoPhepNhieuDapAn'] == true;
    }

    final saved = await showModernModal(
      context: context,
      title: isEdit
          ? 'Chỉnh sửa Câu hỏi #${question['MaCauHoi']}'
          : 'Thêm Câu hỏi vào Ngân hàng',
      subtitle:
          'Câu hỏi sẽ được lưu vào kho chung theo chủ đề và độ khó để dùng sinh đề tự động',
      icon: Icons.help_outline_rounded,
      accentColor: const Color(0xFF2563EB),
      width: 740,
      confirmText: isEdit ? 'Lưu cập nhật' : 'Lưu vào ngân hàng',
      bodyBuilder: (ctx, setDialogState) {
        final isMulti = allowMultiAnswer(selectedTypeId);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: modernDropdownField(
                    value: selectedTopicId,
                    label: 'Chủ đề *',
                    prefixIcon: Icons.layers_outlined,
                    items: _topics.map((t) {
                      return buildModernDropdownItem(
                        value: t['MaChuDe'],
                        text: t['TenChuDe'] ?? '',
                        icon: Icons.layers_rounded,
                        iconColor: const Color(0xFF2563EB),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedTopicId = val as int),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: modernDropdownField(
                    value: selectedTypeId,
                    label: 'Loại câu hỏi *',
                    prefixIcon: Icons.checklist_rounded,
                    items: _questionTypes.map((t) {
                      final multi = t['ChoPhepNhieuDapAn'] == true;
                      return buildModernDropdownItem(
                        value: t['MaLoaiCauHoi'],
                        text: t['TenLoai'] ?? '',
                        icon: multi
                            ? Icons.check_box_outlined
                            : Icons.radio_button_checked_rounded,
                        iconColor: multi
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF0891B2),
                      );
                    }).toList(),
                    onChanged: (val) {
                      final newTypeId = val as int;
                      setDialogState(() {
                        selectedTypeId = newTypeId;
                        if (!allowMultiAnswer(newTypeId)) {
                          int firstTrue = answerCorrects.indexOf(true);
                          for (int i = 0; i < answerCorrects.length; i++) {
                            answerCorrects[i] =
                                (i == (firstTrue >= 0 ? firstTrue : 0));
                          }
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: modernDropdownField(
                    value: selectedDifficulty,
                    label: 'Mức độ câu hỏi *',
                    prefixIcon: Icons.speed_rounded,
                    items: [
                      buildModernDropdownItem(
                        value: 'DE',
                        text: 'Dễ',
                        icon: Icons.signal_cellular_alt_1_bar_rounded,
                        iconColor: const Color(0xFF16A34A),
                      ),
                      buildModernDropdownItem(
                        value: 'TRUNG_BINH',
                        text: 'Trung bình',
                        icon: Icons.signal_cellular_alt_2_bar_rounded,
                        iconColor: const Color(0xFFD97706),
                      ),
                      buildModernDropdownItem(
                        value: 'KHO',
                        text: 'Khó',
                        icon: Icons.signal_cellular_alt_rounded,
                        iconColor: const Color(0xFFDC2626),
                      ),
                    ],
                    onChanged: (val) => setDialogState(
                        () => selectedDifficulty = val as String),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: modernDropdownField(
                    value: selectedStatus,
                    label: 'Trạng thái',
                    prefixIcon: Icons.visibility_outlined,
                    items: [
                      buildModernDropdownItem(
                        value: 'HOAT_DONG',
                        text: 'Hoạt động (Cho phép bốc đề)',
                        icon: Icons.check_circle_outline_rounded,
                        iconColor: const Color(0xFF16A34A),
                      ),
                      buildModernDropdownItem(
                        value: 'AN',
                        text: 'Ẩn câu hỏi',
                        icon: Icons.visibility_off_outlined,
                        iconColor: const Color(0xFF64748B),
                      ),
                    ],
                    onChanged: (val) =>
                        setDialogState(() => selectedStatus = val as String),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentCtrl,
              maxLines: 3,
              decoration: modernInputDecoration(
                label: 'Nội dung đề bài câu hỏi *',
                hint: 'Nhập nội dung câu hỏi chi tiết...',
                prefixIcon: Icons.article_outlined,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: isUploadingImg
                        ? null
                        : () async {
                            final picked = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                              withData: true,
                            );
                            if (picked == null || picked.files.isEmpty) return;
                            final file = picked.files.first;
                            if (file.bytes == null) return;

                            setDialogState(() => isUploadingImg = true);
                            try {
                              final url = await _api.uploadQuestionImage(
                                fileBytes: file.bytes!,
                                fileName: file.name,
                              );
                              setDialogState(() => imageUrl = url);
                            } catch (e) {
                              _showSnack(e.toString(), isError: true);
                            } finally {
                              setDialogState(() => isUploadingImg = false);
                            }
                          },
                    icon: isUploadingImg
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(imageUrl == null
                        ? 'Đính kèm ảnh minh họa'
                        : 'Thay ảnh khác'),
                  ),
                  if (imageUrl != null && imageUrl!.isNotEmpty) ...[
                    const SizedBox(width: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(imageUrl!,
                          width: 84, height: 52, fit: BoxFit.cover),
                    ),
                    IconButton(
                      tooltip: 'Gỡ bỏ ảnh',
                      icon: const Icon(Icons.delete_outline,
                          color: Color(0xFFDC2626)),
                      onPressed: () => setDialogState(() => imageUrl = null),
                    ),
                  ] else ...[
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Không bắt buộc (Hỗ trợ JPG, PNG, WEBP)',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isMulti
                        ? 'Các phương án trả lời (Tích chọn tất cả đáp án đúng):'
                        : 'Các phương án trả lời (Tích chọn 1 đáp án đúng):',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setDialogState(() {
                      answerCtrls.add(TextEditingController());
                      answerCorrects.add(false);
                    });
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Thêm phương án'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < answerCtrls.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: answerCorrects[i] == true
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: answerCorrects[i] == true
                        ? const Color(0xFF86EFAC)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: answerCorrects[i] == true,
                      activeColor: const Color(0xFF16A34A),
                      onChanged: (checked) {
                        setDialogState(() {
                          if (isMulti) {
                            answerCorrects[i] = checked ?? false;
                          } else {
                            for (int j = 0; j < answerCorrects.length; j++) {
                              answerCorrects[j] = (j == i);
                            }
                          }
                        });
                      },
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: answerCorrects[i] == true
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        String.fromCharCode(65 + i),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: answerCorrects[i] == true
                              ? Colors.white
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: answerCtrls[i],
                        decoration: InputDecoration(
                          hintText:
                              'Nhập nội dung phương án ${String.fromCharCode(65 + i)}...',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (answerCtrls.length > 2)
                      IconButton(
                        tooltip: 'Xóa phương án này',
                        icon: const Icon(Icons.close_rounded,
                            color: Color(0xFF94A3B8), size: 20),
                        onPressed: () {
                          setDialogState(() {
                            answerCtrls.removeAt(i);
                            answerCorrects.removeAt(i);
                          });
                        },
                      ),
                  ],
                ),
              ),
          ],
        );
      },
      onConfirm: () async {
        final noiDung = contentCtrl.text.trim();
        if (noiDung.length < 2) {
          _showSnack('Nội dung câu hỏi quá ngắn.', isError: true);
          return false;
        }

        final List dapAnPayload = [];
        for (int i = 0; i < answerCtrls.length; i++) {
          final text = (answerCtrls[i] as TextEditingController).text.trim();
          if (text.isNotEmpty) {
            dapAnPayload.add({
              'NoiDung': text,
              'LaDapAnDung': answerCorrects[i] == true,
              'ThuTuHienThi': dapAnPayload.length + 1,
            });
          }
        }

        if (dapAnPayload.length < 2) {
          _showSnack('Vui lòng nhập ít nhất 2 phương án có nội dung.',
              isError: true);
          return false;
        }

        if (!dapAnPayload.any((a) => a['LaDapAnDung'] == true)) {
          _showSnack('Vui lòng đánh dấu ít nhất 1 đáp án đúng.', isError: true);
          return false;
        }

        final payload = {
          'MaChuDe': selectedTopicId,
          'MaLoaiCauHoi': selectedTypeId,
          'NoiDung': noiDung,
          'HinhAnhUrl': imageUrl,
          'MucDo': selectedDifficulty,
          'TrangThai': selectedStatus,
          'DapAn': dapAnPayload,
        };

        try {
          if (isEdit) {
            await _api.updateQuestion(question['MaCauHoi'], payload);
            _showSnack('Đã cập nhật câu hỏi.');
          } else {
            await _api.createQuestionInBank(payload);
            _showSnack('Đã thêm câu hỏi vào ngân hàng.');
          }
          return true;
        } catch (e) {
          _showSnack(e.toString(), isError: true);
          return false;
        }
      },
    );

    if (saved == true) _loadQuestions();
  }

  Future _confirmDeleteQuestion(Map q) async {
    final confirm = await showModernConfirmDialog(
      context: context,
      title: 'Xóa câu hỏi khỏi Ngân hàng?',
      message:
          'Chỉ có thể xóa câu hỏi chưa nằm trong bộ đề nào và chưa có thí sinh làm bài.',
      highlightText: q['NoiDung'] ?? '',
      confirmText: 'Xóa vĩnh viễn',
    );

    if (confirm != true) return;

    try {
      await _api.deleteQuestionFromBank(q['MaCauHoi']);
      _showSnack('Đã xóa câu hỏi khỏi ngân hàng.');
      _loadQuestions();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_total / _limit).ceil().clamp(1, 9999);
    final tong = (_summary['Tong'] ?? 0) as int;
    final de = (_summary['De'] ?? 0) as int;
    final tb = (_summary['TrungBinh'] ?? 0) as int;
    final kho = (_summary['Kho'] ?? 0) as int;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _buildKpiCard(
                title: _filterTopicId == null
                    ? 'Tổng kho câu hỏi'
                    : 'Tổng câu hỏi chủ đề',
                count: tong,
                icon: Icons.inventory_2_outlined,
                color: const Color(0xFF2563EB),
              ),
              const SizedBox(width: 14),
              _buildKpiCard(
                title: 'Mức độ Dễ',
                count: de,
                icon: Icons.signal_cellular_alt_1_bar_rounded,
                color: const Color(0xFF16A34A),
                subtitle: tong > 0 ? '${(de * 100 / tong).round()}%' : null,
              ),
              const SizedBox(width: 14),
              _buildKpiCard(
                title: 'Mức độ Trung bình',
                count: tb,
                icon: Icons.signal_cellular_alt_2_bar_rounded,
                color: const Color(0xFFD97706),
                subtitle: tong > 0 ? '${(tb * 100 / tong).round()}%' : null,
              ),
              const SizedBox(width: 14),
              _buildKpiCard(
                title: 'Mức độ Khó',
                count: kho,
                icon: Icons.signal_cellular_alt_rounded,
                color: const Color(0xFFDC2626),
                subtitle: tong > 0 ? '${(kho * 100 / tong).round()}%' : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 240,
                child: modernFilterDropdown(
                  value: _filterTopicId,
                  hint: 'Tất cả chủ đề',
                  icon: Icons.layers_outlined,
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
                    _loadQuestions(resetPage: true);
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 185,
                child: modernFilterDropdown(
                  value: _filterDifficulty,
                  hint: 'Tất cả mức độ',
                  icon: Icons.speed_rounded,
                  items: [
                    buildModernDropdownItem(
                      value: null,
                      text: 'Tất cả mức độ',
                      icon: Icons.tune_rounded,
                      iconColor: const Color(0xFF475569),
                    ),
                    buildModernDropdownItem(
                      value: 'DE',
                      text: 'Mức độ Dễ',
                      icon: Icons.signal_cellular_alt_1_bar_rounded,
                      iconColor: const Color(0xFF16A34A),
                    ),
                    buildModernDropdownItem(
                      value: 'TRUNG_BINH',
                      text: 'Trung bình',
                      icon: Icons.signal_cellular_alt_2_bar_rounded,
                      iconColor: const Color(0xFFD97706),
                    ),
                    buildModernDropdownItem(
                      value: 'KHO',
                      text: 'Mức độ Khó',
                      icon: Icons.signal_cellular_alt_rounded,
                      iconColor: const Color(0xFFDC2626),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() => _filterDifficulty = val as String?);
                    _loadQuestions(resetPage: true);
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 240,
                height: 44,
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _loadQuestions(resetPage: true),
                  decoration: InputDecoration(
                    hintText: 'Tìm nội dung câu hỏi...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Tải lại',
                onPressed: () => _loadQuestions(),
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
                onPressed: () => _openQuestionDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Thêm Câu hỏi vào Kho'),
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
                  : _questions.isEmpty
                      ? const Center(
                          child:
                              Text('Chưa có câu hỏi nào phù hợp với bộ lọc.'))
                      : AdminScrollableTable(
                          child: DataTable(
                            columnSpacing: 20,
                            headingRowColor: WidgetStateProperty.all(
                                const Color(0xFFF8FAFC)),
                            columns: const [
                              DataColumn(label: Text('Mã')),
                              DataColumn(label: Text('Nội dung câu hỏi')),
                              DataColumn(label: Text('Chủ đề')),
                              DataColumn(label: Text('Mức độ')),
                              DataColumn(label: Text('Đáp án đúng')),
                              DataColumn(label: Text('Sử dụng')),
                              DataColumn(label: Text('Thao tác')),
                            ],
                            rows: _questions.map((q) {
                              final answers = List.from(q['DapAn'] ?? []);
                              final correctAns = answers
                                  .where((a) => a['LaDapAnDung'] == true)
                                  .map((a) => a['NoiDung'] ?? '')
                                  .join(' | ');
                              final usedCount = q['SoBoDeSuDung'] ?? 0;

                              return DataRow(
                                cells: [
                                  DataCell(Text('#${q['MaCauHoi']}')),
                                  DataCell(
                                    SizedBox(
                                      width: 280,
                                      child: Text(
                                        q['NoiDung'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 140,
                                      child: Text(
                                        q['TenChuDe'] ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(_buildDifficultyBadge(q['MucDo'])),
                                  DataCell(
                                    SizedBox(
                                      width: 180,
                                      child: Text(
                                        correctAns.isEmpty ? '—' : correctAns,
                                        style: const TextStyle(
                                          color: Color(0xFF15803D),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: usedCount > 0
                                            ? const Color(0xFFDBEAFE)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        usedCount > 0
                                            ? '$usedCount bộ đề'
                                            : 'Chưa dùng',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: usedCount > 0
                                              ? const Color(0xFF1D4ED8)
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Sửa câu hỏi',
                                          icon: const Icon(Icons.edit_outlined,
                                              color: Color(0xFF2563EB)),
                                          onPressed: () =>
                                              _openQuestionDialog(question: q),
                                        ),
                                        IconButton(
                                          tooltip: 'Xóa câu hỏi khỏi kho',
                                          icon: const Icon(Icons.delete_outline,
                                              color: Color(0xFFDC2626)),
                                          onPressed: () =>
                                              _confirmDeleteQuestion(q),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                  'Hiển thị ${_questions.length} / $_total câu • Trang $_page / $totalPages'),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _page > 1
                    ? () {
                        setState(() => _page--);
                        _loadQuestions();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: _page < totalPages
                    ? () {
                        setState(() => _page++);
                        _loadQuestions();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
