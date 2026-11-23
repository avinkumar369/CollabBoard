import 'package:flutter/material.dart';

/// Base class for all objects that can be drawn on the whiteboard.
abstract class CanvasObject {
  final int? id;
  final int? userId;

  CanvasObject({this.id, this.userId});

  /// Returns true if the object is within [threshold] distance from [point].
  bool isNear(Offset point, double threshold);

  Map<String, dynamic> toJson();

  static CanvasObject fromJson(Map<String, dynamic> json) {
    final int? id = json['id'] as int?;
    final int? userId = json['user_id'] as int? ?? json['userId'] as int?;
    final String type = json['object_type'] as String? ?? json['type'] as String? ?? '';
    final Map<String, dynamic> data = json['object_data'] is Map<String, dynamic>
        ? json['object_data']
        : json;

    switch (type) {
      case 'path':
        return PathObject.fromData(id: id, userId: userId, data: data);
      case 'rect':
      case 'rectangle':
        return RectObject.fromData(id: id, userId: userId, data: data);
      case 'circle':
        return CircleObject.fromData(id: id, userId: userId, data: data);
      case 'triangle':
        return TriangleObject.fromData(id: id, userId: userId, data: data);
      case 'line':
        return LineObject.fromData(id: id, userId: userId, data: data);
      case 'arrow':
        return ArrowObject.fromData(id: id, userId: userId, data: data);
      case 'diamond':
        return DiamondObject.fromData(id: id, userId: userId, data: data);
      case 'text':
        return TextObject.fromData(id: id, userId: userId, data: data);
      case 'sticky':
      case 'sticky_note':
        return StickyNoteObject.fromData(id: id, userId: userId, data: data);
      default:
        throw Exception('Unknown canvas object type: $type');
    }
  }

  static Color _colorFromHex(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  static String _colorToHex(Color color) {
    final r = (color.r * 255).toInt().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).toInt().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).toInt().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }
}

/// Free-hand path drawn with the pen or highlighter.
class PathObject extends CanvasObject {
  final List<Offset> points;
  final Color color;
  final double thickness;

  PathObject({
    super.id,
    super.userId,
    required this.points,
    required this.color,
    required this.thickness,
  });

  @override
  bool isNear(Offset point, double threshold) {
    for (final p in points) {
      if ((p - point).distance <= threshold) return true;
    }
    return false;
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'object_type': 'path',
    'object_data': {
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'color': CanvasObject._colorToHex(color),
      'thickness': thickness,
    },
  };

  factory PathObject.fromData({int? id, int? userId, required Map<String, dynamic> data}) {
    final List pointsList = data['points'] as List? ?? [];
    return PathObject(
      id: id,
      userId: userId,
      points: pointsList.map((p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble())).toList(),
      color: CanvasObject._colorFromHex(data['color'] as String? ?? '#000000'),
      thickness: (data['thickness'] as num? ?? 2.0).toDouble(),
    );
  }
}

/// Rectangle defined by two opposite corners.
class RectObject extends CanvasObject {
  final Offset start;
  final Offset end;
  final Color color;
  final double thickness;

  RectObject({
    super.id,
    super.userId,
    required this.start,
    required this.end,
    required this.color,
    required this.thickness,
  });

  Rect get _rect => Rect.fromPoints(start, end);

  @override
  bool isNear(Offset point, double threshold) => _rect.inflate(threshold).contains(point);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'object_type': 'rect',
    'object_data': {
      'start': {'x': start.dx, 'y': start.dy},
      'end': {'x': end.dx, 'y': end.dy},
      'color': CanvasObject._colorToHex(color),
      'thickness': thickness,
    },
  };

  factory RectObject.fromData({int? id, int? userId, required Map<String, dynamic> data}) {
    final startData = data['start'] as Map<String, dynamic>? ?? {'x': 0.0, 'y': 0.0};
    final endData = data['end'] as Map<String, dynamic>? ?? {'x': 0.0, 'y': 0.0};
    return RectObject(
      id: id,
      userId: userId,
      start: Offset((startData['x'] as num).toDouble(), (startData['y'] as num).toDouble()),
      end: Offset((endData['x'] as num).toDouble(), (endData['y'] as num).toDouble()),
      color: CanvasObject._colorFromHex(data['color'] as String? ?? '#000000'),
      thickness: (data['thickness'] as num? ?? 2.0).toDouble(),
    );
  }
}

/// Circle defined by center point and edge point.
class CircleObject extends CanvasObject {
  final Offset center;
  final Offset edge;
  final Color color;
  final double thickness;

  CircleObject({
    super.id,
    super.userId,
    required this.center,
    required this.edge,
    required this.color,
    required this.thickness,
  });

  double get radius => (center - edge).distance;

  @override
  bool isNear(Offset point, double threshold) => ((point - center).distance - radius).abs() <= threshold;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'object_type': 'circle',
    'object_data': {
      'center': {'x': center.dx, 'y': center.dy},
      'edge': {'x': edge.dx, 'y': edge.dy},
      'color': CanvasObject._colorToHex(color),
      'thickness': thickness,
    },
  };

  factory CircleObject.fromData({int? id, int? userId, required Map<String, dynamic> data}) {
    final centerData = data['center'] as Map<String, dynamic>? ?? {'x': 0.0, 'y': 0.0};
    final edgeData = data['edge'] as Map<String, dynamic>? ?? {'x': 0.0, 'y': 0.0};
    return CircleObject(
      id: id,
      userId: userId,
      center: Offset((centerData['x'] as num).toDouble(), (centerData['y'] as num).toDouble()),
      edge: Offset((edgeData['x'] as num).toDouble(), (edgeData['y'] as num).toDouble()),
      color: CanvasObject._colorFromHex(data['color'] as String? ?? '#000000'),
      thickness: (data['thickness'] as num? ?? 2.0).toDouble(),
    );
  }
}

/// Triangle shape object.
class TriangleObject extends CanvasObject {
  final Offset start;
  final Offset end;
  final Color color;
  final double thickness;

  TriangleObject({
    super.id,
    super.userId,
    required this.start,
    required this.end,
    required this.color,
    required this.thickness,
  });

  Rect get _rect => Rect.fromPoints(start, end);

  @override
  bool isNear(Offset point, double threshold) => _rect.inflate(threshold).contains(point);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'object_type': 'triangle',
    'object_data': {
      'start': {'x': start.dx, 'y': start.dy},
      'end': {'x': end.dx, 'y': end.dy},
      'color': CanvasObject._colorToHex(color),
      'thickness': thickness,
    },
  };

  factory TriangleObject.fromData({int? id, int? userId, required Map<String, dynamic> data}) {
    final startData = data['start'] as Map<String, dynamic>? ?? {'x': 0.0, 'y': 0.0};
    final endData = data['end'] as Map<String, dynamic>? ?? {'x': 0.0, 'y': 0.0};
    return TriangleObject(
      id: id,
      userId: userId,
      start: Offset((startData['x'] as num).toDouble(), (startData['y'] as num).toDouble()),
      end: Offset((endData['x'] as num).toDouble(), (endData['y'] as num).toDouble()),
      color: CanvasObject._colorFromHex(data['color'] as String? ?? '#000000'),
      thickness: (data['thickness'] as num? ?? 2.0).toDouble(),
    );
  }
}

/// Straight Line object.
class LineObject extends CanvasObject {
  final Offset start;
  final Offset end;
  final Color color;
  final double thickness;

  LineObject({
    super.id,
    super.userId,
    required this.start,
    required this.end,
    required this.color,
    required this.thickness,
  });

  @override
  bool isNear(Offset point, double threshold) => (Offset.lerp(start, end, 0.5)! - point).distance <= threshold * 2;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'object_type': 'line',
    'object_data': {
      'start': {'x': start.dx, 'y': start.dy},
      'end': {'x': end.dx, 'y': end.dy},
      'color': CanvasObject._colorToHex(color),
      'thickness': thickness,
    },
  };

  factory LineObject.fromData({int? id, int? userId, required Map<String, dynamic> data}) {
    final startData = data['start'] as Map<String, dynamic>? ?? {'x': 0.0, 'y': 0.0};
    final endData = data['end'] as Map<String, dynamic>? ?? {'x': 0.0, 'y': 0.0};
    return LineObject(
      id: id,
      userId: userId,
      start: Offset((startData['x'] as num).toDouble(), (startData['y'] as num).toDouble()),
      end: Offset((endData['x'] as num).toDouble(), (endData['y'] as num).toDouble()),
      color: CanvasObject._colorFromHex(data['color'] as String? ?? '#000000'),
      thickness: (data['thickness'] as num? ?? 2.0).toDouble(),
    );
  }
}

/// Arrow from start to end.
class ArrowObject extends CanvasObject {
  final Offset start;
  final Offset end;
  final Color color;
  final double thickness;

  ArrowObject({
    super.id,
    super.userId,
    required this.start,
    required this.end,
    required this.color,
    required this.thickness,
  });

  @override
  bool isNear(Offset point, double threshold) => (Offset.lerp(start, end, 0.5)! - point).distance <= threshold * 2;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'object_type': 'arrow',
    'object_data': {
      'start': {'x': start.dx, 'y': start.dy},
      'end': {'x': end.dx, 'y': end.dy},
      'color': CanvasObject._colorToHex(color),
      'thickness': thickness,
    },
  };

  factory ArrowObject.fromData({int? id, int? userId, required Map<String, dynamic> data}) {
    final startData = data['start'] as Map<String, dynamic>? ?? {'x': 0.0, 'y': 0.0};
    final endData = data['end'] as Map<String, dynamic>? ?? {'x': 0.0, 'y': 0.0};
    return ArrowObject(
      id: id,
      userId: userId,
      start: Offset((startData['x'] as num).toDouble(), (startData['y'] as num).toDouble()),
      end: Offset((endData['x'] as num).toDouble(), (endData['y'] as num).toDouble()),
      color: CanvasObject._colorFromHex(data['color'] as String? ?? '#000000'),
      thickness: (data['thickness'] as num? ?? 2.0).toDouble(),
    );
  }
}

/// Diamond shape object.
class DiamondObject extends CanvasObject {
  final Offset start;
  final Offset end;
  final Color color;
  final double thickness;

  DiamondObject({
    super.id,
    super.userId,
    required this.start,
    required this.end,
    required this.color,
    required this.thickness,
  });

  Rect get _rect => Rect.fromPoints(start, end);

  @override
  bool isNear(Offset point, double threshold) => _rect.inflate(threshold).contains(point);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'object_type': 'diamond',
    'object_data': {
      'start': {'x': start.dx, 'y': start.dy},
      'end': {'x': end.dx, 'y': end.dy},
      'color': CanvasObject._colorToHex(color),
      'thickness': thickness,
    },
  };

  factory DiamondObject.fromData({int? id, int? userId, required Map<String, dynamic> data}) {
    final startData = data['start'] as Map<String, dynamic>? ?? {'x': 0.0, 'y': 0.0};
    final endData = data['end'] as Map<String, dynamic>? ?? {'x': 0.0, 'y': 0.0};
    return DiamondObject(
      id: id,
      userId: userId,
      start: Offset((startData['x'] as num).toDouble(), (startData['y'] as num).toDouble()),
      end: Offset((endData['x'] as num).toDouble(), (endData['y'] as num).toDouble()),
      color: CanvasObject._colorFromHex(data['color'] as String? ?? '#000000'),
      thickness: (data['thickness'] as num? ?? 2.0).toDouble(),
    );
  }
}

/// Text placed at a position.
class TextObject extends CanvasObject {
  final Offset position;
  final String text;
  final Color color;

  TextObject({
    super.id,
    super.userId,
    required this.position,
    required this.text,
    required this.color,
  });

  @override
  bool isNear(Offset point, double threshold) => (position - point).distance <= threshold * 3;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'object_type': 'text',
    'object_data': {
      'position': {'x': position.dx, 'y': position.dy},
      'text': text,
      'color': CanvasObject._colorToHex(color),
    },
  };

  factory TextObject.fromData({int? id, int? userId, required Map<String, dynamic> data}) {
    final posData = data['position'] as Map<String, dynamic>? ?? {'x': 0.0, 'y': 0.0};
    return TextObject(
      id: id,
      userId: userId,
      position: Offset((posData['x'] as num).toDouble(), (posData['y'] as num).toDouble()),
      text: data['text'] as String? ?? '',
      color: CanvasObject._colorFromHex(data['color'] as String? ?? '#000000'),
    );
  }
}

/// Sticky note object.
class StickyNoteObject extends CanvasObject {
  final Offset position;
  final String text;
  final Color color;

  static const Size size = Size(150, 150);

  StickyNoteObject({
    super.id,
    super.userId,
    required this.position,
    required this.text,
    required this.color,
  });

  Rect get _rect => position & size;

  @override
  bool isNear(Offset point, double threshold) => _rect.inflate(threshold).contains(point);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'object_type': 'sticky',
    'object_data': {
      'position': {'x': position.dx, 'y': position.dy},
      'text': text,
      'color': CanvasObject._colorToHex(color),
    },
  };

  factory StickyNoteObject.fromData({int? id, int? userId, required Map<String, dynamic> data}) {
    final posData = data['position'] as Map<String, dynamic>? ?? {'x': 0.0, 'y': 0.0};
    return StickyNoteObject(
      id: id,
      userId: userId,
      position: Offset((posData['x'] as num).toDouble(), (posData['y'] as num).toDouble()),
      text: data['text'] as String? ?? '',
      color: CanvasObject._colorFromHex(data['color'] as String? ?? '#FFFF88'),
    );
  }
}
