class Comment {
  final String id;
  final String announcementId;
  final String senderName;
  final String content;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.announcementId,
    required this.senderName,
    required this.content,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? '',
      announcementId: json['announcement_id'] ?? '',
      senderName: json['sender_name'] ?? 'مجهول',
      content: json['content'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'announcement_id': announcementId,
      'sender_name': senderName,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }
}
