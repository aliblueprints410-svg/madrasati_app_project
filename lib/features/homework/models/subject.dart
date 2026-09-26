class Subject {
  final String id;
  final String classId;
  final String name;
  final String? icon;

  Subject({
    required this.id,
    required this.classId,
    required this.name,
    this.icon,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] ?? '',
      classId: json['class_id'] ?? '',
      name: json['name'] ?? '',
      icon: json['icon'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_id': classId,
      'name': name,
      'icon': icon,
    };
  }
}
