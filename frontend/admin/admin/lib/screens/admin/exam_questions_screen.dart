import 'package:admin/services/admin_api_service.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/admin_ui_kit.dart';

class ExamQuestionsScreen extends StatefulWidget {
  final Map exam;

  const ExamQuestionsScreen({
    super.key,
    required this.exam,
  });

  @override
  State createState() => _ExamQuestionsScreenState();
}

class _ExamQuestionsScreenState extends State {
  final _api = AdminApiService();

  Map get _exam => (widget as ExamQuestionsScreen).exam;

  List _questions = [];
  List _topics = [];
  List _questionTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future _initData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getExamQuestions(_exam['MaBoDe']),
        _api.getTopics(),
        _api.getQuestionTypes(),
      ]);
      if (!mounted) return;
      setState(() {
        _questions = List.from(results[0]);
        _topics = List.from(results[1]);
        _questionTypes = List.from(results[2]);
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

  String _formatDifficulty(String? code) {
    switch (code) {
      case 'DE':
        return 'Dễ';
      case 'KHO':
        return 'Khó';
      default:
        return 'Trung bình';
    }
  }

  Future _openPickFromBankDialog() async {
    final int? lockedTopicId = _exam['MaChuDe'] as int?;
    int? filterTopicId = lockedTopicId;
    String? filterDifficulty;
    final searchCtrl = TextEditingController();

    List bankItems = [];
    bool loadingBank = true;
    bool initialized = false;
    final Set<int> selectedIds = {};
    final Set<int> existingIds =
        _questions.map<int>((q) => q['MaCauHoi'] as int).toSet();

    Future<void> fetchBank(void Function(void Function()) setModalState) async {
      setModalState(() => loadingBank = true);
      try {
        final res = await _api.getQuestions(
          maChuDe: lockedTopicId ?? filterTopicId,
          mucDo: filterDifficulty,
          trangThai: 'HOAT_DONG',
          search: searchCtrl.text,
          page: 1,
          limit: 150,
        );
        setModalState(() {
          bankItems = List.from(res['items'] ?? []);
          loadingBank = false;
        });
      } catch (e) {
        setModalState(() => loadingBank = false);
        _showSnack(e.toString(), isError: true);
      }
    }

    final saved = await showModernModal(
      context: context,
      title: 'Chọn câu hỏi từ Ngân hàng',
      subtitle: lockedTopicId != null
          ? 'Chỉ hiển thị các câu hỏi thuộc chủ đề: ${_exam['TenChuDe'] ?? ''}'
          : 'Đề tổng hợp: Chọn câu hỏi từ các chủ đề trong ngân hàng',
      icon: Icons.inventory_2_rounded,
      accentColor: const Color(0xFF4F46E5),
      width: 820,
      confirmText: 'Thêm các câu đã chọn',
      bodyBuilder: (ctx, setModalState) {
        if (!initialized) {
          initialized = true;
          Future.microtask(() => fetchBank(setModalState));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: lockedTopicId != null
                      ? Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_outline_rounded,
                                  size: 17, color: Color(0xFF475569)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _exam['TenChuDe'] ?? 'Chủ đề cố định',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                    color: Color(0xFF334155),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )
                      : modernFilterDropdown(
                          value: filterTopicId,
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
                            filterTopicId = val as int?;
                            fetchBank(setModalState);
                          },
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: modernFilterDropdown(
                    value: filterDifficulty,
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
                    onChanged: (val) {
                      filterDifficulty = val as String?;
                      fetchBank(setModalState);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      controller: searchCtrl,
                      onSubmitted: (_) => fetchBank(setModalState),
                      decoration: InputDecoration(
                        hintText: 'Tìm nội dung câu hỏi & Enter...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search_rounded, size: 18),
                          onPressed: () => fetchBank(setModalState),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 18, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 8),
                  Text(
                    'Đã chọn ${selectedIds.length} câu hỏi mới để thêm vào đề',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF3730A3)),
                  ),
                  const Spacer(),
                  if (selectedIds.isNotEmpty)
                    TextButton(
                      onPressed: () => setModalState(() => selectedIds.clear()),
                      child: const Text('Bỏ chọn tất cả'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 360,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: loadingBank
                  ? const Center(child: CircularProgressIndicator())
                  : bankItems.isEmpty
                      ? const Center(
                          child: Text(
                              'Không tìm thấy câu hỏi phù hợp trong chủ đề này.'))
                      : ListView.separated(
                          itemCount: bankItems.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, idx) {
                            final item = bankItems[idx];
                            final int qId = item['MaCauHoi'];
                            final bool alreadyInExam =
                                existingIds.contains(qId);
                            final bool isChecked = selectedIds.contains(qId);

                            return CheckboxListTile(
                              value: alreadyInExam ? true : isChecked,
                              enabled: !alreadyInExam,
                              activeColor: const Color(0xFF4F46E5),
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (checked) {
                                setModalState(() {
                                  if (checked == true) {
                                    selectedIds.add(qId);
                                  } else {
                                    selectedIds.remove(qId);
                                  }
                                });
                              },
                              title: Text(
                                '#$qId. ${item['NoiDung'] ?? ''}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: alreadyInExam
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Text(
                                      '${item['TenChuDe'] ?? ''} • Mức độ: ${_formatDifficulty(item['MucDo'])}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B)),
                                    ),
                                    if (alreadyInExam) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Đã có trong đề',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF15803D),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        );
      },
      onConfirm: () async {
        if (selectedIds.isEmpty) {
          _showSnack('Vui lòng tích chọn ít nhất 1 câu hỏi từ ngân hàng.',
              isError: true);
          return false;
        }
        try {
          final res = await _api.attachQuestionsToExam(
              _exam['MaBoDe'], selectedIds.toList());
          _showSnack(res['message'] ?? 'Đã thêm câu hỏi vào bộ đề.');
          return true;
        } catch (e) {
          _showSnack(e.toString(), isError: true);
          return false;
        }
      },
    );

    if (saved == true) _initData();
  }

  Future _openQuestionDialog({Map? question}) async {
    if (_topics.isEmpty || _questionTypes.isEmpty) {
      _showSnack('Cần có ít nhất 1 Chủ đề và 1 Loại câu hỏi trong hệ thống.',
          isError: true);
      return;
    }

    final isEdit = question != null;
    final int? lockedTopicId = _exam['MaChuDe'] as int?;
    final contentCtrl =
        TextEditingController(text: isEdit ? (question['NoiDung'] ?? '') : '');

    int selectedTopicId = isEdit
        ? (question['MaChuDe'] ?? lockedTopicId ?? _topics.first['MaChuDe'])
        : (lockedTopicId ?? _topics.first['MaChuDe']);

    int selectedTypeId = isEdit
        ? (question['MaLoaiCauHoi'] ?? _questionTypes.first['MaLoaiCauHoi'])
        : _questionTypes.first['MaLoaiCauHoi'];

    String selectedDifficulty =
        isEdit ? (question['MucDo'] ?? 'TRUNG_BINH') : 'TRUNG_BINH';
    String selectedStatus =
        isEdit ? (question['TrangThai'] ?? 'HOAT_DONG') : 'HOAT_DONG';
    String? imageUrl = isEdit ? question['HinhAnhUrl'] : null;
    bool isUploadingImg = false;
    String? validationError;

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
          : 'Soạn Câu hỏi mới',
      subtitle: 'Thuộc bộ đề: ${_exam['TieuDe'] ?? ''}',
      icon: Icons.help_outline_rounded,
      accentColor: const Color(0xFF2563EB),
      width: 740,
      confirmText: isEdit ? 'Lưu cập nhật' : 'Thêm câu hỏi',
      bodyBuilder: (ctx, setDialogState) {
        final isMulti = allowMultiAnswer(selectedTypeId);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (validationError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        validationError!,
                        style: const TextStyle(
                            color: Color(0xFF991B1B),
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: lockedTopicId != null
                      ? InputDecorator(
                          decoration: modernInputDecoration(
                            label: 'Chủ đề (Cố định theo bộ đề)',
                            prefixIcon: Icons.lock_outline_rounded,
                          ).copyWith(
                              fillColor: const Color(0xFFF1F5F9), filled: true),
                          child: Text(
                            _exam['TenChuDe'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155)),
                          ),
                        )
                      : modernDropdownField(
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
                          onChanged: (val) => setDialogState(
                              () => selectedTopicId = val as int),
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
                    label: 'Mức độ câu hỏi',
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
                        text: 'Hoạt động',
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
              onChanged: (_) {
                if (validationError != null)
                  setDialogState(() => validationError = null);
              },
              decoration: modernInputDecoration(
                label: 'Nội dung đề bài câu hỏi * (Tối thiểu 5 ký tự)',
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
                          validationError = null;
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
                        onChanged: (_) {
                          if (validationError != null)
                            setDialogState(() => validationError = null);
                        },
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
        if (noiDung.length < 5) {
          _showSnack('Nội dung câu hỏi phải có ít nhất 5 ký tự.',
              isError: true);
          return false;
        }

        final List dapAnPayload = [];
        final Set<String> seenAnswers = {};
        for (int i = 0; i < answerCtrls.length; i++) {
          final text = (answerCtrls[i] as TextEditingController).text.trim();
          if (text.isNotEmpty) {
            final normalized = text.toLowerCase();
            if (seenAnswers.contains(normalized)) {
              _showSnack(
                  'Nội dung các phương án trả lời không được trùng nhau ("$text").',
                  isError: true);
              return false;
            }
            seenAnswers.add(normalized);
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
          'MaChuDe': lockedTopicId ?? selectedTopicId,
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
            await _api.createQuestionInExam(_exam['MaBoDe'], payload);
            _showSnack('Đã thêm câu hỏi vào bộ đề.');
          }
          return true;
        } catch (e) {
          _showSnack(e.toString(), isError: true);
          return false;
        }
      },
    );

    if (saved == true) _initData();
  }

  Future _swapQuestion(Map q) async {
    try {
      final res = await _api.swapQuestionInExam(_exam['MaBoDe'], q['MaCauHoi']);
      _showSnack(res['message'] ?? 'Đã tráo đổi câu hỏi.');
      _initData();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
  }

  Future _confirmRemoveQuestion(Map q) async {
    final confirm = await showModernConfirmDialog(
      context: context,
      title: 'Gỡ câu hỏi khỏi bộ đề?',
      message:
          'Câu hỏi này sẽ được gỡ khỏi danh sách câu hỏi của bộ đề hiện tại.',
      highlightText: q['NoiDung'] ?? '',
      confirmText: 'Xác nhận gỡ',
    );

    if (confirm != true) return;

    try {
      await _api.deleteQuestionFromExam(_exam['MaBoDe'], q['MaCauHoi']);
      _showSnack('Đã gỡ câu hỏi khỏi bộ đề.');
      _initData();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        title: Text(
            'Soạn câu hỏi: ${_exam['TieuDe'] ?? ''} (${_questions.length} câu)'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
              ),
              onPressed: _openPickFromBankDialog,
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              label: const Text('Chọn từ Ngân hàng'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              onPressed: () => _openQuestionDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Soạn câu hỏi mới'),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _questions.isEmpty
              ? const Center(
                  child: Text(
                      'Bộ đề này chưa có câu hỏi nào. Hãy chọn từ Ngân hàng hoặc Soạn câu hỏi mới.'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: _questions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (ctx, idx) {
                    final q = _questions[idx];
                    final answers = List.from(q['DapAn'] ?? []);
                    final imgUrl = (q['HinhAnhUrl'] ?? '').toString();

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Câu ${idx + 1} (#${q['MaCauHoi']})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(q['TenLoai'] ?? '',
                                    style: const TextStyle(fontSize: 12)),
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(
                                  'Mức độ: ${_formatDifficulty(q['MucDo'])}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Tráo đổi sang câu khác cùng mức độ',
                                icon: const Icon(Icons.swap_horiz_rounded,
                                    color: Color(0xFF4F46E5)),
                                onPressed: () => _swapQuestion(q),
                              ),
                              IconButton(
                                tooltip: 'Sửa câu hỏi',
                                icon: const Icon(Icons.edit_outlined,
                                    color: Color(0xFF2563EB)),
                                onPressed: () =>
                                    _openQuestionDialog(question: q),
                              ),
                              IconButton(
                                tooltip: 'Gỡ khỏi bộ đề',
                                icon: const Icon(Icons.delete_outline,
                                    color: Color(0xFFDC2626)),
                                onPressed: () => _confirmRemoveQuestion(q),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            q['NoiDung'] ?? '',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          if (imgUrl.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(imgUrl,
                                  height: 150, fit: BoxFit.contain),
                            ),
                          ],
                          const SizedBox(height: 12),
                          ...answers.asMap().entries.map((entry) {
                            final aIdx = entry.key;
                            final ans = entry.value;
                            final isCorrect = ans['LaDapAnDung'] == true;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isCorrect
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isCorrect
                                      ? const Color(0xFF86EFAC)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isCorrect
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    size: 18,
                                    color: isCorrect
                                        ? const Color(0xFF16A34A)
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${String.fromCharCode(65 + aIdx)}. ${ans['NoiDung'] ?? ''}',
                                      style: TextStyle(
                                        fontWeight: isCorrect
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isCorrect
                                            ? const Color(0xFF14532D)
                                            : const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
