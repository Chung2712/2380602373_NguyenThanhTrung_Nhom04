import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Default for Android phone connected by USB with adb reverse tcp:5222 tcp:5222.
/// Android emulator uses 10.0.2.2; Wi-Fi phone uses the computer's LAN IP.
/// Override with --dart-define=API_URL=http://... or on the login screen.
const defaultBaseUrl = 'https://largeaquapage63.conveyor.cloud/';

class ApiException implements Exception {
  ApiException(this.message, this.code);
  final String message;
  final int code;
  @override
  String toString() => message;
}

class Api {
  Api._();
  static final Api instance = Api._();
  final _storage = const FlutterSecureStorage();
  final _client = http.Client();
  String baseUrl = defaultBaseUrl;
  String? token;
  String? role;
  String? username;

  Future<void> restore() async {
    try {
      token = await _storage.read(key: 'jwt');
      role = await _storage.read(key: 'role');
      username = await _storage.read(key: 'username');
      final savedUrl = await _storage.read(key: 'api_url');
      if (savedUrl == null || savedUrl.contains('127.0.0.1') || savedUrl.contains('10.0.2.2') || savedUrl.contains('localhost')) {
        baseUrl = defaultBaseUrl;
        await _storage.write(key: 'api_url', value: defaultBaseUrl);
      } else {
        baseUrl = savedUrl;
      }
    } catch (_) {
      token = null;
      role = null;
      username = null;
      baseUrl = defaultBaseUrl;
    }
  }

  Future<void> setBaseUrl(String url) async {
    final parsed = Uri.tryParse(url.trim());
    if (parsed == null || (parsed.scheme != 'http' && parsed.scheme != 'https') ||
        parsed.host.isEmpty || parsed.hasQuery || parsed.hasFragment) {
      throw ApiException('URL phải bắt đầu bằng http:// hoặc https://', 0);
    }
    baseUrl = url.trim().replaceFirst(RegExp(r'/$'), '');
    await _storage.write(key: 'api_url', value: baseUrl);
  }

  Future<void> saveSession(Map<String, dynamic> data) async {
    final jwt = data['accessToken']?.toString();
    final serverRole = data['role']?.toString();
    if (jwt == null || jwt.isEmpty || serverRole == null || serverRole.isEmpty) {
      throw ApiException('Phản hồi đăng nhập không hợp lệ.', 0);
    }
    token = jwt;
    role = serverRole;
    username = data['username']?.toString();
    await _storage.write(key: 'jwt', value: token);
    await _storage.write(key: 'role', value: role);
    await _storage.write(key: 'username', value: username);
  }

  Future<void> logout() async {
    token = null;
    role = null;
    username = null;
    await _storage.delete(key: 'jwt');
    await _storage.delete(key: 'role');
    await _storage.delete(key: 'username');
  }

  Future<dynamic> request(String method, String path, [Object? body]) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    try {
      late http.Response response;
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 15));
        case 'POST':
          response = await _client.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 15));
        case 'PUT':
          response = await _client.put(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 15));
        case 'DELETE':
          response = await _client.delete(uri, headers: headers).timeout(const Duration(seconds: 15));
        default:
          throw ApiException('HTTP method không được hỗ trợ.', 0);
      }
      dynamic result;
      if (response.body.isNotEmpty) {
        try { result = jsonDecode(response.body); } catch (_) { result = response.body; }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = result is Map && result['error'] != null
            ? result['error'].toString()
            : response.statusCode == 401 ? 'Phiên đăng nhập đã hết hạn hoặc sai tài khoản.'
            : 'API lỗi HTTP ${response.statusCode}';
        throw ApiException(error, response.statusCode);
      }
      return result;
    } on ApiException { rethrow;
    } on TimeoutException {
      throw ApiException('Hết thời gian kết nối API. Kiểm tra máy chủ và mạng.', 0);
    } on SocketException {
      throw ApiException('Không kết nối được API $baseUrl. Kiểm tra Wi-Fi, IP và firewall.', 0);
    } catch (e) {
      throw ApiException('Không thể gọi API: $e', 0);
    }
  }

  Future<List<Map<String, dynamic>>> list(String endpoint) async {
    final data = await request('GET', '/api/$endpoint');
    if (data is! List) throw ApiException('Dữ liệu trả về không phải danh sách.', 0);
    return data.map((x) => Map<String, dynamic>.from(x as Map)).toList();
  }
}

String humanError(Object error) => error is ApiException ? error.message : error.toString();
