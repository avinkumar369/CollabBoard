import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/canvas_object.dart';
import '../models/canvas_tool.dart';
import '../models/remote_cursor.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class ActiveUser {
  final int userId;
  final String name;
  final String email;
  final String role;

  ActiveUser({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
  });

  factory ActiveUser.fromJson(Map<String, dynamic> json) {
    return ActiveUser(
      userId: _toInt(json['userId'] ?? json['user_id']) ?? 0,
      name: json['name'] as String? ?? 'User',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'viewer',
    );
  }
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

class CollaborationProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final SocketService _socket = SocketService();
  final String? Function()? getAuthToken;

  int? _boardId;

  List<CanvasObject> _objects = [];
  List<ActiveUser> _activeUsers = [];

  bool _isLoading = false;
  String? _errorMessage;

  // Undo / Redo
  final List<List<CanvasObject>> _undoStack = [];
  final List<List<CanvasObject>> _redoStack = [];

  // Drawing settings
  CanvasTool _selectedTool = CanvasTool.pen;
  Color _selectedColor = const Color(0xFF5B4BDB);
  double _penThickness = 3.0;
  bool _showGrid = true;
  double _zoomLevel = 1.0;

  // Socket subscriptions
  StreamSubscription? _subActiveUsers;
  StreamSubscription? _subObjCreated;
  StreamSubscription? _subObjUpdated;
  StreamSubscription? _subObjDeleted;
  StreamSubscription? _subCursorMoved;

  // Live cursors of the other people in the board.
  final Map<int, RemoteCursor> _cursors = {};
  final Map<int, DateTime> _cursorSeen = {};
  Timer? _cursorPruneTimer;

  /// One colour per person, derived from their user id so everybody sees the
  /// same colour for the same user.
  static const List<Color> _cursorColors = [
    Color(0xFF5B4BDB),
    Color(0xFFE5484D),
    Color(0xFF2FA84F),
    Color(0xFFF0A020),
    Color(0xFF1E88E5),
    Color(0xFF9C27B0),
    Color(0xFF00ACC1),
    Color(0xFFD81B60),
  ];

  CollaborationProvider({this.getAuthToken});

  // Getters
  int? get boardId => _boardId;
  List<CanvasObject> get objects => List.unmodifiable(_objects);
  List<ActiveUser> get activeUsers => List.unmodifiable(_activeUsers);
  List<RemoteCursor> get cursors => List.unmodifiable(_cursors.values);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  CanvasTool get selectedTool => _selectedTool;
  Color get selectedColor => _selectedColor;
  double get penThickness => _penThickness;
  bool get showGrid => _showGrid;
  double get zoomLevel => _zoomLevel;

  void setTool(CanvasTool tool) {
    _selectedTool = tool;
    notifyListeners();
  }

  void setColor(Color color) {
    _selectedColor = color;
    notifyListeners();
  }

  void setThickness(double thickness) {
    _penThickness = thickness;
    notifyListeners();
  }

  void toggleGrid() {
    _showGrid = !_showGrid;
    notifyListeners();
  }

  void setZoom(double zoom) {
    _zoomLevel = zoom.clamp(0.5, 3.0);
    notifyListeners();
  }

  /// Sends this device's pointer to everyone else on the board.
  /// [position] must already be in canvas coordinates.
  void sendCursor(Offset position) {
    final currentBoardId = _boardId;

    if (currentBoardId == null) return;

    _socket.emitCursorMoved(currentBoardId, position.dx, position.dy);
  }

  void _startCursorPruning() {
    _cursorPruneTimer?.cancel();

    _cursorPruneTimer = Timer.periodic(
      const Duration(seconds: 3),
          (_) {
        final cutoff = DateTime.now().subtract(
          const Duration(seconds: 10),
        );

        final stale = _cursorSeen.entries
            .where((entry) => entry.value.isBefore(cutoff))
            .map((entry) => entry.key)
            .toList();

        if (stale.isEmpty) return;

        for (final id in stale) {
          _cursorSeen.remove(id);
          _cursors.remove(id);
        }

        notifyListeners();
      },
    );
  }

  // Safely add or replace an object using its database ID.
  void _upsertObject(CanvasObject object) {
    if (object.id == null) {
      _objects.add(object);
      return;
    }

    final index = _objects.indexWhere((item) => item.id == object.id);

    if (index == -1) {
      _objects.add(object);
    } else {
      _objects[index] = object;
    }
  }

  /// How many steps of history to keep. Each step is a full copy of the
  /// board, so this also caps memory.
  static const int _maxUndoDepth = 50;

  void _pushUndoState() {
    _undoStack.add(List<CanvasObject>.from(_objects));

    if (_undoStack.length > _maxUndoDepth) {
      _undoStack.removeAt(0);
    }

    _redoStack.clear();
  }

  Future<void> initBoard(int boardId) async {
    // Leave any previously opened board first.
    if (_boardId != null && _boardId != boardId) {
      leaveBoard();
    }

    _boardId = boardId;
    _isLoading = true;
    _errorMessage = null;

    _objects.clear();
    _activeUsers.clear();
    _undoStack.clear();
    _redoStack.clear();

    notifyListeners();

    debugPrint(
      '🎨 CollaborationProvider: Initializing board ID=$boardId',
    );

    final token = getAuthToken?.call();

    if (token == null || token.isEmpty) {
      _errorMessage = 'Authentication token is missing';
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      debugPrint('🔌 Connecting to Socket.IO...');

      _socket.connect(token);
      _listenToSocketEvents();
      _socket.joinBoard(boardId);

      debugPrint('📥 Loading canvas objects from REST API...');

      final response = await _api.getCanvasObjects(boardId, token);

      if (response.statusCode == 200 && response.data is List) {
        final List dataList = response.data as List;

        final loadedObjects = dataList.map((item) {
          return CanvasObject.fromJson(
            Map<String, dynamic>.from(item as Map),
          );
        }).toList();

        // Merge fetched objects with any socket events received while
        // the REST request was running. Database IDs prevent duplicates.
        for (final object in loadedObjects) {
          _upsertObject(object);
        }

        debugPrint(
          '✅ Loaded ${_objects.length} canvas objects',
        );
      }
    } catch (error) {
      debugPrint('❌ Failed to initialize board: $error');
      _errorMessage = 'Failed to load board objects';
    }

    _isLoading = false;
    notifyListeners();
  }

  void _listenToSocketEvents() {
    _subActiveUsers?.cancel();
    _subObjCreated?.cancel();
    _subObjUpdated?.cancel();
    _subObjDeleted?.cancel();
    _subCursorMoved?.cancel();

    _subActiveUsers = _socket.onActiveUsers.listen((list) {
      _activeUsers = list.map((item) {
        return ActiveUser.fromJson(
          Map<String, dynamic>.from(item),
        );
      }).toList();

      notifyListeners();
    });

    // The backend broadcasts the database-saved object.
    // Upsert by ID so the same event cannot create duplicates.
    _subObjCreated = _socket.onObjectCreated.listen((json) {
      try {
        final object = CanvasObject.fromJson(
          Map<String, dynamic>.from(json),
        );

        _upsertObject(object);
        notifyListeners();
      } catch (error) {
        debugPrint('❌ Error processing created object: $error');
      }
    });

    _subObjUpdated = _socket.onObjectUpdated.listen((json) {
      try {
        final object = CanvasObject.fromJson(
          Map<String, dynamic>.from(json),
        );

        _upsertObject(object);
        notifyListeners();
      } catch (error) {
        debugPrint('❌ Error processing updated object: $error');
      }
    });

    _subObjDeleted = _socket.onObjectDeleted.listen((json) {
      final id = _toInt(json['id']);

      if (id != null) {
        final previousLength = _objects.length;

        _objects.removeWhere((object) => object.id == id);

        if (_objects.length != previousLength) {
          notifyListeners();
        }
      }
    });

    _subCursorMoved = _socket.onCursorMoved.listen((json) {
      final userId = _toInt(json['userId'] ?? json['user_id']);
      final position = json['position'];

      if (userId == null || position is! Map) return;

      final x = (position['x'] as num?)?.toDouble();
      final y = (position['y'] as num?)?.toDouble();

      if (x == null || y == null) return;

      _cursors[userId] = RemoteCursor(
        userId: userId,
        name: json['name'] as String? ?? 'User',
        color: _cursorColors[userId.abs() % _cursorColors.length],
        position: Offset(x, y),
      );

      _cursorSeen[userId] = DateTime.now();

      notifyListeners();
    });

    _startCursorPruning();
  }

  // CREATE:
  // REST is the only persistence route.
  // Socket.IO receives the server broadcast after the database insert.
  Future<void> addObject(CanvasObject object) async {
    final currentBoardId = _boardId;

    if (currentBoardId == null) {
      _pushUndoState();
      _objects.add(object);
      notifyListeners();
      return;
    }

    final token = getAuthToken?.call();

    if (token == null || token.isEmpty) {
      _errorMessage = 'Authentication token is missing';
      notifyListeners();
      return;
    }

    final jsonPayload = object.toJson();

    try {
      debugPrint('📤 Saving canvas object through REST...');

      // IMPORTANT:
      // The backend controller expects camelCase field names.
      final response = await _api.createCanvasObject(
        currentBoardId,
        {
          'objectType': jsonPayload['object_type'],
          'objectData': jsonPayload['object_data'],
        },
        token,
      );

      if (response.statusCode == 201 && response.data is Map) {
        final responseData = Map<String, dynamic>.from(
          response.data as Map,
        );

        final savedId = _toInt(responseData['id']);

        if (savedId == null) {
          throw Exception(
            'Server did not return the saved object ID',
          );
        }

        // Support either a complete database row or an ID-only response.
        final savedObject = CanvasObject.fromJson({
          ...jsonPayload,
          ...responseData,
          'id': savedId,
          'object_type': responseData['object_type'] ??
              responseData['objectType'] ??
              jsonPayload['object_type'],
          'object_data': responseData['object_data'] ??
              responseData['objectData'] ??
              jsonPayload['object_data'],
        });

        _pushUndoState();

        // If the Socket.IO broadcast arrived before the REST response,
        // this replaces the existing object instead of adding another.
        _upsertObject(savedObject);

        _errorMessage = null;
        notifyListeners();

        debugPrint('✅ Canvas object saved with ID=$savedId');
      } else {
        throw Exception(
          'Unexpected create response: ${response.statusCode}',
        );
      }
    } catch (error) {
      debugPrint('❌ Error saving canvas object: $error');
      _errorMessage = 'Failed to save canvas object';
      notifyListeners();
    }
  }

  // DELETE:
  // REST is the only persistence route.
  // Do not also emit a Socket.IO delete request.
  Future<void> removeObjectNear(
      Offset point,
      double threshold,
      ) async {
    final toRemove = _objects
        .where((object) => object.isNear(point, threshold))
        .toList();

    if (toRemove.isEmpty) return;

    final currentBoardId = _boardId;
    final token = getAuthToken?.call();

    // Without a board, remove locally.
    if (currentBoardId == null) {
      _pushUndoState();
      _objects.removeWhere(toRemove.contains);
      notifyListeners();
      return;
    }

    if (token == null || token.isEmpty) {
      _errorMessage = 'Authentication token is missing';
      notifyListeners();
      return;
    }

    final successfullyDeleted = <CanvasObject>[];

    for (final object in toRemove) {
      // Unsaved local objects do not have a database ID.
      if (object.id == null) {
        successfullyDeleted.add(object);
        continue;
      }

      try {
        final response = await _api.deleteCanvasObject(
          currentBoardId,
          object.id!,
          token,
        );

        if (response.statusCode == 200 ||
            response.statusCode == 204) {
          successfullyDeleted.add(object);
        }
      } catch (error) {
        debugPrint(
          '❌ Failed to delete object ${object.id}: $error',
        );
      }
    }

    if (successfullyDeleted.isNotEmpty) {
      _pushUndoState();

      _objects.removeWhere(
            (object) => successfullyDeleted.contains(object),
      );

      _errorMessage = null;
      notifyListeners();
    }
  }

  CanvasObject? objectById(int? id) {
    if (id == null) return null;

    for (final object in _objects) {
      if (object.id == id) return object;
    }

    return null;
  }

  /// Deletes exactly one object, by its database id.
  ///
  /// Unlike [removeObjectNear] this never touches a neighbour, so it is the
  /// correct call for a selected object and for "Clear Canvas".
  Future<void> removeObjectById(int id) async {
    final index = _objects.indexWhere((object) => object.id == id);

    if (index == -1) return;

    final currentBoardId = _boardId;
    final token = getAuthToken?.call();

    // Without a board, remove locally.
    if (currentBoardId == null) {
      _pushUndoState();
      _objects.removeAt(index);
      notifyListeners();
      return;
    }

    if (token == null || token.isEmpty) {
      _errorMessage = 'Authentication token is missing';
      notifyListeners();
      return;
    }

    try {
      final response = await _api.deleteCanvasObject(
        currentBoardId,
        id,
        token,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _pushUndoState();
        _objects.removeWhere((object) => object.id == id);
        _errorMessage = null;
        notifyListeners();
      } else {
        throw Exception(
          'Unexpected delete response: ${response.statusCode}',
        );
      }
    } catch (error) {
      debugPrint('❌ Failed to delete object $id: $error');
      _errorMessage = 'Failed to delete object';
      notifyListeners();
    }
  }

  /// Replaces an existing object: locally first, so the canvas responds
  /// immediately, then through REST. On failure the object is put back the
  /// way it was, so the screen never disagrees with the database.
  Future<void> updateObject(CanvasObject object) async {
    final id = object.id;

    if (id == null) return;

    final index = _objects.indexWhere((item) => item.id == id);

    if (index == -1) return;

    final previous = _objects[index];

    _pushUndoState();
    _objects[index] = object;
    notifyListeners();

    final currentBoardId = _boardId;
    final token = getAuthToken?.call();

    if (currentBoardId == null) return;

    if (token == null || token.isEmpty) {
      _errorMessage = 'Authentication token is missing';
      notifyListeners();
      return;
    }

    final jsonPayload = object.toJson();

    try {
      final response = await _api.updateCanvasObject(
        currentBoardId,
        id,
        {
          'objectType': jsonPayload['object_type'],
          'objectData': jsonPayload['object_data'],
        },
        token,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _errorMessage = null;
        notifyListeners();
      } else {
        throw Exception(
          'Unexpected update response: ${response.statusCode}',
        );
      }
    } catch (error) {
      debugPrint('❌ Failed to update object $id: $error');

      _errorMessage = 'Failed to save the change';

      final currentIndex = _objects.indexWhere((item) => item.id == id);

      if (currentIndex != -1) {
        _objects[currentIndex] = previous;
      }

      notifyListeners();
    }
  }

  /// Steps back one action, on screen first and then in the database, so the
  /// board you see after an undo is the board you get after a reload.
  Future<void> undo() async {
    if (_undoStack.isEmpty) return;

    final current = List<CanvasObject>.from(_objects);
    final target = _undoStack.removeLast();

    _redoStack.add(current);

    _objects = List<CanvasObject>.from(target);
    notifyListeners();

    await _persistDiff(from: current, to: target);
  }

  /// Steps forward one action, on screen first and then in the database.
  Future<void> redo() async {
    if (_redoStack.isEmpty) return;

    final current = List<CanvasObject>.from(_objects);
    final target = _redoStack.removeLast();

    _undoStack.add(current);

    _objects = List<CanvasObject>.from(target);
    notifyListeners();

    await _persistDiff(from: current, to: target);
  }

  /// Brings the database in line with [to], given that the board used to look
  /// like [from]. Deleted objects are removed, changed ones are updated and
  /// objects that have to come back are created again.
  Future<void> _persistDiff({
    required List<CanvasObject> from,
    required List<CanvasObject> to,
  }) async {
    final boardId = _boardId;
    final token = getAuthToken?.call();

    if (boardId == null || token == null || token.isEmpty) return;

    final Map<int, CanvasObject> fromById = {
      for (final object in from)
        if (object.id != null) object.id!: object,
    };

    final Map<int, CanvasObject> toById = {
      for (final object in to)
        if (object.id != null) object.id!: object,
    };

    // 1. Objects that exist now but should not exist any more.
    for (final id in fromById.keys) {
      if (toById.containsKey(id)) continue;

      try {
        await _api.deleteCanvasObject(boardId, id, token);
      } catch (error) {
        debugPrint('❌ Undo: failed to delete object $id: $error');
      }
    }

    // 2. Objects that are in both, but changed.
    for (final entry in toById.entries) {
      final previous = fromById[entry.key];

      if (previous == null) continue;
      if (_sameObjectData(previous, entry.value)) continue;

      try {
        final payload = entry.value.toJson();

        await _api.updateCanvasObject(
          boardId,
          entry.key,
          {
            'objectType': payload['object_type'],
            'objectData': payload['object_data'],
          },
          token,
        );
      } catch (error) {
        debugPrint('❌ Undo: failed to update object ${entry.key}: $error');
      }
    }

    // 3. Objects that have to come back. They get new database ids.
    final Map<int, CanvasObject> recreated = {};

    for (final object in to) {
      final id = object.id;

      if (id == null || fromById.containsKey(id)) continue;

      try {
        final payload = object.toJson();

        final response = await _api.createCanvasObject(
          boardId,
          {
            'objectType': payload['object_type'],
            'objectData': payload['object_data'],
          },
          token,
        );

        if (response.statusCode == 201 && response.data is Map) {
          final data = Map<String, dynamic>.from(
            response.data as Map,
          );

          final newId = _toInt(data['id']);

          if (newId != null) {
            recreated[id] = CanvasObject.fromJson({
              ...payload,
              'id': newId,
            });
          }
        }
      } catch (error) {
        debugPrint('❌ Undo: failed to re-create object $id: $error');
      }
    }

    if (recreated.isNotEmpty) {
      _objects = _objects
          .map((object) => recreated[object.id] ?? object)
          .toList();

      notifyListeners();
    }

    _errorMessage = null;
    notifyListeners();
  }

  /// Compares the payload the server actually stores, ignoring ids.
  bool _sameObjectData(CanvasObject a, CanvasObject b) {
    return jsonEncode(a.toJson()['object_data']) ==
        jsonEncode(b.toJson()['object_data']);
  }

  void leaveBoard() {
    if (_boardId != null) {
      debugPrint('🚪 Leaving board room $_boardId');
      _socket.leaveBoard(_boardId!);
    }

    _subActiveUsers?.cancel();
    _subObjCreated?.cancel();
    _subObjUpdated?.cancel();
    _subObjDeleted?.cancel();
    _subCursorMoved?.cancel();
    _cursorPruneTimer?.cancel();

    _subActiveUsers = null;
    _subObjCreated = null;
    _subObjUpdated = null;
    _subObjDeleted = null;
    _subCursorMoved = null;
    _cursorPruneTimer = null;

    _cursors.clear();
    _cursorSeen.clear();

    _boardId = null;
    _objects.clear();
    _activeUsers.clear();
    _undoStack.clear();
    _redoStack.clear();

    notifyListeners();
  }

  @override
  void dispose() {
    leaveBoard();
    _socket.dispose();
    super.dispose();
  }
}
