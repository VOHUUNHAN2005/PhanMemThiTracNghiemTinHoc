import 'dart:convert';
import 'dart:typed_data';
import 'package:user/core/constants/api_client.dart';
import 'package:user/core/constants/api_constants.dart';
import 'package:user/core/models/attempt_history_model.dart';
import 'package:user/core/models/cup_history_model.dart';

import '../models/user_model.dart';

typedef JsonMap = Map<String, dynamic>;

class UserService {
  Future<UserModel> getProfile() async {
    final res = await ApiClient.get(ApiConstants.getMe);
    if (res.statusCode != 200) {
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      throw err['detail'] ?? 'Lỗi tải hồ sơ cá nhân.';
    }
    return UserModel.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

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

  Future<List<CupHistoryModel>> getCupHistory() async {
    final res = await ApiClient.get(ApiConstants.userHistory);
    if (res.statusCode != 200) {
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      throw err['detail'] ?? 'Không thể tải lịch sử biến động cúp.';
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    final List rawList = decoded['cup_history'] ?? [];
    return rawList
        .map((e) => CupHistoryModel.fromJson(JsonMap.from(e)))
        .toList();
  }

  Future<JsonMap> getLeaderboard() async {
    final res = await ApiClient.get(ApiConstants.leaderboard);
    if (res.statusCode != 200) {
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      throw err['detail'] ?? 'Không thể tải bảng xếp hạng.';
    }
    return JsonMap.from(jsonDecode(utf8.decode(res.bodyBytes)));
  }
  Future<List<AttemptHistoryModel>> getAttemptHistory() async {
    final res = await ApiClient.get(ApiConstants.userHistory);
    if (res.statusCode != 200) {
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      throw err['detail'] ?? 'Không thể tải lịch sử làm bài.';
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    final List rawList = decoded['attempts'] ?? [];
    return rawList
        .whereType()
        .map((e) => AttemptHistoryModel.fromJson(JsonMap.from(e)))
        .toList();
  }

  Future<AttemptDetailModel> getAttemptDetail(int maLuotLam) async {
    final res = await ApiClient.get(ApiConstants.attemptDetail(maLuotLam));
    if (res.statusCode != 200) {
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      throw err['detail'] ?? 'Không thể tải chi tiết bài làm.';
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    return AttemptDetailModel.fromJson(JsonMap.from(decoded));
  }
}