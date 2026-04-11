import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:own_calendar/providers/auth_provider.dart';
import 'package:own_calendar/services/api_service.dart';

/// 테스트용 [ApiService] 더미.
/// - 네트워크/secure storage를 전혀 건드리지 않고 인메모리로 동작
/// - [onGet] 콜백으로 /auth/me 응답을 시나리오별로 조작
class _FakeApiService implements ApiService {
  _FakeApiService({
    String? access,
    String? refresh,
    String? cachedUser,
    this.onGet,
  })  : _access = access,
        _refresh = refresh,
        _cachedUser = cachedUser;

  String? _access;
  String? _refresh;
  String? _cachedUser;
  http.Response Function(String path)? onGet;

  int getCallCount = 0;
  String? lastSavedCachedUser;

  @override
  Future<String?> get accessToken async => _access;

  @override
  Future<String?> get refreshToken async => _refresh;

  @override
  Future<String?> get cachedUserJson async => _cachedUser;

  @override
  Future<void> saveTokens(String access, String refresh) async {
    _access = access;
    _refresh = refresh;
  }

  @override
  Future<void> saveCachedUser(String userJson) async {
    _cachedUser = userJson;
    lastSavedCachedUser = userJson;
  }

  @override
  Future<void> clearTokens() async {
    _access = null;
    _refresh = null;
    _cachedUser = null;
  }

  @override
  Future<http.Response> get(String path) async {
    getCallCount++;
    return onGet?.call(path) ?? http.Response('', 500);
  }

  @override
  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    throw UnimplementedError('post not needed in tryRestore tests');
  }

  @override
  Future<http.Response> put(String path, Map<String, dynamic> body) async {
    throw UnimplementedError('put not needed in tryRestore tests');
  }

  @override
  Future<http.Response> delete(String path) async {
    throw UnimplementedError('delete not needed in tryRestore tests');
  }
}

/// 마이크로태스크 큐를 비워서 백그라운드 hydrate가 완료되도록 기다린다.
Future<void> _drainMicrotasks() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('AuthProvider.tryRestore', () {
    test('저장된 토큰이 없으면 미인증 상태로 초기화 완료', () async {
      final fake = _FakeApiService();
      final auth = AuthProvider(api: fake);

      await auth.tryRestore();
      await _drainMicrotasks();

      expect(auth.isInitialized, isTrue);
      expect(auth.user, isNull);
      expect(auth.isAuthenticated, isFalse);
      // 토큰이 없으면 /auth/me 호출도 없어야 한다
      expect(fake.getCallCount, 0);
    });

    test('토큰 + 캐시된 user JSON 있으면 즉시 복원 (offline-safe)', () async {
      final fake = _FakeApiService(
        access: 'access-abc',
        cachedUser: jsonEncode({
          'id': 'u1',
          'email': 'cached@example.com',
          'name': '캐시된 사용자',
        }),
        // 오프라인 시뮬레이션: 서버 500
        onGet: (_) => http.Response('', 500),
      );
      final auth = AuthProvider(api: fake);

      await auth.tryRestore();

      // tryRestore 자체가 완료되는 시점에 이미 캐시된 user로 로그인 상태
      expect(auth.isInitialized, isTrue);
      expect(auth.user, isNotNull);
      expect(auth.user!.email, 'cached@example.com');
      expect(auth.isAuthenticated, isTrue);

      // 백그라운드 hydrate가 실패해도 상태가 뒤집히지 않아야 한다
      await _drainMicrotasks();
      expect(auth.user!.email, 'cached@example.com');
    });

    test('토큰만 있고 캐시 없음 → 백그라운드 hydrate가 user를 채우고 캐시 저장', () async {
      final fake = _FakeApiService(
        access: 'access-abc',
        onGet: (_) => http.Response(
          jsonEncode({
            'user': {
              'id': 'u1',
              'email': 'fresh@example.com',
              'name': 'Fresh User',
            },
          }),
          200,
        ),
      );
      final auth = AuthProvider(api: fake);

      await auth.tryRestore();

      // tryRestore 시점엔 캐시가 없어서 아직 user null
      expect(auth.isInitialized, isTrue);

      // 백그라운드 hydrate 완료 대기
      await _drainMicrotasks();

      expect(auth.user, isNotNull);
      expect(auth.user!.email, 'fresh@example.com');
      expect(fake.lastSavedCachedUser, isNotNull);
      expect(jsonDecode(fake.lastSavedCachedUser!)['email'], 'fresh@example.com');
    });

    test('캐시 JSON이 손상되어도 크래시하지 않는다', () async {
      final fake = _FakeApiService(
        access: 'access-abc',
        cachedUser: 'not a valid json {{{',
        onGet: (_) => http.Response('', 500),
      );
      final auth = AuthProvider(api: fake);

      await auth.tryRestore();
      await _drainMicrotasks();

      expect(auth.isInitialized, isTrue);
      // 캐시가 깨졌으니 user는 null로 남는다 (hydrate도 500이므로 못 채움)
      expect(auth.user, isNull);
    });

    test('hydrate가 401을 반환하면 _user를 null로 내려 listener에 통지', () async {
      final fake = _FakeApiService(
        access: 'access-abc',
        cachedUser: jsonEncode({
          'id': 'u1',
          'email': 'cached@example.com',
          'name': '캐시',
        }),
        onGet: (_) => http.Response('{"error":"unauth"}', 401),
      );
      final auth = AuthProvider(api: fake);

      var notifyCount = 0;
      auth.addListener(() => notifyCount++);

      await auth.tryRestore();

      // 초기엔 캐시된 user로 즉시 로그인 상태
      expect(auth.user, isNotNull);

      // 백그라운드 hydrate의 401 반영 대기
      await _drainMicrotasks();

      expect(auth.user, isNull);
      // 최소 2회: tryRestore finally, hydrate 401
      expect(notifyCount, greaterThanOrEqualTo(2));
    });
  });
}
