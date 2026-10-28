import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../workspace/screens/workspace_shell.dart';
import 'register_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    this.apiClient,
    this.skipInitialCheck = false,
  });

  final ApiClient? apiClient;
  final bool skipInitialCheck;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final ApiClient _api;
  
  bool _obscure = true;
  bool _busy = false;
  late bool _checkingSession;
  bool? _backendHealthy;
  String? _backendError;

  @override
  void initState() {
    super.initState();
    _api = widget.apiClient ?? ApiClient();
    _checkingSession = !widget.skipInitialCheck;
    if (!widget.skipInitialCheck) {
      _checkInitialStatus();
    }
  }

  Future<void> _checkInitialStatus() async {
    // 1. Check backend health
    try {
      final health = await _api.healthCheck();
      if (mounted) {
        setState(() {
          _backendHealthy = health['status'] == 'healthy';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _backendHealthy = false;
          _backendError = e.toString();
        });
      }
    }

    // 2. Check if we already have an active valid token
    try {
      final token = await const TokenStorage().readAccessToken();
      if (token != null && token.isNotEmpty) {
        final user = await _api.me();
        if (user.isNotEmpty && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const WorkspaceShell()),
          );
          return;
        }
      }
    } catch (_) {
      await const TokenStorage().clear();
    } finally {
      if (mounted) {
        setState(() => _checkingSession = false);
      }
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _api.close();
    super.dispose();
  }

  void _message(String value, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        backgroundColor: isError ? AppTheme.statusFailed.withValues(alpha: 0.9) : AppTheme.card,
      ),
    );
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    final password = _password.text;

    if (email.isEmpty || password.isEmpty) {
      _message('Please enter both email and password.');
      return;
    }

    setState(() => _busy = true);
    try {
      // Calls POST /auth/login with OAuth2 form urlencoded
      await _api.login(email, password);
      // Verify profile with GET /auth/me
      await _api.me();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WorkspaceShell()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) _message(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showServerConfigDialog() {
    final urlController = TextEditingController(text: ApiConfig.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend API Server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the base URL where your FastAPI backend is running:',
              style: TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                hintText: 'http://15.134.215.0:8000',
                labelText: 'Base URL',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ApiConfig.customBaseUrl = urlController.text;
              Navigator.pop(ctx);
              _checkInitialStatus();
            },
            child: const Text('Save & Test'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Connecting to NexusAI...', style: TextStyle(color: AppTheme.muted)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(minHeight: viewport.maxHeight - 48),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final form = _buildForm();
                        if (constraints.maxWidth < 780) {
                          return form;
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(child: _WelcomeHeroPanel()),
                            Expanded(child: form),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'Sign In',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // Backend health badge
              InkWell(
                onTap: _showServerConfigDialog,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (_backendHealthy == true
                            ? AppTheme.statusCompleted
                            : AppTheme.statusFailed)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (_backendHealthy == true
                              ? AppTheme.statusCompleted
                              : AppTheme.statusFailed)
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: _backendHealthy == true
                            ? AppTheme.statusCompleted
                            : AppTheme.statusFailed,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _backendHealthy == true ? 'API Connected' : 'API Offline',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _backendHealthy == true
                              ? AppTheme.statusCompleted
                              : AppTheme.statusFailed,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.settings_outlined, size: 12, color: AppTheme.muted),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Sign in to access your multi-agent collaboration workspace.',
            style: TextStyle(color: AppTheme.muted, height: 1.4),
          ),
          if (_backendHealthy == false) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.statusFailed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.statusFailed.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.statusFailed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _backendError?.contains('Failed to fetch') == true
                              ? 'CORS Origin Blocked: The backend only allows port 5173.'
                              : 'Backend not reachable at ${ApiConfig.baseUrl}',
                          style: const TextStyle(
                            color: AppTheme.statusFailed,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _backendError?.contains('Failed to fetch') == true
                              ? 'To fix: Run Flutter Web with:\nflutter run -d chrome --web-port=5173\nOr run as a desktop app:\nflutter run -d windows'
                              : (_backendError ?? 'Ensure your FastAPI server is running on port 8000.'),
                          style: const TextStyle(color: AppTheme.statusFailed, fontSize: 11, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          const Text(
            'Email Address',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'user@example.com',
              prefixIcon: Icon(Icons.mail_outline, size: 20, color: AppTheme.muted),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Password',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _password,
            obscureText: _obscure,
            onSubmitted: (_) => _signIn(),
            decoration: InputDecoration(
              hintText: 'Enter password',
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
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _busy ? null : _signIn,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Sign In'),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              );
            },
            child: const Text('Create New Account'),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton.icon(
              onPressed: _showServerConfigDialog,
              icon: const Icon(Icons.tune, size: 16, color: AppTheme.muted),
              label: Text(
                'Server: ${ApiConfig.baseUrl}',
                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeHeroPanel extends StatelessWidget {
  const _WelcomeHeroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(44),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.hub_rounded, size: 26, color: AppTheme.accent),
              ),
              const SizedBox(width: 12),
              const Text(
                'NexusAI',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
            ],
          ),
          const SizedBox(height: 60),
          const Text(
            'Autonomous Multi-Agent Collaboration',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Deploy coordinated teams of Planner, Researcher, Developer, Coder, and Reviewer agents to execute complex software workflows in real-time.',
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 40),
          _featureRow(Icons.auto_mode_outlined, 'Intelligent agent workflows with human-in-the-loop approval'),
          const SizedBox(height: 16),
          _featureRow(Icons.bolt_outlined, 'Live WebSocket telemetry for streaming agent steps'),
          const SizedBox(height: 16),
          _featureRow(Icons.task_alt_outlined, 'Comprehensive project tracking & task management'),
        ],
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.4),
          ),
        ),
      ],
    );
  }
}
