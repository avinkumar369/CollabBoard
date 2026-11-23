import 'package:flutter/foundation.dart';
import '../models/board.dart';
import '../services/api_service.dart';
import 'package:dio/dio.dart';

class BoardProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final String? Function()? getAuthToken;

  List<Board> _boards = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Board> get boards => _boards;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  BoardProvider({this.getAuthToken});

  Future<void> loadBoards() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final token = getAuthToken?.call();
      debugPrint('📦 BoardProvider.loadBoards: Token available? ${token != null && token.isNotEmpty}');
      final response = await _api.dio.get(
        '/boards',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      debugPrint('📦 Load boards status: ${response.statusCode}');
      final List data = response.data as List;
      _boards = data.map((json) => Board.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      debugPrint('❌ Load boards DioException: ${e.message} (Status: ${e.response?.statusCode})');
      _errorMessage = e.response?.data['message'] ?? e.message;
    } catch (e) {
      debugPrint('❌ Load boards unexpected error: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Board?> createBoard(String title, String description) async {
    final token = getAuthToken?.call();
    debugPrint('📤 BoardProvider.createBoard submitted: title="$title", token available? ${token != null && token.isNotEmpty}');
    
    try {
      final response = await _api.dio.post(
        '/boards',
        data: {'title': title, 'description': description},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      debugPrint('📥 Create board response status: ${response.statusCode}');
      debugPrint('📥 Create board response data: ${response.data}');

      await loadBoards();

      if (response.data is Map<String, dynamic>) {
        final newBoard = Board.fromJson(response.data as Map<String, dynamic>);
        debugPrint('✅ Created board successfully: ID=${newBoard.id}, Title="${newBoard.title}"');
        return newBoard;
      }
      if (_boards.isNotEmpty) {
        return _boards.first;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('❌ Create board DioException: ${e.message} (Status: ${e.response?.statusCode})');
      debugPrint('   Response data: ${e.response?.data}');
      _errorMessage = e.response?.data is Map ? e.response?.data['message'] : e.message;
      notifyListeners();
      return null;
    } catch (e, stack) {
      debugPrint('❌ Create board unexpected error: $e');
      debugPrint('   Stack trace: $stack');
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateBoard(int id, String title, String description) async {
    final token = getAuthToken?.call();
    try {
      await _api.dio.put(
        '/boards/$id',
        data: {'title': title, 'description': description},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      await loadBoards();
      return true;
    } on DioException catch (e) {
      _errorMessage = e.response?.data['message'] ?? e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> duplicateBoard(int id) async {
    final token = getAuthToken?.call();
    try {
      await _api.dio.post(
        '/boards/$id/duplicate',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      await loadBoards();
      return true;
    } on DioException catch (e) {
      _errorMessage = e.response?.data['message'] ?? e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteBoard(int id) async {
    final token = getAuthToken?.call();
    try {
      await _api.dio.delete(
        '/boards/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      _boards.removeWhere((b) => b.id == id);
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _errorMessage = e.response?.data['message'] ?? e.message;
      notifyListeners();
      return false;
    }
  }
}
