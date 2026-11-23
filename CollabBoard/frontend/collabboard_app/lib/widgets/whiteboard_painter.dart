
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/canvas_object.dart';

/// Paints persisted canvas objects, active drawing paths and the optional grid.
class WhiteboardPainter extends CustomPainter {
  final List<CanvasObject> objects;
  final List<Offset> currentPath;
  final Color penColor;
  final double penThickness;
  final bool showGrid;

  WhiteboardPainter({
    required List<CanvasObject> objects,
    required List<Offset> currentPath,
    required this.penColor,
    required this.penThickness,
    this.showGrid = true,
  })  : objects = List<CanvasObject>.unmodifiable(objects),
        currentPath = List<Offset>.unmodifiable(currentPath);

  @override
  void paint(Canvas canvas, Size size) {
    // Background grid.
    if (showGrid) {
      final gridPaint = Paint()
        ..color = const Color(0xFFE9E5F3).withValues(alpha: 0.7)
        ..strokeWidth = 1.0;

      const double step = 30.0;

      for (double x = 0; x < size.width; x += step) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          gridPaint,
        );
      }

      for (double y = 0; y < size.height; y += step) {
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          gridPaint,
        );
      }
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final obj in objects) {
      if (obj is PathObject) {
        if (obj.points.isEmpty) continue;

        paint
          ..color = obj.color
          ..strokeWidth = obj.thickness
          ..style = PaintingStyle.stroke;

        final path = Path()
          ..moveTo(obj.points.first.dx, obj.points.first.dy);

        for (final point in obj.points.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }

        canvas.drawPath(path, paint);
      } else if (obj is RectObject) {
        paint
          ..color = obj.color
          ..strokeWidth = obj.thickness
          ..style = PaintingStyle.stroke;

        canvas.drawRect(
          Rect.fromPoints(obj.start, obj.end),
          paint,
        );
      } else if (obj is CircleObject) {
        paint
          ..color = obj.color
          ..strokeWidth = obj.thickness
          ..style = PaintingStyle.stroke;

        final radius = (obj.center - obj.edge).distance;

        canvas.drawCircle(obj.center, radius, paint);
      } else if (obj is TriangleObject) {
        paint
          ..color = obj.color
          ..strokeWidth = obj.thickness
          ..style = PaintingStyle.stroke;

        final rect = Rect.fromPoints(obj.start, obj.end);

        final path = Path()
          ..moveTo(rect.center.dx, rect.top)
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..close();

        canvas.drawPath(path, paint);
      } else if (obj is LineObject) {
        paint
          ..color = obj.color
          ..strokeWidth = obj.thickness
          ..style = PaintingStyle.stroke;

        canvas.drawLine(obj.start, obj.end, paint);
      } else if (obj is ArrowObject) {
        paint
          ..color = obj.color
          ..strokeWidth = obj.thickness
          ..style = PaintingStyle.stroke;

        canvas.drawLine(obj.start, obj.end, paint);

        const double headSize = 12.0;
        final angle = (obj.end - obj.start).direction;

        final arrowPath = Path()
          ..moveTo(obj.end.dx, obj.end.dy)
          ..lineTo(
            obj.end.dx - headSize * math.cos(angle - math.pi / 6),
            obj.end.dy - headSize * math.sin(angle - math.pi / 6),
          )
          ..moveTo(obj.end.dx, obj.end.dy)
          ..lineTo(
            obj.end.dx - headSize * math.cos(angle + math.pi / 6),
            obj.end.dy - headSize * math.sin(angle + math.pi / 6),
          );

        canvas.drawPath(arrowPath, paint);
      } else if (obj is DiamondObject) {
        paint
          ..color = obj.color
          ..strokeWidth = obj.thickness
          ..style = PaintingStyle.stroke;

        final rect = Rect.fromPoints(obj.start, obj.end);

        final path = Path()
          ..moveTo(rect.center.dx, rect.top)
          ..lineTo(rect.right, rect.center.dy)
          ..lineTo(rect.center.dx, rect.bottom)
          ..lineTo(rect.left, rect.center.dy)
          ..close();

        canvas.drawPath(path, paint);
      } else if (obj is TextObject) {
        final textSpan = TextSpan(
          text: obj.text,
          style: TextStyle(
            color: obj.color,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();
        textPainter.paint(canvas, obj.position);
      } else if (obj is StickyNoteObject) {
        final rect = Rect.fromLTWH(
          obj.position.dx,
          obj.position.dy,
          StickyNoteObject.size.width,
          StickyNoteObject.size.height,
        );

        final shadowPaint = Paint()
          ..color = Colors.black.withValues(alpha: 0.1)
          ..maskFilter = const MaskFilter.blur(
            BlurStyle.normal,
            6,
          );

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect.shift(const Offset(3, 3)),
            const Radius.circular(8),
          ),
          shadowPaint,
        );

        paint
          ..color = obj.color
          ..style = PaintingStyle.fill;

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect,
            const Radius.circular(8),
          ),
          paint,
        );

        paint
          ..color = obj.color.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect,
            const Radius.circular(8),
          ),
          paint,
        );

        final textSpan = TextSpan(
          text: obj.text,
          style: const TextStyle(
            color: Color(0xFF25233A),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
          maxLines: 6,
        );

        textPainter.layout(
          maxWidth: StickyNoteObject.size.width - 16,
        );

        textPainter.paint(
          canvas,
          obj.position + const Offset(8, 8),
        );

        paint.style = PaintingStyle.stroke;
      }
    }

    // Active pen path.
    if (currentPath.isNotEmpty) {
      paint
        ..color = penColor
        ..strokeWidth = penThickness
        ..style = PaintingStyle.stroke;

      final path = Path()
        ..moveTo(currentPath.first.dx, currentPath.first.dy);

      for (final point in currentPath.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WhiteboardPainter oldDelegate) {
    return !listEquals(oldDelegate.objects, objects) ||
        !listEquals(oldDelegate.currentPath, currentPath) ||
        oldDelegate.penColor != penColor ||
        oldDelegate.penThickness != penThickness ||
        oldDelegate.showGrid != showGrid;
  }
}
