import 'package:admin/services/admin_api_service.dart';
import 'package:flutter/material.dart';
import '../widgets/admin_ui_kit.dart';

class ManageTopicsScreen extends StatefulWidget {
  const ManageTopicsScreen({super.key});

  @override
  State createState() => _ManageTopicsScreenState();
}

class _ManageTopicsScreenState extends State {
  final _api = AdminApiService();
  List _topics = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future _loadTopics() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getTopics();
      if (!mounted) return;
      setState(() => _topics = data);
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

  Future _openTopicFormDialog({Map? topic}) async {
    final isEdit = topic != null;
    final nameCtrl =
        TextEditingController(text: isEdit ? (topic['TenChuDe'] ?? '') : '');
    final descCtrl =
        TextEditingController(text: isEdit ? (topic['MoTa'] ?? '') : '');

    final saved = await showModernModal(
      context: context,
      title: isEdit ? 'Chỉnh sửa Chủ đề' : 'Thêm Chủ đề mới',
      subtitle: isEdit
          ? 'Cập nhật thông tin danh mục chủ đề ôn tập'
          : 'Phân loại kiến thức cho ngân hàng câu hỏi và bộ đề',
      icon: isEdit ? Icons.edit_note_rounded : Icons.layers_rounded,
      accentColor: const Color(0xFF2563EB),
      width: 480,
      confirmText: isEdit ? 'Lưu thay đổi' : 'Tạo chủ đề',
      bodyBuilder: (ctx, setModalState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: modernInputDecoration(
              label: 'Tên chủ đề *',
              hint: 'VD: Mạng máy tính căn bản',
              prefixIcon: Icons.bookmark_border_rounded,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: descCtrl,
            maxLines: 3,
            decoration: modernInputDecoration(
              label: 'Mô tả ngắn',
              hint: 'Nhập nội dung mô tả phạm vi kiến thức của chủ đề...',
              prefixIcon: Icons.notes_rounded,
            ),
          ),
        ],
      ),
      onConfirm: () async {
        final name = nameCtrl.text.trim();
        if (name.length < 2) {
          _showSnack('Tên chủ đề phải có ít nhất 2 ký tự.', isError: true);
          return false;
        }

        try {
          if (isEdit) {
            await _api.updateTopic(
              maChuDe: topic['MaChuDe'],
              tenChuDe: name,
              moTa: descCtrl.text.trim(),
            );
            _showSnack('Đã cập nhật chủ đề.');
          } else {
            await _api.createTopic(
              tenChuDe: name,
              moTa: descCtrl.text.trim(),
            );
            _showSnack('Đã tạo chủ đề mới.');
          }
          return true;
        } catch (e) {
          _showSnack(e.toString(), isError: true);
          return false;
        }
      },
    );

    if (saved == true) _loadTopics();
  }

  Future _confirmDeleteTopic(Map topic) async {
    final confirm = await showModernConfirmDialog(
      context: context,
      title: 'Xóa chủ đề này?',
      message:
          'Chỉ có thể xóa chủ đề khi không còn bộ đề hoặc câu hỏi nào trực thuộc.',
      highlightText: topic['TenChuDe'] ?? '',
      confirmText: 'Xóa chủ đề',
    );

    if (confirm != true) return;

    try {
      await _api.deleteTopic(topic['MaChuDe']);
      _showSnack('Đã xóa chủ đề.');
      _loadTopics();
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
              Text(
                'Tổng số chủ đề: ${_topics.length}',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569)),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Tải lại',
                onPressed: _loadTopics,
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
                onPressed: () => _openTopicFormDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Thêm Chủ đề mới'),
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
                  : _topics.isEmpty
                      ? const Center(
                          child: Text(
                              'Chưa có chủ đề nào. Hãy bấm "Thêm Chủ đề mới".'))
                      : AdminScrollableTable(
                          child: DataTable(
                            columnSpacing: 26,
                            headingRowColor: WidgetStateProperty.all(
                                const Color(0xFFF8FAFC)),
                            columns: const [
                              DataColumn(label: Text('Mã')),
                              DataColumn(label: Text('Tên Chủ đề')),
                              DataColumn(label: Text('Mô tả')),
                              DataColumn(label: Text('Đề ôn tập')),
                              DataColumn(label: Text('Đề thi')),
                              DataColumn(label: Text('Kho câu hỏi (Độ khó)')),
                              DataColumn(label: Text('Thao tác')),
                            ],
                            rows: _topics.map((t) {
                              final de = t['SoCauDe'] ?? 0;
                              final tb = t['SoCauTrungBinh'] ?? 0;
                              final kho = t['SoCauKho'] ?? 0;

                              return DataRow(
                                cells: [
                                  DataCell(Text('#${t['MaChuDe']}')),
                                  DataCell(
                                    Text(
                                      t['TenChuDe'] ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 220,
                                      child: Text(
                                        (t['MoTa'] ?? '').toString().isEmpty
                                            ? '—'
                                            : t['MoTa'],
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text('${t['SoDeOnTap'] ?? 0} bộ')),
                                  DataCell(Text('${t['SoDeThi'] ?? 0} đề')),
                                  DataCell(
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${t['SoCauHoi'] ?? 0} câu',
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
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Sửa chủ đề',
                                          icon: const Icon(Icons.edit_outlined,
                                              color: Color(0xFF2563EB)),
                                          onPressed: () =>
                                              _openTopicFormDialog(topic: t),
                                        ),
                                        IconButton(
                                          tooltip: 'Xóa chủ đề',
                                          icon: const Icon(Icons.delete_outline,
                                              color: Color(0xFFDC2626)),
                                          onPressed: () =>
                                              _confirmDeleteTopic(t),
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
        ],
      ),
    );
  }
}
