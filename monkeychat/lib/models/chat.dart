class Chat {
  final int id;
  final String title;
  final DateTime createdAt;

  Chat({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  factory Chat.fromMap(Map<String, dynamic> map) => Chat(
    id: map['id'],
    title: map['title'],
    createdAt: DateTime.parse(map['created_at']),
  );
}
