import 'dart:convert';

import 'package:user/core/constants/api_client.dart';
import 'package:user/core/constants/api_constants.dart';

class OfficialExamService {
  dynamic _safeDecode(List<int> bodyBytes) {
    final raw = utf8.decode(bodyBytes).trim();
    if (raw.isEmpty) return null;
    return jsonDecode(raw);
  }

  String _errorMessage(dynamic body, String fallback) {
    if (body is Map && body['detail'] != null) {
      final detail = body['detail'];
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) {
          return first['msg'].toString();
        }
        return first.toString();
      }
      return detail.toString();
    }
    return fallback;
  }

  Future<dynamic> getAllOfficialExams() async {
    final topicsResponse = await ApiClient.get(ApiConstants.homeTopics);
    final topicsBody = _safeDecode(topicsResponse.bodyBytes);
    if (topicsResponse.statusCode != 200) {
      throw Exception(
        _errorMessage(
          topicsBody,
          'Không thể tải danh sách chủ đề thi chính thức.',
        ),
      );
    }
    if (topicsBody is! List) {
      throw const FormatException('Dữ liệu danh sách chủ đề không hợp lệ.');
    }

    final List<dynamic> allExams = [];
    for (final rawTopic in topicsBody) {
      final topic = Map<String, dynamic>.from(rawTopic as Map);
      final response = await ApiClient.get(
        ApiConstants.homeExamsByTopic(topic['MaChuDe'] as int),
      );
      final body = _safeDecode(response.bodyBytes);
      if (response.statusCode != 200) {
        throw Exception(
          _errorMessage(body, 'Không thể tải danh sách đề thi.'),
        );
      }
      if (body is! Map || body['DanhSachBoDe'] is! List) {
        throw const FormatException('Dữ liệu danh sách đề thi không hợp lệ.');
      }

      for (final rawExam in (body['DanhSachBoDe'] as List)) {
        allExams.add({
          ...Map<String, dynamic>.from(rawExam as Map),
          'TenChuDe': topic['TenChuDe'],
        });
      }
    }

    return allExams;
  }

  Future<dynamic> startExam(int maBoDe) async {
    final response =
        await ApiClient.post(ApiConstants.startOfficialExam(maBoDe));
    final body = _safeDecode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(body, 'Không thể bắt đầu bài thi.'));
    }
    return Map<String, dynamic>.from(body as Map);
  }

  Future<void> saveAnswer({
    required int maLuotLam,
    required int maCauHoi,
    required List<int> danhSachMaDapAn,
  }) async {
    final response = await ApiClient.post(
      ApiConstants.saveOfficialAnswer(maLuotLam),
      body: {
        'MaCauHoi': maCauHoi,
        'DanhSachMaDapAn': danhSachMaDapAn,
      },
    );
    if (response.statusCode != 200) {
      final body = _safeDecode(response.bodyBytes);
      throw Exception(_errorMessage(body, 'Không thể lưu câu trả lời.'));
    }
  }

  Future<dynamic> submitExam(int maLuotLam) async {
    final response =
        await ApiClient.post(ApiConstants.submitOfficialExam(maLuotLam));
    final body = _safeDecode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(body, 'Không thể nộp bài thi.'));
    }
    return Map<String, dynamic>.from(body as Map);
  }

  Future<void> abortExam(int maLuotLam) async {
    final response =
        await ApiClient.post(ApiConstants.abortOfficialExam(maLuotLam));
    if (response.statusCode != 200) {
      final body = _safeDecode(response.bodyBytes);
      throw Exception(_errorMessage(body, 'Không thể hủy bài thi.'));
    }
  }

  Future<dynamic> reportCheat({
    required int maLuotLam,
    String lyDo = 'Rời khỏi ứng dụng khi thi',
  }) async {
    final cleaned =
        lyDo.trim().isEmpty ? 'Gian lận trong phòng thi' : lyDo.trim();
    final safeReason =
        cleaned.length > 30 ? cleaned.substring(0, 30) : cleaned;

    final response = await ApiClient.post(
      '/api/official/attempts/$maLuotLam/cheat',
      body: {'LyDo': safeReason},
    );
    final body = _safeDecode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw Exception(
        _errorMessage(body, 'Không thể ghi nhận hành vi gian lận.'),
      );
    }
    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }
}