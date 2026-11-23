import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String get _defaultBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    } else {
      // Android Emulator uses 10.0.2.2 to reach host machine localhost
      return 'http://10.0.2.2:5000/api';
    }
  }

  static String _baseUrl = 'http://10.0.2.2:5000/api';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('custom_api_url');
    if (saved != null && saved.isNotEmpty) {
      // Automatically sanitize stale localhost/127.0.0.1 URLs on Android/iOS emulators/devices
      if (!kIsWeb && (saved.contains('localhost') || saved.contains('127.0.0.1'))) {
        _baseUrl = _defaultBaseUrl;
        await prefs.setString('custom_api_url', _defaultBaseUrl);
        debugPrint('⚠️ Sanitized cached API URL from localhost to Android emulator host $_defaultBaseUrl');
      } else {
        _baseUrl = saved;
      }
    } else {
      _baseUrl = _defaultBaseUrl;
    }
    debugPrint('🌐 ApiService initialized with base URL: $_baseUrl');
  }

  static Future<void> setBaseUrl(String url) async {
    _baseUrl = url.endsWith('/api') ? url : '$url/api';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_api_url', _baseUrl);
    debugPrint('🌐 ApiService base URL updated to: $_baseUrl');
  }

  static String get currentBaseUrl => _baseUrl;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  ApiService() {
    _dio.options.baseUrl = _baseUrl;
  }

  Dio get dio {
    _dio.options.baseUrl = _baseUrl;
    return _dio;
  }

  // Auth
  Future<Response> register(Map<String, dynamic> data) async {
    _dio.options.baseUrl = _baseUrl;
    debugPrint('📤 POST $_baseUrl/auth/register');
    return _dio.post('/auth/register', data: data);
  }

  Future<Response> login(Map<String, dynamic> data) async {
    _dio.options.baseUrl = _baseUrl;
    debugPrint('📤 POST $_baseUrl/auth/login');
    return _dio.post('/auth/login', data: data);
  }

  Future<Response> getMe(String token) async {
    _dio.options.baseUrl = _baseUrl;
    return _dio.get('/auth/me', options: Options(headers: {'Authorization': 'Bearer $token'}));
  }

  // Boards
  Future<Response> createBoard(Map<String, dynamic> data, String token) =>
      _dio.post('/boards', data: data, options: Options(headers: {'Authorization': 'Bearer $token'}));
  Future<Response> getBoards(String token) =>
      _dio.get('/boards', options: Options(headers: {'Authorization': 'Bearer $token'}));
  Future<Response> getBoard(int boardId, String token) =>
      _dio.get('/boards/$boardId', options: Options(headers: {'Authorization': 'Bearer $token'}));
  Future<Response> updateBoard(int boardId, Map<String, dynamic> data, String token) =>
      _dio.put('/boards/$boardId', data: data, options: Options(headers: {'Authorization': 'Bearer $token'}));
  Future<Response> deleteBoard(int boardId, String token) =>
      _dio.delete('/boards/$boardId', options: Options(headers: {'Authorization': 'Bearer $token'}));

  // Board members
  Future<Response> getMembers(int boardId, String token) =>
      _dio.get('/boards/$boardId/members', options: Options(headers: {'Authorization': 'Bearer $token'}));
  Future<Response> addMember(int boardId, Map<String, dynamic> data, String token) =>
      _dio.post('/boards/$boardId/members', data: data, options: Options(headers: {'Authorization': 'Bearer $token'}));
  Future<Response> removeMember(int boardId, int userId, String token) =>
      _dio.delete('/boards/$boardId/members/$userId', options: Options(headers: {'Authorization': 'Bearer $token'}));
  Future<Response> updateMemberRole(int boardId, int userId, String role, String token) =>
      _dio.put('/boards/$boardId/members/$userId', data: {'role': role}, options: Options(headers: {'Authorization': 'Bearer $token'}));

  // Canvas Objects
  Future<Response> getCanvasObjects(int boardId, String token) =>
      _dio.get('/boards/$boardId/objects', options: Options(headers: {'Authorization': 'Bearer $token'}));
  Future<Response> createCanvasObject(int boardId, Map<String, dynamic> data, String token) =>
      _dio.post('/boards/$boardId/objects', data: data, options: Options(headers: {'Authorization': 'Bearer $token'}));
  Future<Response> updateCanvasObject(int boardId, int objectId, Map<String, dynamic> data, String token) =>
      _dio.put('/boards/$boardId/objects/$objectId', data: data, options: Options(headers: {'Authorization': 'Bearer $token'}));
  Future<Response> deleteCanvasObject(int boardId, int objectId, String token) =>
      _dio.delete('/boards/$boardId/objects/$objectId', options: Options(headers: {'Authorization': 'Bearer $token'}));

  // Public sharing (no login required)
  Future<Response> getSharedBoard(String shareToken) =>
      _dio.get('/boards/share/$shareToken');
  Future<Response> createShareLink(int boardId, String token, {bool rotate = false}) =>
      _dio.post('/boards/$boardId/share', data: {'rotate': rotate}, options: Options(headers: {'Authorization': 'Bearer $token'}));

  // Invitations
  Future<Response> createInvitation(int boardId, Map<String, dynamic> data, String token) =>
      _dio.post('/boards/$boardId/invitations', data: data, options: Options(headers: {'Authorization': 'Bearer $token'}));
  Future<Response> listInvitations(int boardId, String token) =>
      _dio.get('/boards/$boardId/invitations', options: Options(headers: {'Authorization': 'Bearer $token'}));
  Future<Response> getInvitationInfo(String token) =>
      _dio.get('/boards/invitations/info/$token');
  Future<Response> joinInvitation(String token, String authToken) =>
      _dio.post('/boards/invitations/join/$token', options: Options(headers: {'Authorization': 'Bearer $authToken'}));
  Future<Response> revokeInvitation(int boardId, String token, String authToken) =>
      _dio.delete('/boards/$boardId/invitations/revoke/$token', options: Options(headers: {'Authorization': 'Bearer $authToken'}));

  // Profile
  Future<Response> getProfile(String token) =>
      _dio.get('/profile', options: Options(headers: {'Authorization': 'Bearer $token'}));
  Future<Response> updateProfile(Map<String, dynamic> data, String token) =>
      _dio.put('/profile', data: data, options: Options(headers: {'Authorization': 'Bearer $token'}));
  Future<Response> changePassword(Map<String, dynamic> data, String token) =>
      _dio.post('/profile/change-password', data: data, options: Options(headers: {'Authorization': 'Bearer $token'}));

  // Notifications
  Future<Response> getNotifications(String token) =>
      _dio.get('/notifications', options: Options(headers: {'Authorization': 'Bearer $token'}));
  Future<Response> markNotificationRead(int id, String token) =>
      _dio.put('/notifications/$id/read', options: Options(headers: {'Authorization': 'Bearer $token'}));

  // Activity
  Future<Response> getActivityLogs(int boardId, String token) =>
      _dio.get('/activity/$boardId', options: Options(headers: {'Authorization': 'Bearer $token'}));
}
