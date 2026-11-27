class ApiConstants {
  static const bool useNgrok = false;
  static const String _lanHost = '192.168.20.63';
  static const int _lanPort = 8000;
  static const String _ngrokHost = 'your-ngrok-domain.ngrok-free.app';

  static String get baseUrl {
    if (useNgrok) {
      return 'https://$_ngrokHost';
    }
    return 'http://$_lanHost:$_lanPort';
  }

  static String get wsBaseUrl {
    if (useNgrok) {
      return 'wss://$_ngrokHost';
    }
    return 'ws://$_lanHost:$_lanPort';
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
}