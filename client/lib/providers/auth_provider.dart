import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
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

  Future<bool> checkAuth() async {
    final token = await _api.accessToken;
    if (token == null) return false;
    final res = await _api.get('/calendars');
    return res.statusCode == 200;
  }
}
