import '../models/llm_model.dart';

abstract class AIProvider {
  // Returns a list of available models
  Future<List<LLMModel>> getModels({bool forceRefresh = false});

  // Streams the response from the AI provider
  Stream<String> streamResponse(String modelId, String question);
}
