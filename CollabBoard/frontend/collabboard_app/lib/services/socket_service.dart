
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  static String get _serverUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else {
      return 'http://10.0.2.2:5000';
    }
  }

  io.Socket? _socket;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  final _activeUsersController =
  StreamController<List<dynamic>>.broadcast();

  final _objectCreatedController =
  StreamController<Map<String, dynamic>>.broadcast();

  final _objectUpdatedController =
  StreamController<Map<String, dynamic>>.broadcast();

  final _objectDeletedController =
  StreamController<Map<String, dynamic>>.broadcast();

  final _drawingUpdatedController =
  StreamController<Map<String, dynamic>>.broadcast();

  final _cursorMovedController =
  StreamController<Map<String, dynamic>>.broadcast();

  Stream<List<dynamic>> get onActiveUsers =>
      _activeUsersController.stream;

  Stream<Map<String, dynamic>> get onObjectCreated =>
      _objectCreatedController.stream;

  Stream<Map<String, dynamic>> get onObjectUpdated =>
      _objectUpdatedController.stream;

  Stream<Map<String, dynamic>> get onObjectDeleted =>
      _objectDeletedController.stream;

  Stream<Map<String, dynamic>> get onDrawingUpdated =>
      _drawingUpdatedController.stream;

  Stream<Map<String, dynamic>> get onCursorMoved =>
      _cursorMovedController.stream;

  void connect(String token) {
    if (_socket != null && _socket!.connected) return;

    _socket = io.io(
      _serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;

      if (kDebugMode) {
        debugPrint('🔌 Socket connected to server: $_serverUrl');
      }
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;

      if (kDebugMode) {
        debugPrint('🔌 Socket disconnected');
      }
    });

    _socket!.onConnectError((err) {
      _isConnected = false;

      if (kDebugMode) {
        debugPrint('🔌 Socket connection error: $err');
      }
    });

    // Active users
    _socket!.on('active_users', (data) {
      if (data is List) {
        _activeUsersController.add(data);
      }
    });

    // Incoming canvas object events
    _socket!.on('canvas_object_created', (data) {
      if (data is Map) {
        _objectCreatedController.add(
          Map<String, dynamic>.from(data),
        );
      }
    });

    _socket!.on('canvas_object_updated', (data) {
      if (data is Map) {
        _objectUpdatedController.add(
          Map<String, dynamic>.from(data),
        );
      }
    });

    _socket!.on('canvas_object_deleted', (data) {
      if (data is Map) {
        _objectDeletedController.add(
          Map<String, dynamic>.from(data),
        );
      }
    });

    // Drawing synchronization
    _socket!.on('drawing_updated', (data) {
      if (data is Map) {
        _drawingUpdatedController.add(
          Map<String, dynamic>.from(data),
        );
      }
    });

    // Cursor synchronization
    _socket!.on('cursor_moved', (data) {
      if (data is Map) {
        _cursorMovedController.add(
          Map<String, dynamic>.from(data),
        );
      }
    });

    _socket!.connect();
  }

  // Board management
  void joinBoard(int boardId) {
    _socket?.emit('join_board', {'boardId': boardId});
  }

  void leaveBoard(int boardId) {
    _socket?.emit('leave_board', {'boardId': boardId});
  }

  // Drawing synchronization
  void emitDrawingUpdated(
      int boardId,
      List<Map<String, double>> points,
      String color,
      double thickness,
      ) {
    _socket?.emit('drawing_updated', {
      'boardId': boardId,
      'points': points,
      'color': color,
      'thickness': thickness,
    });
  }

  // Cursor synchronization
  void emitCursorMoved(
      int boardId,
      double x,
      double y,
      ) {
    _socket?.emit('cursor_moved', {
      'boardId': boardId,
      'position': {
        'x': x,
        'y': y,
      },
    });
  }

  // Disconnect socket
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();

    _socket = null;
    _isConnected = false;
  }

  // Dispose resources
  void dispose() {
    disconnect();

    _activeUsersController.close();
    _objectCreatedController.close();
    _objectUpdatedController.close();
    _objectDeletedController.close();
    _drawingUpdatedController.close();
    _cursorMovedController.close();
  }
}
