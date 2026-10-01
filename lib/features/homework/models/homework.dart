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

  bool get isExpired {
    if (deadline == null) return false;
    final endOfDay = DateTime(deadline!.year, deadline!.month, deadline!.day, 23, 59, 59);
    return DateTime.now().isAfter(endOfDay);
  }

  static DateTime? _extractDeadlineFromDescription(String desc) {
    final regex = RegExp(r'(\d{4})-(\d{2})-(\d{2})');
    final match = regex.firstMatch(desc);
    if (match == null) return null;

    try {
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      final afterDate = desc.substring(match.end);
      final isEvening = afterDate.contains('مسائي') ||
          afterDate.contains('مساءً') ||
          afterDate.contains('PM');
      final hour = isEvening ? 20 : 9;
      return DateTime(year, month, day, hour, 0);
    } catch (_) {
      return null;
    }
  }

  factory Homework.fromJson(Map<String, dynamic> json) {
    final desc = (json['description'] ?? '').toString();
    DateTime? parsedDeadline;
    if (json['deadline'] != null) {
      parsedDeadline = DateTime.tryParse(json['deadline'].toString());
    }
    parsedDeadline ??= _extractDeadlineFromDescription(desc);

    return Homework(
      id: json['id'] ?? '',
      subjectId: json['subject_id'] ?? '',
      title: json['title'] ?? '',
      description: desc,
      imageUrl: json['image_url'],
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      deadline: parsedDeadline,
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
