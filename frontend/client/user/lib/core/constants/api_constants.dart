import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  static const bool useNgrok = false;

  // Truyền --dart-define=API_HOST=192.168.x.x khi chạy từ máy khác / điện thoại qua LAN
  static const String _lanHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: '127.0.0.1',
  );

  // Truyền --dart-define=API_PORT=8000 nếu muốn đổi cổng
  static const String _lanPortRaw = String.fromEnvironment(
    'API_PORT',
    defaultValue: '8000',
  );

  static int get _lanPort => int.tryParse(_lanPortRaw) ?? 8000;

  // ignore: unused_field
  static const String _ngrokHost = 'your-ngrok-domain.ngrok-free.app';

  // Trên Web (Chrome/Edge), nếu không truyền API_HOST riêng thì dùng localhost
  static String get _activeHost {
    if (kIsWeb && !_lanHost.contains('.')) {
      return 'localhost';
    }
    if (kIsWeb && _lanHost == '127.0.0.1') {
      return 'localhost';
    }
    return _lanHost;
  }

  static String get baseUrl {
    if (useNgrok) {
      return 'https://$_ngrokHost';
    }
    return 'http://$_activeHost:$_lanPort';
  }

  static String get wsBaseUrl {
    if (useNgrok) {
      return 'wss://$_ngrokHost';
    }
    return 'ws://$_activeHost:$_lanPort';
  }

  // Auth & User
  static String get getMe => '$baseUrl/api/users/get_me';
  static String get updateMe => '$baseUrl/api/users/update_me';
  static String get uploadAvatar => '$baseUrl/api/users/upload_avatar';
  static String get syncDevice => '$baseUrl/api/users/device';
  static String get userHistory => '$baseUrl/api/users/me/history';
  static String get leaderboard => '$baseUrl/api/leaderboard';
  static String get register => '$baseUrl/api/users/register';
  static String get logout => '$baseUrl/api/users/logout';
  static String get homeTopics => '$baseUrl/api/home/topics';

  static String homeExamsByTopic(Object topicId) =>
      '$baseUrl/api/home/topics/$topicId/exams';

  // Official Exam
  static String startOfficialExam(Object examId) =>
      '$baseUrl/api/official/exams/$examId/start';

  static String saveOfficialAnswer(Object sessionId) =>
      '$baseUrl/api/official/attempts/$sessionId/answer';

  static String submitOfficialExam(Object sessionId) =>
      '$baseUrl/api/official/attempts/$sessionId/submit';

  static String abortOfficialExam(Object sessionId) =>
      '$baseUrl/api/official/attempts/$sessionId/abort';

  // Practice
  static String get practiceTopics => '$baseUrl/api/practice/topics';

  static String practiceExamsByTopic(Object topicId) =>
      '$baseUrl/api/practice/topics/$topicId/exams';

  static String startPractice(Object examId) =>
      '$baseUrl/api/practice/exams/$examId/start';

  static String checkPracticeQuestion(Object sessionId) =>
      '$baseUrl/api/practice/attempts/$sessionId/check-question';

  static String finishPractice(Object sessionId) =>
      '$baseUrl/api/practice/attempts/$sessionId/finish';

  static String cancelPractice(Object sessionId) =>
      '$baseUrl/api/practice/attempts/$sessionId';

  // Friends
  static String get friendsList => '$baseUrl/api/friends/';
  static String get friendRequests => '$baseUrl/api/friends/requests';
  static String get sendFriendRequest => '$baseUrl/api/friends/request';
  static String get respondFriendRequest => '$baseUrl/api/friends/respond';

  static String searchFriends(String keyword) =>
      '$baseUrl/api/friends/search?q=${Uri.encodeQueryComponent(keyword.trim())}';

  static String friendProfile(Object targetUserId) =>
      '$baseUrl/api/friends/profile/$targetUserId';

  static String cancelSentRequest(Object targetUserId) =>
      '$baseUrl/api/friends/request/$targetUserId';

  static String unfriend(Object friendUserId) =>
      '$baseUrl/api/friends/$friendUserId';

  // Arena
  static String get createArenaRoom => '$baseUrl/api/arena/rooms';
  static String get joinArenaRoom => '$baseUrl/api/arena/rooms/join';
  static String get inviteArenaFriend => '$baseUrl/api/arena/rooms/invite';

  static String openArenaRooms({String? loaiPhong, Object? roomId}) {
    final base = roomId == null
        ? '$baseUrl/api/arena/rooms/open'
        : '$baseUrl/api/arena/rooms/open/$roomId';
    if (loaiPhong != null && loaiPhong.trim().isNotEmpty) {
      return '$base?loai_phong=${Uri.encodeQueryComponent(loaiPhong.trim())}';
    }
    return base;
  }

  static String kickArenaPlayer(Object targetUserId) =>
      '$baseUrl/api/arena/rooms/kick/$targetUserId';

  static String arenaMatchReview(Object maPhong) =>
      '$baseUrl/api/arena/history/$maPhong/review';
}