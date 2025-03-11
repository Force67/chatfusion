class Attachment {
  final String attachmentId;
  int messageId; // Made non-final
  final String mimeType;
  String data; // File path
  final bool isFilePath;
  String? fileData; // Base64-encoded data

  Attachment({
    required this.attachmentId,
    required this.messageId,
    required this.mimeType,
    required this.data,
    required this.isFilePath,
    this.fileData,
  });

  Map<String, dynamic> toMap() {
    return {
      'attachment_id': attachmentId,
      'message_id': messageId,
      'mime_type': mimeType,
      'data': data,
      'is_file_path': isFilePath ? 1 : 0,
      'file_data': fileData,
    };
  }

  factory Attachment.fromMap(Map<String, dynamic> map) {
    return Attachment(
      attachmentId: map['attachment_id'],
      messageId: map['message_id'],
      mimeType: map['mime_type'],
      data: map['data'],
      isFilePath: map['is_file_path'] == 1,
      fileData: map['file_data'],
    );
  }

  // copyWith method remains the same
  Attachment copyWith({
    String? attachmentId,
    int? messageId,
    String? mimeType,
    String? data,
    bool? isFilePath,
    String? fileData,
  }) {
    return Attachment(
      attachmentId: attachmentId ?? this.attachmentId,
      messageId: messageId ?? this.messageId,
      mimeType: mimeType ?? this.mimeType,
      data: data ?? this.data,
      isFilePath: isFilePath ?? this.isFilePath,
      fileData: fileData ?? this.fileData,
    );
  }
}
