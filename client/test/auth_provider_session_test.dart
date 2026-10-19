import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:own_calendar/providers/auth_provider.dart';
import 'package:own_calendar/services/api_service.dart';

/// In-memory fake [ApiService] for session expiry tests.
///
/// Supports configurable token presence and allows triggering the
/// onSessionExpired callback that AuthProvider wires up.
class _FakeApiService implements ApiService {
  @override
  Future<String?> createWidgetKey() async => null;
  _FakeApiService({
    String? access,
    String? refresh,
    String? cachedUser,
  })  : _access = access,
        _refresh = refresh,
        _cachedUser = cachedUser;

  @override
  void Function()? onSessionExpired;

  String? _access;
  String? _refresh;
  String? _cachedUser;

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
  group('AuthProvider.onSessionExpired (#135)', () {
    test('constructor wires onSessionExpired callback', () {
      final fake = _FakeApiService();
      AuthProvider(api: fake);

      expect(fake.onSessionExpired, isNotNull,
          reason: 'AuthProvider must wire onSessionExpired in constructor');
    });

    test('onSessionExpired clears user and notifies listeners', () async {
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

      var notifyCount = 0;
      auth.addListener(() => notifyCount++);

      // Act: simulate ApiService detecting definitive refresh failure
      fake.onSessionExpired!();

      // Assert: session invalidated, listeners notified
      expect(auth.isAuthenticated, isFalse,
          reason: 'isAuthenticated must be false after onSessionExpired fires');
      expect(auth.user, isNull,
          reason: '_user must be cleared when onSessionExpired fires');
      expect(notifyCount, greaterThanOrEqualTo(1),
          reason: 'notifyListeners must fire at least once');
    });

    test('onSessionExpired is safe when user is already null', () async {
      final fake = _FakeApiService();
      final auth = AuthProvider(api: fake);
      await auth.tryRestore();
      await _drainMicrotasks();

      // User is not authenticated
      expect(auth.isAuthenticated, isFalse);

      var notifyCount = 0;
      auth.addListener(() => notifyCount++);

      // Act: calling onSessionExpired when already logged out should not crash
      fake.onSessionExpired!();

      // notifyListeners is still called (idempotent), but no crash
      expect(auth.isAuthenticated, isFalse);
    });

    test('onSessionExpired called twice is idempotent', () async {
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

      // First call
      fake.onSessionExpired!();
      expect(auth.isAuthenticated, isFalse);

      // Second call: should not crash, state remains cleared
      var notifyCount = 0;
      auth.addListener(() => notifyCount++);

      fake.onSessionExpired!();
      expect(auth.isAuthenticated, isFalse);
    });
  });
}
