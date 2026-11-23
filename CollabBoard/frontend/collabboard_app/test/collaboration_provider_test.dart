import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/models/canvas_object.dart';
import '../lib/models/canvas_tool.dart';
import '../lib/providers/collaboration_provider.dart';

CanvasObject rectangle() => RectObject(
  start: const Offset(10, 10),
  end: const Offset(90, 90),
  color: Colors.black,
  thickness: 2,
);

void main() {
  group('local board (no server)', () {
    late CollaborationProvider provider;

    setUp(() {
      // No board and no token: every call takes the local path, so these
      // tests never touch the network.
      provider = CollaborationProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('starts empty', () {
      expect(provider.objects, isEmpty);
      expect(provider.canUndo, isFalse);
      expect(provider.canRedo, isFalse);
    });

    test('addObject adds locally', () async {
      await provider.addObject(rectangle());

      expect(provider.objects, hasLength(1));
      expect(provider.canUndo, isTrue);
    });

    test('undo removes the last added object', () async {
      await provider.addObject(rectangle());

      await provider.undo();

      expect(provider.objects, isEmpty);
      expect(provider.canRedo, isTrue);
    });

    test('redo puts the object back', () async {
      await provider.addObject(rectangle());
      await provider.undo();

      await provider.redo();

      expect(provider.objects, hasLength(1));
    });

    test('undo with empty history does nothing', () async {
      await provider.undo();

      expect(provider.objects, isEmpty);
      expect(provider.canUndo, isFalse);
    });

    test('a new action clears the redo stack', () async {
      await provider.addObject(rectangle());
      await provider.undo();

      await provider.addObject(rectangle());

      expect(provider.canRedo, isFalse);
      expect(provider.objects, hasLength(1));
    });

    test('removeObjectNear deletes the object under the point', () async {
      await provider.addObject(rectangle());

      await provider.removeObjectNear(const Offset(50, 50), 20);

      expect(provider.objects, isEmpty);
    });

    test('removeObjectNear leaves distant objects alone', () async {
      await provider.addObject(rectangle());

      await provider.removeObjectNear(const Offset(900, 900), 20);

      expect(provider.objects, hasLength(1));
    });

    test('a delete can be undone', () async {
      await provider.addObject(rectangle());
      await provider.removeObjectNear(const Offset(50, 50), 20);

      await provider.undo();

      expect(provider.objects, hasLength(1));
    });

    test('settings changes notify listeners', () {
      var notifications = 0;
      provider.addListener(() => notifications++);

      provider.setTool(CanvasTool.text);
      provider.setColor(Colors.red);
      provider.setThickness(5);
      provider.toggleGrid();

      expect(notifications, 4);
      expect(provider.selectedTool, CanvasTool.text);
      expect(provider.showGrid, isFalse);
    });
  });
}
