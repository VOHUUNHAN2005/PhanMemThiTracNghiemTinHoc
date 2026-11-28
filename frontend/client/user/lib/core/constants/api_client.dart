import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

typedef HeaderMap = Map<String, String>;

class ApiClient {
  static final http.Client _client = http.Client();

  static Future<HeaderMap> _getHeaders({
    bool isJson = true,
    bool forceRefresh = false,
  }) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken(
      forceRefresh,
    );

    return {
      if (token != null) 'Authorization': 'Bearer $token',
      if (isJson) 'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
      'Connection': 'keep-alive',
    };
  }

  static Future<http.Response> _executeWithNetworkRetry(
    Future<http.Response> Function() fn, {
    int maxRetries = 2,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn().timeout(const Duration(seconds: 15));
      } on HandshakeException {
        if (attempt >= maxRetries) rethrow;
      } on SocketException {
        if (attempt >= maxRetries) rethrow;
      } on http.ClientException {
        if (attempt >= maxRetries) rethrow;
      } on TimeoutException {
        if (attempt >= maxRetries) rethrow;
      }

      attempt++;

      await Future.delayed(Duration(milliseconds: 250 * attempt));
    }
  }

  static Future<http.Response> _sendWithRetryOn401(
    Future<http.Response> Function(HeaderMap headers) requestFn, {
    bool isJson = true,
  }) async {
    final headers = await _getHeaders(isJson: isJson, forceRefresh: false);

    final res = await _executeWithNetworkRetry(() => requestFn(headers));

    if (res.statusCode == 401 && FirebaseAuth.instance.currentUser != null) {
      await Future.delayed(const Duration(milliseconds: 300));

      final refreshedHeaders = await _getHeaders(
        isJson: isJson,
        forceRefresh: true,
      );

      return _executeWithNetworkRetry(() => requestFn(refreshedHeaders));
    }

    return res;
  }

  static Future<http.Response> get(String url) {
    return _sendWithRetryOn401(
      (headers) => _client.get(Uri.parse(url), headers: headers),
      isJson: false,
    );
  }

  static Future<http.Response> post(String url, {Map<String, dynamic>? body}) {
    final encodedBody = body != null ? jsonEncode(body) : null;

    return _sendWithRetryOn401(
      (headers) =>
          _client.post(Uri.parse(url), headers: headers, body: encodedBody),
    );
  }

  static Future<http.Response> put(String url, {Map<String, dynamic>? body}) {
    final encodedBody = body != null ? jsonEncode(body) : null;

    return _sendWithRetryOn401(
      (headers) =>
          _client.put(Uri.parse(url), headers: headers, body: encodedBody),
    );
  }

  static Future<http.Response> delete(String url) {
    return _sendWithRetryOn401(
      (headers) => _client.delete(Uri.parse(url), headers: headers),
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
      return _executeWithNetworkRetry(() async {
        final token = await FirebaseAuth.instance.currentUser?.getIdToken(
          forceRefresh,
        );

        final request = http.MultipartRequest('POST', Uri.parse(url));

        request.headers['ngrok-skip-browser-warning'] = 'true';
        request.headers['Connection'] = 'keep-alive';

        if (token != null) {
          request.headers['Authorization'] = 'Bearer $token';
        }

        request.files.add(
          http.MultipartFile.fromBytes(fieldName, bytes, filename: filename),
        );

        final streamedRes = await _client.send(request);
        return http.Response.fromStream(streamedRes);
      });
    }

    final res = await sendMultipart(false);

    if (res.statusCode == 401 && FirebaseAuth.instance.currentUser != null) {
      await Future.delayed(const Duration(milliseconds: 300));
      return sendMultipart(true);
    }

    return res;
  }
}
