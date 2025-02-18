class Message {
  final int id;
  final int chatId;
  final String text;
  final String reasoning;
  final bool isUser;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.chatId,
    required this.text,
    required this.reasoning,
    required this.isUser,
    required this.createdAt,
  });

  // copyWith
  copyWith({
    int? id,
    int? chatId,
    String? text,
    String? reasoning,
    bool? isUser,
    DateTime? createdAt,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      text: text ?? this.text,
      reasoning: reasoning ?? this.reasoning,
      isUser: isUser ?? this.isUser,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Message.fromMap(Map<String, dynamic> map) => Message(
    id: map['id'],
    chatId: map['chat_id'],
    text: map['text'],
    reasoning: map['reasoning'],
    isUser: map['is_user'] == 1,
    createdAt: DateTime.parse(map['created_at']),
  );
}
