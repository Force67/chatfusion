enum MessageType { user, bot, system }

class Message {
  final int id;
  final int chatId;
  final MessageType type;
  final String text;
  final String reasoning;
  final String? imagePath; // optional
  final DateTime createdAt;

  Message({
    required this.id,
    required this.chatId,
    required this.type,
    required this.text,
    required this.reasoning,
    this.imagePath,
    required this.createdAt,
  });

  bool isUser() => type == MessageType.user;
  bool isBot() => type == MessageType.bot;
  bool isSystem() => type == MessageType.system;

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
      type: type ?? this.type,
      text: text ?? this.text,
      reasoning: reasoning ?? this.reasoning,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Message.fromMap(Map<String, dynamic> map) => Message(
        id: map['id'],
        chatId: map['chat_id'],
        type: MessageType.values[map['type']],
        text: map['text'],
        reasoning: map['reasoning'],
        imagePath: map['image_path'],
        createdAt: DateTime.parse(map['created_at']),
      );
}
