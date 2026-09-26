class Homework {
  final String id;
  final String subjectId;
  final String title;
  final String description;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime? deadline;
  final bool isCurrent;
  final bool isDeleted;

  Homework({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.createdAt,
    this.deadline,
    required this.isCurrent,
    required this.isDeleted,
  });

  factory Homework.fromJson(Map<String, dynamic> json) {
    return Homework(
      id: json['id'] ?? '',
      subjectId: json['subject_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      isCurrent: json['is_current'] ?? false,
      isDeleted: json['is_deleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject_id': subjectId,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      if (deadline != null) 'deadline': deadline!.toIso8601String(),
      'is_current': isCurrent,
      'is_deleted': isDeleted,
    };
  }
}
