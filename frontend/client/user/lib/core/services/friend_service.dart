import 'dart:convert';
import 'package:user/core/constants/api_client.dart';
import 'package:user/core/constants/api_constants.dart';

typedef JsonMap = Map<String, dynamic>;
typedef JsonList = List<JsonMap>;

class FriendService {
  JsonList _parseJsonList(dynamic decoded) {
    final List rawList = decoded is List
        ? decoded
        : (decoded is Map && decoded['data'] is List
            ? decoded['data'] as List
            : const []);
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
    if (keyword.trim().isEmpty) return [];
    final res = await ApiClient.get(ApiConstants.searchFriends(keyword));
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      final err = _parseJsonMap(body);
      throw err['detail'] ?? 'Lỗi tìm kiếm người dùng.';
    }
    return _parseJsonList(body);
  }

  Future<JsonList> getFriends() async {
    final res = await ApiClient.get(ApiConstants.friendsList);
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      final err = _parseJsonMap(body);
      throw err['detail'] ?? 'Không thể tải danh sách bạn bè.';
    }
    return _parseJsonList(body);
  }

  Future<JsonMap> getFriendRequests() async {
    final res = await ApiClient.get(ApiConstants.friendRequests);
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      final err = _parseJsonMap(body);
      throw err['detail'] ?? 'Không thể tải danh sách lời mời.';
    }
    return _parseJsonMap(body);
  }

  Future<void> sendRequest(int maNguoiNhan) async {
    final res = await ApiClient.post(
      ApiConstants.sendFriendRequest,
      body: {'MaNguoiNhan': maNguoiNhan},
    );
    if (res.statusCode != 201) {
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      final map = _parseJsonMap(err);
      throw map['detail'] ?? 'Không thể gửi lời mời kết bạn.';
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
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      final map = _parseJsonMap(err);
      throw map['detail'] ?? 'Không thể xử lý lời mời kết bạn.';
    }
  }

  Future<void> cancelSentRequest(int targetUserId) async {
    final res =
        await ApiClient.delete(ApiConstants.cancelSentRequest(targetUserId));
    if (res.statusCode != 200) {
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      final map = _parseJsonMap(err);
      throw map['detail'] ?? 'Không thể hủy lời mời.';
    }
  }

  Future<void> unfriend(int friendUserId) async {
    final res = await ApiClient.delete(ApiConstants.unfriend(friendUserId));
    if (res.statusCode != 200) {
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      final map = _parseJsonMap(err);
      throw map['detail'] ?? 'Không thể hủy kết bạn.';
    }
  }
}