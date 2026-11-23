import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:collabboard_app/models/board.dart';
import 'package:collabboard_app/providers/board_provider.dart';
import 'package:collabboard_app/providers/collaboration_provider.dart';
import 'package:collabboard_app/screens/board_workspace_screen.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('BoardWorkspaceScreen builds on wide width without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final board = Board(id: 1, title: 'Test Board', description: 'Desc', ownerId: 0);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BoardProvider>(create: (_) => BoardProvider()),
          ChangeNotifierProvider<CollaborationProvider>(create: (_) => CollaborationProvider()),
        ],
        child: MaterialApp(
          home: BoardWorkspaceScreen(board: board),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BoardWorkspaceScreen), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('BoardWorkspaceScreen builds on narrow width without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(300, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final board = Board(id: 1, title: 'Test Board', description: 'Desc', ownerId: 0);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BoardProvider>(create: (_) => BoardProvider()),
          ChangeNotifierProvider<CollaborationProvider>(create: (_) => CollaborationProvider()),
        ],
        child: MaterialApp(
          home: BoardWorkspaceScreen(board: board),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BoardWorkspaceScreen), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });
}
