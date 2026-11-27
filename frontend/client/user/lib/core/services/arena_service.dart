import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:user/core/constants/api_constants.dart';

typedef JsonMap = Map<String, dynamic>;
typedef HeaderMap = Map<String, String>;

class ArenaService {
  static WebSocketChannel? _channel;
  static StreamSubscription? _wsSub;
  static Timer? _pingTimer;
  static Timer? _reconnectTimer;
  static bool _isConnecting = false;
  static bool _manualDisconnect = false;

  static final StreamController<JsonMap> _eventController =
      StreamController<JsonMap>.broadcast();

  static Stream<JsonMap> get events => _eventController.stream;

  static Future<void> ensureConnected() async {
    if (_channel != null || _isConnecting) return;
    _isConnecting = true;
    _manualDisconnect = false;

    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return;

      final uri = Uri.parse(
        '${ApiConstants.wsBaseUrl}/ws/realtime?token=${Uri.encodeComponent(token)}',
      );
      final channel = WebSocketChannel.connect(uri);
      await channel.ready;
      _channel = channel;

      _wsSub = channel.stream.listen(
        (raw) {
          try {
            final decoded = jsonDecode(raw.toString());
            if (decoded is Map) {
              _eventController.add(JsonMap.from(decoded));
            }
          } catch (_) {}
        },
        onDone: _handleSocketClosed,
        onError: (_) => _handleSocketClosed(),
      );

      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        sendAction('PING');
      });
    } catch (_) {
      _handleSocketClosed();
    } finally {
      _isConnecting = false;
    }
  }

  static void _handleSocketClosed() {
    _cleanupSocket();
    if (!_manualDisconnect && FirebaseAuth.instance.currentUser != null) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 4), () {
        ensureConnected();
      });
    }
  }

  static void _cleanupSocket() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _wsSub?.cancel();
    _wsSub = null;
    _channel = null;
  }

  static Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _cleanupSocket();
  }

  static Future<void> sendAction(String action, [JsonMap? data]) async {
    await ensureConnected();
    if (_channel == null) return;
    try {
      _channel!.sink.add(jsonEncode({
        'action': action,
        'data': data ?? <String, dynamic>{},
      }));
    } catch (_) {}
  }

  static Future<HeaderMap> _getHeaders() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      'ngrok-skip-browser-warning': 'true'
    };
  }

  static String _extractError(http.Response res, String fallback) {
    try {
      final rawText = utf8.decode(res.bodyBytes).trim();
      if (rawText.isEmpty) {
        return '$fallback (HTTP ${res.statusCode})';
      }
      final decoded = jsonDecode(rawText);
      if (decoded is Map) {
        final detail = decoded['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail;
        }
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) {
            final loc = (first['loc'] is List) ? (first['loc'] as List).join('.') : '';
            return loc.isNotEmpty ? '$loc: ${first['msg']}' : first['msg'].toString();
          }
          return detail.first.toString();
        }
        if (decoded['message'] != null) {
          return decoded['message'].toString();
        }
      }
    } catch (_) {}
    return '$fallback (HTTP ${res.statusCode})';
  }

  static Future<JsonMap> getCurrentUserProfile() async {
    final fbUser = FirebaseAuth.instance.currentUser;
    String fallbackName = fbUser?.displayName ?? '';
    if (fallbackName.trim().isEmpty && fbUser?.email != null) {
      fallbackName = fbUser!.email!.split('@').first;
    }
    if (fallbackName.trim().isEmpty) {
      fallbackName = 'Thí sinh';
    }

    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(ApiConstants.getMe),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final JsonMap data = (decoded is Map && decoded['data'] is Map)
            ? JsonMap.from(decoded['data'])
            : (decoded is Map ? JsonMap.from(decoded) : {});

        return {
          'id': int.tryParse((data['MaNguoiDung'] ?? 0).toString()) ?? 0,
          'name': (data['HoTen'] ?? data['TenDangNhap'] ?? fallbackName)
              .toString(),
          'rank': (data['TenHang'] ?? 'Đồng').toString(),
          'cups': int.tryParse((data['SoCupHienTai'] ?? 0).toString()) ?? 0,
        };
      }
    } catch (_) {}

    return {'id': 0, 'name': fallbackName, 'rank': 'Đồng', 'cups': 0};
  }

  static Future<List<JsonMap>> getArenaTopics() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(ApiConstants.homeTopics),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final List raw = (decoded is Map && decoded['data'] is List)
            ? decoded['data']
            : (decoded is List ? decoded : []);
        return raw.whereType().map((e) {
          final m = JsonMap.from(e);
          return {
            'ma_chu_de':
                int.tryParse((m['MaChuDe'] ?? m['ma_chu_de'] ?? 0).toString()) ??
                    0,
            'ten_chu_de':
                (m['TenChuDe'] ?? m['ten_chu_de'] ?? 'Chủ đề Tin học').toString(),
          };
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<JsonMap> createRoom({
    required String loaiPhong,
    required int maChuDe,
    String? matKhauPhong,
  }) async {
    await ensureConnected();
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse(ApiConstants.createArenaRoom),
      headers: headers,
      body: jsonEncode({
        'LoaiPhong': loaiPhong,
        'MaChuDe': maChuDe,
        if (matKhauPhong != null && matKhauPhong.trim().isNotEmpty)
          'MatKhauPhong': matKhauPhong.trim(),
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['Phong'] is Map) {
        return JsonMap.from(decoded['Phong']);
      }
      if (decoded is Map && decoded['data'] is Map) {
        return JsonMap.from(decoded['data']);
      }
      return JsonMap.from(decoded);
    }
    throw Exception(_extractError(response, 'Không thể tạo phòng đấu.'));
  }

  static Future<List<JsonMap>> getOpenRooms({String? loaiPhong}) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse(ApiConstants.openArenaRooms(loaiPhong: loaiPhong));
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          return decoded
              .whereType()
              .map((e) => JsonMap.from(e))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<JsonMap> joinRoom({
    int? maPhong,
    String? maCodePhong,
    String? matKhauPhong,
  }) async {
    await ensureConnected();
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse(ApiConstants.joinArenaRoom),
      headers: headers,
      body: jsonEncode({
        'MaPhong': ?maPhong,
        if (maCodePhong != null && maCodePhong.trim().isNotEmpty)
          'MaCodePhong': maCodePhong.trim().toUpperCase(),
        if (matKhauPhong != null && matKhauPhong.trim().isNotEmpty)
          'MatKhauPhong': matKhauPhong.trim(),
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['Phong'] is Map) {
        return JsonMap.from(decoded['Phong']);
      }
      if (decoded is Map && decoded['data'] is Map) {
        return JsonMap.from(decoded['data']);
      }
      return JsonMap.from(decoded);
    }
    throw Exception(_extractError(response, 'Không thể tham gia phòng đấu.'));
  }

  static Future<void> inviteFriend(int targetUserId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse(ApiConstants.inviteArenaFriend),
      headers: headers,
      body: jsonEncode({'MaNguoiDuocMoi': targetUserId}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_extractError(response, 'Không thể gửi lời mời.'));
    }
  }

  static Future<void> kickPlayer(int targetUserId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse(ApiConstants.kickArenaPlayer(targetUserId)),
      headers: headers,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_extractError(response, 'Không thể đuổi người chơi.'));
    }
  }

  static Future<List<JsonMap>> getRealFriends() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(ApiConstants.friendsList),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final List raw = (decoded is Map && decoded['data'] is List)
            ? decoded['data']
            : (decoded is List ? decoded : []);
        return raw.whereType().map((item) {
          final m = JsonMap.from(item);
          return {
            'maNguoiDung':
                int.tryParse((m['MaNguoiDung'] ?? m['id'] ?? 0).toString()) ??
                    0,
            'hoTen': (m['HoTen'] ?? m['TenDangNhap'] ?? 'Bạn bè').toString(),
            'tenHang': (m['TenHang'] ?? 'Đồng').toString(),
            'isOnline': m['TrangThaiOnline'] == true || m['TrangThaiOnline'] == 1,
          };
        }).toList();
      }
    } catch (_) {}
    return [];
  }
}