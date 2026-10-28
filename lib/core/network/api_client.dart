import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/token_storage.dart';
import 'api_config.dart';

class ApiClient {
  ApiClient({http.Client? client, TokenStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const TokenStorage();

  final http.Client _client;
  final TokenStorage _storage;

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await _storage.readAccessToken();
    return <String, String>{
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ----------------------------------------------------
  // Core HTTP Primitives
  // ----------------------------------------------------

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final uri = ApiConfig.buildUri(path, query);
    final response = await _client.get(uri, headers: await _headers(json: false));
    return _decode(response);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final uri = ApiConfig.buildUri(path);
    final response = await _client.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _decode(response);
  }

  Future<dynamic> put(String path, {Object? body}) async {
    final uri = ApiConfig.buildUri(path);
    final response = await _client.put(
      uri,
      headers: await _headers(),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _decode(response);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    final uri = ApiConfig.buildUri(path);
    final response = await _client.patch(
      uri,
      headers: await _headers(),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _decode(response);
  }

  Future<void> delete(String path) async {
    final uri = ApiConfig.buildUri(path);
    final response = await _client.delete(uri, headers: await _headers(json: false));
    _decode(response);
  }

  // ----------------------------------------------------
  // Health
  // ----------------------------------------------------

  /// GET /health
  Future<Map<String, dynamic>> healthCheck() async {
    final res = await get('/health');
    return _asMap(res);
  }

  // ----------------------------------------------------
  // Auth Endpoints
  // ----------------------------------------------------

  /// POST /auth/login (OAuth2 Password Request Form)
  Future<Map<String, dynamic>> login(String email, String password) async {
    final uri = ApiConfig.buildUri('/auth/login');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json'},
      body: {'username': email, 'password': password},
    );
    final decoded = _decode(response);
    if (decoded is! Map<String, dynamic> || decoded['access_token'] is! String) {
      throw const ApiException('Login response did not contain access_token.', 500);
    }
    await _storage.saveAccessToken(decoded['access_token'] as String);
    return decoded;
  }

  /// POST /auth/register
  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final value = await post('/auth/register', body: {
      'email': email,
      'username': username,
      'password': password,
    });
    return _asMap(value);
  }

  /// GET /auth/me
  Future<Map<String, dynamic>> me() async {
    return _asMap(await get('/auth/me'));
  }

  // ----------------------------------------------------
  // Project Endpoints
  // ----------------------------------------------------

  /// GET /project?page={page}&limit={limit}
  Future<Map<String, dynamic>> listProjects({int page = 1, int limit = 50}) async {
    final value = await get('/project', query: {
      'page': '$page',
      'limit': '$limit',
    });
    return _asMap(value);
  }

  /// Helper to extract list of project maps directly
  Future<List<Map<String, dynamic>>> listProjectsItems({int page = 1, int limit = 50}) async {
    final value = await listProjects(page: page, limit: limit);
    final items = value['items'];
    return items is List
        ? items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
  }

  /// GET /project/{project_id}
  Future<Map<String, dynamic>> getProject(String projectId) async {
    return _asMap(await get('/project/$projectId'));
  }

  /// POST /project
  Future<Map<String, dynamic>> createProject({
    required String title,
    String? description,
  }) async {
    final value = await post('/project', body: {
      'title': title,
      'description': description ?? '',
    });
    return _asMap(value);
  }

  /// PUT /project/{project_id}
  Future<Map<String, dynamic>> updateProject(
    String projectId, {
    String? name,
    String? description,
  }) async {
    final value = await put('/project/$projectId', body: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
    });
    return _asMap(value);
  }

  /// PATCH /project/{project_id}/status
  Future<Map<String, dynamic>> setProjectStatus(String projectId, String status) async {
    final value = await patch('/project/$projectId/status', body: {'status': status});
    return _asMap(value);
  }

  /// DELETE /project/{project_id}
  Future<void> deleteProject(String projectId) async {
    await delete('/project/$projectId');
  }

  // ----------------------------------------------------
  // Task Endpoints
  // ----------------------------------------------------

  /// GET /projects/{project_id}/tasks
  Future<List<Map<String, dynamic>>> listTasks(String projectId) async {
    final value = await get('/projects/$projectId/tasks');
    return value is List
        ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
  }

  /// GET /projects/{project_id}/tasks/{task_id}
  Future<Map<String, dynamic>> getTask(String projectId, String taskId) async {
    return _asMap(await get('/projects/$projectId/tasks/$taskId'));
  }

  /// POST /projects/{project_id}/tasks
  Future<Map<String, dynamic>> createTask(
    String projectId, {
    required String title,
    String? description,
    String priority = 'medium',
  }) async {
    final value = await post('/projects/$projectId/tasks', body: {
      'title': title,
      'description': description ?? '',
      'priority': priority,
    });
    return _asMap(value);
  }

  /// PATCH /projects/{project_id}/tasks/{task_id}
  Future<Map<String, dynamic>> updateTask(
    String projectId,
    String taskId, {
    String? title,
    String? description,
    String? priority,
    String? status,
  }) async {
    final value = await patch('/projects/$projectId/tasks/$taskId', body: {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (priority != null) 'priority': priority,
      if (status != null) 'status': status,
    });
    return _asMap(value);
  }

  /// PATCH /projects/{project_id}/tasks/{task_id}/status
  Future<Map<String, dynamic>> updateTaskStatus(
    String projectId,
    String taskId,
    String status,
  ) async {
    final value = await patch('/projects/$projectId/tasks/$taskId/status', body: {
      'status': status,
    });
    return _asMap(value);
  }

  /// DELETE /projects/{project_id}/tasks/{task_id}
  Future<void> deleteTask(String projectId, String taskId) async {
    await delete('/projects/$projectId/tasks/$taskId');
  }

  // ----------------------------------------------------
  // Agent & Workflow Endpoints
  // ----------------------------------------------------

  /// POST /agents/run
  Future<Map<String, dynamic>> startRun(String projectId, String task) async {
    final value = await post('/agents/run', body: {
      'project_id': projectId,
      'task': task,
    });
    return _asMap(value);
  }

  /// GET /agents/runs/{project_id}
  Future<List<Map<String, dynamic>>> runHistory(String projectId) async {
    final value = await get('/agents/runs/$projectId');
    return value is List
        ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
  }

  /// GET /agents/runs/{run_id}/plan
  Future<Map<String, dynamic>> runPlan(String runId) async {
    return _asMap(await get('/agents/runs/$runId/plan'));
  }

  /// POST /agents/runs/{run_id}/approve
  Future<Map<String, dynamic>> approveRun(String runId) async {
    return _asMap(await post('/agents/runs/$runId/approve'));
  }

  /// POST /agents/runs/{run_id}/request-changes
  Future<Map<String, dynamic>> requestChanges(String runId, String feedback) async {
    final value = await post('/agents/runs/$runId/request-changes', body: {
      'feedback': feedback,
    });
    return _asMap(value);
  }

  /// GET /agents/runs/{run_id}/messages
  Future<List<Map<String, dynamic>>> runMessages(String runId) async {
    final value = await get('/agents/runs/$runId/messages');
    return value is List
        ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
  }

  // ----------------------------------------------------
  // Helpers
  // ----------------------------------------------------

  Map<String, dynamic> _asMap(dynamic value) =>
      value is Map<String, dynamic> ? value : <String, dynamic>{};

  dynamic _decode(http.Response response) {
    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      decoded = response.body;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Request failed (${response.statusCode}).';
      if (decoded is Map) {
        message = (decoded['detail'] ?? message).toString();
      }
      if (response.statusCode == 401) {
        message = 'Your session has expired. Please sign in again.';
      } else if (response.statusCode == 403) {
        message = 'You do not have permission to perform this action.';
      } else if (response.statusCode == 404) {
        message = decoded is Map && decoded['detail'] != null
            ? decoded['detail'].toString()
            : 'Requested resource was not found.';
      } else if (response.statusCode == 409) {
        message = decoded is Map && decoded['detail'] != null
            ? decoded['detail'].toString()
            : 'This workflow state has changed. Refresh and try again.';
      } else if (response.statusCode == 422 && decoded is Map) {
        message = (decoded['detail'] ?? message).toString();
      }
      throw ApiException(message, response.statusCode);
    }
    return decoded;
  }

  void close() => _client.close();
}

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
