import 'dart:convert';

class Chat {
  final int id;

  // A chat always belongs to a folder. If none is specified by the UI it gets added
  // to the default folder (Id 0)
  final int folderId;

  final String title;
  final String modelId;
  final DateTime createdAt;

  // Every chat has its own parameters, which can be modified by the user
  // The default params shall be inherited from the settings, eventually
  // For supported parameters, see https://openrouter.ai/docs/api-reference/parameters
  final Map<String, dynamic> modelSettings;

  Chat({
    required this.id,
    required this.folderId,
    required this.title,
    required this.modelId,
    required this.createdAt,
    required this.modelSettings,
  });

  factory Chat.fromMap(Map<String, dynamic> map) {
    try {
      return Chat(
        id: map['id'] as int,
        folderId: map['folder_id'] as int,
        title: map['title'] as String,
        modelId: map['model_id'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        modelSettings: jsonDecode(map['params'] as String),
      );
    } catch (e) {
      throw FormatException('Failed to parse Chat from map: $e');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'folder_id': folderId,
      'title': title,
      'model_id': modelId,
      'created_at': createdAt.toIso8601String(),
      'params': jsonEncode(modelSettings),
    };
  }

  Chat copyWith({
    int? id,
    int? folderId,
    String? title,
    String? modelId,
    DateTime? createdAt,
    Map<String, dynamic>? modelSettings,
  }) {
    return Chat(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      title: title ?? this.title,
      modelId: modelId ?? this.modelId,
      createdAt: createdAt ?? this.createdAt,
      modelSettings: modelSettings ?? this.modelSettings,
    );
  }
}
