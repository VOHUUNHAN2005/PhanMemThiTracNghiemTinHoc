import 'package:flutter/material.dart';
import 'package:user/core/models/attempt_history_model.dart';
import 'package:user/core/models/cup_history_model.dart';
import 'package:user/core/services/user_service.dart';
import 'package:user/features/history/attempt_detail_screen.dart';

class AttemptHistoryScreen extends StatefulWidget {
  const AttemptHistoryScreen({super.key});

  @override
  State<AttemptHistoryScreen> createState() => _AttemptHistoryScreenState();
}

class _AttemptHistoryScreenState extends State<AttemptHistoryScreen>
    with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  late TabController _tabController;

  List<AttemptHistoryModel> _allAttempts = [];
  List<CupHistoryModel> _cupHistory = [];
  bool _isLoading = true;
  String? _error;

  String _selectedType = 'ALL'; // ALL | THI_CHINH_THUC | LUYEN_TAP
  String _selectedTopic = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAllHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _userService.getAttemptHistory(),
        _userService.getCupHistory(),
      ]);
      if (mounted) {
        setState(() {
          _allAttempts = results[0] as List<AttemptHistoryModel>;
          _cupHistory = results[1] as List<CupHistoryModel>;
        });
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

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Chưa xác định';
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$d/$m/$y • $hh:$mm';
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    return '${m}p ${s.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF172554),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Lịch sử hoạt động',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: const Color(0xFF172554),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF38BDF8),
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Bài thi & Ôn tập'),
                Tab(text: 'Biến động cúp'),
              ],
            ),
          ),
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
                          onPressed: _fetchAllHistory,
                          child: const Text('Tải lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAttemptsTab(),
                    _buildCupHistoryTab(),
                  ],
                ),
    );
  }

  Widget _buildAttemptsTab() {
    final topics = <String>{'ALL'};
    for (final item in _allAttempts) {
      if (item.tenChuDe.trim().isNotEmpty) {
        topics.add(item.tenChuDe.trim());
      }
    }

    final filtered = _allAttempts.where((item) {
      if (_selectedType != 'ALL' && item.loaiBoDe != _selectedType) {
        return false;
      }
      if (_selectedTopic != 'ALL' && item.tenChuDe.trim() != _selectedTopic) {
        return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchAllHistory,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTypeChip('ALL', 'Tất cả'),
                    _buildTypeChip('THI_CHINH_THUC', 'Thi chính thức'),
                    _buildTypeChip('LUYEN_TAP', 'Ôn tập'),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: topics.contains(_selectedTopic)
                          ? _selectedTopic
                          : 'ALL',
                      isExpanded: true,
                      items: topics
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(
                                t == 'ALL'
                                    ? 'Chủ đề: Tất cả chủ đề'
                                    : 'Chủ đề: $t',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedTopic = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (filtered.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(
                      child: Text(
                        'Chưa có lượt làm bài nào phù hợp.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ...filtered.map(_buildAttemptCard),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String value, String label) {
    final selected = _selectedType == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFF1D5CE5),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF334155),
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      onSelected: (_) => setState(() => _selectedType = value),
    );
  }

  Widget _buildAttemptCard(AttemptHistoryModel item) {
    final bool isOfficial = item.loaiBoDe == 'THI_CHINH_THUC';
    final bool isCanceled = item.trangThai == 'HUY_GIAN_LAN';
    final bool isInProgress = item.trangThai == 'DANG_LAM';
    final bool canReview =
        item.trangThai == 'DA_NOP' || item.trangThai == 'HET_GIO';

    String badgeText = item.daDat ? 'Đạt' : 'Chưa đạt';
    Color badgeBg =
        item.daDat ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2);
    Color badgeColor =
        item.daDat ? const Color(0xFF065F46) : const Color(0xFFB91C1C);

    if (isCanceled) {
      badgeText = 'Bị hủy';
      badgeBg = const Color(0xFFFEE2E2);
      badgeColor = const Color(0xFFB91C1C);
    } else if (isInProgress) {
      badgeText = 'Đang làm';
      badgeBg = const Color(0xFFFEF3C7);
      badgeColor = const Color(0xFF92400E);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOfficial
                      ? const Color(0xFFEDE9FE)
                      : const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isOfficial ? 'Thi chính thức' : 'Ôn tập',
                  style: TextStyle(
                    color: isOfficial
                        ? const Color(0xFF6D28D9)
                        : const Color(0xFF1D5CE5),
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.tenChuDe,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.tenBoDe,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nộp lúc: ${_formatDateTime(item.thoiGianNopBai ?? item.thoiGianBatDau)}',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Điểm: ${item.diemSo.toStringAsFixed(1)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: Color(0xFF1D5CE5),
                ),
              ),
              Text(
                'Đúng: ${item.soCauDung}/${item.tongSoCau}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
              Text(
                'TG: ${_formatDuration(item.thoiGianLamGiay)}',
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (canReview) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AttemptDetailScreen(
                        maLuotLam: item.maLuotLam,
                        fallbackTitle: item.tenBoDe,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text(
                  'Xem chi tiết bài làm',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1D5CE5),
                  side: const BorderSide(color: Color(0xFF1D5CE5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCupHistoryTab() {
    return RefreshIndicator(
      onRefresh: _fetchAllHistory,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _cupHistory.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(
                      child: Text(
                        'Chưa có lịch sử biến động cúp.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : Column(
                    children: _cupHistory.map((cup) {
                      final bool isPositive = cup.isPositive;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isPositive
                                    ? const Color(0xFFFEF3C7)
                                    : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.emoji_events_rounded,
                                color: isPositive
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cup.displayTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${cup.soCupTruoc} → ${cup.soCupSau} cúp',
                                    style: const TextStyle(
                                      color: Color(0xFF475569),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDateTime(cup.ngayTao),
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isPositive
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                cup.formattedValue,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isPositive
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ),
      ),
    );
  }
}