import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../models/canvas_object.dart';
import '../services/api_service.dart';
import '../widgets/whiteboard_painter.dart';

/// Read-only view of a board, opened from a share link.
///
/// No login, no tools: it loads the board through the public endpoint and
/// renders it with the same painter the editor uses, so a shared board looks
/// exactly like the real thing.
class SharedBoardScreen extends StatefulWidget {
  final String shareToken;

  const SharedBoardScreen({super.key, required this.shareToken});

  @override
  State<SharedBoardScreen> createState() => _SharedBoardScreenState();
}

class _SharedBoardScreenState extends State<SharedBoardScreen> {
  static const Size _canvasSize = Size(4000, 4000);

  final ApiService _api = ApiService();
  final TransformationController _transformationController =
  TransformationController();

  bool _isLoading = true;
  String? _error;
  String _title = 'Shared board';
  List<CanvasObject> _objects = const [];
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();

    _transformationController.addListener(_onTransformChanged);
    _load();
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();

    if (scale != _scale && mounted) {
      setState(() {
        _scale = scale;
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _api.getSharedBoard(widget.shareToken);

      if (response.statusCode != 200 || response.data is! Map) {
        throw Exception('Unexpected response: ${response.statusCode}');
      }

      final data = Map<String, dynamic>.from(response.data as Map);

      final board = data['board'] is Map
          ? Map<String, dynamic>.from(data['board'] as Map)
          : <String, dynamic>{};

      final loaded = <CanvasObject>[];

      if (data['objects'] is List) {
        for (final item in data['objects'] as List) {
          if (item is! Map) continue;

          try {
            loaded.add(
              CanvasObject.fromJson(Map<String, dynamic>.from(item)),
            );
          } catch (error) {
            // Skip a type this version does not understand rather than
            // failing the whole board.
            debugPrint('Skipped an unknown object: $error');
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _title = board['title'] as String? ?? 'Shared board';
        _objects = loaded;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      final status =
      error is DioException ? error.response?.statusCode : null;

      setState(() {
        _error = status == 404
            ? 'This link is no longer valid.'
            : 'Could not load this board. Check your connection.';
        _isLoading = false;
      });
    }
  }

  void _zoomIn() => _zoomBy(1.2);

  void _zoomOut() => _zoomBy(1 / 1.2);

  void _zoomBy(double factor) {
    final current =
    _transformationController.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(0.25, 3.0);

    if (target == current) return;

    final size = MediaQuery.of(context).size;
    final focal = Offset(size.width / 2, size.height / 2);
    final ratio = target / current;

    final zoom = Matrix4.translationValues(focal.dx, focal.dy, 0)
        .multiplied(Matrix4.diagonal3Values(ratio, ratio, 1.0))
        .multiplied(Matrix4.translationValues(-focal.dx, -focal.dy, 0));

    _transformationController.value =
        zoom.multiplied(_transformationController.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Read-only view',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out),
            tooltip: 'Zoom out',
            onPressed: _zoomOut,
          ),
          Text(
            '${(_scale * 100).toInt()}%',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            tooltip: 'Zoom in',
            onPressed: _zoomIn,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF5B4BDB)),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.link_off,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_objects.isEmpty) {
      return const Center(
        child: Text('This board is empty.'),
      );
    }

    return Container(
      color: Colors.white,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.25,
        maxScale: 3.0,
        constrained: false,
        boundaryMargin: const EdgeInsets.all(400),
        child: SizedBox(
          width: _canvasSize.width,
          height: _canvasSize.height,
          child: CustomPaint(
            size: _canvasSize,
            painter: WhiteboardPainter(
              objects: _objects,
              currentPath: const [],
              penColor: const Color(0xFF5B4BDB),
              penThickness: 1,
              showGrid: true,
            ),
          ),
        ),
      ),
    );
  }
}
