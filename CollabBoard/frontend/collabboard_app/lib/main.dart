import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/board_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/collaboration_provider.dart';
import 'services/api_service.dart';

import 'theme/app_theme.dart';
import 'screens/auth_wrapper.dart';
import 'screens/dashboard_screen.dart';
import 'screens/shared_board_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..loadFromStorage(),
        ),
        ChangeNotifierProvider(
          create: (context) => BoardProvider(
            getAuthToken: () => Provider.of<AuthProvider>(context, listen: false).token,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => CollaborationProvider(
            getAuthToken: () => Provider.of<AuthProvider>(context, listen: false).token,
          ),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'CollabBoard',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const AuthWrapper(),
            routes: {
              '/welcome': (context) => const WelcomeScreen(),
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/dashboard': (context) => const DashboardScreen(),
              '/profile': (context) => const ProfileScreen(),
              '/settings': (context) => const SettingsScreen(),
            },
            // Opens a read-only board from a share link: '/share/<token>'.
            // Named routes above are matched first; this only sees names
            // that are not in the routes table.
            onGenerateRoute: (settings) {
              final name = settings.name ?? '';

              if (name.startsWith('/share/')) {
                final token = name.substring('/share/'.length);

                if (token.isNotEmpty) {
                  return MaterialPageRoute(
                    builder: (_) => SharedBoardScreen(shareToken: token),
                  );
                }
              }

              return null;
            },
          );
        },
      ),
    );
  }
}
