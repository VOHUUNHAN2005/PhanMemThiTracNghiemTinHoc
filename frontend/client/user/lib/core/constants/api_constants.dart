import 'package:flutter/foundation.dart';

class ApiConstants {
  // Đổi thành true khi test 2 máy 5G (máy ảo Android/Web cũng dùng được luôn)
  // Đổi thành false khi muốn chạy offline nội bộ trên máy ảo / localhost
  static const bool useNgrok = true;
  static const String _ngrokUrl = 'https://pound-trailside-brim.ngrok-free.dev';

  static String get baseUrl {
    if (useNgrok) return _ngrokUrl;
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  // Endpoints phân hệ Users
  static String get register => '$baseUrl/api/users/register';
  static String get getMe => '$baseUrl/api/users/get_me';
  static String get updateMe => '$baseUrl/api/users/update_me';
  static String get uploadAvatar => '$baseUrl/api/users/upload_avatar';
  static String get syncDevice => '$baseUrl/api/users/device';
  static String get logout => '$baseUrl/api/users/logout';
}