import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:user/core/constants/api_client.dart';
import 'package:user/core/constants/api_constants.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserModel> login({
    required String email,
    required String password,
    String deviceId = 'FLUTTER_CLIENT',
  }) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

    final res = await ApiClient.get(ApiConstants.getMe);
    if (res.statusCode != 200) {
      await _auth.signOut();
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      throw err['detail'] ?? 'Không thể tải thông tin tài khoản.';
    }

    final userData = jsonDecode(utf8.decode(res.bodyBytes));

    // Đồng bộ thiết bị (không chặn luồng nếu lỗi phụ)
    try {
      await ApiClient.post(
        ApiConstants.syncDevice,
        body: {'MaThietBiHienTai': deviceId},
      );
    } catch (_) {}

    return UserModel.fromJson(userData);
  }

  /// Đăng ký tài khoản Firebase + Lưu xuống SQL Server
  Future<void> register({
    required String email,
    required String password,
    required String hoTen,
    required String tenDangNhap,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final res = await ApiClient.post(
      ApiConstants.register,
      body: {
        'HoTen': hoTen.trim(),
        'TenDangNhap': tenDangNhap.trim(),
      },
    );

    if (res.statusCode != 201) {
      // Rollback user Firebase nếu lưu SQL Server thất bại (ví dụ trùng username)
      await cred.user?.delete();
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      throw err['detail'] ?? 'Đăng ký thất bại.';
    }
  }

  /// Gửi email khôi phục mật khẩu
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Đổi mật khẩu khi đang đăng nhập
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw 'Phiên đăng nhập không hợp lệ.';
    }
    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
  }

  /// Đăng xuất hệ thống & cập nhật TrangThaiOnline = 0
  Future<void> logout() async {
    try {
      await ApiClient.post(ApiConstants.logout);
    } finally {
      await _auth.signOut();
    }
  }
}