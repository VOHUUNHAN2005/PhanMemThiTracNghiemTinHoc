import 'dart:convert';
import 'package:user/core/constants/api_client.dart';
import 'package:user/core/constants/api_constants.dart';

class FavoriteReviewService {
  dynamic _safeDecode(List<int> bodyBytes) {
    final raw = utf8.decode(bodyBytes).trim();
    if (raw.isEmpty) return null;
    return jsonDecode(raw);
  }

  String _extractError(dynamic body, String fallback) {
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

  Future<Map<String, dynamic>> getMyFavoritesGroupedByTopic() async {
    final res = await ApiClient.get(ApiConstants.myFavorites);
    final body = _safeDecode(res.bodyBytes);

    if (res.statusCode != 200) {
      throw Exception(
        _extractError(body, 'Không thể tải danh sách bộ đề yêu thích.'),
      );
    }

    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> toggleFavoriteExam(int maBoDe) async {
    final res = await ApiClient.post(ApiConstants.toggleFavoriteExam(maBoDe));

    final body = _safeDecode(res.bodyBytes);

    if (res.statusCode != 200) {
      throw Exception(
        _extractError(body, 'Không thể cập nhật trạng thái yêu thích.'),
      );
    }

    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getOfficialExamReviewSummary(int maBoDe) async {
    final res = await ApiClient.get(
      ApiConstants.officialExamReviewSummary(maBoDe),
    );

    final body = _safeDecode(res.bodyBytes);

    if (res.statusCode != 200) {
      throw Exception(
        _extractError(body, 'Không thể tải thông tin đánh giá độ khó.'),
      );
    }

    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> submitOfficialExamReview({
    required int maBoDe,
    required int soSao,
    String? gopY,
  }) async {
    final res = await ApiClient.post(
      ApiConstants.submitOfficialExamReview(maBoDe),
      body: {
        'SoSao': soSao,
        if (gopY != null && gopY.trim().isNotEmpty) 'BinhLuan': gopY.trim(),
      },
    );

    final body = _safeDecode(res.bodyBytes);

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_extractError(body, 'Không thể gửi đánh giá và góp ý.'));
    }

    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }
}
