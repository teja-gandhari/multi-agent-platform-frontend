import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../core/realtime/websocket_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/components.dart';

class ProjectControlScreen extends StatefulWidget {
  const ProjectControlScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  final String projectId;
  final String projectName;

  @override
  State<ProjectControlScreen> createState() => _ProjectControlScreenState();
}

class _ProjectControlScreenState extends State<ProjectControlScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  final _ws = WebSocketService();

  late TabController _tabController;
  StreamSubscription? _wsEventsSub;
  StreamSubscription? _wsStatusSub;

  // Project state
  Map<String, dynamic>? _projectDetails;
  String _currentProjectName = '';

  // Tasks state
  List<Map<String, dynamic>> _tasks = [];

  // Agent runs state
  List<Map<String, dynamic>> _runs = [];
  Map<String, dynamic>? _selectedRun;
  List<Map<String, dynamic>> _activeRunMessages = [];

  // Controllers
  final _workflowPromptCtrl = TextEditingController();
  final _feedbackCtrl = TextEditingController();

  // Loading & statuses
  bool _loading = true;
  bool _isWorkflowBusy = false;
  WsConnectionStatus _wsStatus = WsConnectionStatus.disconnected;

  @override
  void initState() {
    super.initState();
    _currentProjectName = widget.projectName;
    _tabController = TabController(length: 3, vsync: this);
    _initDataAndWebSocket();
  }

  Future<void> _initDataAndWebSocket() async {
    await _loadAll();
    await _connectWebSocket();
  }

  Future<void> _connectWebSocket() async {
    final token = await const TokenStorage().readAccessToken();
    if (token == null || token.isEmpty) return;

    _wsStatusSub = _ws.statusStream.listen((status) {
      if (mounted) setState(() => _wsStatus = status);
    });

    _wsEventsSub = _ws.events.listen((event) {
      if (mounted) {
        setState(() {
          // Prepend or append to live messages
          _activeRunMessages.add({
            'agent': event['agent'] ?? 'workflow',
            'status': event['status'] ?? 'in_progress',
            'message': event['message'] ?? '',
            'created_at': DateTime.now().toIso8601String(),
            'event_data': event,
          });

          // If the event corresponds to active run or indicates status change, update active run
          if (event['workflow_status'] != null && _selectedRun != null) {
            _selectedRun!['workflow_status'] = event['workflow_status'];
          }
        });
      }
    });

    await _ws.connect(widget.projectId, token);
  }

  @override
  void dispose() {
    _wsEventsSub?.cancel();
    _wsStatusSub?.cancel();
    _ws.dispose();
    _api.close();
    _tabController.dispose();
    _workflowPromptCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  void _message(String text, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? AppTheme.statusFailed.withValues(alpha: 0.9) : AppTheme.card,
      ),
    );
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      // 1. Fetch project info (GET /project/{id})
      final project = await _api.getProject(widget.projectId);
      // 2. Fetch tasks (GET /projects/{id}/tasks)
      final tasks = await _api.listTasks(widget.projectId);
      // 3. Fetch agent run history (GET /agents/runs/{id})
      final runs = await _api.runHistory(widget.projectId);

      if (mounted) {
        setState(() {
          _projectDetails = project;
          if (project['name'] != null) {
            _currentProjectName = project['name'].toString();
          }
          _tasks = tasks;
          _runs = runs;

          if (runs.isNotEmpty && _selectedRun == null) {
            _selectRun(runs.first, loadMessages: true);
          }
        });
      }
    } catch (e) {
      if (mounted) _message(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectRun(Map<String, dynamic> run, {bool loadMessages = true}) async {
    setState(() => _selectedRun = run);
    final runId = (run['id'] ?? run['run_id'] ?? '').toString();
    if (runId.isEmpty) return;

    // Load full plan if available (GET /agents/runs/{run_id}/plan)
    try {
      final plan = await _api.runPlan(runId);
      if (mounted) {
        setState(() {
          _selectedRun = {
            ..._selectedRun!,
            ...plan,
            'run_id': runId,
          };
        });
      }
    } catch (_) {}

    // Load messages if requested (GET /agents/runs/{run_id}/messages)
    if (loadMessages) {
      try {
        final messages = await _api.runMessages(runId);
        if (mounted) setState(() => _activeRunMessages = messages);
      } catch (_) {}
    }
  }

  // ----------------------------------------------------
  // Project Management Actions
  // ----------------------------------------------------

  Future<void> _editProjectDetails() async {
    final nameCtrl = TextEditingController(text: _currentProjectName);
    final descCtrl = TextEditingController(text: (_projectDetails?['description'] ?? '').toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Project Details'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Project Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(controller: nameCtrl),
              const SizedBox(height: 16),
              const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(controller: descCtrl, maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      // Calls PUT /project/{id}
      await _api.updateProject(
        widget.projectId,
        name: nameCtrl.text.trim(),
        description: descCtrl.text.trim(),
      );
      await _loadAll();
      _message('Project updated.', isError: false);
    } catch (e) {
      _message(e.toString());
    }
  }

  Future<void> _updateProjectStatus(String status) async {
    try {
      // Calls PATCH /project/{id}/status
      await _api.setProjectStatus(widget.projectId, status);
      await _loadAll();
      _message('Project status updated to $status.', isError: false);
    } catch (e) {
      _message(e.toString());
    }
  }

  // ----------------------------------------------------
  // Task Management Actions
  // ----------------------------------------------------

  Future<void> _createTask() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String priority = 'medium';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create New Task'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Task Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(controller: titleCtrl, decoration: const InputDecoration(hintText: 'e.g. Implement OAuth Flow')),
                const SizedBox(height: 14),
                const Text('Description (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Specific criteria...')),
                const SizedBox(height: 14),
                const Text('Priority', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  items: const ['low', 'medium', 'high', 'critical'].map((p) {
                    return DropdownMenuItem(value: p, child: Text(p.toUpperCase()));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => priority = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create Task')),
          ],
        ),
      ),
    );

    if (ok != true) return;
    if (titleCtrl.text.trim().isEmpty) {
      _message('Task title cannot be empty.');
      return;
    }

    try {
      // Calls POST /projects/{project_id}/tasks
      await _api.createTask(
        widget.projectId,
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim(),
        priority: priority,
      );
      final tasks = await _api.listTasks(widget.projectId);
      if (mounted) setState(() => _tasks = tasks);
      _message('Task created.', isError: false);
    } catch (e) {
      _message(e.toString());
    }
  }

  Future<void> _editTask(Map<String, dynamic> task) async {
    final titleCtrl = TextEditingController(text: (task['title'] ?? '').toString());
    final descCtrl = TextEditingController(text: (task['description'] ?? '').toString());
    String priority = (task['priority'] ?? 'medium').toString();
    String status = (task['status'] ?? 'pending').toString();
    final taskId = task['id'].toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Task'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(controller: titleCtrl),
                const SizedBox(height: 12),
                const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(controller: descCtrl, maxLines: 3),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Priority', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: priority,
                            items: const ['low', 'medium', 'high', 'critical'].map((p) {
                              return DropdownMenuItem(value: p, child: Text(p.toUpperCase()));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => priority = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: status,
                            items: const ['pending', 'in_progress', 'completed', 'failed'].map((s) {
                              return DropdownMenuItem(value: s, child: Text(s.toUpperCase()));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => status = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save Changes')),
          ],
        ),
      ),
    );

    if (ok != true) return;

    try {
      // Calls PATCH /projects/{project_id}/tasks/{task_id}
      await _api.updateTask(
        widget.projectId,
        taskId,
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim(),
        priority: priority,
        status: status,
      );
      final tasks = await _api.listTasks(widget.projectId);
      if (mounted) setState(() => _tasks = tasks);
      _message('Task updated.', isError: false);
    } catch (e) {
      _message(e.toString());
    }
  }

  Future<void> _updateTaskStatus(String taskId, String status) async {
    try {
      // Calls PATCH /projects/{project_id}/tasks/{task_id}/status
      await _api.updateTaskStatus(widget.projectId, taskId, status);
      final tasks = await _api.listTasks(widget.projectId);
      if (mounted) setState(() => _tasks = tasks);
    } catch (e) {
      _message(e.toString());
    }
  }

  Future<void> _deleteTask(String taskId) async {
    try {
      // Calls DELETE /projects/{project_id}/tasks/{task_id}
      await _api.deleteTask(widget.projectId, taskId);
      final tasks = await _api.listTasks(widget.projectId);
      if (mounted) setState(() => _tasks = tasks);
      _message('Task removed.', isError: false);
    } catch (e) {
      _message(e.toString());
    }
  }

  // ----------------------------------------------------
  // Agent Workflow Execution Actions
  // ----------------------------------------------------

  Future<void> _startWorkflow() async {
    final taskText = _workflowPromptCtrl.text.trim();
    if (taskText.isEmpty) {
      _message('Please describe what you want the multi-agent team to build.');
      return;
    }

    setState(() => _isWorkflowBusy = true);
    try {
      // Calls POST /agents/run
      final runResponse = await _api.startRun(widget.projectId, taskText);
      final runs = await _api.runHistory(widget.projectId);

      if (mounted) {
        setState(() {
          _runs = runs;
          _selectedRun = runResponse;
        });
        _workflowPromptCtrl.clear();
        final runId = (runResponse['run_id'] ?? '').toString();
        if (runId.isNotEmpty) {
          final messages = await _api.runMessages(runId);
          if (mounted) setState(() => _activeRunMessages = messages);
        }
      }
      _message('Multi-agent workflow started!', isError: false);
    } catch (e) {
      _message(e.toString());
    } finally {
      if (mounted) setState(() => _isWorkflowBusy = false);
    }
  }

  Future<void> _approvePlan() async {
    final runId = (_selectedRun?['run_id'] ?? _selectedRun?['id'] ?? '').toString();
    if (runId.isEmpty) return;

    setState(() => _isWorkflowBusy = true);
    try {
      // Calls POST /agents/runs/{run_id}/approve
      final updated = await _api.approveRun(runId);
      final runs = await _api.runHistory(widget.projectId);

      if (mounted) {
        setState(() {
          _selectedRun = updated;
          _runs = runs;
        });
        final messages = await _api.runMessages(runId);
        if (mounted) setState(() => _activeRunMessages = messages);
      }
      _message('Plan approved! Multi-agent execution resumed.', isError: false);
    } catch (e) {
      _message(e.toString());
    } finally {
      if (mounted) setState(() => _isWorkflowBusy = false);
    }
  }

  Future<void> _requestPlanChanges() async {
    final runId = (_selectedRun?['run_id'] ?? _selectedRun?['id'] ?? '').toString();
    final feedback = _feedbackCtrl.text.trim();

    if (runId.isEmpty) return;
    if (feedback.isEmpty) {
      _message('Please provide feedback for the planner agent.');
      return;
    }

    setState(() => _isWorkflowBusy = true);
    try {
      // Calls POST /agents/runs/{run_id}/request-changes
      final updated = await _api.requestChanges(runId, feedback);
      final runs = await _api.runHistory(widget.projectId);

      if (mounted) {
        setState(() {
          _selectedRun = updated;
          _runs = runs;
        });
        _feedbackCtrl.clear();
        final messages = await _api.runMessages(runId);
        if (mounted) setState(() => _activeRunMessages = messages);
      }
      _message('Feedback submitted to Planner.', isError: false);
    } catch (e) {
      _message(e.toString());
    } finally {
      if (mounted) setState(() => _isWorkflowBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_currentProjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('ID: ${widget.projectId}', style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
          ],
        ),
        actions: [
          // WebSocket status badge
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (_wsStatus == WsConnectionStatus.connected
                      ? AppTheme.statusCompleted
                      : (_wsStatus == WsConnectionStatus.connecting
                          ? AppTheme.statusWaiting
                          : AppTheme.statusFailed))
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (_wsStatus == WsConnectionStatus.connected
                        ? AppTheme.statusCompleted
                        : (_wsStatus == WsConnectionStatus.connecting
                            ? AppTheme.statusWaiting
                            : AppTheme.statusFailed))
                    .withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi,
                  size: 14,
                  color: _wsStatus == WsConnectionStatus.connected
                      ? AppTheme.statusCompleted
                      : (_wsStatus == WsConnectionStatus.connecting
                          ? AppTheme.statusWaiting
                          : AppTheme.statusFailed),
                ),
                const SizedBox(width: 6),
                Text(
                  _wsStatus == WsConnectionStatus.connected
                      ? 'Live WS'
                      : (_wsStatus == WsConnectionStatus.connecting ? 'Connecting...' : 'WS Offline'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _wsStatus == WsConnectionStatus.connected
                        ? AppTheme.statusCompleted
                        : (_wsStatus == WsConnectionStatus.connecting
                            ? AppTheme.statusWaiting
                            : AppTheme.statusFailed),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Change Project Status',
            icon: const Icon(Icons.flag_outlined, size: 20),
            onSelected: _updateProjectStatus,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'created', child: Text('Mark Created')),
              PopupMenuItem(value: 'planning', child: Text('Mark Planning')),
              PopupMenuItem(value: 'running', child: Text('Mark Running')),
              PopupMenuItem(value: 'completed', child: Text('Mark Completed')),
              PopupMenuItem(value: 'failed', child: Text('Mark Failed')),
            ],
          ),
          IconButton(
            tooltip: 'Edit Project',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: _editProjectDetails,
          ),
          IconButton(
            tooltip: 'Refresh All',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadAll,
          ),
          const SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.muted,
          tabs: [
            const Tab(
              icon: Icon(Icons.smart_toy_outlined, size: 18),
              text: 'Agent Team & Workflow',
            ),
            Tab(
              icon: const Icon(Icons.check_box_outlined, size: 18),
              text: 'Tasks (${_tasks.length})',
            ),
            Tab(
              icon: const Icon(Icons.history_outlined, size: 18),
              text: 'Run History (${_runs.length})',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildWorkflowTab(),
                _buildTasksTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  // ====================================================
  // TAB 1: WORKFLOW & AGENTS
  // ====================================================

  Widget _buildWorkflowTab() {
    final status = (_selectedRun?['workflow_status'] ?? _selectedRun?['status'] ?? 'not_started').toString();
    final approvalStatus = (_selectedRun?['approval_status'] ?? '').toString();
    final isWaitingForApproval = status.toLowerCase() == 'waiting_for_approval' ||
        approvalStatus.toLowerCase().contains('wait') ||
        approvalStatus.toLowerCase().contains('await');

    final planText = (_selectedRun?['planner_md'] ?? _selectedRun?['plan'] ?? '').toString();
    final rawAppUrl = (_selectedRun?['application_url'] ?? '').toString();
    final appUrl = ApiConfig.resolveAppUrl(rawAppUrl);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Launch Prompt Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Run AI Agent Team',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Planner → Researcher → Developer → Coder → Tester → Reviewer',
                                style: TextStyle(color: AppTheme.muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _workflowPromptCtrl,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          hintText: 'Describe what you want the agent team to build or solve...\ne.g. "Build a REST API authentication service with JWT and redis session rate limiting"',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isWorkflowBusy ? null : _startWorkflow,
                            icon: _isWorkflowBusy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.play_arrow_rounded, size: 18),
                            label: Text(_isWorkflowBusy ? 'Agent Team Executing...' : 'Start Workflow'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Active Run Header & Status
              if (_selectedRun != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Active Workflow Execution',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            StatusBadge(status: status),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Task: "${_selectedRun!['requested_task'] ?? _selectedRun!['task'] ?? 'Workflow execution'}"',
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontStyle: FontStyle.italic),
                        ),
                        if (_selectedRun!['error_message'] != null &&
                            _selectedRun!['error_message'].toString().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.statusFailed.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.statusFailed.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppTheme.statusFailed, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Error: ${_selectedRun!['error_message']}',
                                    style: const TextStyle(color: AppTheme.statusFailed, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (appUrl.startsWith('http')) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.statusCompleted.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.statusCompleted.withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.open_in_browser, color: AppTheme.statusCompleted, size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Generated Application Running',
                                        style: TextStyle(
                                          color: AppTheme.statusCompleted,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      SelectableText(
                                        appUrl,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  color: AppTheme.muted,
                                  tooltip: 'Copy URL',
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: appUrl));
                                    _message('App URL copied to clipboard!', isError: false);
                                  },
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.statusCompleted,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  icon: const Icon(Icons.launch, size: 14),
                                  label: const Text('Open App'),
                                  onPressed: () async {
                                    final uri = Uri.tryParse(appUrl);
                                    if (uri != null) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // PLAN APPROVAL BANNER (HUMAN IN THE LOOP)
                if (isWaitingForApproval) ...[
                  Card(
                    color: AppTheme.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppTheme.statusWaiting, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.rate_review, color: AppTheme.statusWaiting, size: 24),
                              SizedBox(width: 10),
                              Text(
                                'Plan Ready for Review & Approval',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.statusWaiting,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'The Planner agent generated an execution plan for your review. Approve to continue, or provide feedback for revision.',
                            style: TextStyle(color: AppTheme.muted, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: SelectableText(
                              planText.isNotEmpty ? planText : 'No plan markdown provided.',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.statusCompleted,
                                  foregroundColor: Colors.black,
                                ),
                                onPressed: _isWorkflowBusy ? null : _approvePlan,
                                icon: const Icon(Icons.check_circle_outline, size: 18),
                                label: const Text('Approve Plan & Proceed'),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextField(
                                  controller: _feedbackCtrl,
                                  decoration: const InputDecoration(
                                    hintText: 'Feedback / requested changes for the planner...',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                onPressed: _isWorkflowBusy ? null : _requestPlanChanges,
                                icon: const Icon(Icons.replay, size: 16),
                                label: const Text('Request Revision'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // AGENT TELEMETRY FEED (REAL-TIME WEBSOCKET + MESSAGES)
                _buildAgentTelemetryFeed(),

                const SizedBox(height: 20),

                // WORKFLOW OUTPUTS TABS
                _buildAgentOutputsTabs(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgentTelemetryFeed() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.stream, size: 20, color: AppTheme.accent),
                const SizedBox(width: 10),
                const Text(
                  'Live Agent Telemetry Feed',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    '${_activeRunMessages.length} events',
                    style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_activeRunMessages.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Waiting for agent events. Logs will stream here in real-time.',
                    style: TextStyle(color: AppTheme.muted, fontSize: 13),
                  ),
                ),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 320),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: _activeRunMessages.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (context, i) {
                    final msg = _activeRunMessages[i];
                    final agent = (msg['agent'] ?? 'workflow').toString();
                    final status = (msg['status'] ?? 'in_progress').toString();
                    final text = (msg['message'] ?? '').toString();
                    final time = msg['created_at'] != null ? msg['created_at'].toString().split('T').last.split('.').first : '';

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(time, style: const TextStyle(color: AppTheme.muted, fontSize: 11, fontFamily: 'monospace')),
                        const SizedBox(width: 10),
                        AgentBadge(agent: agent, status: status),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SelectableText(
                            text,
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentOutputsTabs() {
    final result = _selectedRun?['result'] is Map
        ? Map<String, dynamic>.from(_selectedRun!['result'] as Map)
        : <String, dynamic>{};

    final plan = (_selectedRun?['plan'] ?? _selectedRun?['planner_md'] ?? result['plan'] ?? '').toString();
    final research = (_selectedRun?['research_output'] ?? result['research_output'] ?? '').toString();
    final dev = (_selectedRun?['developer_output'] ?? result['developer_output'] ?? '').toString();
    final test = _selectedRun?['test_result'] ?? result['test_result'];
    final review = _selectedRun?['review'] ?? result['review'];
    final runner = _selectedRun?['runner_result'] ?? result['runner_result'];

    return DefaultTabController(
      length: 6,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Agent Artifacts & Output Inspector',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              const TabBar(
                isScrollable: true,
                indicatorColor: AppTheme.accent,
                tabs: [
                  Tab(text: 'Planner Output'),
                  Tab(text: 'Research Output'),
                  Tab(text: 'Developer / Code'),
                  Tab(text: 'Test Results'),
                  Tab(text: 'Reviewer'),
                  Tab(text: 'Runner Execution'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: TabBarView(
                  children: [
                    _outputBox(plan.isNotEmpty ? plan : 'No planner output recorded yet.'),
                    _outputBox(research.isNotEmpty ? research : 'No research findings generated yet.'),
                    _outputBox(dev.isNotEmpty ? dev : 'No developer source generated yet.'),
                    _outputBox(test != null && test.toString().isNotEmpty ? test.toString() : 'No automated tests run yet.'),
                    _outputBox(review != null && review.toString().isNotEmpty ? review.toString() : 'No code review submitted yet.'),
                    _outputBox(runner != null && runner.toString().isNotEmpty ? runner.toString() : 'No runner execution logs yet.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _outputBox(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          content,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4),
        ),
      ),
    );
  }

  // ====================================================
  // TAB 2: TASKS MANAGEMENT
  // ====================================================

  Widget _buildTasksTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Project Tasks',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Manage backlog, in-progress items, and verification status.',
                        style: TextStyle(color: AppTheme.muted, fontSize: 13),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _createTask,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Task'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_tasks.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.task_alt, size: 48, color: AppTheme.muted),
                          const SizedBox(height: 12),
                          const Text('No tasks created yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          const Text('Create tasks to track deliverables alongside your AI agent team.', style: TextStyle(color: AppTheme.muted)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _createTask,
                            icon: const Icon(Icons.add),
                            label: const Text('Create First Task'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ..._tasks.map((task) {
                  final taskId = task['id'].toString();
                  final title = (task['title'] ?? 'Task').toString();
                  final desc = (task['description'] ?? '').toString();
                  final status = (task['status'] ?? 'pending').toString();
                  final priority = (task['priority'] ?? 'medium').toString();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status toggle popup
                          PopupMenuButton<String>(
                            tooltip: 'Update status',
                            onSelected: (st) => _updateTaskStatus(taskId, st),
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'pending', child: Text('Pending')),
                              PopupMenuItem(value: 'in_progress', child: Text('In Progress')),
                              PopupMenuItem(value: 'completed', child: Text('Completed')),
                              PopupMenuItem(value: 'failed', child: Text('Failed')),
                            ],
                            icon: Icon(
                              status == 'completed'
                                  ? Icons.check_circle
                                  : (status == 'in_progress' ? Icons.play_circle : Icons.circle_outlined),
                              color: AppTheme.statusColor(status),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          decoration: status == 'completed' ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ),
                                    PriorityBadge(priority: priority),
                                    const SizedBox(width: 8),
                                    StatusBadge(status: status),
                                  ],
                                ),
                                if (desc.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    desc,
                                    style: const TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.4),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.muted),
                            tooltip: 'Edit task',
                            onPressed: () => _editTask(task),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.statusFailed),
                            tooltip: 'Delete task',
                            onPressed: () => _deleteTask(taskId),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  // ====================================================
  // TAB 3: RUN HISTORY
  // ====================================================

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Workflow Run History',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Historical multi-agent executions, plans, and output artifacts for this project.',
                style: TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              if (_runs.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text('No workflow runs recorded yet.', style: TextStyle(color: AppTheme.muted)),
                    ),
                  ),
                )
              else
                ..._runs.map((run) {
                  final isSelected = _selectedRun != null &&
                      (_selectedRun!['id'] ?? _selectedRun!['run_id']) == (run['id'] ?? run['run_id']);
                  final status = (run['status'] ?? 'unknown').toString();
                  final task = (run['requested_task'] ?? 'Run execution').toString();
                  final created = run['created_at'] != null ? run['created_at'].toString().replaceFirst('T', ' ').split('.').first : '';

                  return Card(
                    color: isSelected ? AppTheme.card : AppTheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: isSelected ? AppTheme.accent : AppTheme.border),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.statusColor(status).withValues(alpha: 0.15),
                        child: Icon(Icons.bolt, color: AppTheme.statusColor(status), size: 20),
                      ),
                      title: Text(task, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Executed: $created',
                          style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StatusBadge(status: status),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSelected ? AppTheme.accentDark : AppTheme.card,
                              minimumSize: const Size(80, 36),
                            ),
                            onPressed: () {
                              _selectRun(run, loadMessages: true);
                              _tabController.animateTo(0);
                            },
                            child: Text(isSelected ? 'Viewing' : 'Inspect'),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
