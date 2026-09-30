import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:own_calendar/providers/auth_provider.dart';
import 'package:own_calendar/services/api_service.dart';

/// In-memory fake [ApiService] for session verification tests.
///
/// Supports configurable token presence and throwing on storage reads
/// to simulate iOS keychain lock scenarios (dw2).
class _FakeApiService implements ApiService {
  _FakeApiService({
    String? access,
    String? refresh,
    String? cachedUser,
  })  : _access = access,
        _refresh = refresh,
        _cachedUser = cachedUser;

  String? _access;
  String? _refresh;
  String? _cachedUser;
  bool throwOnAccessToken = false;
  bool throwOnRefreshToken = false;

  @override
  Future<String?> get accessToken async {
    if (throwOnAccessToken) throw Exception('Keychain locked');
    return _access;
  }

  @override
  Future<String?> get refreshToken async {
    if (throwOnRefreshToken) throw Exception('Keychain locked');
    return _refresh;
  }

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
  }

  @override
  Future<void> clearTokens() async {
    _access = null;
    _refresh = null;
    _cachedUser = null;
  }

  @override
  Future<http.Response> get(String path) async => http.Response('', 500);
  @override
  Future<http.Response> post(String path, Map<String, dynamic> body) async =>
      throw UnimplementedError();
  @override
  Future<http.Response> put(String path, Map<String, dynamic> body) async =>
      throw UnimplementedError();
  @override
  Future<http.Response> delete(String path) async =>
      throw UnimplementedError();
  @override
  Future<http.Response> patch(String path,
          [Map<String, dynamic>? body]) async =>
      throw UnimplementedError();
}

/// Drains the microtask queue so unawaited background work completes.
Future<void> _drainMicrotasks() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Builds an AuthProvider in the "already authenticated" state.
///
/// Simulates a user who cold-started successfully: tryRestore loaded the
/// cached user JSON and the provider considers the session valid.
Future<AuthProvider> _authenticatedProvider(_FakeApiService fake) async {
  final auth = AuthProvider(api: fake);
  await auth.tryRestore();
  await _drainMicrotasks();
  assert(auth.isAuthenticated, 'precondition: provider must be authenticated');
  return auth;
}

void main() {
  group('AuthProvider.verifySession (#108)', () {
    test('test_108_verify_session_clears_auth', () async {
      // Arrange: start with a valid session (tokens + cached user present)
      final fake = _FakeApiService(
        access: 'access-token-abc',
        refresh: 'refresh-token-xyz',
        cachedUser: jsonEncode({
          'id': 'u1',
          'email': 'user@example.com',
          'name': 'Test User',
        }),
      );
      final auth = await _authenticatedProvider(fake);

      // Simulate the #106 race: tokens disappear from secure storage
      // while the app is still running and _user is non-null.
      fake._access = null;
      fake._refresh = null;

      var notifyCount = 0;
      auth.addListener(() => notifyCount++);

      // Act
      await auth.verifySession();

      // Assert: session invalidated, listeners notified
      expect(auth.isAuthenticated, isFalse,
          reason: 'isAuthenticated must be false when both tokens are absent');
      expect(auth.user, isNull,
          reason: '_user must be cleared when tokens are absent');
      expect(notifyCount, greaterThanOrEqualTo(1),
          reason: 'notifyListeners must fire at least once');
    });

    test('test_108_verify_session_noop_when_only_access_missing', () async {
      // Edge case: only the access token is gone but refresh remains.
      // This is not evidence of total token loss (refresh may still recover).
      final fake = _FakeApiService(
        access: 'access-token-abc',
        refresh: 'refresh-token-xyz',
        cachedUser: jsonEncode({
          'id': 'u1',
          'email': 'user@example.com',
          'name': 'Test User',
        }),
      );
      final auth = await _authenticatedProvider(fake);

      // Only access token is removed; refresh still present
      fake._access = null;

      await auth.verifySession();

      expect(auth.isAuthenticated, isTrue,
          reason: 'Session should remain when refresh token exists');
    });

    test('test_108_storage_error_keeps_session', () async {
      // Arrange: authenticated session
      final fake = _FakeApiService(
        access: 'access-token-abc',
        refresh: 'refresh-token-xyz',
        cachedUser: jsonEncode({
          'id': 'u1',
          'email': 'user@example.com',
          'name': 'Test User',
        }),
      );
      final auth = await _authenticatedProvider(fake);
      final userBefore = auth.user;

      // Simulate iOS keychain being locked (storage reads throw)
      fake.throwOnAccessToken = true;
      fake.throwOnRefreshToken = true;

      var notifyCount = 0;
      auth.addListener(() => notifyCount++);

      // Capture debugPrint output to verify operational observability (dw2 rubric)
      final debugPrintLog = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) debugPrintLog.add(message);
      };

      // Act
      await auth.verifySession();

      // Restore debugPrint before assertions (so test failures print correctly)
      debugPrint = originalDebugPrint;

      // Assert: session preserved, no notification for unchanged state
      expect(auth.isAuthenticated, isTrue,
          reason: 'A storage error must not cause a false logout');
      expect(auth.user, equals(userBefore),
          reason: '_user must not change on storage error');
      expect(notifyCount, 0,
          reason: 'No listener notification should fire when state is unchanged');
      // Assert: the failure is logged via debugPrint for operational observability
      expect(debugPrintLog, contains(contains('verifySession: storage read failed:')),
          reason: 'Storage read failure must be logged via debugPrint (dw2 rubric)');
    });

    test('test_108_verify_session_idempotent_after_clear', () async {
      // Calling verifySession twice after tokens are gone should be safe
      final fake = _FakeApiService(
        access: 'access-token-abc',
        refresh: 'refresh-token-xyz',
        cachedUser: jsonEncode({
          'id': 'u1',
          'email': 'user@example.com',
          'name': 'Test User',
        }),
      );
      final auth = await _authenticatedProvider(fake);
      fake._access = null;
      fake._refresh = null;

      await auth.verifySession();
      expect(auth.isAuthenticated, isFalse);

      // Second call: _user is already null, should be a no-op
      var notifyCount = 0;
      auth.addListener(() => notifyCount++);

      await auth.verifySession();
      expect(auth.isAuthenticated, isFalse);
      expect(notifyCount, 0,
          reason: 'Second call with _user already null should not notify');
    });
  });
}
