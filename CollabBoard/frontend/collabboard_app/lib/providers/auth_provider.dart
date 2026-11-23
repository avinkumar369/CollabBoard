import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoading = false;
  final ApiService _api = ApiService();

  // Public getters
  User? get user => _user;
  bool get isAuthenticated => _token != null && _user != null;
  String? get token => _token;
  bool get isLoading => _isLoading;

  Future<void> loadFromStorage() async {
    _isLoading = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('auth_token');
    if (storedToken != null) {
      _token = storedToken;
      try {
        final response = await _api.getMe(_token!);
        if (response.statusCode == 200 && response.data != null) {
          _user = User.fromJson(Map<String, dynamic>.from(response.data));
        } else {
          await logout();
        }
      } catch (e) {
        debugPrint('loadFromStorage error: $e');
        await logout();
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<String?> register(String name, String email, String password, String confirmPassword) async {
    if (password != confirmPassword) return 'Passwords do not match';
    if (password.length < 8) return 'Password must be at least 8 characters';
    try {
      final targetUrl = '${_api.dio.options.baseUrl}/auth/register';
      debugPrint('📤 Sending POST request to: $targetUrl');
      final resp = await _api.register({
        'name': name,
        'email': email,
        'password': password,
        'confirmPassword': confirmPassword,
      });
      debugPrint('📥 Register response status: ${resp.statusCode}');
      debugPrint('📥 Register response data: ${resp.data}');

      _token = resp.data['token'];
      await _saveToken(_token!);
      final meResp = await _api.getMe(_token!);
      _user = User.fromJson(Map<String, dynamic>.from(meResp.data));
      notifyListeners();
      return null; // success
    } on DioException catch (e) {
      debugPrint('❌ Register DioException caught:');
      debugPrint('   - URI: ${e.requestOptions.uri}');
      debugPrint('   - Message: ${e.message}');
      debugPrint('   - Type: ${e.type}');
      debugPrint('   - Status code: ${e.response?.statusCode}');
      debugPrint('   - Response data: ${e.response?.data}');
      if (e.response?.data is Map && e.response?.data['message'] != null) {
        return e.response!.data['message'].toString();
      }
      return 'Registration failed. Network error (${e.message}). Run adb reverse tcp:5000 tcp:5000';
    } catch (e, stack) {
      debugPrint('❌ Register unexpected error: $e');
      debugPrint('   Stack trace: $stack');
      return 'Registration failed: ${e.toString()}';
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final targetUrl = '${_api.dio.options.baseUrl}/auth/login';
      debugPrint('📤 Sending POST request to: $targetUrl');
      final resp = await _api.login({'email': email, 'password': password});
      debugPrint('📥 Login response status: ${resp.statusCode}');
      debugPrint('📥 Login response data: ${resp.data}');

      _token = resp.data['token'];
      await _saveToken(_token!);
      final meResp = await _api.getMe(_token!);
      _user = User.fromJson(Map<String, dynamic>.from(meResp.data));
      notifyListeners();
      return null;
    } on DioException catch (e) {
      debugPrint('❌ Login DioException caught:');
      debugPrint('   - URI: ${e.requestOptions.uri}');
      debugPrint('   - Message: ${e.message}');
      debugPrint('   - Type: ${e.type}');
      debugPrint('   - Status code: ${e.response?.statusCode}');
      debugPrint('   - Response data: ${e.response?.data}');
      if (e.response?.data is Map && e.response?.data['message'] != null) {
        return e.response!.data['message'].toString();
      }
      return 'Login failed. Network error (${e.message}). Run adb reverse tcp:5000 tcp:5000';
    } catch (e, stack) {
      debugPrint('❌ Login unexpected error: $e');
      debugPrint('   Stack trace: $stack');
      return 'Login error: ${e.toString()}';
    }
  }

  Future<String?> updateProfile(String newName) async {
    if (_token == null) return 'Not authenticated';
    try {
      final resp = await _api.updateProfile({'name': newName}, _token!);
      if (resp.statusCode == 200) {
        _user = User(
          id: _user?.id ?? 0,
          name: newName,
          email: _user?.email ?? '',
        );
        notifyListeners();
        return null; // success
      }
      return 'Failed to update profile';
    } on DioException catch (e) {
      debugPrint('❌ Update profile error: ${e.response?.data ?? e.message}');
      if (e.response?.data is Map && e.response?.data['message'] != null) {
        return e.response!.data['message'].toString();
      }
      return 'Profile update failed';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> changePassword(String currentPassword, String newPassword) async {
    if (_token == null) return 'Not authenticated';
    if (newPassword.length < 8) return 'New password must be at least 8 characters';
    try {
      final resp = await _api.changePassword({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }, _token!);
      if (resp.statusCode == 200) {
        return null; // success
      }
      return 'Password update failed';
    } on DioException catch (e) {
      debugPrint('❌ Change password error: ${e.response?.data ?? e.message}');
      if (e.response?.data is Map && e.response?.data['message'] != null) {
        return e.response!.data['message'].toString();
      }
      return 'Incorrect current password or server error';
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _token = null;
    _user = null;
    notifyListeners();
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }
}
