import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _api = ApiClient();
  
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _api.close();
    super.dispose();
  }

  void _message(String text, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? AppTheme.statusFailed.withValues(alpha: 0.9) : AppTheme.statusCompleted.withValues(alpha: 0.9),
      ),
    );
  }

  Future<void> _register() async {
    final username = _username.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    final confirmPassword = _confirmPassword.text;

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      _message('Please complete all fields.');
      return;
    }

    if (password.length < 6) {
      _message('Password must be at least 6 characters.');
      return;
    }

    if (password != confirmPassword) {
      _message('Passwords do not match.');
      return;
    }

    setState(() => _busy = true);
    try {
      // Calls POST /auth/register
      await _api.register(
        email: email,
        username: username,
        password: password,
      );

      if (!mounted) return;
      _message('Account created successfully! Please sign in.', isError: false);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _message(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.person_add_outlined, size: 22, color: AppTheme.accent),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Join NexusAI',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create your workspace user account to start collaborating with AI agents.',
                      style: TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Username',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _username,
                      decoration: const InputDecoration(
                        hintText: 'alex_developer',
                        prefixIcon: Icon(Icons.person_outline, size: 20, color: AppTheme.muted),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Email Address',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'alex@example.com',
                        prefixIcon: Icon(Icons.mail_outline, size: 20, color: AppTheme.muted),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Password',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: 'Create a password (min 6 characters)',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppTheme.muted),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                            color: AppTheme.muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Confirm Password',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _confirmPassword,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                        hintText: 'Re-enter your password',
                        prefixIcon: Icon(Icons.lock_reset_outlined, size: 20, color: AppTheme.muted),
                      ),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: _busy ? null : _register,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Create Account'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Already have an account? Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
