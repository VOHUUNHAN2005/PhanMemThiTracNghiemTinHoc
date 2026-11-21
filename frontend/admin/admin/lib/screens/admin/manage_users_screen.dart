import 'package:admin/services/admin_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/admin_ui_kit.dart';
import 'user_activity_screen.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _api = AdminApiService();
  final _searchCtrl = TextEditingController();

  List _users = [];
  int _totalUsers = 0;
  String? _filterStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getUsers(
        search: _searchCtrl.text,
        accountStatus: _filterStatus,
        page: 1,
        limit: 100,
      );
      if (!mounted) return;
      final rawItems = List.from(res['items'] ?? []);
      final studentOnly =
          rawItems.where((u) => u['VaiTro'] != 'ADMIN').toList();
      setState(() {
        _users = studentOnly;
        _totalUsers = studentOnly.length;
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

  String _getRankNameFromCups(int cups, String? apiRankName) {
    if (apiRankName != null && apiRankName.trim().isNotEmpty)
      return apiRankName;
    if (cups >= 5000) return 'Cao Thủ';
    if (cups >= 1500) return 'Kim Cương';
    if (cups >= 500) return 'Vàng';
    if (cups >= 100) return 'Bạc';
    return 'Đồng';
  }

  Widget _buildRankBadge(int cups, String? apiRankName) {
    final rankName = _getRankNameFromCups(cups, apiRankName);

    Color bgColor;
    Color textColor;
    Color borderColor;

    if (cups >= 5000 || rankName.toLowerCase().contains('cao thủ')) {
      bgColor = const Color(0xFFFDF2F8);
      textColor = const Color(0xFFBE185D);
      borderColor = const Color(0xFFFBCFE8);
    } else if (cups >= 1500 || rankName.toLowerCase().contains('kim cương')) {
      bgColor = const Color(0xFFECFEFF);
      textColor = const Color(0xFF0E7490);
      borderColor = const Color(0xFFA5F3FC);
    } else if (cups >= 500 || rankName.toLowerCase().contains('vàng')) {
      bgColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFFB45309);
      borderColor = const Color(0xFFFDE68A);
    } else if (cups >= 100 || rankName.toLowerCase().contains('bạc')) {
      bgColor = const Color(0xFFF1F5F9);
      textColor = const Color(0xFF334155);
      borderColor = const Color(0xFFCBD5E1);
    } else {
      bgColor = const Color(0xFFFFF7ED);
      textColor = const Color(0xFF9A3412);
      borderColor = const Color(0xFFFED7AA);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        rankName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Future<void> _openCupDialog(Map user) async {
    final deltaCtrl = TextEditingController(text: '10');
    final reasonCtrl = TextEditingController(text: 'Thưởng thành tích học tập');
    final int currentCups =
        ((user['SoCupHienTai'] ?? user['SoCup'] ?? 0) as num).toInt();

    final saved = await showModernModal(
      context: context,
      title: 'Điều chỉnh Số Cúp',
      subtitle:
          'Tài khoản: ${user['HoTen'] ?? user['Email']} (Hiện có: $currentCups cúp)',
      icon: Icons.emoji_events_rounded,
      accentColor: const Color(0xFFD97706),
      width: 480,
      confirmText: 'Xác nhận cập nhật',
      bodyBuilder: (ctx, setModalState) {
        final parsedDelta = int.tryParse(deltaCtrl.text.trim()) ?? 0;
        final previewCups =
            (currentCups + parsedDelta) < 0 ? 0 : (currentCups + parsedDelta);
        final previewRank = _getRankNameFromCups(previewCups, null);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 18, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sau cập nhật dự kiến: $previewCups 🏆 (Hạng: $previewRank)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: deltaCtrl,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d{0,6}$')),
              ],
              onChanged: (_) => setModalState(() {}),
              decoration: modernInputDecoration(
                label: 'Số cúp thay đổi (+ để cộng, - để trừ) *',
                hint: 'VD: 20 hoặc -10',
                prefixIcon: Icons.exposure_rounded,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              maxLength: 250,
              decoration: modernInputDecoration(
                label: 'Lý do điều chỉnh * (Tối thiểu 3 ký tự)',
                hint: 'VD: Thưởng sự kiện tuần, Khắc phục sự cố...',
                prefixIcon: Icons.notes_rounded,
              ).copyWith(counterText: ''),
            ),
          ],
        );
      },
      onConfirm: () async {
        final delta = int.tryParse(deltaCtrl.text.trim());
        if (delta == null || delta == 0) {
          _showSnack('Vui lòng nhập số cúp khác 0 (ví dụ: 10 hoặc -5).',
              isError: true);
          return false;
        }
        if (delta < -100000 || delta > 100000) {
          _showSnack(
              'Số cúp điều chỉnh một lần phải nằm trong khoảng -100.000 đến 100.000.',
              isError: true);
          return false;
        }
        final reason = reasonCtrl.text.trim();
        if (reason.length < 3) {
          _showSnack('Lý do điều chỉnh phải có ít nhất 3 ký tự.',
              isError: true);
          return false;
        }

        try {
          await _api.adjustUserCups(
            userId: user['MaNguoiDung'],
            soCupThayDoi: delta,
            moTa: reason,
          );
          _showSnack('Đã cập nhật số cúp và bậc hạng thành công.');
          return true;
        } catch (e) {
          _showSnack(e.toString(), isError: true);
          return false;
        }
      },
    );

    if (saved == true) _loadUsers();
  }

  Future<void> _toggleUserStatus(Map user) async {
    final currentStatus =
        (user['TrangThaiTaiKhoan'] ?? user['TrangThai'] ?? 'HOAT_DONG')
            .toString();
    final isCurrentlyLocked =
        currentStatus == 'BI_KHOA' || currentStatus == 'KHOA';
    final nextStatus = isCurrentlyLocked ? 'HOAT_DONG' : 'BI_KHOA';
    final actionText =
        isCurrentlyLocked ? 'Mở khóa tài khoản' : 'Khóa tài khoản';

    final reasonCtrl = TextEditingController();

    final confirm = await showModernModal(
      context: context,
      title: '$actionText?',
      subtitle: isCurrentlyLocked
          ? 'Khôi phục quyền đăng nhập và làm bài thi cho ${user['HoTen'] ?? user['Email']}'
          : 'Tạm khóa quyền đăng nhập của ${user['HoTen'] ?? user['Email']}',
      icon: isCurrentlyLocked
          ? Icons.lock_open_rounded
          : Icons.lock_outline_rounded,
      accentColor:
          isCurrentlyLocked ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
      width: 460,
      confirmText: actionText,
      bodyBuilder: (ctx, setModalState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isCurrentlyLocked)
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              maxLength: 200,
              decoration: modernInputDecoration(
                label: 'Lý do khóa tài khoản *',
                hint: 'VD: Vi phạm quy chế thi cử...',
                prefixIcon: Icons.report_problem_outlined,
              ).copyWith(counterText: ''),
            )
          else
            const Text(
              'Bạn có chắc chắn muốn mở khóa lại tài khoản này để thí sinh tiếp tục sử dụng ứng dụng?',
              style: TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
            ),
        ],
      ),
      onConfirm: () async {
        if (!isCurrentlyLocked && reasonCtrl.text.trim().length < 3) {
          _showSnack('Vui lòng nhập lý do khóa tài khoản (tối thiểu 3 ký tự).',
              isError: true);
          return false;
        }

        try {
          await _api.updateUserStatus(
            user,
            userId: user['MaNguoiDung'],
            status: nextStatus,
            lyDoKhoa: isCurrentlyLocked ? null : reasonCtrl.text.trim(),
          );
          _showSnack('Đã cập nhật trạng thái tài khoản.');
          return true;
        } catch (e) {
          _showSnack(e.toString(), isError: true);
          return false;
        }
      },
    );

    if (confirm == true) _loadUsers();
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
                width: 300,
                height: 44,
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _loadUsers(),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên hoặc email...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 220,
                child: modernFilterDropdown(
                  value: _filterStatus,
                  hint: 'Tất cả trạng thái',
                  icon: Icons.filter_list_rounded,
                  items: [
                    buildModernDropdownItem(
                      value: null,
                      text: 'Tất cả trạng thái',
                      icon: Icons.people_outline_rounded,
                      iconColor: const Color(0xFF475569),
                    ),
                    buildModernDropdownItem(
                      value: 'HOAT_DONG',
                      text: 'Đang hoạt động',
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: const Color(0xFF16A34A),
                    ),
                    buildModernDropdownItem(
                      value: 'BI_KHOA',
                      text: 'Đã khóa',
                      icon: Icons.lock_outline_rounded,
                      iconColor: const Color(0xFFDC2626),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() => _filterStatus = val as String?);
                    _loadUsers();
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                ),
                onPressed: _loadUsers,
                child: const Text('Tìm kiếm'),
              ),
              const Spacer(),
              Text(
                'Tổng: $_totalUsers thí sinh',
                style: const TextStyle(
                    color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Tải lại',
                onPressed: _loadUsers,
                icon: const Icon(Icons.refresh),
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
                  : _users.isEmpty
                      ? const Center(
                          child: Text('Không tìm thấy thí sinh nào.'))
                      : AdminScrollableTable(
                          child: DataTable(
                            columnSpacing: 20,
                            headingRowColor: WidgetStateProperty.all(
                                const Color(0xFFF8FAFC)),
                            columns: const [
                              DataColumn(label: Text('ID')),
                              DataColumn(label: Text('Họ và tên')),
                              DataColumn(label: Text('Email')),
                              DataColumn(label: Text('Bậc hạng')),
                              DataColumn(label: Text('Số cúp')),
                              DataColumn(label: Text('Trạng thái')),
                              DataColumn(label: Text('Thao tác')),
                            ],
                            rows: _users.map((u) {
                              final rawStatus = (u['TrangThaiTaiKhoan'] ??
                                      u['TrangThai'] ??
                                      'HOAT_DONG')
                                  .toString();
                              final isLocked =
                                  rawStatus == 'BI_KHOA' || rawStatus == 'KHOA';
                              final int cups = ((u['SoCupHienTai'] ??
                                      u['SoCup'] ??
                                      0) as num)
                                  .toInt();

                              return DataRow(
                                cells: [
                                  DataCell(Text('#${u['MaNguoiDung']}')),
                                  DataCell(
                                    Text(
                                      u['HoTen'] ?? 'Chưa cập nhật',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  DataCell(Text(u['Email'] ?? '')),
                                  DataCell(_buildRankBadge(cups, u['TenHang'])),
                                  DataCell(
                                    Text(
                                      '$cups 🏆',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isLocked
                                            ? const Color(0xFFFEE2E2)
                                            : const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isLocked ? 'Đã khóa' : 'Hoạt động',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isLocked
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFF15803D),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    UserActivityScreen(user: u),
                                              ),
                                            );
                                            _loadUsers();
                                          },
                                          icon: const Icon(
                                            Icons.history_edu_rounded,
                                            size: 16,
                                            color: Color(0xFF2563EB),
                                          ),
                                          label: const Text('Lịch sử'),
                                        ),
                                        const SizedBox(width: 6),
                                        OutlinedButton.icon(
                                          onPressed: () => _openCupDialog(u),
                                          icon: const Icon(
                                              Icons.emoji_events_outlined,
                                              size: 16),
                                          label: const Text('+/- Cúp'),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          tooltip: isLocked
                                              ? 'Mở khóa tài khoản'
                                              : 'Khóa tài khoản',
                                          icon: Icon(
                                            isLocked
                                                ? Icons.lock_open_rounded
                                                : Icons.lock_outline_rounded,
                                            color: isLocked
                                                ? const Color(0xFF16A34A)
                                                : const Color(0xFFDC2626),
                                          ),
                                          onPressed: () => _toggleUserStatus(u),
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
