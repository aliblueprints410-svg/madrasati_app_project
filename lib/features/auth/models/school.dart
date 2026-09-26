class School {
  final String id;
  final String name;
  final String schoolCode;

  School({
    required this.id,
    required this.name,
    required this.schoolCode,
  });

  factory School.fromJson(Map<String, dynamic> json) {
    return School(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      schoolCode: json['school_code'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'school_code': schoolCode,
    };
  }
}
