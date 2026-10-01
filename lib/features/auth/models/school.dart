class School {
  final String id;
  final String name;
  final String schoolCode;
  final String stage; // 'primary' or 'middle'

  const School({
    required this.id,
    required this.name,
    required this.schoolCode,
    this.stage = 'primary',
  });

  bool get isMiddle =>
      stage.toLowerCase() == 'middle' ||
      name.contains('متوسط');

  bool get isPrimary => !isMiddle;

  factory School.fromJson(Map<String, dynamic> json) {
    return School(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      schoolCode: json['school_code'] ?? '',
      stage: json['stage'] ??
          (json['name']?.toString().contains('متوسط') == true ? 'middle' : 'primary'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'school_code': schoolCode,
      'stage': stage,
    };
  }
}
