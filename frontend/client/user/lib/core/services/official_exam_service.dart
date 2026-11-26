import 'dart:convert';

import 'package:user/core/constants/api_client.dart';
import 'package:user/core/constants/api_constants.dart';

class OfficialExamService {
  Future<List<Map<String, dynamic>>> getAllOfficialExams() async {
    final topicsResponse = await ApiClient.get(ApiConstants.homeTopics);
    final topicsBody = jsonDecode(utf8.decode(topicsResponse.bodyBytes));
    if (topicsResponse.statusCode != 200) {
      throw _errorMessage(
        topicsBody,
        'Không thể tải danh sách chủ đề thi chính thức.',
      );
    }
    if (topicsBody is! List) {
      throw const FormatException('Dữ liệu danh sách chủ đề không hợp lệ.');
    }

    final topics = topicsBody
        .map((topic) => Map<String, dynamic>.from(topic as Map))
        .toList();
    final examsByTopic = await Future.wait(
      topics.map((topic) async {
        final response = await ApiClient.get(
          ApiConstants.homeExamsByTopic(topic['MaChuDe'] as int),
        );
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (response.statusCode != 200) {
          throw _errorMessage(body, 'Không thể tải danh sách đề thi.');
        }
        if (body is! Map || body['DanhSachBoDe'] is! List) {
          throw const FormatException('Dữ liệu danh sách đề thi không hợp lệ.');
        }

        return (body['DanhSachBoDe'] as List).map((exam) {
          return <String, dynamic>{
            ...Map<String, dynamic>.from(exam as Map),
            'TenChuDe': topic['TenChuDe'],
          };
        }).toList();
      }),
    );

    return examsByTopic.expand((exams) => exams).toList();
  }

  Future<Map<String, dynamic>> startExam(int maBoDe) async {
    final response =
        await ApiClient.post(ApiConstants.startOfficialExam(maBoDe));
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      throw _errorMessage(body, 'Không thể bắt đầu bài thi.');
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
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      throw _errorMessage(body, 'Không thể lưu câu trả lời.');
    }
  }

  Future<Map<String, dynamic>> submitExam(int maLuotLam) async {
    final response =
        await ApiClient.post(ApiConstants.submitOfficialExam(maLuotLam));
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      throw _errorMessage(body, 'Không thể nộp bài thi.');
    }
    return Map<String, dynamic>.from(body as Map);
  }

  Future<void> abortExam(int maLuotLam) async {
    final response =
        await ApiClient.post(ApiConstants.abortOfficialExam(maLuotLam));
    if (response.statusCode != 200) {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      throw _errorMessage(body, 'Không thể hủy bài thi.');
    }
  }

  Object _errorMessage(dynamic body, String fallback) {
    if (body is Map && body['detail'] != null) {
      return body['detail'] as Object;
    }
    return fallback;
  }
}
