import 'dart:convert';

class Chat {
  final int id;
  final String title;
  final String modelId;
  final DateTime createdAt;

  // Every chat has its own parameters, which can be modified by the user
  // The default params shall be inherited from the settings, eventually
  // For supported parameters, see https://openrouter.ai/docs/api-reference/parameters
  final Map<String, dynamic> modelSettings;

  Chat({
    required this.id,
    required this.title,
    required this.modelId,
    required this.createdAt,
    required this.modelSettings,
  });

  factory Chat.fromMap(Map<String, dynamic> map) {
    try {
      return Chat(
        id: map['id'] as int,
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
      'title': title,
      'model_id': modelId,
      'created_at': createdAt.toIso8601String(),
      'params': jsonEncode(modelSettings),
    };
  }
}
