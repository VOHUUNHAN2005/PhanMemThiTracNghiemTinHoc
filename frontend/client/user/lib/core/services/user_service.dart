import 'dart:convert';
import 'dart:typed_data';
import 'package:user/core/constants/api_client.dart';
import 'package:user/core/constants/api_constants.dart';

import '../models/user_model.dart';

class UserService {
  /// Lấy hồ sơ mới nhất của người dùng hiện tại
  Future<UserModel> getProfile() async {
    final res = await ApiClient.get(ApiConstants.getMe);
    if (res.statusCode != 200) {
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      throw err['detail'] ?? 'Lỗi tải hồ sơ cá nhân.';
    }
    return UserModel.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  /// Cập nhật Họ tên & Tên đăng nhập
  Future<void> updateProfile({
    required String hoTen,
    required String tenDangNhap,
  }) async {
    final res = await ApiClient.put(
      ApiConstants.updateMe,
      body: {
        'HoTen': hoTen.trim(),
        'TenDangNhap': tenDangNhap.trim(),
      },
    );
    if (res.statusCode != 200) {
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      throw err['detail'] ?? 'Cập nhật thông tin thất bại.';
    }
  }

  /// Tải ảnh đại diện mới lên server
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String filename,
  }) async {
    final res = await ApiClient.uploadFile(
      url: ApiConstants.uploadAvatar,
      bytes: bytes,
      filename: filename,
    );
    if (res.statusCode != 200) {
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      throw err['detail'] ?? 'Tải ảnh đại diện thất bại.';
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    return data['AnhDaiDien'];
  }
}