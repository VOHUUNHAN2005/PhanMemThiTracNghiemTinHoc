import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:user/core/constants/api_client.dart';
import 'package:user/core/constants/api_constants.dart';
import 'package:user/core/constants/app_colors.dart';
import 'package:user/core/models/user_model.dart';
import 'package:user/core/services/auth_service.dart';
import 'package:user/core/services/user_service.dart';
import 'package:user/core/shared/widgets/bottom_menu.dart';
import 'package:user/features/auth/login_screen.dart';
class ProfileScreen extends StatefulWidget {
  final UserModel? initialProfile;

  const ProfileScreen({super.key, this.initialProfile});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final ImagePicker _picker = ImagePicker();

  int selectedIndex = 4;
  String step = 'hoso';
  bool _isLoading = false;
  UserModel? _profile;

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
      }
    } catch (_) {}
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
    final tenHang = _profile?.tenHang ?? 'Đồng';
    final soCup = _profile?.soCupHienTai ?? 0;
    final avatarUrl = _profile?.anhDaiDien;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildBodyByStep(hoTen, tenHang, soCup, avatarUrl),
          ),
        ),
      ),
      bottomNavigationBar: BottomMenu(
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

  Widget _buildBodyByStep(String hoTen, String tenHang, int soCup, String? avatarUrl) {
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
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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
                TextField(controller: oldPassCtrl, obscureText: true, decoration: const InputDecoration(hintText: '••••••••', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                const Text('Mật khẩu mới (tối thiểu 6 ký tự)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(controller: newPassCtrl, obscureText: true, decoration: const InputDecoration(hintText: '••••••••', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                const Text('Xác nhận mật khẩu mới', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(controller: confirmPassCtrl, obscureText: true, decoration: const InputDecoration(hintText: '••••••••', border: OutlineInputBorder())),
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
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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
        const SizedBox(height: 6),
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
        const SizedBox(height: 14),
        const CupHistoryCard(),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: _isLoading ? null : _handleLogout,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            side: const BorderSide(color: AppColors.primaryBlue),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.primaryBlue, strokeWidth: 2))
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

// =========================================================================
// WIDGET CON NỘI BỘ CỦA PROFILE SCREEN
// =========================================================================

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
  const CupHistoryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.07), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lịch sử biến động cúp',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.darkText),
          ),
          SizedBox(height: 10),
          CupHistoryItem(title: 'Thi chính thức đạt', value: '+100', isPositive: true),
          CupHistoryItem(title: 'Thắng 1vs1', value: '+20', isPositive: true),
          CupHistoryItem(title: 'Top 2 giải đấu', value: '+50', isPositive: true),
          CupHistoryItem(title: 'Thua 1vs1', value: '+5', isPositive: true),
          CupHistoryItem(title: 'Bị hủy kết quả thi', value: '-1000', isPositive: false),
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