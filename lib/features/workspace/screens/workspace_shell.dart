import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/screens/sign_in_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../projects/screens/projects_screen.dart';

class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({super.key});

  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _user;
  bool? _isBackendHealthy;
  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _loadUser();
    _checkHealth();
  }

  Future<void> _loadUser() async {
    try {
      final u = await _api.me();
      if (mounted) setState(() => _user = u);
    } catch (_) {
      // Session expired or invalid
      if (mounted) _logout();
    }
  }

  Future<void> _checkHealth() async {
    try {
      final h = await _api.healthCheck();
      if (mounted) {
        setState(() => _isBackendHealthy = h['status'] == 'healthy');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isBackendHealthy = false);
      }
    }
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _logout() async {
    await const TokenStorage().clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (_) => false,
    );
  }

  void _showHealthDetailsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.dns_outlined, color: AppTheme.accent),
            SizedBox(width: 10),
            Text('Backend API Status'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _isBackendHealthy == true ? Icons.check_circle : Icons.error,
                color: _isBackendHealthy == true ? AppTheme.statusCompleted : AppTheme.statusFailed,
              ),
              title: Text(_isBackendHealthy == true ? 'Online & Healthy' : 'Disconnected / Error'),
              subtitle: Text(ApiConfig.baseUrl),
            ),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Endpoints active:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Text('• GET /health', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
            const Text('• POST /auth/login, POST /auth/register, GET /auth/me', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
            const Text('• /project (CRUD & Status)', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
            const Text('• /projects/{id}/tasks (CRUD & Status)', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
            const Text('• /agents/run, history, approve, changes, messages', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
            const Text('• /ws/{project_id} (Real-time agent stream)', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _checkHealth();
            },
            child: const Text('Re-check Connection'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final pages = [
      DashboardScreen(
        onOpenProjects: () => setState(() => _selectedIndex = 1),
      ),
      const ProjectsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.hub_rounded, color: AppTheme.accent, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'NexusAI',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
          ],
        ),
        actions: [
          // Connection Pill
          InkWell(
            onTap: _showHealthDetailsDialog,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (_isBackendHealthy == true
                        ? AppTheme.statusCompleted
                        : AppTheme.statusFailed)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (_isBackendHealthy == true
                          ? AppTheme.statusCompleted
                          : AppTheme.statusFailed)
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: _isBackendHealthy == true
                        ? AppTheme.statusCompleted
                        : AppTheme.statusFailed,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isBackendHealthy == true ? 'Backend Online' : 'Offline',
                    style: TextStyle(
                      color: _isBackendHealthy == true
                          ? AppTheme.statusCompleted
                          : AppTheme.statusFailed,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // User Badge
          if (_user != null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 10,
                    backgroundColor: AppTheme.accent,
                    child: Icon(Icons.person, size: 12, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    (_user!['username'] ?? _user!['email'] ?? 'User').toString(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Sign Out',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, size: 20, color: AppTheme.muted),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              labelType: NavigationRailLabelType.all,
              backgroundColor: AppTheme.surface,
              indicatorColor: AppTheme.accent.withValues(alpha: 0.2),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard, color: AppTheme.accent),
                  label: Text('Overview'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder, color: AppTheme.accent),
                  label: Text('Projects'),
                ),
              ],
            ),
          if (wide) const VerticalDivider(width: 1),
          Expanded(child: pages[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              backgroundColor: AppTheme.surface,
              indicatorColor: AppTheme.accent.withValues(alpha: 0.2),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard, color: AppTheme.accent),
                  label: 'Overview',
                ),
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder, color: AppTheme.accent),
                  label: 'Projects',
                ),
              ],
            ),
    );
  }
}
