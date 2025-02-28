import '../models/llm.dart';

enum TokenEventType { response, reasoning }

class TokenEvent {
  final TokenEventType type;
  final String text;

  TokenEvent(this.type, this.text);

  @override
  String toString() => '[$type] $text';
}

class BillingInfo {
  final double usage;
  final double limit;
  final double maxRequests;

  BillingInfo(this.usage, this.limit, this.maxRequests);
}

abstract class AIProvider {
  // Returns a list of available models
  Future<List<LLModel>> getModels({bool forceRefresh = false});

  // Streams the response from the AI provider, the modelId is the model to use
  // e.g. openai/gpt-4o
  Stream<TokenEvent> streamResponse(String modelId, String question,
      Map<String, dynamic> params, List<String>? attachmentPaths);

  Future<String> fetchImageURL(String modelId);

  // Returns info about the amount of credits used etc.
  Future<BillingInfo?> fetchBilling();
}
