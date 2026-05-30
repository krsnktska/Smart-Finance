import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/widgets/app_buttons.dart';
import 'package:mobile/widgets/app_text_field.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _rememberMe = false;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final email = _loginEmailController.text;
    final password = _loginPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Enter email and password');
      return;
    }

    final success = await ref
        .read(authProvider.notifier)
        .login(email: email, password: password, remember: _rememberMe);

    if (!mounted) return;

    if (success) {
      _showSnackBar('Login successful!', isError: false);
    } else {
      final error = ref.read(authProvider).error;
      _showSnackBar(error ?? 'Login error');
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      // Залишаємо AppBar пустим або прибираємо зовсім, щоб логотип красиво став зверху
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),

            // ─── АНІМОВАНИЙ БЛОК ЛОГОТИПУ ───
            Center(
              child: Column(
                children: [
                  Hero(
                    tag: 'app_wallet_icon',
                    child: Container(
                      width: 90, // Трохи міняємо розмір для екрану логіну
                      height: 90,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        size: 55,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Hero(
                    tag: 'app_title_text',
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        'SmartFinance',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─────────────────────────────────
            const SizedBox(height: 40),
            AppTextField(
              controller: _loginEmailController,
              enabled: !isLoading,
              hintText: 'Email',
              prefixIcon: const Icon(Icons.email),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _loginPasswordController,
              enabled: !isLoading,
              hintText: 'Password',
              prefixIcon: const Icon(Icons.lock),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: isLoading
                      ? null
                      : (v) => setState(() => _rememberMe = v ?? false),
                ),
                const Text('Remember me'),
              ],
            ),
            AppButton(
              label: 'Login',
              onPressed: isLoading ? null : _handleLogin,
              isLoading: isLoading,
            ),
            const SizedBox(height: 16),
            AppOutlinedButton(
              label: 'Test Credentials',
              onPressed: isLoading
                  ? null
                  : () {
                      _loginEmailController.text = 'test@example.com';
                      _loginPasswordController.text = 'password123';
                    },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterScreen(),
                        ),
                      );
                    },
              child: const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}
