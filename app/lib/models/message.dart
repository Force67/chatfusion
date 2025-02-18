
enum MessageType { user, bot, system }

class Message {
  final int id;
  final int chatId;
  final MessageType type;
  final String text;
  final String? reasoning;
  final DateTime createdAt;
  final List<Attachment> attachments;

  Message({
    required this.id,
    required this.chatId,
    required this.type,
    required this.text,
    this.reasoning,
    required this.createdAt,
    required this.attachments,
  });

  bool isUser() => type == MessageType.user;
  bool isBot() => type == MessageType.bot;
  bool isSystem() => type == MessageType.system;

  // copyWith
  Message copyWith({
    int? id,
    int? chatId,
    MessageType? type,
    String? text,
    String? reasoning,
    List<Attachment>? attachments,
    DateTime? createdAt,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      type: type ?? this.type,
      text: text ?? this.text,
      reasoning: reasoning ?? this.reasoning,
      createdAt: createdAt ?? this.createdAt,
      attachments: attachments ?? this.attachments,
    );
  }

  // You may not need this if attachments are optional
  factory Message.fromMap(Map<String, dynamic> map) => Message(
        id: map['id'],
        chatId: map['chat_id'],
        type: MessageType.values[map['type']],
        text: map['text'],
        reasoning: map['reasoning'],
        createdAt: DateTime.parse(map['created_at']),
        attachments: [], // Empty list if no attachments from basic Message.fromMap
      );

  factory Message.fromMapWithAttachments(Map<String, dynamic> map) {
    List<Attachment> attachmentsList = [];

    if (map['attachment_ids'] != null &&
        (map['attachment_ids'] as String).isNotEmpty) {
      List<String> attachmentIds = (map['attachment_ids'] as String).split(',');
      List<String> mimeTypes = (map['mime_types'] as String).split(',');
      List<String> attachmentData =
          (map['attachment_data'] as String).split(',');
      List<String> isFilePaths = (map['is_file_paths'] as String).split(',');

      for (int i = 0; i < attachmentIds.length; i++) {
        attachmentsList.add(Attachment(
          attachmentId: attachmentIds[i],
          mimeType: mimeTypes[i],
          data: attachmentData[i],
          isFilePath: isFilePaths[i] == '1',
          // Ensure that the isFilePath variable is properly read
        ));
      }
    }

    return Message(
      id: map['id'],
      chatId: map['chat_id'],
      type: MessageType.values[map['type']],
      text: map['text'],
      reasoning: map['reasoning'],
      createdAt: DateTime.parse(map['created_at']),
      attachments: attachmentsList,
    );
  }
}

class Attachment {
  final String attachmentId;
  final String mimeType;
  final String data; // path or base64
  final bool isFilePath;

  Attachment({
    required this.attachmentId,
    required this.mimeType,
    required this.data,
    required this.isFilePath,
  });
}
