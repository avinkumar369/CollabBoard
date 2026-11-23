
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/board_provider.dart';

import 'screens/auth_wrapper.dart';
import 'screens/dashboard_screen.dart';
import 'screens/welcome_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..loadFromStorage(),
        ),
        ChangeNotifierProvider(
          create: (context) => BoardProvider(
            getAuthToken: () =>
                Provider.of<AuthProvider>(
                  context,
                  listen: false,
                ).token,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'CollabBoard',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
          ),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
        routes: {
          '/dashboard': (context) => const DashboardScreen(),
          '/welcome': (context) => const WelcomeScreen(),
        },
      ),
    );
  }
}
