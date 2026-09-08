import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // Override at build/run time:
  //   flutter run --dart-define-from-file=config/prod.json
  //   flutter build ios --dart-define=API_BASE_URL=https://your-host/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://own-calendar.tailb2886a.ts.net/api',
  );
  final _storage = const FlutterSecureStorage();

  // Storage keys
  static const _kAccessTokenKey = 'accessToken';
  static const _kRefreshTokenKey = 'refreshToken';
  static const _kCachedUserKey = 'cachedUser';

  Future<String?> get accessToken => _storage.read(key: _kAccessTokenKey);
  Future<String?> get refreshToken => _storage.read(key: _kRefreshTokenKey);

  /// 마지막 로그인 시 서버에서 받은 user JSON.
  /// 자동 로그인 부트스트랩에서 토큰과 함께 읽어 즉시 세션을 복원할 때 사용.
  Future<String?> get cachedUserJson => _storage.read(key: _kCachedUserKey);

  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: _kAccessTokenKey, value: access);
    await _storage.write(key: _kRefreshTokenKey, value: refresh);
  }

  Future<void> saveCachedUser(String userJson) async {
    await _storage.write(key: _kCachedUserKey, value: userJson);
  }

  /// 토큰 + 캐시된 user + 그 외 secure storage 전체 삭제.
  /// refresh 실패로 세션이 무효화될 때 호출된다.
  Future<void> clearTokens() async {
    await _storage.deleteAll();
  }

  Future<Map<String, String>> _headers() async {
    final token = await accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> get(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );
    if (response.statusCode == 401) {
      final refreshed = await _refreshTokens();
      if (refreshed) {
        return http.get(Uri.parse('$baseUrl$path'), headers: await _headers());
      }
    }
    return response;
  }

  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (response.statusCode == 401) {
      final refreshed = await _refreshTokens();
      if (refreshed) {
        return http.post(
          Uri.parse('$baseUrl$path'),
          headers: await _headers(),
          body: jsonEncode(body),
        );
      }
    }
    return response;
  }

  Future<http.Response> put(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (response.statusCode == 401) {
      final refreshed = await _refreshTokens();
      if (refreshed) {
        return http.put(
          Uri.parse('$baseUrl$path'),
          headers: await _headers(),
          body: jsonEncode(body),
        );
      }
    }
    return response;
  }

  Future<http.Response> patch(String path, [Map<String, dynamic>? body]) async {
    final response = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    if (response.statusCode == 401) {
      final refreshed = await _refreshTokens();
      if (refreshed) {
        return http.patch(
          Uri.parse('$baseUrl$path'),
          headers: await _headers(),
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }
    return response;
  }

  Future<http.Response> delete(String path) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );
    if (response.statusCode == 401) {
      final refreshed = await _refreshTokens();
      if (refreshed) {
        return http.delete(
          Uri.parse('$baseUrl$path'),
          headers: await _headers(),
        );
      }
    }
    return response;
  }

  Future<bool> _refreshTokens() async {
    final refresh = await refreshToken;
    if (refresh == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refresh}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveTokens(data['accessToken'], data['refreshToken']);
        return true;
      }
    } catch (_) {}
    await clearTokens();
    return false;
  }
}
