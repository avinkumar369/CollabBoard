import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/models/canvas_object.dart';
import '../lib/models/canvas_object_move.dart';

void main() {
  const color = Color(0xFF5B4BDB);

  CanvasObject roundTrip(CanvasObject object) =>
      CanvasObject.fromJson(object.toJson());

  group('fromJson round-trips every type', () {
    test('path', () {
      final object = PathObject(
        id: 1,
        points: const [Offset(10, 10), Offset(30, 40)],
        color: color,
        thickness: 3,
      );

      final restored = roundTrip(object) as PathObject;

      expect(restored.id, 1);
      expect(restored.points, object.points);
      expect(restored.color, color);
      expect(restored.thickness, 3);
    });

    test('rect', () {
      final object = RectObject(
        id: 2,
        start: const Offset(10, 10),
        end: const Offset(90, 60),
        color: color,
        thickness: 2,
      );

      final restored = roundTrip(object) as RectObject;

      expect(restored.id, 2);
      expect(restored.start, object.start);
      expect(restored.end, object.end);
      expect(restored.color, color);
    });

    test('circle', () {
      final object = CircleObject(
        id: 3,
        center: const Offset(50, 50),
        edge: const Offset(90, 50),
        color: color,
        thickness: 2,
      );

      final restored = roundTrip(object) as CircleObject;

      expect(restored.center, object.center);
      expect(restored.edge, object.edge);
      expect(restored.radius, object.radius);
    });

    test('triangle', () {
      final object = TriangleObject(
        id: 4,
        start: const Offset(10, 10),
        end: const Offset(90, 70),
        color: color,
        thickness: 2,
      );

      final restored = roundTrip(object) as TriangleObject;

      expect(restored.id, 4);
      expect(restored.start, object.start);
      expect(restored.end, object.end);
      expect(restored.color, color);
    });

    test('line', () {
      final object = LineObject(
        id: 5,
        start: const Offset(0, 0),
        end: const Offset(100, 100),
        color: color,
        thickness: 2,
      );

      final restored = roundTrip(object) as LineObject;

      expect(restored.start, object.start);
      expect(restored.end, object.end);
    });

    test('arrow', () {
      final object = ArrowObject(
        id: 6,
        start: const Offset(0, 0),
        end: const Offset(80, 20),
        color: color,
        thickness: 2,
      );

      final restored = roundTrip(object) as ArrowObject;

      expect(restored.start, object.start);
      expect(restored.end, object.end);
    });

    test('diamond', () {
      final object = DiamondObject(
        id: 7,
        start: const Offset(10, 10),
        end: const Offset(70, 70),
        color: color,
        thickness: 2,
      );

      final restored = roundTrip(object) as DiamondObject;

      expect(restored.start, object.start);
      expect(restored.end, object.end);
    });

    test('text', () {
      final object = TextObject(
        id: 8,
        position: const Offset(20, 30),
        text: 'hello',
        color: color,
      );

      final restored = roundTrip(object) as TextObject;

      expect(restored.id, 8);
      expect(restored.position, object.position);
      expect(restored.text, 'hello');
      expect(restored.color, color);
    });

    test('sticky note', () {
      final object = StickyNoteObject(
        id: 9,
        position: const Offset(40, 60),
        text: 'note',
        color: const Color(0xFFFEF08A),
      );

      final restored = roundTrip(object) as StickyNoteObject;

      expect(restored.id, 9);
      expect(restored.position, object.position);
      expect(restored.text, 'note');
      expect(restored.color, const Color(0xFFFEF08A));
    });
  });

  test('fromJson rejects an unknown type', () {
    expect(
          () => CanvasObject.fromJson({'object_type': 'hologram'}),
      throwsA(isA<Exception>()),
    );
  });

  group('geometry helpers', () {
    test('bounds cover a rectangle', () {
      final object = RectObject(
        start: const Offset(10, 20),
        end: const Offset(90, 80),
        color: color,
        thickness: 2,
      );

      expect(object.bounds, const Rect.fromLTRB(10, 20, 90, 80));
    });

    test('bounds cover a circle', () {
      final object = CircleObject(
        center: const Offset(50, 50),
        edge: const Offset(90, 50),
        color: color,
        thickness: 2,
      );

      expect(object.bounds, const Rect.fromLTRB(10, 10, 90, 90));
    });

    test('bounds cover a path', () {
      final object = PathObject(
        points: const [Offset(10, 10), Offset(50, 70)],
        color: color,
        thickness: 2,
      );

      // Inflated by half the stroke width on every side.
      expect(object.bounds, const Rect.fromLTRB(9, 9, 51, 71));
    });

    test('movedBy shifts every point of a path', () {
      final object = PathObject(
        points: const [Offset(0, 0), Offset(10, 10)],
        color: color,
        thickness: 2,
      );

      final moved = object.movedBy(const Offset(5, 7)) as PathObject;

      expect(moved.points, const [Offset(5, 7), Offset(15, 17)]);
      expect(moved.id, object.id);
    });

    test('movedBy shifts a sticky note', () {
      final object = StickyNoteObject(
        position: const Offset(100, 100),
        text: 'note',
        color: color,
      );

      final moved = object.movedBy(const Offset(-20, 30)) as StickyNoteObject;

      expect(moved.position, const Offset(80, 130));
      expect(moved.text, 'note');
    });
  });
}

