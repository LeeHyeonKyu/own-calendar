import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;
  User? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  Future<bool> register(String email, String name, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.post(
        '/auth/register',
        {'email': email, 'name': name, 'password': password},
      );
      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        await _api.saveTokens(data['accessToken'], data['refreshToken']);
        await _api.saveCachedUser(jsonEncode(data['user']));
        _user = User.fromJson(data['user']);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = jsonDecode(res.body)['error'] ?? 'Registration failed';
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.post(
        '/auth/login',
        {'email': email, 'password': password},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await _api.saveTokens(data['accessToken'], data['refreshToken']);
        await _api.saveCachedUser(jsonEncode(data['user']));
        _user = User.fromJson(data['user']);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = jsonDecode(res.body)['error'] ?? 'Login failed';
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    final refresh = await _api.refreshToken;
    if (refresh != null) {
      await _api.post('/auth/logout', {'refreshToken': refresh});
    }
    await _api.clearTokens();
    _user = null;
    notifyListeners();
  }

  /// 앱 시작 시 1회 호출. 저장된 토큰과 캐시된 user JSON으로 세션을 즉시 복원.
  ///
  /// 네트워크는 절대 await하지 않는다 — 오프라인에서도 저장된 토큰이 있으면
  /// 로그인 상태로 진입할 수 있도록 disk I/O만으로 초기화를 끝낸다.
  /// 서버 권위 있는 fresh 프로필은 [_hydrateFromServer]가 백그라운드에서 채운다.
  Future<void> tryRestore() async {
    try {
      final token = await _api.accessToken;
      if (token == null) return;

      // 로컬 캐시된 user로 즉시 복원 (offline-safe)
      final cachedJson = await _api.cachedUserJson;
      if (cachedJson != null) {
        try {
          _user = User.fromJson(
            jsonDecode(cachedJson) as Map<String, dynamic>,
          );
        } catch (_) {
          // 캐시 포맷이 깨진 경우 무시 — hydrate에서 복원 시도
        }
      }

      // 백그라운드에서 fresh 프로필 동기화. 의도적으로 await 하지 않는다.
      unawaited(_hydrateFromServer());
    } catch (_) {
      // 복원 실패는 조용히 무시. 다음 API 호출에서 검증된다.
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// 백그라운드에서 /auth/me를 호출해 서버 권위 있는 user 정보로 갱신한다.
  /// 401/refresh 실패 시 ApiService가 clearTokens까지 자동으로 처리하므로,
  /// 여기서는 _user를 null로 내려 router가 refreshListenable을 통해 로그인으로
  /// 자동 redirect하도록 한다.
  Future<void> _hydrateFromServer() async {
    try {
      final res = await _api.get('/auth/me');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final userJson = data['user'] as Map<String, dynamic>;
        _user = User.fromJson(userJson);
        await _api.saveCachedUser(jsonEncode(userJson));
        notifyListeners();
      } else if (res.statusCode == 401) {
        // ApiService가 refresh 시도 + 실패 시 clearTokens까지 이미 수행.
        _user = null;
        notifyListeners();
      }
      // 기타 상태 코드(5xx 등)는 일시 장애로 간주하고 기존 상태 유지.
    } catch (_) {
      // 네트워크 실패 = 캐시된 user 상태 그대로 유지
    }
  }
}
