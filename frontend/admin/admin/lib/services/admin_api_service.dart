import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AdminApiService {
  static const String baseUrl = 'http://127.0.0.1:8000';

  Future _getHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }
    final token = await user.getIdToken();
    final map = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    return map;
  }

  dynamic _handleResponse(http.Response response) {
    final bodyText = utf8.decode(response.bodyBytes);
    final data = bodyText.isNotEmpty ? jsonDecode(bodyText) : null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    if (data is Map && data['detail'] != null) {
      if (data['detail'] is String) {
        throw data['detail'];
      }
      if (data['detail'] is List && (data['detail'] as List).isNotEmpty) {
        throw data['detail'][0]['msg'] ?? 'Dữ liệu gửi lên không hợp lệ.';
      }
    }
    throw 'Lỗi máy chủ (${response.statusCode}).';
  }

  Future getMyProfile() async {
    final headers = await _getHeaders();
    final res = await http.get(
      Uri.parse('$baseUrl/api/users/get_me'),
      headers: headers,
    );
    return Map.from(_handleResponse(res));
  }

  Future getUsers({
    String search = '',
    String? role,
    String? accountStatus,
    int page = 1,
    int limit = 20,
    String? trangThai,
  }) async {
    final headers = await _getHeaders();
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (search.trim().isNotEmpty) queryParams['search'] = search.trim();
    if (role != null && role.isNotEmpty) queryParams['role'] = role;
    if (accountStatus != null && accountStatus.isNotEmpty) {
      queryParams['account_status'] = accountStatus;
    }

    final uri = Uri.parse('$baseUrl/api/admin/users')
        .replace(queryParameters: queryParams);
    final res = await http.get(uri, headers: headers);
    return Map.from(_handleResponse(res));
  }

  Future updateUserStatus(
    user, {
    required int userId,
    required String status,
    String? lyDoKhoa,
  }) async {
    final headers = await _getHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/api/admin/users/$userId/status'),
      headers: headers,
      body: jsonEncode({
        'TrangThaiTaiKhoan': status,
        'LyDoKhoa': lyDoKhoa,
      }),
    );
    _handleResponse(res);
  }

  Future adjustUserCups({
    required int userId,
    required int soCupThayDoi,
    required String moTa,
  }) async {
    final headers = await _getHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/api/admin/users/$userId/adjust-cups'),
      headers: headers,
      body: jsonEncode({
        'SoCupThayDoi': soCupThayDoi,
        'MoTa': moTa,
      }),
    );
    _handleResponse(res);
  }

  Future getTopics() async {
    final headers = await _getHeaders();
    final res = await http.get(
      Uri.parse('$baseUrl/api/admin/topics'),
      headers: headers,
    );
    return List.from(_handleResponse(res));
  }

  Future createTopic({required String tenChuDe, String? moTa}) async {
    final headers = await _getHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/api/admin/topics'),
      headers: headers,
      body: jsonEncode({'TenChuDe': tenChuDe, 'MoTa': moTa}),
    );
    _handleResponse(res);
  }

  Future updateTopic({
    required int maChuDe,
    required String tenChuDe,
    String? moTa,
  }) async {
    final headers = await _getHeaders();
    final res = await http.put(
      Uri.parse('$baseUrl/api/admin/topics/$maChuDe'),
      headers: headers,
      body: jsonEncode({'TenChuDe': tenChuDe, 'MoTa': moTa}),
    );
    _handleResponse(res);
  }

  Future deleteTopic(int maChuDe) async {
    final headers = await _getHeaders();
    final res = await http.delete(
      Uri.parse('$baseUrl/api/admin/topics/$maChuDe'),
      headers: headers,
    );
    _handleResponse(res);
  }

  Future getQuestions({
    int? maChuDe,
    String? mucDo,
    String? trangThai,
    String search = '',
    int page = 1,
    int limit = 30,
  }) async {
    final headers = await _getHeaders();
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (maChuDe != null) queryParams['ma_chu_de'] = maChuDe.toString();
    if (mucDo != null && mucDo.isNotEmpty) queryParams['muc_do'] = mucDo;
    if (trangThai != null && trangThai.isNotEmpty)
      queryParams['trang_thai'] = trangThai;
    if (search.trim().isNotEmpty) queryParams['search'] = search.trim();

    final uri = Uri.parse('$baseUrl/api/admin/questions')
        .replace(queryParameters: queryParams);
    final res = await http.get(uri, headers: headers);
    return Map.from(_handleResponse(res));
  }

  Future createQuestionInBank(Map payload) async {
    final headers = await _getHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/api/admin/questions'),
      headers: headers,
      body: jsonEncode(payload),
    );
    _handleResponse(res);
  }

  Future deleteQuestionFromBank(int maCauHoi) async {
    final headers = await _getHeaders();
    final res = await http.delete(
      Uri.parse('$baseUrl/api/admin/questions/$maCauHoi'),
      headers: headers,
    );
    _handleResponse(res);
  }

  Future getExams({
    String? loaiBoDe,
    int? maChuDe,
  }) async {
    final headers = await _getHeaders();
    final queryParams = <String, String>{};
    if (loaiBoDe != null) queryParams['loai_bo_de'] = loaiBoDe;
    if (maChuDe != null) queryParams['ma_chu_de'] = maChuDe.toString();

    final uri = Uri.parse('$baseUrl/api/admin/exams').replace(
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    final res = await http.get(uri, headers: headers);
    return List.from(_handleResponse(res));
  }

  Future autoGenerateExams(Map payload) async {
    final headers = await _getHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/api/admin/exams/auto-generate'),
      headers: headers,
      body: jsonEncode(payload),
    );
    return Map.from(_handleResponse(res));
  }

  Future createExam(Map payload) async {
    final headers = await _getHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/api/admin/exams'),
      headers: headers,
      body: jsonEncode(payload),
    );
    _handleResponse(res);
  }

  Future updateExam(int maBoDe, Map payload) async {
    final headers = await _getHeaders();
    final res = await http.put(
      Uri.parse('$baseUrl/api/admin/exams/$maBoDe'),
      headers: headers,
      body: jsonEncode(payload),
    );
    _handleResponse(res);
  }

  Future deleteExam(int maBoDe) async {
    final headers = await _getHeaders();
    final res = await http.delete(
      Uri.parse('$baseUrl/api/admin/exams/$maBoDe'),
      headers: headers,
    );
    _handleResponse(res);
  }

  Future getQuestionTypes() async {
    final headers = await _getHeaders();
    final res = await http.get(
      Uri.parse('$baseUrl/api/admin/question-types'),
      headers: headers,
    );
    return List.from(_handleResponse(res));
  }

  Future getExamQuestions(int maBoDe) async {
    final headers = await _getHeaders();
    final res = await http.get(
      Uri.parse('$baseUrl/api/admin/exams/$maBoDe/questions'),
      headers: headers,
    );
    return List.from(_handleResponse(res));
  }

  Future createQuestionInExam(int maBoDe, Map payload) async {
    final headers = await _getHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/api/admin/exams/$maBoDe/questions'),
      headers: headers,
      body: jsonEncode(payload),
    );
    _handleResponse(res);
  }

  Future swapQuestionInExam(int maBoDe, int maCauHoi) async {
    final headers = await _getHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/api/admin/exams/$maBoDe/questions/$maCauHoi/swap'),
      headers: headers,
    );
    return Map.from(_handleResponse(res));
  }

  Future updateQuestion(int maCauHoi, Map payload) async {
    final headers = await _getHeaders();
    final res = await http.put(
      Uri.parse('$baseUrl/api/admin/questions/$maCauHoi'),
      headers: headers,
      body: jsonEncode(payload),
    );
    _handleResponse(res);
  }

  Future deleteQuestionFromExam(int maBoDe, int maCauHoi) async {
    final headers = await _getHeaders();
    final res = await http.delete(
      Uri.parse('$baseUrl/api/admin/exams/$maBoDe/questions/$maCauHoi'),
      headers: headers,
    );
    _handleResponse(res);
  }

  Future uploadQuestionImage({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'Phiên đăng nhập đã hết hạn.';
    final token = await user.getIdToken();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/admin/questions/upload-image'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
    );

    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);
    final data = _handleResponse(res);
    return data['HinhAnhUrl'] as String;
  }

  Future attachQuestionsToExam(int maBoDe, List<int> maCauHoiList) async {
    final headers = await _getHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/api/admin/exams/$maBoDe/questions/attach'),
      headers: headers,
      body: jsonEncode({'MaCauHoiList': maCauHoiList}),
    );
    return Map.from(_handleResponse(res));
  }

  Future getUserActivityHistory(int userId) async {
    final headers = await _getHeaders();
    final res = await http.get(
      Uri.parse('$baseUrl/api/admin/users/$userId/activity'),
      headers: headers,
    );
    return Map.from(_handleResponse(res));
  }

  Future getAttemptDetail(int maLuotLam) async {
    final headers = await _getHeaders();
    final res = await http.get(
      Uri.parse('$baseUrl/api/admin/attempts/$maLuotLam'),
      headers: headers,
    );
    return Map.from(_handleResponse(res));
  }

  Future<Map<String, dynamic>> getExamFeedbacks(int maBoDe) async {
    final headers = await _getHeaders();

    final res = await http.get(
      Uri.parse('$baseUrl/api/admin/exams/$maBoDe/feedbacks'),
      headers: headers,
    );

    return Map<String, dynamic>.from(_handleResponse(res));
  }

  Future<Map<String, dynamic>> getArenaRooms({
    String? loaiPhong,
    String? trangThai,
    String search = '',
    int page = 1,
    int limit = 30,
  }) async {
    final headers = await _getHeaders();

    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (loaiPhong != null && loaiPhong.isNotEmpty) {
      queryParams['loai_phong'] = loaiPhong;
    }

    if (trangThai != null && trangThai.isNotEmpty) {
      queryParams['trang_thai'] = trangThai;
    }

    if (search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final uri = Uri.parse('$baseUrl/api/admin/arena/rooms')
        .replace(queryParameters: queryParams);

    final res = await http.get(uri, headers: headers);

    return Map<String, dynamic>.from(_handleResponse(res));
  }

  Future<Map<String, dynamic>> getArenaRoomDetail(int maPhong) async {
    final headers = await _getHeaders();

    final res = await http.get(
      Uri.parse('$baseUrl/api/admin/arena/rooms/$maPhong'),
      headers: headers,
    );

    return Map<String, dynamic>.from(_handleResponse(res));
  }

  Future<Map<String, dynamic>> createAdminTournament({
    required int maChuDe,
    required int soCauHoi,
    String? matKhauPhong,
  }) async {
    final headers = await _getHeaders();

    final res = await http.post(
      Uri.parse('$baseUrl/api/admin/arena/tournaments'),
      headers: headers,
      body: jsonEncode({
        'MaChuDe': maChuDe,
        'SoCauHoi': soCauHoi,
        if (matKhauPhong != null && matKhauPhong.trim().isNotEmpty)
          'MatKhauPhong': matKhauPhong.trim(),
      }),
    );

    return Map<String, dynamic>.from(_handleResponse(res));
  }

  Future<Map<String, dynamic>> cancelArenaRoom(
    int maPhong, {
    String? lyDo,
  }) async {
    final headers = await _getHeaders();

    final res = await http.post(
      Uri.parse('$baseUrl/api/admin/arena/rooms/$maPhong/cancel'),
      headers: headers,
      body: jsonEncode({
        if (lyDo != null && lyDo.trim().isNotEmpty) 'LyDo': lyDo.trim(),
      }),
    );

    return Map<String, dynamic>.from(_handleResponse(res));
  }
}
