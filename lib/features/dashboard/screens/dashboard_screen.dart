import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/components.dart';
import '../../projects/screens/project_control_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onOpenProjects});
  final VoidCallback onOpenProjects;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _projects = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await _api.listProjectsItems(page: 1, limit: 50);
      if (mounted) setState(() => _projects = p);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = _projects.where((p) => (p['status'] ?? '').toString() == 'completed').length;
    final running = _projects.where((p) => (p['status'] ?? '').toString() == 'running').length;
    final planning = _projects.where((p) => (p['status'] ?? '').toString() == 'planning').length;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Workspace Overview',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Monitor project health, task progression, and agent executions.',
                            style: TextStyle(color: AppTheme.muted, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _load,
                      tooltip: 'Refresh overview',
                      icon: const Icon(Icons.refresh, color: AppTheme.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                // Metric cards row
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _MetricCard(
                      label: 'Total Projects',
                      value: _loading ? '…' : '${_projects.length}',
                      icon: Icons.folder_open,
                      color: AppTheme.accent,
                    ),
                    _MetricCard(
                      label: 'Running Workflows',
                      value: _loading ? '…' : '$running',
                      icon: Icons.bolt_outlined,
                      color: AppTheme.statusRunning,
                    ),
                    _MetricCard(
                      label: 'In Planning',
                      value: _loading ? '…' : '$planning',
                      icon: Icons.psychology_outlined,
                      color: AppTheme.statusPlanning,
                    ),
                    _MetricCard(
                      label: 'Completed',
                      value: _loading ? '…' : '$completed',
                      icon: Icons.task_alt,
                      color: AppTheme.statusCompleted,
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Projects',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: widget.onOpenProjects,
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_error != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.statusFailed),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: AppTheme.statusFailed),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_projects.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.folder_open, size: 48, color: AppTheme.muted),
                            const SizedBox(height: 12),
                            const Text(
                              'No projects yet',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Create your first project to orchestrate AI agents and manage tasks.',
                              style: TextStyle(color: AppTheme.muted),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: widget.onOpenProjects,
                              icon: const Icon(Icons.add),
                              label: const Text('Go to Projects'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ..._projects.take(6).map((p) {
                    final status = (p['status'] ?? 'created').toString();
                    final name = (p['name'] ?? p['title'] ?? 'Untitled Project').toString();
                    final desc = (p['description'] ?? 'No description provided').toString();
                    final projectId = p['id'].toString();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.account_tree_outlined, color: AppTheme.accent),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            desc,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StatusBadge(status: status),
                            const SizedBox(width: 12),
                            const Icon(Icons.chevron_right, color: AppTheme.muted),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProjectControlScreen(
                                projectId: projectId,
                                projectName: name,
                              ),
                            ),
                          ).then((_) => _load());
                        },
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
