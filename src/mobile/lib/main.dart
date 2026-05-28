import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/providers/user_provider.dart';
import 'package:mobile/providers/accounts_provider.dart';

import 'package:mobile/screens/auth.dart';
import 'package:mobile/screens/home.dart';

void main() {
  runApp(ProviderScope(child: const MyApp()));
}

final colorScheme = ColorScheme.fromSeed(
  brightness: Brightness.dark,
  seedColor: const Color.fromARGB(255, 0, 141, 24),
  surface: const Color.fromARGB(255, 0, 37, 16),
  primary: const Color.fromARGB(255, 0, 200, 83),
  onPrimary: Colors.black,
  onSurface: const Color.fromARGB(255, 220, 230, 225),
  secondary: const Color.fromARGB(255, 0, 184, 212),
  onSecondary: Colors.black,
  error: const Color.fromARGB(255, 255, 82, 82),
  onError: Colors.white,
);

final theme = ThemeData().copyWith(
  colorScheme: colorScheme,
  textTheme: ThemeData.dark().textTheme.copyWith(
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: colorScheme.onSurface,
    ),
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
      }
    });

    return MaterialApp(
      title: 'SmartFinance',
      theme: theme,
      home: authState.isAuthenticated ? const HomeScreen() : const AuthScreen(),
    );
  }
}
