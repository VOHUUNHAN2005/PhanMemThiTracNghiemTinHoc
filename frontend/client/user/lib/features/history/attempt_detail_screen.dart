import 'package:flutter/material.dart';
import 'package:user/core/constants/api_constants.dart';
import 'package:user/core/models/attempt_history_model.dart';
import 'package:user/core/services/user_service.dart';

class AttemptDetailScreen extends StatefulWidget {
  final int maLuotLam;
  final String? fallbackTitle;

  const AttemptDetailScreen({
    super.key,
    required this.maLuotLam,
    this.fallbackTitle,
  });

  @override
  State<AttemptDetailScreen> createState() => _AttemptDetailScreenState();
}

class _AttemptDetailScreenState extends State<AttemptDetailScreen> {
  final UserService _userService = UserService();
  AttemptDetailModel? _detail;
  bool _isLoading = true;
  String? _error;
  String _filter = 'ALL'; // ALL | CORRECT | WRONG | UNANSWERED

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _userService.getAttemptDetail(widget.maLuotLam);
      if (mounted) {
        setState(() => _detail = data);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    return '${m}p ${s.toString().padLeft(2, '0')}s';
  }

  String _resolveImageUrl(String? rawUrl) {
    final url = (rawUrl ?? '').trim();
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '${ApiConstants.baseUrl}$url';
    return '${ApiConstants.baseUrl}/$url';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF172554),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _detail?.tenBoDe ?? widget.fallbackTitle ?? 'Chi tiết bài làm',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadDetail,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final detail = _detail!;
    final filteredQuestions = detail.danhSachCauHoi.where((q) {
      if (_filter == 'CORRECT') return q.traLoiDung;
      if (_filter == 'WRONG') return q.daTraLoi && !q.traLoiDung;
      if (_filter == 'UNANSWERED') return !q.daTraLoi;
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: SizedBox(
          width: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card tổng quan kết quả
              Container(
                padding: const EdgeInsets.all(18),
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
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              detail.loaiBoDe == 'THI_CHINH_THUC'
                                  ? 'THI CHÍNH THỨC'
                                  : 'ÔN TẬP',
                              style: const TextStyle(
                                color: Color(0xFF1D5CE5),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Điểm số: ${detail.diemSo.toStringAsFixed(1)} / 10',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: detail.daDat
                                ? const Color(0xFFD1FAE5)
                                : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            detail.daDat ? 'ĐẠT' : 'CHƯA ĐẠT',
                            style: TextStyle(
                              color: detail.daDat
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFFB91C1C),
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          'Đúng',
                          '${detail.soCauDung}',
                          const Color(0xFF16A34A),
                        ),
                        _buildStatItem(
                          'Sai',
                          '${detail.soCauSai}',
                          const Color(0xFFDC2626),
                        ),
                        _buildStatItem(
                          'Chưa làm',
                          '${detail.soCauChuaLam}',
                          const Color(0xFF64748B),
                        ),
                        _buildStatItem(
                          'Thời gian',
                          _formatDuration(detail.thoiGianLamGiay),
                          const Color(0xFF1D5CE5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Bộ lọc câu hỏi
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      'ALL',
                      'Tất cả (${detail.danhSachCauHoi.length})',
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'CORRECT',
                      'Đúng (${detail.soCauDung})',
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'WRONG',
                      'Sai (${detail.soCauSai})',
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'UNANSWERED',
                      'Chưa làm (${detail.soCauChuaLam})',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Danh sách từng câu
              ...List.generate(filteredQuestions.length, (idx) {
                final q = filteredQuestions[idx];
                final originalIndex = detail.danhSachCauHoi.indexOf(q) + 1;
                return _buildQuestionCard(q, originalIndex);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final selected = _filter == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFF1D5CE5),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF334155),
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
      ),
      onSelected: (_) => setState(() => _filter = key),
    );
  }

  Widget _buildQuestionCard(AttemptQuestionReview q, int index) {
    const labels = ['A', 'B', 'C', 'D', 'E', 'F'];
    final imgUrl = _resolveImageUrl(q.hinhAnhUrl);

    Color statusColor;
    String statusText;
    if (q.traLoiDung) {
      statusColor = const Color(0xFF16A34A);
      statusText = 'Trả lời đúng';
    } else if (!q.daTraLoi) {
      statusColor = const Color(0xFF64748B);
      statusText = 'Chưa trả lời';
    } else {
      statusColor = const Color(0xFFDC2626);
      statusText = 'Trả lời sai';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Câu $index',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            q.noiDung,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          if (imgUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(imgUrl, fit: BoxFit.contain),
            ),
          ],
          const SizedBox(height: 12),
          ...List.generate(q.dapAn.length, (i) {
            final opt = q.dapAn[i];
            final prefix = i < labels.length ? '${labels[i]}. ' : '';

            Color bg = const Color(0xFFF8FAFC);
            Color border = const Color(0xFFE2E8F0);
            IconData? trailingIcon;
            Color? iconColor;

            if (opt.laDapAnDung) {
              bg = const Color(0xFFDCFCE7);
              border = const Color(0xFF16A34A);
              trailingIcon = Icons.check_circle_rounded;
              iconColor = const Color(0xFF16A34A);
            } else if (opt.nguoiDungChon && !opt.laDapAnDung) {
              bg = const Color(0xFFFEE2E2);
              border = const Color(0xFFDC2626);
              trailingIcon = Icons.cancel_rounded;
              iconColor = const Color(0xFFDC2626);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$prefix${opt.noiDung}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: (opt.laDapAnDung || opt.nguoiDungChon)
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: 8),
                    Icon(trailingIcon, color: iconColor, size: 20),
                  ],
                ],
              ),
            );
          }),
          if (q.giaiThich != null && q.giaiThich!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Giải thích: ${q.giaiThich!}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}