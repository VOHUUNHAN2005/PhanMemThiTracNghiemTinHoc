import 'package:admin/services/admin_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/admin_ui_kit.dart';

class ManageArenaScreen extends StatefulWidget {
  const ManageArenaScreen({super.key});

  @override
  State<ManageArenaScreen> createState() => _ManageArenaScreenState();
}

class _ManageArenaScreenState extends State<ManageArenaScreen> {
  final _api = AdminApiService();

  bool _isLoading = true;
  Map<String, dynamic> _summary = {};
  List _rooms = [];
  List _topics = [];

  String? _filterType;
  String? _filterStatus;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getArenaRooms(
          loaiPhong: _filterType,
          trangThai: _filterStatus,
          search: _searchCtrl.text,
        ),
        _api.getTopics(),
      ]);
      if (!mounted) return;
      final arenaData = results[0] as Map<String, dynamic>;
      setState(() {
        _summary = Map<String, dynamic>.from(arenaData['summary'] ?? {});
        _rooms = List.from(arenaData['items'] ?? []);
        _topics = List.from(results[1] as List);
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

  Widget _buildStatusBadge(String? status) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);
    String label = status ?? '—';

    switch (status) {
      case 'CHO_NGUOI_CHOI':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        label = 'Đang chờ thí sinh';
        break;
      case 'DANG_DIEN_RA':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = 'Đang thi đấu';
        break;
      case 'DA_KET_THUC':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        label = 'Đã kết thúc';
        break;
      case 'DA_HUY':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        label = 'Đã hủy';
        break;
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

  Future<void> _openCreateTournamentDialog() async {
    if (_topics.isEmpty) {
      _showSnack('Cần có ít nhất 1 Chủ đề có đủ câu hỏi trước.', isError: true);
      return;
    }

    int selectedTopicId = _topics.first['MaChuDe'];
    final questionCountCtrl = TextEditingController(text: '50');
    final passwordCtrl = TextEditingController();

    final created = await showModernModal(
      context: context,
      title: 'Tạo Phòng Giải Đấu Sự Kiện',
      subtitle:
          'Sinh mã phòng giải đấu chính thức để phát cho thí sinh tham gia tranh tài',
      icon: Icons.emoji_events_rounded,
      accentColor: const Color(0xFF7C3AED),
      width: 520,
      confirmText: 'Mở phòng giải đấu',
      bodyBuilder: (ctx, setModalState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          modernDropdownField(
            value: selectedTopicId,
            label: 'Chủ đề thi đấu *',
            prefixIcon: Icons.layers_outlined,
            items: _topics.map((t) {
              final tong = (t['SoCauDe'] ?? 0) +
                  (t['SoCauTrungBinh'] ?? 0) +
                  (t['SoCauKho'] ?? 0);
              return buildModernDropdownItem(
                value: t['MaChuDe'],
                text: '${t['TenChuDe']} ($tong câu hoạt động)',
                icon: Icons.layers_rounded,
                iconColor: const Color(0xFF7C3AED),
              );
            }).toList(),
            onChanged: (val) =>
                setModalState(() => selectedTopicId = val as int),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: questionCountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: modernInputDecoration(
              label: 'Số lượng câu hỏi (5 - 100 câu) *',
              hint: '50',
              prefixIcon: Icons.quiz_outlined,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passwordCtrl,
            maxLength: 20,
            decoration: modernInputDecoration(
              label: 'Mật khẩu phòng (Để trống nếu mở tự do)',
              hint: 'VD: GIAIDAU2026',
              prefixIcon: Icons.lock_outline_rounded,
            ).copyWith(counterText: ''),
          ),
        ],
      ),
      onConfirm: () async {
        final qCount = int.tryParse(questionCountCtrl.text.trim());
        if (qCount == null || qCount < 5 || qCount > 100) {
          _showSnack('Số lượng câu hỏi phải từ 5 đến 100 câu.', isError: true);
          return false;
        }
        try {
          final res = await _api.createAdminTournament(
            maChuDe: selectedTopicId,
            soCauHoi: qCount,
            matKhauPhong: passwordCtrl.text,
          );
          _showSnack(res['message'] ?? 'Đã tạo phòng giải đấu!');
          return true;
        } catch (e) {
          _showSnack(e.toString(), isError: true);
          return false;
        }
      },
    );

    if (created == true) _loadData();
  }

  Future<void> _openRoomDetailDialog(Map room) async {
    final int maPhong = room['MaPhong'];
    Map<String, dynamic>? detailData;
    bool loading = true;
    bool initialized = false;

    await showModernModal(
      context: context,
      title: 'Chi tiết phòng #${room['MaCodePhong']}',
      subtitle: room['LoaiPhong'] == 'DOI_KHANG_1VS1'
          ? 'Chế độ Đối kháng 1 vs 1'
          : 'Chế độ Giải đấu nhiều người',
      icon: Icons.sports_esports_rounded,
      accentColor: const Color(0xFF2563EB),
      width: 860,
      confirmText: 'Đóng',
      bodyBuilder: (ctx, setModalState) {
        if (!initialized) {
          initialized = true;
          Future.microtask(() async {
            try {
              final res = await _api.getArenaRoomDetail(maPhong);
              setModalState(() {
                detailData = res;
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

        final members = List.from(detailData?['members'] ?? []);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (members.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('Chưa có thí sinh nào tham gia phòng này.'),
                ),
              )
            else
              AdminScrollableTable(
                child: DataTable(
                  columnSpacing: 16,
                  headingRowColor:
                      WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('Hạng')),
                    DataColumn(label: Text('Thí sinh')),
                    DataColumn(label: Text('Trạng thái')),
                    DataColumn(label: Text('Số câu đúng')),
                    DataColumn(label: Text('Tổng thời gian')),
                    DataColumn(label: Text('Biến động cúp')),
                  ],
                  rows: members.map((m) {
                    final int cup = (m['CupThayDoi'] as num?)?.toInt() ?? 0;
                    final int ms =
                        (m['TongThoiGianTraLoiMs'] as num?)?.toInt() ?? 0;
                    return DataRow(
                      cells: [
                        DataCell(Text(
                          m['ThuHang'] != null ? '#${m['ThuHang']}' : '—',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        )),
                        DataCell(
                            Text('${m['HoTen'] ?? ''} (${m['Email'] ?? ''})')),
                        DataCell(Text('${m['TrangThai'] ?? ''}')),
                        DataCell(Text('${m['SoCauDung'] ?? 0} câu')),
                        DataCell(Text('${(ms / 1000).toStringAsFixed(1)}s')),
                        DataCell(Text(
                          cup > 0 ? '+$cup 🏆' : '$cup 🏆',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cup > 0
                                ? const Color(0xFF15803D)
                                : const Color(0xFF64748B),
                          ),
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      },
      onConfirm: () async => true,
    );
  }

  Future<void> _confirmCancelRoom(Map room) async {
    final confirm = await showModernConfirmDialog(
      context: context,
      title: 'Buộc hủy phòng thi đấu?',
      message:
          'Phòng sẽ chuyển sang trạng thái ĐÃ HỦY và toàn bộ thí sinh đang trong phòng sẽ được giải phóng ngay lập tức.',
      highlightText: 'Mã phòng: ${room['MaCodePhong']}',
      confirmText: 'Buộc hủy phòng',
    );
    if (confirm != true) return;

    try {
      final res = await _api.cancelArenaRoom(room['MaPhong']);
      _showSnack(res['message'] ?? 'Đã hủy phòng.');
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
              _buildStatBox(
                'Tổng số phòng',
                '${_summary['TongPhong'] ?? 0}',
                Icons.meeting_room_rounded,
                const Color(0xFF2563EB),
              ),
              const SizedBox(width: 14),
              _buildStatBox(
                'Đối kháng 1 vs 1',
                '${_summary['Tong1vs1'] ?? 0}',
                Icons.bolt_rounded,
                const Color(0xFFD97706),
              ),
              const SizedBox(width: 14),
              _buildStatBox(
                'Giải đấu N người',
                '${_summary['TongGiaiDau'] ?? 0}',
                Icons.emoji_events_rounded,
                const Color(0xFF7C3AED),
              ),
              const SizedBox(width: 14),
              _buildStatBox(
                'Đang hoạt động',
                '${_summary['DangHoatDong'] ?? 0}',
                Icons.sensors_rounded,
                const Color(0xFF16A34A),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 210,
                child: modernFilterDropdown(
                  value: _filterType,
                  hint: 'Tất cả chế độ',
                  icon: Icons.sports_esports_outlined,
                  items: [
                    buildModernDropdownItem(
                        value: null, text: 'Tất cả chế độ'),
                    buildModernDropdownItem(
                        value: 'DOI_KHANG_1VS1', text: 'Đối kháng 1 vs 1'),
                    buildModernDropdownItem(
                        value: 'GIAI_DAU_NN', text: 'Giải đấu N người'),
                  ],
                  onChanged: (val) {
                    setState(() => _filterType = val as String?);
                    _loadData();
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 210,
                child: modernFilterDropdown(
                  value: _filterStatus,
                  hint: 'Tất cả trạng thái',
                  icon: Icons.filter_alt_outlined,
                  items: [
                    buildModernDropdownItem(
                        value: null, text: 'Tất cả trạng thái'),
                    buildModernDropdownItem(
                        value: 'CHO_NGUOI_CHOI', text: 'Đang chờ thí sinh'),
                    buildModernDropdownItem(
                        value: 'DANG_DIEN_RA', text: 'Đang thi đấu'),
                    buildModernDropdownItem(
                        value: 'DA_KET_THUC', text: 'Đã kết thúc'),
                    buildModernDropdownItem(value: 'DA_HUY', text: 'Đã hủy'),
                  ],
                  onChanged: (val) {
                    setState(() => _filterStatus = val as String?);
                    _loadData();
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 240,
                height: 44,
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _loadData(),
                  decoration: InputDecoration(
                    hintText: 'Tìm mã phòng / chủ phòng...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
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
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onPressed: _openCreateTournamentDialog,
                icon: const Icon(Icons.emoji_events_rounded, size: 18),
                label: const Text('Tạo phòng Giải đấu'),
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
                  : _rooms.isEmpty
                      ? const Center(
                          child: Text('Chưa có phòng thi đấu nào.'))
                      : AdminScrollableTable(
                          child: DataTable(
                            columnSpacing: 20,
                            headingRowColor: WidgetStateProperty.all(
                                const Color(0xFFF8FAFC)),
                            columns: const [
                              DataColumn(label: Text('Mã phòng')),
                              DataColumn(label: Text('Chế độ')),
                              DataColumn(label: Text('Chủ phòng / Nguồn')),
                              DataColumn(label: Text('Số thí sinh')),
                              DataColumn(label: Text('Mật khẩu')),
                              DataColumn(label: Text('Trạng thái')),
                              DataColumn(label: Text('Thao tác')),
                            ],
                            rows: _rooms.map((r) {
                              final bool is1v1 =
                                  r['LoaiPhong'] == 'DOI_KHANG_1VS1';
                              final String st = (r['TrangThai'] ?? '').toString();
                              final bool canCancel = st == 'CHO_NGUOI_CHOI' ||
                                  st == 'DANG_DIEN_RA';

                              return DataRow(
                                cells: [
                                  DataCell(Text(
                                    '#${r['MaCodePhong']}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1D4ED8)),
                                  )),
                                  DataCell(Text(
                                    is1v1 ? 'Đối kháng 1vs1' : 'Giải đấu N người',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  )),
                                  DataCell(Text(
                                    r['CheDoGhep'] == 'MOI_BAN_BE'
                                        ? 'Sự kiện Admin (${r['TenChuDe'] ?? ''})'
                                        : '${r['TenChuPhong'] ?? 'Hệ thống'}',
                                  )),
                                  DataCell(Text(
                                      '${r['SoNguoiThamGia'] ?? 0} thí sinh')),
                                  DataCell(Text(r['MatKhauPhong'] ?? 'Không có')),
                                  DataCell(_buildStatusBadge(st)),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              _openRoomDetailDialog(r),
                                          icon: const Icon(
                                              Icons.leaderboard_outlined,
                                              size: 16),
                                          label: const Text('Kết quả / BXH'),
                                        ),
                                        if (canCancel) ...[
                                          const SizedBox(width: 6),
                                          IconButton(
                                            tooltip: 'Buộc hủy phòng đấu',
                                            icon: const Icon(
                                                Icons.cancel_outlined,
                                                color: Color(0xFFDC2626)),
                                            onPressed: () =>
                                                _confirmCancelRoom(r),
                                          ),
                                        ],
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

  Widget _buildStatBox(
      String title, String value, IconData icon, Color color) {
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
            Column(
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}