import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/providers/user_provider.dart';
import 'package:mobile/providers/accounts_provider.dart';

import 'package:mobile/screens/auth.dart';
import 'package:mobile/screens/home.dart';
import 'package:mobile/screens/splash_screen.dart';
import 'package:mobile/providers/invitations_provider.dart';

void main() {
  runApp(ProviderScope(child: const MyApp()));
}

final colorScheme = ColorScheme.fromSeed(
  brightness: Brightness.dark,
  seedColor: const Color.fromARGB(255, 0, 141, 24),
  surface: const Color.fromARGB(255, 0, 37, 16),
  primary: const Color.fromARGB(255, 0, 200, 83),
  onPrimary: Colors.black,
  onSurface: const Color.fromARGB(255, 110, 223, 138),
  secondary: const Color.fromARGB(255, 0, 184, 212),
  onSecondary: Colors.black,
  error: const Color.fromARGB(255, 255, 82, 82),
  onError: Colors.white,
);

final theme = ThemeData.dark().copyWith(
  colorScheme: colorScheme,
  textTheme: ThemeData.dark().textTheme.copyWith(
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: colorScheme.onSurface,
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    ),
    titleSmall: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: colorScheme.onSurface,
    ),
    bodyLarge: TextStyle(fontSize: 16, color: colorScheme.onSurface),
    bodyMedium: TextStyle(fontSize: 14, color: colorScheme.onSurface),
    bodySmall: TextStyle(fontSize: 12, color: colorScheme.onSurface),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: colorScheme.surface,

    titleTextStyle: TextStyle(
      fontSize: 20,
      color: colorScheme.onSurface,
      fontWeight: FontWeight.bold,
    ),
  ),
  scaffoldBackgroundColor: colorScheme.surface,
);

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (prev, next) {
      if (prev?.isAuthenticated == false && next.isAuthenticated) {
        ref.read(userProvider.notifier).loadUser();
        ref.read(accountsProvider.notifier).loadAccounts();
        ref.read(invitationsProvider.notifier).fetchInvitations();
      }
    });

    return MaterialApp(
      title: 'SmartFinance',
      theme: theme,
      home: _buildHome(authState),
    );
  }

  Widget _buildHome(AuthState authState) {
    if (authState.isInitializing) {
      return const SplashScreen();
    }

    if (authState.isAuthenticated) {
      return const HomeScreen();
    }

    return const AuthScreen();
  }
}
