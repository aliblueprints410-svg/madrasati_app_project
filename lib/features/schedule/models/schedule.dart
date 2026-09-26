class Schedule {
  final String id;
  final String classId;
  // scheduleData will store days as keys and list of subjects as values
  // e.g. {'الأحد': ['رياضيات', 'عربي', 'إنجليزي'], 'الإثنين': [...]}
  final Map<String, dynamic> scheduleData;

  Schedule({
    required this.id,
    required this.classId,
    required this.scheduleData,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'] ?? '',
      classId: json['class_id'] ?? '',
      scheduleData: json['schedule_data'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_id': classId,
      'schedule_data': scheduleData,
    };
  }
}
