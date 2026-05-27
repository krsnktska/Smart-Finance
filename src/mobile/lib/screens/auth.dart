import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Login controllers
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  
  // Register controllers
  final _registerNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerNameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final email = _loginEmailController.text;
    final password = _loginPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Заполни email и пароль');
      return;
    }

    final success = await ref
        .read(authProvider.notifier)
        .login(email: email, password: password);

    if (!mounted) return;

    if (success) {
      _showSnackBar('Вход успешен!', isError: false);
    } else {
      final error = ref.read(authProvider).error;
      _showSnackBar(error ?? 'Ошибка логина');
    }
  }

  void _handleRegister() async {
    final name = _registerNameController.text;
    final email = _registerEmailController.text;
    final password = _registerPasswordController.text;
    final confirmPassword = _registerConfirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar('Заполни все поля');
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar('Пароли не совпадают');
      return;
    }

    if (password.length < 6) {
      _showSnackBar('Пароль должен быть минимум 6 символов');
      return;
    }

    final success = await ref
        .read(authProvider.notifier)
        .register(name: name, email: email, password: password);

    if (!mounted) return;

    if (success) {
      _showSnackBar('Регистрация успешна!', isError: false);
    } else {
      final error = ref.read(authProvider).error;
      _showSnackBar(error ?? 'Ошибка регистрации');
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
      appBar: AppBar(
        title: const Text('SmartFinance'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // TabBar
          TabBar(
            controller: _tabController,
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Вход'),
              Tab(text: 'Регистрация'),
            ],
          ),
          // TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Login Tab
                _buildLoginTab(context, isLoading),
                // Register Tab
                _buildRegisterTab(context, isLoading),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginTab(BuildContext context, bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.account_balance_wallet,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 40),
          // Email field
          TextField(
            controller: _loginEmailController,
            enabled: !isLoading,
            decoration: InputDecoration(
              hintText: 'Email',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          // Password field
          TextField(
            controller: _loginPasswordController,
            enabled: !isLoading,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Пароль',
              prefixIcon: const Icon(Icons.lock),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Login button
          ElevatedButton(
            onPressed: isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Войти',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 16),
          // Test login button
          OutlinedButton(
            onPressed: isLoading
                ? null
                : () {
                    _loginEmailController.text = 'test@example.com';
                    _loginPasswordController.text = 'password123';
                  },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Тестовые данные'),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterTab(BuildContext context, bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          // Name field
          TextField(
            controller: _registerNameController,
            enabled: !isLoading,
            decoration: InputDecoration(
              hintText: 'Имя',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Email field
          TextField(
            controller: _registerEmailController,
            enabled: !isLoading,
            decoration: InputDecoration(
              hintText: 'Email',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          // Password field
          TextField(
            controller: _registerPasswordController,
            enabled: !isLoading,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Пароль',
              prefixIcon: const Icon(Icons.lock),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Confirm password field
          TextField(
            controller: _registerConfirmPasswordController,
            enabled: !isLoading,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Повтори пароль',
              prefixIcon: const Icon(Icons.lock),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Register button
          ElevatedButton(
            onPressed: isLoading ? null : _handleRegister,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Зарегистрироваться',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
