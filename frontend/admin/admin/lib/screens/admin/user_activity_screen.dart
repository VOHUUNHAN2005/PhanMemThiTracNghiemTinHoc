import 'package:admin/services/admin_api_service.dart';
import 'package:flutter/material.dart';
import '../widgets/admin_ui_kit.dart';

class UserActivityScreen extends StatefulWidget {
  final Map user;

  const UserActivityScreen({super.key, required this.user});

  @override
  State<UserActivityScreen> createState() => _UserActivityScreenState();
}

class _UserActivityScreenState extends State<UserActivityScreen>
    with SingleTickerProviderStateMixin {
  final _api = AdminApiService();
  late TabController _tabController;

  bool _isLoading = true;
  Map _userInfo = {};
  Map _summary = {};
  List _attempts = [];
  List _cupHistory = [];
  String _attemptFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _userInfo = Map.from(widget.user);
    _loadActivity();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadActivity() async {
    setState(() => _isLoading = true);
    try {
      final data =
          await _api.getUserActivityHistory(widget.user['MaNguoiDung']);
      if (!mounted) return;
      setState(() {
        _userInfo = Map.from(data['user'] ?? widget.user);
        _summary = Map.from(data['summary'] ?? {});
        _attempts = List.from(data['attempts'] ?? []);
        _cupHistory = List.from(data['cup_history'] ?? []);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFDC2626)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final y = dt.year;
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$d/$m/$y $h:$min';
    } catch (_) {
      return iso;
    }
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds < 0) return '—';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    return '${m}p ${s}s';
  }

  String _formatCupType(String? code) {
    switch (code) {
      case 'THI_CHINH_THUC_DAT':
      case 'THUONG_LAM_BAI':
      case 'HOAN_THANH_DE':
        return 'Thi chính thức đạt';
      case 'THANG_1VS1':
        return 'Đấu trường 1vs1 (Thắng)';
      case 'THUA_1VS1':
        return 'Đấu trường 1vs1 (Thua)';
      case 'GIAI_DAU_NN':
        return 'Giải đấu nhiều người';
      case 'PHAT_GIAN_LAN':
        return 'Vi phạm / Gian lận';
      case 'HOAN_PHAT':
        return 'Hoàn phạt cúp';
      case 'ADMIN_DIEU_CHINH':
      case 'ADMIN_CONG_TRU':
        return 'Admin điều chỉnh';
      default:
        return code ?? 'Biến động cúp';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredAttempts = _attempts.where((a) {
      if (_attemptFilter == 'ALL') return true;
      return a['LoaiBoDe'] == _attemptFilter;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lịch sử hoạt động: ${_userInfo['HoTen'] ?? 'Thí sinh'}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_userInfo['Email'] ?? ''} • ID #${_userInfo['MaNguoiDung']}',
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại dữ liệu',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadActivity,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _buildKpiCard(
                        title: 'Tổng lượt tham gia',
                        value: '${_summary['total_attempts'] ?? 0} lượt',
                        subtitle:
                            '${_summary['practice_count'] ?? 0} ôn tập · ${_summary['exam_count'] ?? 0} thi chính thức',
                        icon: Icons.assignment_turned_in_rounded,
                        color: const Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 16),
                      _buildKpiCard(
                        title: 'Điểm trung bình',
                        value: '${_summary['avg_score'] ?? 0.0} / 10',
                        subtitle:
                            'Tính trên ${_summary['completed_count'] ?? 0} bài đã nộp',
                        icon: Icons.analytics_rounded,
                        color: const Color(0xFF7C3AED),
                      ),
                      const SizedBox(width: 16),
                      _buildKpiCard(
                        title: 'Số bài đạt yêu cầu',
                        value:
                            '${_summary['passed_count'] ?? 0} / ${_summary['completed_count'] ?? 0}',
                        subtitle: 'Đạt ngưỡng điểm tối thiểu của đề',
                        icon: Icons.verified_rounded,
                        color: const Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 16),
                      _buildKpiCard(
                        title: 'Số cúp & Bậc hạng',
                        value:
                            '${_userInfo['SoCup'] ?? _userInfo['SoCupHienTai'] ?? 0} 🏆 - Hạng ${_userInfo['TenHang'] ?? 'Đồng'}',
                        subtitle: '· ${_cupHistory.length} lần biến động',
                        icon: Icons.emoji_events_rounded,
                        color: const Color(0xFFD97706),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              labelColor: const Color(0xFF2563EB),
                              unselectedLabelColor: const Color(0xFF64748B),
                              indicatorColor: const Color(0xFF2563EB),
                              indicatorWeight: 3,
                              labelStyle: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                              tabs: [
                                Tab(
                                  icon:
                                      const Icon(Icons.quiz_outlined, size: 18),
                                  text: 'Lịch sử làm bài (${_attempts.length})',
                                ),
                                Tab(
                                  icon: const Icon(Icons.emoji_events_outlined,
                                      size: 18),
                                  text:
                                      'Lịch sử nhận / trừ cúp (${_cupHistory.length})',
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 12, 16, 8),
                                      child: Row(
                                        children: [
                                          _buildFilterChip('ALL',
                                              'Tất cả (${_attempts.length})'),
                                          const SizedBox(width: 8),
                                          _buildFilterChip('LUYEN_TAP',
                                              'Đề ôn tập (${_summary['practice_count'] ?? 0})'),
                                          const SizedBox(width: 8),
                                          _buildFilterChip('THI_CHINH_THUC',
                                              'Thi chính thức (${_summary['exam_count'] ?? 0})'),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: filteredAttempts.isEmpty
                                          ? const Center(
                                              child: Text(
                                                  'Người dùng chưa tham gia bộ đề nào.'))
                                          : AdminScrollableTable(
                                              child: DataTable(
                                                columnSpacing: 20,
                                                headingRowColor:
                                                    WidgetStateProperty.all(
                                                        const Color(
                                                            0xFFF8FAFC)),
                                                columns: const [
                                                  DataColumn(
                                                      label: Text('Mã lượt')),
                                                  DataColumn(
                                                      label: Text('Tên bộ đề')),
                                                  DataColumn(
                                                      label: Text('Loại đề')),
                                                  DataColumn(
                                                      label: Text(
                                                          'Thời gian làm')),
                                                  DataColumn(
                                                      label:
                                                          Text('Số câu đúng')),
                                                  DataColumn(
                                                      label: Text('Điểm số')),
                                                  DataColumn(
                                                      label: Text('Kết quả')),
                                                  DataColumn(
                                                      label: Text('Chi tiết')),
                                                ],
                                                rows: filteredAttempts.map((a) {
                                                  final isPractice =
                                                      a['LoaiBoDe'] ==
                                                          'LUYEN_TAP';
                                                  final isSubmitted =
                                                      a['TrangThai'] ==
                                                          'DA_NOP';
                                                  final isPassed =
                                                      a['DaDat'] == true;

                                                  return DataRow(
                                                    cells: [
                                                      DataCell(Text(
                                                          '#${a['MaLuotLam']}')),
                                                      DataCell(
                                                        SizedBox(
                                                          width: 220,
                                                          child: Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                a['TenBoDe'] ??
                                                                    '',
                                                                style: const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                              Text(
                                                                a['TenChuDe'] ??
                                                                    'Tổng hợp',
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    color: Color(
                                                                        0xFF64748B)),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: isPractice
                                                                ? const Color(
                                                                    0xFFE0F2FE)
                                                                : const Color(
                                                                    0xFFFEF3C7),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6),
                                                          ),
                                                          child: Text(
                                                            isPractice
                                                                ? 'Ôn tập'
                                                                : 'Thi chính thức',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: isPractice
                                                                  ? const Color(
                                                                      0xFF0369A1)
                                                                  : const Color(
                                                                      0xFFB45309),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                                _formatDateTime(a[
                                                                    'ThoiGianBatDau']),
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        12.5)),
                                                            Text(
                                                              'Thời lượng: ${_formatDuration(a['ThoiGianLamGiay'])}',
                                                              style: const TextStyle(
                                                                  fontSize:
                                                                      11.5,
                                                                  color: Color(
                                                                      0xFF64748B)),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      DataCell(Text(
                                                          '${a['SoCauDung'] ?? 0} / ${a['TongSoCau'] ?? 0}')),
                                                      DataCell(
                                                        Text(
                                                          a['DiemSo'] != null
                                                              ? '${a['DiemSo']}'
                                                              : '—',
                                                          style:
                                                              const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 14),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      10,
                                                                  vertical: 4),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: !isSubmitted
                                                                ? const Color(
                                                                    0xFFF1F5F9)
                                                                : isPassed
                                                                    ? const Color(
                                                                        0xFFDCFCE7)
                                                                    : const Color(
                                                                        0xFFFEE2E2),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        20),
                                                          ),
                                                          child: Text(
                                                            !isSubmitted
                                                                ? 'Đang làm dở'
                                                                : isPassed
                                                                    ? 'Đạt'
                                                                    : 'Chưa đạt',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: !isSubmitted
                                                                  ? const Color(0xFF475569)
                                                                  : isPassed
                                                                      ? const Color(0xFF15803D)
                                                                      : const Color(0xFFDC2626),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        OutlinedButton.icon(
                                                          onPressed: () {
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (_) =>
                                                                    AttemptDetailScreen(
                                                                  maLuotLam: a[
                                                                      'MaLuotLam'],
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                          icon: const Icon(
                                                              Icons
                                                                  .visibility_outlined,
                                                              size: 16),
                                                          label: const Text(
                                                              'Xem bài làm'),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                                _cupHistory.isEmpty
                                    ? const Center(
                                        child: Text(
                                            'Chưa có lịch sử nhận hoặc trừ cúp nào.'))
                                    : AdminScrollableTable(
                                        child: DataTable(
                                          columnSpacing: 24,
                                          headingRowColor:
                                              WidgetStateProperty.all(
                                                  const Color(0xFFF8FAFC)),
                                          columns: const [
                                            DataColumn(label: Text('Mã GD')),
                                            DataColumn(
                                                label: Text('Thời gian')),
                                            DataColumn(
                                                label: Text('Nguồn biến động')),
                                            DataColumn(
                                                label: Text('Cúp trước')),
                                            DataColumn(label: Text('Thay đổi')),
                                            DataColumn(label: Text('Cúp sau')),
                                            DataColumn(
                                                label: Text('Mô tả / Lý do')),
                                          ],
                                          rows: _cupHistory.map((c) {
                                            final int delta =
                                                c['SoCupThayDoi'] ?? 0;
                                            final bool isPlus = delta >= 0;

                                            return DataRow(
                                              cells: [
                                                DataCell(Text(
                                                    '#${c['MaBienDong']}')),
                                                DataCell(Text(_formatDateTime(
                                                    c['NgayTao']))),
                                                DataCell(Text(_formatCupType(
                                                    c['LoaiBienDong']))),
                                                DataCell(Text(
                                                    '${c['SoCupTruoc'] ?? 0}')),
                                                DataCell(
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: isPlus
                                                          ? const Color(
                                                              0xFFDCFCE7)
                                                          : const Color(
                                                              0xFFFEE2E2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Text(
                                                      isPlus
                                                          ? '+$delta 🏆'
                                                          : '$delta 🏆',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: isPlus
                                                            ? const Color(
                                                                0xFF15803D)
                                                            : const Color(
                                                                0xFFDC2626),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    '${c['SoCupSau'] ?? 0}',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: 300,
                                                    child: Text(
                                                      c['MoTa'] ?? '—',
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final selected = _attemptFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFFDBEAFE),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
      ),
      onSelected: (_) => setState(() => _attemptFilter = value),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11.5, color: Color(0xFF94A3B8)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AttemptDetailScreen extends StatefulWidget {
  final int maLuotLam;

  const AttemptDetailScreen({super.key, required this.maLuotLam});

  @override
  State<AttemptDetailScreen> createState() => _AttemptDetailScreenState();
}

class _AttemptDetailScreenState extends State<AttemptDetailScreen> {
  final _api = AdminApiService();
  bool _isLoading = true;
  Map _attempt = {};
  List _questions = [];
  String _filterMode = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getAttemptDetail(widget.maLuotLam);
      if (!mounted) return;
      setState(() {
        _attempt = Map.from(data['attempt'] ?? {});
        _questions = List.from(data['questions'] ?? []);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFDC2626)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final correctCount =
        _questions.where((q) => q['TraLoiDung'] == true).length;
    final wrongCount = _questions.length - correctCount;

    final visibleQuestions = _questions.where((q) {
      if (_filterMode == 'CORRECT') return q['TraLoiDung'] == true;
      if (_filterMode == 'WRONG') return q['TraLoiDung'] != true;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        title: Text(
            'Chi tiết bài làm #${widget.maLuotLam} - ${_attempt['TenBoDe'] ?? ''}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  color: Colors.white,
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Thí sinh: ${_attempt['HoTen'] ?? ''} (${_attempt['Email'] ?? ''})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Chip(
                        backgroundColor: const Color(0xFFDBEAFE),
                        label: Text(
                          'Điểm: ${_attempt['DiemSo'] ?? 0} / 10 (${_attempt['SoCauDung'] ?? 0}/${_attempt['TongSoCau'] ?? 0} câu)',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D4ED8)),
                        ),
                      ),
                      ChoiceChip(
                        label: Text('Tất cả (${_questions.length})'),
                        selected: _filterMode == 'ALL',
                        onSelected: (_) => setState(() => _filterMode = 'ALL'),
                      ),
                      ChoiceChip(
                        label: Text('Câu đúng ($correctCount)'),
                        selected: _filterMode == 'CORRECT',
                        selectedColor: const Color(0xFFDCFCE7),
                        onSelected: (_) =>
                            setState(() => _filterMode = 'CORRECT'),
                      ),
                      ChoiceChip(
                        label: Text('Câu sai / Bỏ trống ($wrongCount)'),
                        selected: _filterMode == 'WRONG',
                        selectedColor: const Color(0xFFFEE2E2),
                        onSelected: (_) =>
                            setState(() => _filterMode = 'WRONG'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: visibleQuestions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, idx) {
                      final q = visibleQuestions[idx];
                      final bool isCorrect = q['TraLoiDung'] == true;
                      final bool isAnswered = q['DaTraLoi'] == true;
                      final answers = List.from(q['DapAn'] ?? []);
                      final imgUrl = (q['HinhAnhUrl'] ?? '').toString();

                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCorrect
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFFFCA5A5),
                            width: 1.5,
                          ),
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
                                    color: isCorrect
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isCorrect
                                            ? Icons.check_circle_rounded
                                            : Icons.cancel_rounded,
                                        size: 16,
                                        color: isCorrect
                                            ? const Color(0xFF15803D)
                                            : const Color(0xFFDC2626),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Câu ${q['ThuTuCau']} — ${isCorrect ? "ĐÚNG" : (!isAnswered ? "BỎ TRỐNG" : "SAI")}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isCorrect
                                              ? const Color(0xFF15803D)
                                              : const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'ID #${q['MaCauHoi']} • ${q['TenLoai'] ?? ''}',
                                  style: const TextStyle(
                                      fontSize: 12.5, color: Color(0xFF64748B)),
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
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(imgUrl,
                                    height: 140, fit: BoxFit.contain),
                              ),
                            ],
                            const SizedBox(height: 12),
                            ...answers.asMap().entries.map((entry) {
                              final aIdx = entry.key;
                              final ans = entry.value;
                              final bool isSysCorrect =
                                  ans['LaDapAnDung'] == true;
                              final bool isUserPicked =
                                  ans['NguoiDungChon'] == true;

                              Color bg = const Color(0xFFF8FAFC);
                              Color border = const Color(0xFFE2E8F0);
                              if (isSysCorrect) {
                                bg = const Color(0xFFDCFCE7);
                                border = const Color(0xFF86EFAC);
                              } else if (isUserPicked && !isSysCorrect) {
                                bg = const Color(0xFFFEE2E2);
                                border = const Color(0xFFFCA5A5);
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: border),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isUserPicked
                                          ? (isSysCorrect
                                              ? Icons.check_circle
                                              : Icons.cancel)
                                          : (isSysCorrect
                                              ? Icons.check_circle_outline
                                              : Icons.radio_button_unchecked),
                                      size: 18,
                                      color: isSysCorrect
                                          ? const Color(0xFF16A34A)
                                          : (isUserPicked
                                              ? const Color(0xFFDC2626)
                                              : Colors.grey),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '${String.fromCharCode(65 + aIdx)}. ${ans['NoiDung'] ?? ''}',
                                        style: TextStyle(
                                          fontWeight:
                                              (isSysCorrect || isUserPicked)
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if (isUserPicked)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isSysCorrect
                                              ? const Color(0xFF16A34A)
                                              : const Color(0xFFDC2626),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Thí sinh chọn',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    if (isSysCorrect)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF15803D),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Đáp án đúng',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold),
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
                ),
              ],
            ),
    );
  }
}