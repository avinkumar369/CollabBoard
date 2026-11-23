import 'package:flutter/material.dart';

import 'canvas_object.dart';

/// Geometry helpers for [CanvasObject]s.
///
/// Kept in its own file so the models stay pure data and nothing in
/// canvas_object.dart has to change.
extension CanvasObjectGeometry on CanvasObject {
  /// Axis-aligned bounding box of the object, in canvas coordinates.
  /// Used for the selection outline and for hit-testing with the Select tool.
  Rect get bounds {
    final obj = this;

    if (obj is PathObject) {
      if (obj.points.isEmpty) return Rect.zero;

      double minX = obj.points.first.dx;
      double maxX = minX;
      double minY = obj.points.first.dy;
      double maxY = minY;

      for (final point in obj.points) {
        if (point.dx < minX) minX = point.dx;
        if (point.dx > maxX) maxX = point.dx;
        if (point.dy < minY) minY = point.dy;
        if (point.dy > maxY) maxY = point.dy;
      }

      return Rect.fromLTRB(minX, minY, maxX, maxY)
          .inflate(obj.thickness / 2);
    }

    if (obj is RectObject) return Rect.fromPoints(obj.start, obj.end);
    if (obj is TriangleObject) return Rect.fromPoints(obj.start, obj.end);
    if (obj is DiamondObject) return Rect.fromPoints(obj.start, obj.end);
    if (obj is LineObject) return Rect.fromPoints(obj.start, obj.end);
    if (obj is ArrowObject) return Rect.fromPoints(obj.start, obj.end);

    if (obj is CircleObject) {
      final radius = (obj.center - obj.edge).distance;
      return Rect.fromCircle(center: obj.center, radius: radius);
    }

    if (obj is TextObject) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: obj.text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      return obj.position & textPainter.size;
    }

    if (obj is StickyNoteObject) {
      return obj.position & StickyNoteObject.size;
    }

    return Rect.zero;
  }

  /// Returns a copy of this object shifted by [delta].
  /// Every field on the models is final, so moving means rebuilding.
  CanvasObject movedBy(Offset delta) {
    final obj = this;

    if (obj is PathObject) {
      return PathObject(
        id: obj.id,
        userId: obj.userId,
        points: obj.points.map((point) => point + delta).toList(),
        color: obj.color,
        thickness: obj.thickness,
      );
    }

    if (obj is RectObject) {
      return RectObject(
        id: obj.id,
        userId: obj.userId,
        start: obj.start + delta,
        end: obj.end + delta,
        color: obj.color,
        thickness: obj.thickness,
      );
    }

    if (obj is CircleObject) {
      return CircleObject(
        id: obj.id,
        userId: obj.userId,
        center: obj.center + delta,
        edge: obj.edge + delta,
        color: obj.color,
        thickness: obj.thickness,
      );
    }

    if (obj is TriangleObject) {
      return TriangleObject(
        id: obj.id,
        userId: obj.userId,
        start: obj.start + delta,
        end: obj.end + delta,
        color: obj.color,
        thickness: obj.thickness,
      );
    }

    if (obj is LineObject) {
      return LineObject(
        id: obj.id,
        userId: obj.userId,
        start: obj.start + delta,
        end: obj.end + delta,
        color: obj.color,
        thickness: obj.thickness,
      );
    }

    if (obj is ArrowObject) {
      return ArrowObject(
        id: obj.id,
        userId: obj.userId,
        start: obj.start + delta,
        end: obj.end + delta,
        color: obj.color,
        thickness: obj.thickness,
      );
    }

    if (obj is DiamondObject) {
      return DiamondObject(
        id: obj.id,
        userId: obj.userId,
        start: obj.start + delta,
        end: obj.end + delta,
        color: obj.color,
        thickness: obj.thickness,
      );
    }

    if (obj is TextObject) {
      return TextObject(
        id: obj.id,
        userId: obj.userId,
        position: obj.position + delta,
        text: obj.text,
        color: obj.color,
      );
    }

    if (obj is StickyNoteObject) {
      return StickyNoteObject(
        id: obj.id,
        userId: obj.userId,
        position: obj.position + delta,
        text: obj.text,
        color: obj.color,
      );
    }

    return obj;
  }
}
