import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/widgets/app_buttons.dart';
import 'package:mobile/widgets/app_text_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _registerNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();
  DateTime? _registerBirthday;

  @override
  void dispose() {
    _registerNameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    final name = _registerNameController.text;
    final email = _registerEmailController.text;
    final password = _registerPasswordController.text;
    final confirmPassword = _registerConfirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill in all fields');
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar('Passwords do not match');
      return;
    }

    if (password.length < 6) {
      _showSnackBar('Password must be at least 6 characters');
      return;
    }

    final success = await ref
        .read(authProvider.notifier)
        .register(
          name: name,
          email: email,
          password: password,
          birthday: _registerBirthday,
        );

    if (!mounted) return;

    if (success) {
      _showSnackBar('Registration successful!', isError: false);
    } else {
      final error = ref.read(authProvider).error;
      _showSnackBar(error ?? 'Registration error');
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
      appBar: AppBar(title: const Text('Register'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            AppTextField(
              controller: _registerNameController,
              enabled: !isLoading,
              hintText: 'Name',
              prefixIcon: const Icon(Icons.person),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _registerEmailController,
              enabled: !isLoading,
              hintText: 'Email',
              prefixIcon: const Icon(Icons.email),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _registerPasswordController,
              enabled: !isLoading,
              hintText: 'Password',
              obscureText: true,
              prefixIcon: const Icon(Icons.lock),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _registerConfirmPasswordController,
              enabled: !isLoading,
              hintText: 'Confirm Password',
              obscureText: true,
              prefixIcon: const Icon(Icons.lock),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: isLoading
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().subtract(
                          const Duration(days: 365 * 25),
                        ),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _registerBirthday = picked);
                      }
                    },
              icon: const Icon(Icons.cake),
              label: Text(
                _registerBirthday != null
                    ? 'Birthday: ${_registerBirthday!.toLocal().toString().split(' ')[0]}'
                    : 'Birthday (optional)',
              ),
            ),
            const SizedBox(height: 32),
            AppButton(
              label: 'Register',
              onPressed: isLoading ? null : _handleRegister,
              isLoading: isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
