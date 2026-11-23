import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/canvas_object.dart';
import '../models/canvas_object_move.dart';
import '../widgets/whiteboard_painter.dart';

/// Renders the whole board to a PNG, independently of the screen.
///
/// The board is 4000 x 4000 on screen, so capturing the widget would either
/// give you one screenful or a 256 MB bitmap. This draws the objects into an
/// offscreen picture sized to their own bounds instead.
class BoardExporter {
  /// Blank space around the drawing, in logical pixels.
  static const double padding = 40;

  /// Never produce a bitmap bigger than this on its longest side.
  static const int maxSide = 8000;

  /// The smallest rectangle containing every object.
  static Rect boundsOf(List<CanvasObject> objects) {
    if (objects.isEmpty) return Rect.zero;

    var result = objects.first.bounds;

    for (final object in objects.skip(1)) {
      result = result.expandToInclude(object.bounds);
    }

    return result;
  }

  /// Returns PNG bytes, or null when there is nothing to export.
  static Future<Uint8List?> toPng(
      List<CanvasObject> objects, {
        double pixelRatio = 2.0,
        bool showGrid = false,
      }) async {
    if (objects.isEmpty) return null;

    final content = boundsOf(objects);

    final logicalWidth = content.width + padding * 2;
    final logicalHeight = content.height + padding * 2;

    // Reduce the pixel ratio if the bitmap would be too large.
    final longest = logicalWidth > logicalHeight ? logicalWidth : logicalHeight;
    final ratio =
    longest * pixelRatio > maxSide ? maxSide / longest : pixelRatio;

    final canvasWidth =
    (logicalWidth * ratio).ceil().clamp(1, maxSide).toInt();
    final canvasHeight =
    (logicalHeight * ratio).ceil().clamp(1, maxSide).toInt();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.scale(ratio);

    // The painter draws a transparent background, and a transparent PNG looks
    // broken in most viewers, so fill white first.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, logicalWidth, logicalHeight),
      Paint()..color = Colors.white,
    );

    canvas.translate(padding - content.left, padding - content.top);

    WhiteboardPainter(
      objects: objects,
      currentPath: const [],
      penColor: Colors.black,
      penThickness: 1,
      showGrid: showGrid,
    ).paint(canvas, Size(logicalWidth, logicalHeight));

    final picture = recorder.endRecording();

    try {
      final image = await picture.toImage(canvasWidth, canvasHeight);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);

      image.dispose();

      return data?.buffer.asUint8List();
    } finally {
      picture.dispose();
    }
  }
}
