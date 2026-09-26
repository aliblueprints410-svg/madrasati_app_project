class Announcement {
  final String id;
  final String schoolId;
  final String title;
  final String content;
  final DateTime createdAt;
  final bool priority;
  final bool isDeleted;

  Announcement({
    required this.id,
    required this.schoolId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.priority,
    required this.isDeleted,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] ?? '',
      schoolId: json['school_id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      priority: json['priority'] ?? false,
      isDeleted: json['is_deleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'priority': priority,
      'is_deleted': isDeleted,
    };
  }
}
