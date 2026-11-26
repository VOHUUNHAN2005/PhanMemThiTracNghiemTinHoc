import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

typedef HeaderMap = Map<String, String>;

class ApiClient {
  static Future<HeaderMap> _getHeaders({
    bool isJson = true,
    bool forceRefresh = false,
  }) async {
    final token =
        await FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh);

    return {
      if (token != null) 'Authorization': 'Bearer $token',
      if (isJson) 'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
  }

  static Future<http.Response> _sendWithRetryOn401(
    Future<http.Response> Function(HeaderMap headers) requestFn, {
    bool isJson = true,
  }) async {
    final headers = await _getHeaders(isJson: isJson, forceRefresh: false);
    final res = await requestFn(headers);

    if (res.statusCode == 401 && FirebaseAuth.instance.currentUser != null) {
      final refreshedHeaders =
          await _getHeaders(isJson: isJson, forceRefresh: true);
      return requestFn(refreshedHeaders);
    }

    return res;
  }

  static Future<http.Response> get(String url) {
    return _sendWithRetryOn401(
      (headers) => http.get(Uri.parse(url), headers: headers),
      isJson: false,
    );
  }

  static Future<http.Response> post(
    String url, {
    Map<String, dynamic>? body,
  }) {
    final encodedBody = body != null ? jsonEncode(body) : null;
    return _sendWithRetryOn401(
      (headers) => http.post(Uri.parse(url), headers: headers, body: encodedBody),
      isJson: true,
    );
  }

  static Future<http.Response> put(
    String url, {
    Map<String, dynamic>? body,
  }) {
    final encodedBody = body != null ? jsonEncode(body) : null;
    return _sendWithRetryOn401(
      (headers) => http.put(Uri.parse(url), headers: headers, body: encodedBody),
      isJson: true,
    );
  }

  static Future<http.Response> delete(String url) {
    return _sendWithRetryOn401(
      (headers) => http.delete(Uri.parse(url), headers: headers),
      isJson: false,
    );
  }

  static Future<http.Response> uploadFile({
    required String url,
    required Uint8List bytes,
    required String filename,
    String fieldName = 'file',
  }) async {
    Future<http.Response> sendMultipart(bool forceRefresh) async {
      final token =
          await FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh);

      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['ngrok-skip-browser-warning'] = 'true';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: filename,
        ),
      );

      final streamedRes = await request.send();
      return http.Response.fromStream(streamedRes);
    }

    final res = await sendMultipart(false);
    if (res.statusCode == 401 && FirebaseAuth.instance.currentUser != null) {
      return sendMultipart(true);
    }
    return res;
  }
}