class ProjectTask {
  const ProjectTask({
    required this.id,
    required this.projectId,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectId;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ProjectTask.fromJson(Map<String, dynamic> json) {
    return ProjectTask(
      id: (json['id'] ?? '').toString(),
      projectId: (json['project_id'] ?? '').toString(),
      title: (json['title'] ?? 'Task').toString(),
      description: json['description']?.toString(),
      status: (json['status'] ?? 'pending').toString(),
      priority: (json['priority'] ?? 'medium').toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'project_id': projectId,
    'title': title,
    'description': description,
    'status': status,
    'priority': priority,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}

