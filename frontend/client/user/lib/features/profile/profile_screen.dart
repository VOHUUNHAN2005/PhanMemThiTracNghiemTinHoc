import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:user/core/constants/app_colors.dart';
import 'package:user/core/models/cup_history_model.dart';
import 'package:user/core/models/user_model.dart';
import 'package:user/core/services/auth_service.dart';
import 'package:user/core/services/user_service.dart';
import 'package:user/core/shared/widgets/bottom_menu.dart';
import 'package:user/features/auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel? initialProfile;
  final bool embeddedInHome;
  final void Function(UserModel updatedProfile)? onProfileUpdated;

  const ProfileScreen({
    super.key,
    this.initialProfile,
    this.embeddedInHome = false,
    this.onProfileUpdated,
  });

  @override
  State createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final ImagePicker _picker = ImagePicker();

  int selectedIndex = 4;
  String step = 'hoso';
  bool _isLoading = false;
  bool _isLoadingHistory = true;
  UserModel? _profile;
  List _cupHistory = [];

  XFile? _pickedImageFile;
  Uint8List? _pickedImageBytes;

  late final TextEditingController hoTenCtrl;
  late final TextEditingController usernameCtrl;
  final oldPassCtrl = TextEditingController();
  final newPassCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
    hoTenCtrl = TextEditingController(text: _profile?.hoTen ?? '');
    usernameCtrl = TextEditingController(text: _profile?.tenDangNhap ?? '');
    _fetchProfile();
    _fetchCupHistory();
  }

  @override
  void dispose() {
    hoTenCtrl.dispose();
    usernameCtrl.dispose();
    oldPassCtrl.dispose();
    newPassCtrl.dispose();
    confirmPassCtrl.dispose();
    super.dispose();
  }

  void showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green.shade700,
      ),
    );
  }

  Future<void> _fetchProfile() async {
    try {
      final data = await _userService.getProfile();
      if (mounted) {
        setState(() {
          _profile = data;
          hoTenCtrl.text = data.hoTen;
          usernameCtrl.text = data.tenDangNhap;
        });
        widget.onProfileUpdated?.call(data);
      }
    } catch (_) {}
  }

  Future<void> _fetchCupHistory() async {
    if (mounted) setState(() => _isLoadingHistory = true);
    try {
      final list = await _userService.getCupHistory();
      if (mounted) {
        setState(() => _cupHistory = list);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _pickAvatarImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _pickedImageFile = image;
          _pickedImageBytes = bytes;
        });
      }
    } catch (e) {
      showMessage('Không thể mở thư viện ảnh: $e', isError: true);
    }
  }

  Future<void> _handleUpdateProfile() async {
    if (hoTenCtrl.text.trim().isEmpty || usernameCtrl.text.trim().isEmpty) {
      showMessage('Không được để trống họ tên hoặc tên đăng nhập.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_pickedImageFile != null && _pickedImageBytes != null) {
        await _userService.uploadAvatar(
          bytes: _pickedImageBytes!,
          filename: _pickedImageFile!.name,
        );
      }

      await _userService.updateProfile(
        hoTen: hoTenCtrl.text,
        tenDangNhap: usernameCtrl.text,
      );

      _pickedImageFile = null;
      _pickedImageBytes = null;
      await _fetchProfile();
      if (mounted) setState(() => step = 'hoso');
      showMessage('Cập nhật hồ sơ thành công!');
    } catch (e) {
      showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleChangePassword() async {
    if (oldPassCtrl.text.isEmpty || newPassCtrl.text.length < 6) {
      showMessage('Mật khẩu mới phải có ít nhất 6 ký tự.', isError: true);
      return;
    }
    if (newPassCtrl.text != confirmPassCtrl.text) {
      showMessage('Mật khẩu xác nhận không khớp.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.changePassword(
        currentPassword: oldPassCtrl.text,
        newPassword: newPassCtrl.text,
      );
      oldPassCtrl.clear();
      newPassCtrl.clear();
      confirmPassCtrl.clear();
      if (mounted) setState(() => step = 'hoso');
      showMessage('Đổi mật khẩu thành công!');
    } catch (e) {
      showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoading = true);
    try {
      await _authService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      showMessage('Lỗi khi đăng xuất: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCupRulesBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.amber, size: 26),
                SizedBox(width: 8),
                Text(
                  'Quy tắc cộng / trừ cúp',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildRuleRow('Đề thi chính thức (Đạt lần đầu)', '+100 Cúp', true),
            _buildRuleRow('Đấu 1vs1 - Thắng trận (đúng > 50%)', '+50 Cúp', true),
            _buildRuleRow('Đấu 1vs1 - Thua trận (đúng > 50%)', '+25 Cúp', true),
            _buildRuleRow('Đấu 1vs1 / Giải đấu - Đúng ≤ 50% hoặc bỏ cuộc', '+0 Cúp', true),
            _buildRuleRow('Giải đấu nhiều người - Top 1 (đúng > 50%)', '+100 Cúp', true),
            _buildRuleRow('Giải đấu nhiều người - Top 2 (đúng > 50%)', '+70 Cúp', true),
            _buildRuleRow('Giải đấu nhiều người - Top 3 (đúng > 50%)', '+50 Cúp', true),
            _buildRuleRow('Giải đấu nhiều người - Hạng 4+ (đúng > 50%)', '+25 Cúp', true),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleRow(String label, String value, bool isPositive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.subText))),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isPositive ? const Color(0xFF176B38) : const Color(0xFFAA2020),
            ),
          ),
        ],
      ),
    );
  }

  void _openLeaderboardModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => FutureBuilder(
          future: _userService.getLeaderboard(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Lỗi tải bảng xếp hạng: ${snapshot.error}'));
            }
            final Map data = (snapshot.data as Map?) ?? {};
            final int myRank = data['HangCuaToi'] ?? 0;
            final int myCups = data['SoCupCuaToi'] ?? 0;
            final String myTier = data['TenHangCuaToi'] ?? '';
            final List topPlayers = data['TopNguoiChoi'] ?? [];

            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Bảng xếp hạng',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkText),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.rankBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hạng hiện tại của bạn: #$myRank',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText)),
                          Text('Bậc rank: $myTier', style: const TextStyle(color: AppColors.subText, fontSize: 13)),
                        ],
                      ),
                      Text(
                        '$myCups Cúp',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.rankText),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: topPlayers.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final p = topPlayers[index];
                      final int rank = p['Hang'] ?? (index + 1);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: CircleAvatar(
                          backgroundColor: rank == 1
                              ? Colors.amber
                              : (rank == 2 ? Colors.grey.shade400 : (rank == 3 ? Colors.brown.shade300 : AppColors.rankBg)),
                          child: Text(
                            '$rank',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText),
                          ),
                        ),
                        title: Text(p['HoTen'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('@${p['TenDangNhap'] ?? ''} • ${p['TenHang'] ?? ''}'),
                        trailing: Text(
                          '${p['SoCupHienTai'] ?? 0} Cúp',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'US';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[parts.length - 2][0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hoTen = _profile?.hoTen ?? 'Đang tải...';
    final tenDangNhap = _profile?.tenDangNhap ?? '';
    final tenHang = _profile?.tenHang ?? 'Đồng';
    final soCup = _profile?.soCupHienTai ?? 0;
    final avatarUrl = _profile?.anhDaiDien;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([_fetchProfile(), _fetchCupHistory()]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildBodyByStep(hoTen, tenDangNhap, tenHang, soCup, avatarUrl),
            ),
          ),
        ),
      ),
      bottomNavigationBar: widget.embeddedInHome
          ? null
          : BottomMenu(
              selectedIndex: selectedIndex,
              onTap: (index) {
                setState(() {
                  selectedIndex = index;
                  if (index == 4) step = 'hoso';
                });
              },
            ),
    );
  }

  Widget _buildBodyByStep(
      String hoTen, String tenDangNhap, String tenHang, int soCup, String? avatarUrl) {
    if (step == 'sua') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                          _pickedImageFile = null;
                          _pickedImageBytes = null;
                          step = 'hoso';
                        }),
              ),
              const Text(
                'Sửa thông tin',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.darkText),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _isLoading ? null : _pickAvatarImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      AvatarWidget(
                        initials: _getInitials(hoTen),
                        avatarUrl: avatarUrl,
                        previewBytes: _pickedImageBytes,
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _isLoading ? null : _pickAvatarImage,
                  child: const Text(
                    'Đổi ảnh đại diện',
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(_profile?.email ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Họ và tên', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(controller: hoTenCtrl, decoration: const InputDecoration(border: OutlineInputBorder())),
                const SizedBox(height: 14),
                const Text('Tên đăng nhập (Username)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(controller: usernameCtrl, decoration: const InputDecoration(border: OutlineInputBorder())),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleUpdateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Lưu thay đổi', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
    }

    if (step == 'matkhau') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _isLoading ? null : () => setState(() => step = 'hoso'),
              ),
              const Text(
                'Đổi mật khẩu',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.darkText),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mật khẩu hiện tại', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                    controller: oldPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: '••••••••', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                const Text('Mật khẩu mới (tối thiểu 6 ký tự)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                    controller: newPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: '••••••••', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                const Text('Xác nhận mật khẩu mới', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                    controller: confirmPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: '••••••••', border: OutlineInputBorder())),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleChangePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Cập nhật mật khẩu', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
    }

    return Column(
      children: [
        const SizedBox(height: 28),
        AvatarWidget(initials: _getInitials(hoTen), avatarUrl: avatarUrl),
        const SizedBox(height: 8),
        Text(
          hoTen,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.darkText),
        ),
        if (tenDangNhap.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            '@$tenDangNhap',
            style: const TextStyle(fontSize: 14, color: AppColors.subText, fontWeight: FontWeight.w500),
          ),
        ],
        const SizedBox(height: 8),
        RankWidget(tenHang: tenHang, soCup: soCup),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ActionButton(
                text: 'Sửa thông tin',
                onPressed: () {
                  hoTenCtrl.text = _profile?.hoTen ?? '';
                  usernameCtrl.text = _profile?.tenDangNhap ?? '';
                  _pickedImageFile = null;
                  _pickedImageBytes = null;
                  setState(() => step = 'sua');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ActionButton(
                text: 'Đổi mật khẩu',
                onPressed: () => setState(() => step = 'matkhau'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openLeaderboardModal,
                icon: const Icon(Icons.leaderboard, size: 18, color: AppColors.primaryBlue),
                label: const Text('Bảng xếp hạng',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.primaryBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showCupRulesBottomSheet,
                icon: const Icon(Icons.info_outline, size: 18, color: AppColors.primaryBlue),
                label: const Text('Luật +/- cúp',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.primaryBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        CupHistoryCard(
          historyList: _cupHistory,
          isLoading: _isLoadingHistory,
          onViewRules: _showCupRulesBottomSheet,
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: _isLoading ? null : _handleLogout,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            side: const BorderSide(color: AppColors.primaryBlue),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.primaryBlue, strokeWidth: 2))
              : const Text(
                  'Đăng xuất',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class AvatarWidget extends StatelessWidget {
  final String initials;
  final String? avatarUrl;
  final Uint8List? previewBytes;

  const AvatarWidget({
    super.key,
    required this.initials,
    this.avatarUrl,
    this.previewBytes,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (previewBytes != null) {
      imageProvider = MemoryImage(previewBytes!);
    } else if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      imageProvider = NetworkImage(avatarUrl!);
    }

    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFF2048B8), Color(0xFF2862EB)]),
        image: imageProvider != null ? DecorationImage(image: imageProvider, fit: BoxFit.cover) : null,
      ),
      alignment: Alignment.center,
      child: imageProvider == null
          ? Text(
              initials,
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            )
          : null,
    );
  }
}

class RankWidget extends StatelessWidget {
  final String tenHang;
  final int soCup;

  const RankWidget({super.key, required this.tenHang, required this.soCup});

  @override
  Widget build(BuildContext context) {
    final formattedCup = soCup.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: AppColors.rankBg, borderRadius: BorderRadius.circular(30)),
      child: Text(
        'Hạng $tenHang • $formattedCup Cúp',
        style: const TextStyle(color: AppColors.rankText, fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const ActionButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class CupHistoryCard extends StatelessWidget {
  final List historyList;
  final bool isLoading;
  final VoidCallback onViewRules;

  const CupHistoryCard({
    super.key,
    required this.historyList,
    required this.isLoading,
    required this.onViewRules,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasScroll = historyList.length > 7;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.07),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lịch sử biến động cúp',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                ),
              ),
              GestureDetector(
                onTap: onViewRules,
                child: const Text(
                  'Quy tắc',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (historyList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Chưa có lịch sử biến động cúp nào.',
                  style: TextStyle(color: AppColors.subText, fontSize: 14),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: Scrollbar(
                thumbVisibility: hasScroll,
                child: ListView.builder(
                  shrinkWrap: true,
                  primary: false,
                  physics: hasScroll
                      ? const AlwaysScrollableScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.only(right: hasScroll ? 12 : 0),
                  itemCount: historyList.length,
                  itemBuilder: (context, index) {
                    final CupHistoryModel history =
                        historyList[index] as CupHistoryModel;
                    return CupHistoryItem(
                      title: history.displayTitle,
                      value: history.formattedValue,
                      isPositive: history.isPositive,
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CupHistoryItem extends StatelessWidget {
  final String title;
  final String value;
  final bool isPositive;

  const CupHistoryItem({super.key, required this.title, required this.value, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 14, color: AppColors.subText)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isPositive ? const Color(0xFF176B38) : const Color(0xFFAA2020),
            ),
          ),
        ],
      ),
    );
  }
}