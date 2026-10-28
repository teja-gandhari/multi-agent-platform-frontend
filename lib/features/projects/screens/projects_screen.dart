import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/components.dart';
import 'project_control_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final _api = ApiClient();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _projects = [];
  bool _loading = true;
  String? _error;
  String _selectedStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.close();
    _searchController.dispose();
    super.dispose();
  }

  void _message(String s, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s),
        backgroundColor: isError ? AppTheme.statusFailed.withValues(alpha: 0.9) : AppTheme.card,
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.listProjectsItems(page: 1, limit: 100);
      if (mounted) setState(() => _projects = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createProject() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Project'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Project Title', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'e.g. NextGen Microservice Platform'),
              ),
              const SizedBox(height: 16),
              const Text('Description (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Objectives and scope of this project...'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create Project')),
        ],
      ),
    );

    if (ok != true) return;
    if (titleCtrl.text.trim().isEmpty) {
      _message('Project title is required.');
      return;
    }

    try {
      // Calls POST /project
      await _api.createProject(
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim(),
      );
      await _load();
      _message('Project created successfully.', isError: false);
    } catch (e) {
      _message(e.toString());
    }
  }

  Future<void> _editProject(Map<String, dynamic> p) async {
    final nameCtrl = TextEditingController(text: (p['name'] ?? p['title'] ?? '').toString());
    final descCtrl = TextEditingController(text: (p['description'] ?? '').toString());
    final projectId = p['id'].toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Project Details'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Project Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(controller: nameCtrl),
              const SizedBox(height: 16),
              const Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(controller: descCtrl, maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save Changes')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      // Calls PUT /project/{id}
      await _api.updateProject(
        projectId,
        name: nameCtrl.text.trim(),
        description: descCtrl.text.trim(),
      );
      await _load();
      _message('Project updated.', isError: false);
    } catch (e) {
      _message(e.toString());
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> p, String newStatus) async {
    try {
      // Calls PATCH /project/{id}/status
      await _api.setProjectStatus(p['id'].toString(), newStatus);
      await _load();
      _message('Status changed to $newStatus.', isError: false);
    } catch (e) {
      _message(e.toString());
    }
  }

  Future<void> _deleteProject(Map<String, dynamic> p) async {
    final name = (p['name'] ?? p['title'] ?? 'this project').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project?'),
        content: Text('Are you sure you want to delete "$name"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.statusFailed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Calls DELETE /project/{id}
      await _api.deleteProject(p['id'].toString());
      await _load();
      _message('Project deleted.', isError: false);
    } catch (e) {
      _message(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final filterQuery = _searchController.text.trim().toLowerCase();
    final filteredProjects = _projects.where((p) {
      final name = (p['name'] ?? p['title'] ?? '').toString().toLowerCase();
      final desc = (p['description'] ?? '').toString().toLowerCase();
      final status = (p['status'] ?? '').toString().toLowerCase();

      final matchesQuery = filterQuery.isEmpty || name.contains(filterQuery) || desc.contains(filterQuery);
      final matchesStatus = _selectedStatusFilter == 'all' || status == _selectedStatusFilter;

      return matchesQuery && matchesStatus;
    }).toList();

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
                // Header with action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Projects',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Orchestrate autonomous agent workflows, tasks, and code execution.',
                          style: TextStyle(color: AppTheme.muted, fontSize: 14),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _createProject,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Project'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Search and status filter bar
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 260,
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Search projects...',
                              prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.muted),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ...['all', 'created', 'planning', 'running', 'completed', 'failed'].map((st) {
                          final isSelected = _selectedStatusFilter == st;
                          return ChoiceChip(
                            label: Text(st.toUpperCase()),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : AppTheme.muted,
                            ),
                            selected: isSelected,
                            selectedColor: AppTheme.accentDark,
                            backgroundColor: AppTheme.surface,
                            onSelected: (_) => setState(() => _selectedStatusFilter = st),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(50),
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
                          Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.statusFailed))),
                          ElevatedButton(onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    ),
                  )
                else if (filteredProjects.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.folder_open, size: 48, color: AppTheme.muted),
                            const SizedBox(height: 12),
                            const Text(
                              'No projects found',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Try clearing your search filters or create a new project.',
                              style: TextStyle(color: AppTheme.muted),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _createProject,
                              icon: const Icon(Icons.add),
                              label: const Text('Create Project'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 420,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      mainAxisExtent: 250,
                    ),
                    itemCount: filteredProjects.length,
                    itemBuilder: (context, i) {
                      final p = filteredProjects[i];
                      final name = (p['name'] ?? p['title'] ?? 'Untitled Project').toString();
                      final desc = (p['description'] ?? 'No description provided.').toString();
                      final status = (p['status'] ?? 'created').toString();
                      final id = p['id'].toString();

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: AppTheme.accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.account_tree_outlined, color: AppTheme.accent, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        StatusBadge(status: status),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Options',
                                    onSelected: (val) {
                                      if (val == 'edit') {
                                        _editProject(p);
                                      } else if (val == 'delete') {
                                        _deleteProject(p);
                                      } else {
                                        _updateStatus(p, val);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_outlined, size: 16),
                                            SizedBox(width: 8),
                                            Text('Edit details'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                      const PopupMenuItem(
                                        enabled: false,
                                        child: Text('Change Status:', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                                      ),
                                      const PopupMenuItem(value: 'created', child: Text('Mark Created')),
                                      const PopupMenuItem(value: 'planning', child: Text('Mark Planning')),
                                      const PopupMenuItem(value: 'running', child: Text('Mark Running')),
                                      const PopupMenuItem(value: 'completed', child: Text('Mark Completed')),
                                      const PopupMenuItem(value: 'failed', child: Text('Mark Failed')),
                                      const PopupMenuDivider(),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline, size: 16, color: AppTheme.statusFailed),
                                            SizedBox(width: 8),
                                            Text('Delete project', style: TextStyle(color: AppTheme.statusFailed)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: Text(
                                  desc,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.4),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ProjectControlScreen(
                                              projectId: id,
                                              projectName: name,
                                            ),
                                          ),
                                        ).then((_) => _load());
                                      },
                                      icon: const Icon(Icons.bolt_outlined, size: 16),
                                      label: const Text('Open Workspace'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
