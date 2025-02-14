import '../models/llm.dart';

enum TokenEventType { response, reasoning }

class TokenEvent {
  final TokenEventType type;
  final String text;

  TokenEvent(this.type, this.text);

  @override
  String toString() => '[$type] $text';
}

abstract class AIProvider {
  // Returns a list of available models
  Future<List<LLModel>> getModels({bool forceRefresh = false});

  // Streams the response from the AI provider, the modelId is the model to use
  // e.g. openai/gpt-4o
  Stream<TokenEvent> streamResponse(
      String modelId, String question, Map<String, dynamic> params,
      {String? imagePath});

  Future<String> fetchImageURL(String modelId);
}
