class Chat {
  final int id;
  final String title;
  final String modelId;
  final DateTime createdAt;

  Chat({
    required this.id,
    required this.title,
    required this.modelId,
    required this.createdAt,
  });

  factory Chat.fromMap(Map<String, dynamic> map) => Chat(
    id: map['id'],
    title: map['title'],
    modelId: map['model_id'],
    createdAt: DateTime.parse(map['created_at']),
  );
}
