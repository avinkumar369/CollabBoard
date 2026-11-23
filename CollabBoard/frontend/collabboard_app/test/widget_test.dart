import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collabboard_app/screens/welcome_screen.dart';
import 'package:collabboard_app/screens/login_screen.dart';
import 'package:collabboard_app/screens/register_screen.dart';

void main() {
  Widget createApp({required Widget child}) {
    return MaterialApp(
      home: child,
      routes: {
        '/register': (_) => const RegisterScreen(),
        '/login': (_) => const LoginScreen(),
      },
    );
  }

  testWidgets('Welcome screen renders correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createApp(child: const WelcomeScreen()));
    expect(find.text('Bring Your Ideas to Life'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('Navigation from Welcome to Register', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createApp(child: const WelcomeScreen()));
    final getStartedFinder = find.text('Get Started');
    await tester.ensureVisible(getStartedFinder);
    await tester.tap(getStartedFinder);
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
  });

  testWidgets('Navigation from Welcome to Login', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createApp(child: const WelcomeScreen()));
    final signInFinder = find.text('Sign In');
    await tester.ensureVisible(signInFinder);
    await tester.tap(signInFinder);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
