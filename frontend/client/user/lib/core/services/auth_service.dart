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
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    await cred.user?.getIdToken(true);

    final res = await ApiClient.get(ApiConstants.getMe);
    if (res.statusCode != 200) {
      String detailMessage = 'Không thể tải thông tin tài khoản.';
      try {
        final err = jsonDecode(utf8.decode(res.bodyBytes));
        if (err is Map && err['detail'] != null) {
          detailMessage = err['detail'].toString();
        }
      } catch (_) {}

      await _auth.signOut();
      throw detailMessage;
    }

    final userData = jsonDecode(utf8.decode(res.bodyBytes));

    try {
      await ApiClient.post(
        ApiConstants.syncDevice,
        body: {'MaThietBiHienTai': deviceId},
      );
    } catch (_) {}

    return UserModel.fromJson(userData);
  }

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

    await cred.user?.getIdToken(true);

    final res = await ApiClient.post(
      ApiConstants.register,
      body: {'HoTen': hoTen.trim(), 'TenDangNhap': tenDangNhap.trim()},
    );

    if (res.statusCode != 201) {
      await cred.user?.delete();
      String detailMessage = 'Đăng ký thất bại.';
      try {
        final err = jsonDecode(utf8.decode(res.bodyBytes));
        if (err is Map && err['detail'] != null) {
          detailMessage = err['detail'].toString();
        }
      } catch (_) {}
      throw detailMessage;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

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

  Future<void> logout() async {
    try {
      await ApiClient.post(ApiConstants.logout);
    } finally {
      await _auth.signOut();
    }
  }
}
