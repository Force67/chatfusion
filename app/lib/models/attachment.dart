class Attachment {
  final String attachmentId;
  int messageId; // Made non-final
  final String mimeType;
  String? filePath; // File path
  String? fileData; // Base64-encoded data

  Attachment({
    required this.attachmentId,
    required this.messageId,
    required this.mimeType,
    required this.fileData,
    required this.filePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'attachment_id': attachmentId,
      'message_id': messageId,
      'mime_type': mimeType,
      'file_path': filePath,
      'file_data': fileData,
    };
  }

  factory Attachment.fromMap(Map<String, dynamic> map) {
    return Attachment(
      attachmentId: map['attachment_id'],
      messageId: map['message_id'],
      mimeType: map['mime_type'],
      filePath: map['file_path'],
      fileData: map['file_data'],
    );
  }

  // copyWith method remains the same
  Attachment copyWith({
    String? attachmentId,
    int? messageId,
    String? mimeType,
    String? filePath,
    String? fileData,
  }) {
    return Attachment(
      attachmentId: attachmentId ?? this.attachmentId,
      messageId: messageId ?? this.messageId,
      mimeType: mimeType ?? this.mimeType,
      filePath: filePath ?? this.filePath,
      fileData: fileData ?? this.fileData,
    );
  }
}
