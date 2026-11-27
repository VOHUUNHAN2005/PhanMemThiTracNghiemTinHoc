import 'dart:convert';
import 'dart:core';
import 'package:user/core/constants/api_client.dart';
import 'package:user/core/constants/api_constants.dart';

class PracticeService {
  Future<List<Map<String, dynamic>>> getPracticeTopics() async {
    final res = await ApiClient.get(ApiConstants.practiceTopics);
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      throw body['detail'] ?? 'Không thể tải danh sách chủ đề ôn tập.';
    }
    return List<Map<String, dynamic>>.from(body);
  }

  Future<List<Map<String, dynamic>>> getExamsByTopic(int maChuDe) async {
    final res =
        await ApiClient.get(ApiConstants.practiceExamsByTopic(maChuDe));
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      throw body['detail'] ?? 'Không thể tải danh sách bộ đề.';
    }
    return List<Map<String, dynamic>>.from(body['DanhSachBoDe'] ?? []);
  }

  Future<Map<String, dynamic>> startOrResumePractice(int maBoDe) async {
    final res = await ApiClient.post(ApiConstants.startPractice(maBoDe));
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      throw body['detail'] ?? 'Không thể khởi tạo phiên ôn tập.';
    }
    return Map<String, dynamic>.from(body);
  }

  Future<Map<String, dynamic>> checkQuestion({
    required int maLuotLam,
    required int maCauHoi,
    required List<int> danhSachMaDapAn,
  }) async {
    final res = await ApiClient.post(
      ApiConstants.checkPracticeQuestion(maLuotLam),
      body: {
        'MaCauHoi': maCauHoi,
        'DanhSachMaDapAn': danhSachMaDapAn,
      },
    );
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      throw body['detail'] ?? 'Không thể kiểm tra đáp án.';
    }
    return Map<String, dynamic>.from(body);
  }

  Future<Map<String, dynamic>> finishPractice(int maLuotLam) async {
    final res = await ApiClient.post(ApiConstants.finishPractice(maLuotLam));
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      throw body['detail'] ?? 'Không thể nộp bài ôn tập.';
    }
    return Map<String, dynamic>.from(body);
  }

  Future<void> cancelPractice(int maLuotLam) async {
    final res = await ApiClient.delete(ApiConstants.cancelPractice(maLuotLam));
    if (res.statusCode != 200) {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      throw body['detail'] ?? 'Không thể hủy lượt ôn tập.';
    }
  }
}