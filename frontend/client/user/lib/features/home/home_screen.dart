import 'package:flutter/material.dart';
import 'package:user/core/models/user_model.dart';
import 'package:user/core/services/friend_service.dart';
import 'package:user/core/services/user_service.dart';
import 'package:user/core/shared/widgets/bottom_menu.dart';
import 'package:user/features/friends/friends_screen.dart';
import 'package:user/features/home/official_exam_screen.dart';
import 'package:user/features/practice/practice_screen.dart';
import 'package:user/features/profile/profile_screen.dart';
import 'package:user/features/arena/arena_lobby_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final UserService _userService = UserService();
  final FriendService _friendService = FriendService();

  int _tabIndex = 0;
  UserModel? _profile;
  int _pendingRequestsCount = 0;

  static const _ranks = [
    {
      'name': 'Đồng',
      'min': 0,
      'max': 500,
      'color': Color(0xFFB45309),
      'asset': 'assets/images/ranks/Rank_đồng.png',
      'icon': Icons.shield_rounded,
    },
    {
      'name': 'Bạc',
      'min': 500,
      'max': 1000,
      'color': Color(0xFF64748B),
      'asset': 'assets/images/ranks/Rank_bạc.png',
      'icon': Icons.shield_rounded,
    },
    {
      'name': 'Vàng',
      'min': 1000,
      'max': 1500,
      'color': Color(0xFFD97706),
      'asset': 'assets/images/ranks/Rank_vàng.png',
      'icon': Icons.shield_rounded,
    },
    {
      'name': 'Kim Cương',
      'min': 1500,
      'max': 2000,
      'color': Color(0xFF2563EB),
      'asset': 'assets/images/ranks/Rank_kim_cương.png',
      'icon': Icons.diamond_rounded,
    },
    {
      'name': 'Cao Thủ',
      'min': 2000,
      'max': 3000,
      'color': Color(0xFF7C3AED),
      'asset': 'assets/images/ranks/Rank_cao_thủ.png',
      'icon': Icons.workspace_premium_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final profile = await _userService.getProfile();
      if (mounted) {
        setState(() => _profile = profile);
      }
    } catch (_) {}

    try {
      final reqData = await _friendService.getFriendRequests();
      final incoming = reqData['incoming'] as List? ?? [];
      if (mounted) {
        setState(() => _pendingRequestsCount = incoming.length);
      }
    } catch (_) {}
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'US';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts[parts.length - 2][0]}${parts.last[0]}'.toUpperCase();
  }

  int _resolveCurrentRankIndex(int cups, String tenHang) {
    final idxByName = _ranks.indexWhere(
      (r) =>
          (r['name'] as String).toLowerCase() == tenHang.trim().toLowerCase(),
    );
    if (idxByName != -1) return idxByName;
    if (cups >= 2000) return 4;
    if (cups >= 1500) return 3;
    if (cups >= 1000) return 2;
    if (cups >= 500) return 1;
    return 0;
  }

  Widget _buildRankBadgeImage(
    Map<String, Object> rank, {
    required double size,
    required Color fallbackColor,
  }) {
    final String? assetPath = rank['asset'] as String?;
    final IconData fallbackIcon = rank['icon'] as IconData;

    if (assetPath == null || assetPath.isEmpty) {
      return Icon(fallbackIcon, color: fallbackColor, size: size * 0.75);
    }

    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => Icon(
        fallbackIcon,
        color: fallbackColor,
        size: size * 0.75,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget currentBody;
    switch (_tabIndex) {
      case 1:
        currentBody = const PracticeScreen();
        break;
      case 2:
        currentBody = const ArenaLobbyScreen();
        break;
      case 3:
        currentBody = const FriendsScreen();
        break;
      case 4:
        currentBody = ProfileScreen(
          initialProfile: _profile,
          embeddedInHome: true,
          onProfileUpdated: (updated) {
            if (mounted) setState(() => _profile = updated as UserModel?);
          },
        );
        break;
      default:
        currentBody = _buildDashboard();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEEF2FF),
      body: currentBody,
      bottomNavigationBar: BottomMenu(
        selectedIndex: _tabIndex,
        onTap: (idx) {
          setState(() => _tabIndex = idx);
          if (idx == 0) _loadDashboardData();
        },
      ),
    );
  }

  Widget _buildDashboard() {
    final String hoTen = _profile?.hoTen ?? 'Người dùng';
    final int soCup = _profile?.soCupHienTai ?? 0;
    final String tenHang = _profile?.tenHang ?? 'Đồng';
    final String? avatarUrl = _profile?.anhDaiDien;

    final int rankIndex = _resolveCurrentRankIndex(soCup, tenHang);
    final currentRank = _ranks[rankIndex];
    final int targetCup = currentRank['max'] as int;
    final int minCup = currentRank['min'] as int;
    final double progress =
        ((soCup - minCup) / (targetCup - minCup)).clamp(0.08, 1.0);

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // ================= HEADER XANH ĐẬM + TIẾN TRÌNH CÚP =================
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 14,
                20,
                24,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF172554), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: Center(
                child: SizedBox(
                  width: 390,
                  child: Column(
                    children: [
                      // Hàng thông tin User + Nút cài đặt
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF60A5FA),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor: const Color(0xFF1D5CE5),
                              backgroundImage:
                                  (avatarUrl != null && avatarUrl.isNotEmpty)
                                      ? NetworkImage(avatarUrl)
                                      : null,
                              child: (avatarUrl == null || avatarUrl.isEmpty)
                                  ? Text(
                                      _getInitials(hoTen),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Xin chào,',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        hoTen,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.verified_rounded,
                                      color: Color(0xFF38BDF8),
                                      size: 18,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // VỊ TRÍ 1: Huy hiệu rank nhỏ dưới tên người dùng
                                GestureDetector(
                                  onTap: () => setState(() => _tabIndex = 4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFFBBF24)
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildRankBadgeImage(
                                          currentRank,
                                          size: 16,
                                          fallbackColor: const Color(0xFFFBBF24),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${currentRank['name']} ›',
                                          style: const TextStyle(
                                            color: Color(0xFFFDE68A),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() => _tabIndex = 4),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.settings_outlined,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Thẻ Tiến trình lên hạng & 5 huy hiệu Rank
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _buildRankBadgeImage(
                                  currentRank,
                                  size: 22,
                                  fallbackColor: const Color(0xFF38BDF8),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Tiến trình lên ${currentRank['name']}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_formatNumber(soCup)} / ${_formatNumber(targetCup)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.18),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF38BDF8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // VỊ TRÍ 2: Dãy 5 huy hiệu Rank
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(_ranks.length, (i) {
                                final r = _ranks[i];
                                final bool isCurrent = i == rankIndex;
                                return Expanded(
                                  child: Column(
                                    children: [
                                      Container(
                                        width: isCurrent ? 48 : 40,
                                        height: isCurrent ? 48 : 40,
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: (r['color'] as Color)
                                              .withValues(
                                                  alpha: isCurrent ? 0.35 : 0.18),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isCurrent
                                                ? const Color(0xFFFBBF24)
                                                : Colors.white24,
                                            width: isCurrent ? 2 : 1,
                                          ),
                                        ),
                                        child: _buildRankBadgeImage(
                                          r,
                                          size: isCurrent ? 36 : 28,
                                          fallbackColor: isCurrent
                                              ? const Color(0xFF7DD3FC)
                                              : Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        r['name'] as String,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isCurrent
                                              ? const Color(0xFF7DD3FC)
                                              : Colors.white70,
                                          fontSize: 11,
                                          fontWeight: isCurrent
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ================= 4 Ô TÍNH NĂNG & QUẢN LÝ BẠN BÈ =================
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Center(
                child: SizedBox(
                  width: 390,
                  child: Column(
                    children: [
                      // Hàng 1: Ôn tập & Thi chính thức
                      Row(
                        children: [
                          Expanded(
                            child: _buildFeatureCard(
                              icon: Icons.menu_book_rounded,
                              iconBg: const Color(0xFF2563EB),
                              title: 'Ôn tập',
                              subtitle: 'Luyện đề tự do',
                              subtitleColor: const Color(0xFF64748B),
                              onTap: () => setState(() => _tabIndex = 1),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildFeatureCard(
                              icon: Icons.emoji_events_rounded,
                              iconBg: const Color(0xFF6D28D9),
                              title: 'Thi chính thức',
                              subtitle: 'Đạt: +100 cúp',
                              subtitleColor: const Color(0xFF2563EB),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const OfficialExamScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Hàng 2: Thi đấu trực tuyến & Lịch sử & BXH
                      Row(
                        children: [
                          Expanded(
                            child: _buildFeatureCard(
                              icon: Icons.sports_esports_rounded,
                              iconBg: const Color(0xFF5B21B6),
                              title: 'Thi đấu trực tuyến',
                              subtitle: '1 vs 1 và giải đấu',
                              subtitleColor: const Color(0xFF64748B),
                              onTap: () => setState(() => _tabIndex = 2),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildFeatureCard(
                              icon: Icons.bar_chart_rounded,
                              iconBg: const Color(0xFF16A34A),
                              title: 'Lịch sử & BXH',
                              subtitle: 'Kết quả, thứ hạng',
                              subtitleColor: const Color(0xFF64748B),
                              onTap: () => setState(() => _tabIndex = 4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Thanh banner Quản lý bạn bè
                      GestureDetector(
                        onTap: () => setState(() => _tabIndex = 3),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E3A8A), Color(0xFF312E81)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E3A8A)
                                    .withValues(alpha: 0.22),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.people_alt_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Quản lý bạn bè',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _pendingRequestsCount > 0
                                          ? '$_pendingRequestsCount lời mời đang chờ'
                                          : 'Kết bạn & mời đấu 1vs1',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text(
                                  'Xem →',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required Color subtitleColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: subtitleColor,
                    ),
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE0E7FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Color(0xFF1D5CE5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}