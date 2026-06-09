import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/providers/user_provider.dart';
import 'package:mobile/providers/accounts_provider.dart';
import 'package:mobile/screens/auth/login_screen.dart';
import 'package:mobile/screens/home.dart';
import 'package:mobile/screens/splash_screen.dart';
import 'package:mobile/providers/invitations_provider.dart';
import 'package:mobile/providers/gmail_provider.dart';
import 'package:mobile/utils/app_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(child: const MyApp()));
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final colorScheme = ColorScheme.fromSeed(
  brightness: Brightness.dark,
  seedColor: const Color.fromARGB(255, 0, 141, 24),
  surface: const Color.fromARGB(255, 0, 37, 16),
  primary: const Color.fromARGB(255, 0, 200, 83),
  onPrimary: Colors.black,
  onSurface: const Color.fromARGB(255, 110, 223, 138),
  secondary: const Color.fromARGB(255, 0, 184, 212),
  onSecondary: Colors.black,
  tertiary: const Color.fromARGB(255, 176, 236, 11),
  onTertiary: Colors.black,
  error: const Color.fromARGB(255, 133, 161, 106),
  onError: Colors.white,
);

final theme = ThemeData.dark().copyWith(
  colorScheme: colorScheme,
  scaffoldBackgroundColor: colorScheme.surface,
  extensions: const [
    AppColors(expense: Color(0xFFCF3030)),
  ],
);

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  static const _deepLinkChannel = MethodChannel('smartfinance/deep_link');
  Uri? _pendingDeepLink;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinkListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkChannel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      final authState = ref.read(authProvider);
      if (authState.isAuthenticated) {
        ref.read(gmailIntegrationProvider.notifier).loadStatus();
      }
    }
  }

  Future<void> _initDeepLinkListener() async {
    _deepLinkChannel.setMethodCallHandler((call) async {
      if (call.method == 'linkChanged' && call.arguments is String) {
        final uri = Uri.tryParse(call.arguments as String);
        if (uri != null) {
          _handleDeepLink(uri);
        }
      }
      return null;
    });

    try {
      final initialLink = await _deepLinkChannel.invokeMethod<String>(
        'getInitialLink',
      );
      if (initialLink != null) {
        final uri = Uri.tryParse(initialLink);
        if (uri != null) {
          _handleDeepLink(uri);
        }
      }
    } on PlatformException {
      print('Failed to get initial deep link');
    }
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme != 'smartfinance') return;
    print('Deep link received: $uri');

    if (uri.host != 'gmail-callback') return;

    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated) {
      _pendingDeepLink = uri;
      print('Deep link deferred until authentication is ready');
      return;
    }

    ref.read(gmailIntegrationProvider.notifier).loadStatus();
  }

  void _processPendingDeepLink() {
    final pendingLink = _pendingDeepLink;
    if (pendingLink == null) return;
    _pendingDeepLink = null;
    _handleDeepLink(pendingLink);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (prev, next) {
      if (prev?.isAuthenticated == false && next.isAuthenticated) {
        ref.read(userProvider.notifier).loadUser();
        ref.read(accountsProvider.notifier).loadAccounts();
        ref.read(invitationsProvider.notifier).fetchInvitations();
        _processPendingDeepLink();

        SchedulerBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        });
        return;
      }

      if (prev?.isAuthenticated == true &&
          !next.isAuthenticated &&
          !next.isInitializing) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.pushAndRemoveUntil(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 400),
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const LoginScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeIn,
                      ),
                      child: child,
                    );
                  },
            ),
            (route) => false,
          );
        });
        return;
      }

      if (prev?.isInitializing == true &&
          next.isInitializing == false &&
          !next.isAuthenticated) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.pushAndRemoveUntil(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 1400),
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const LoginScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: CurvedAnimation(
                        parent: animation,
                        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
                      ),
                      child: child,
                    );
                  },
            ),
            (route) => false,
          );
        });
      }
    });

    return MaterialApp(
      title: 'SmartFinance',
      theme: theme,
      navigatorKey: navigatorKey,
      home: const SplashScreen(),
    );
  }
}
