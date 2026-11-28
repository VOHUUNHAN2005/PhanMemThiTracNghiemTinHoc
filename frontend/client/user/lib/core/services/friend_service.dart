import 'dart:convert';
import 'package:user/core/constants/api_client.dart';
import 'package:user/core/constants/api_constants.dart';

typedef JsonMap = Map<String, dynamic>;
typedef JsonList = List<JsonMap>;

class FriendService {
  dynamic _safeDecode(List<int> bodyBytes) {
    final raw = utf8.decode(bodyBytes).trim();
    if (raw.isEmpty) return null;
    return jsonDecode(raw);
  }

  String _extractErrorMessage(dynamic decoded, String fallback) {
    if (decoded is Map) {
      final detail = decoded['detail'] ?? decoded['message'] ?? decoded['error'];
      if (detail != null && detail.toString().trim().isNotEmpty) {
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) {
            return first['msg'].toString();
          }
          return first.toString();
        }
        return detail.toString();
      }
    }
    if (decoded is String && decoded.trim().isNotEmpty) {
      return decoded.trim();
    }
    return fallback;
  }

  JsonList _parseJsonList(dynamic decoded) {
    final List rawList = decoded is List
        ? decoded
        : (decoded is Map && decoded['data'] is List
            ? decoded['data'] as List
            : (decoded is Map && decoded['items'] is List
                ? decoded['items'] as List
                : const []));

    return rawList
        .whereType()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  JsonMap _parseJsonMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  Future<JsonList> searchUsers(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return [];

    final res = await ApiClient.get(ApiConstants.searchFriends(trimmed));
    final body = _safeDecode(res.bodyBytes);
    if (res.statusCode != 200) {
      throw Exception(_extractErrorMessage(body, 'Lỗi tìm kiếm người dùng.'));
    }
    return _parseJsonList(body);
  }

  Future<JsonList> getFriends() async {
    final res = await ApiClient.get(ApiConstants.friendsList);
    final body = _safeDecode(res.bodyBytes);
    if (res.statusCode != 200) {
      throw Exception(
        _extractErrorMessage(body, 'Không thể tải danh sách bạn bè.'),
      );
    }
    return _parseJsonList(body);
  }

  Future<JsonMap> getFriendRequests() async {
    final res = await ApiClient.get(ApiConstants.friendRequests);
    final body = _safeDecode(res.bodyBytes);
    if (res.statusCode != 200) {
      throw Exception(
        _extractErrorMessage(body, 'Không thể tải danh sách lời mời.'),
      );
    }
    return _parseJsonMap(body);
  }

  Future<JsonMap> getFriendProfile(int targetUserId) async {
    final res = await ApiClient.get(ApiConstants.friendProfile(targetUserId));
    final body = _safeDecode(res.bodyBytes);
    if (res.statusCode != 200) {
      throw Exception(
        _extractErrorMessage(body, 'Không thể tải hồ sơ người chơi.'),
      );
    }
    return _parseJsonMap(body);
  }

  Future<void> sendRequest(int maNguoiNhan) async {
    final res = await ApiClient.post(
      ApiConstants.sendFriendRequest,
      body: {'MaNguoiNhan': maNguoiNhan},
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      final body = _safeDecode(res.bodyBytes);
      throw Exception(
        _extractErrorMessage(body, 'Không thể gửi lời mời kết bạn.'),
      );
    }
  }

  Future<void> respondRequest({
    required int maKetBan,
    required bool chapNhan,
  }) async {
    final res = await ApiClient.post(
      ApiConstants.respondFriendRequest,
      body: {
        'MaKetBan': maKetBan,
        'ChapNhan': chapNhan,
      },
    );
    if (res.statusCode != 200) {
      final body = _safeDecode(res.bodyBytes);
      throw Exception(
        _extractErrorMessage(body, 'Không thể xử lý lời mời kết bạn.'),
      );
    }
  }

  Future<void> cancelSentRequest(int targetUserId) async {
    final res =
        await ApiClient.delete(ApiConstants.cancelSentRequest(targetUserId));
    if (res.statusCode != 200 && res.statusCode != 204) {
      final body = _safeDecode(res.bodyBytes);
      throw Exception(_extractErrorMessage(body, 'Không thể hủy lời mời.'));
    }
  }

  Future<void> unfriend(int friendUserId) async {
    final res = await ApiClient.delete(ApiConstants.unfriend(friendUserId));
    if (res.statusCode != 200 && res.statusCode != 204) {
      final body = _safeDecode(res.bodyBytes);
      throw Exception(_extractErrorMessage(body, 'Không thể hủy kết bạn.'));
    }
  }
}