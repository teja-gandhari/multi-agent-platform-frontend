class AgentRun {
  const AgentRun({
    required this.id,
    required this.projectId,
    required this.requestedTask,
    required this.status,
    this.result,
    this.errorMessage,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectId;
  final String requestedTask;
  final String status;
  final Map<String, dynamic>? result;
  final String? errorMessage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AgentRun.fromJson(Map<String, dynamic> json) {
    return AgentRun(
      id: (json['id'] ?? '').toString(),
      projectId: (json['project_id'] ?? '').toString(),
      requestedTask: (json['requested_task'] ?? '').toString(),
      status: (json['status'] ?? 'unknown').toString(),
      result: json['result'] is Map ? Map<String, dynamic>.from(json['result'] as Map) : null,
      errorMessage: json['error_message']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }
}

class AgentMessage {
  const AgentMessage({
    required this.id,
    required this.runId,
    required this.agent,
    required this.status,
    required this.message,
    this.eventData,
    this.createdAt,
  });

  final String id;
  final String runId;
  final String agent;
  final String status;
  final String message;
  final Map<String, dynamic>? eventData;
  final DateTime? createdAt;

  factory AgentMessage.fromJson(Map<String, dynamic> json) {
    return AgentMessage(
      id: (json['id'] ?? '').toString(),
      runId: (json['run_id'] ?? '').toString(),
      agent: (json['agent'] ?? 'agent').toString(),
      status: (json['status'] ?? 'in_progress').toString(),
      message: (json['message'] ?? '').toString(),
      eventData: json['event_data'] is Map ? Map<String, dynamic>.from(json['event_data'] as Map) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}

