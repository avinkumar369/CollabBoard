import 'package:flutter/material.dart';

/// Another person's pointer on the board.
///
/// [position] is in canvas coordinates, the same space the painter draws in,
/// so a cursor arriving from another device needs no transform here.
class RemoteCursor {
  final int userId;
  final String name;
  final Color color;
  final Offset position;

  const RemoteCursor({
    required this.userId,
    required this.name,
    required this.color,
    required this.position,
  });

  RemoteCursor movedTo(Offset newPosition) => RemoteCursor(
    userId: userId,
    name: name,
    color: color,
    position: newPosition,
  );
}
