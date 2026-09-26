class SchoolClass {
  final String id;
  final String schoolId;
  final String name;
  final int order;

  SchoolClass({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.order,
  });

  factory SchoolClass.fromJson(Map<String, dynamic> json) {
    return SchoolClass(
      id: json['id'] ?? '',
      schoolId: json['school_id'] ?? '',
      name: json['name'] ?? '',
      order: json['order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'name': name,
      'order': order,
    };
  }
}
