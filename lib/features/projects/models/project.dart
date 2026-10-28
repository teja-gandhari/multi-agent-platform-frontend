class Project {
  const Project({
    required this.id,
    required this.name,
    this.description,
    this.ownerId,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final String? ownerId;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? 'Untitled').toString(),
      description: json['description']?.toString(),
      ownerId: json['owner_id']?.toString(),
      status: (json['status'] ?? 'created').toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'owner_id': ownerId,
    'status': status,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  Project copyWith({
    String? name,
    String? description,
    String? status,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerId: ownerId,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
