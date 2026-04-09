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

  Future<String?> get accessToken => _storage.read(key: 'accessToken');
  Future<String?> get refreshToken => _storage.read(key: 'refreshToken');

  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: 'accessToken', value: access);
    await _storage.write(key: 'refreshToken', value: refresh);
  }

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
