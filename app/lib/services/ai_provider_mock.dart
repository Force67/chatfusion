import 'package:chatfusion/models/llm.dart';

import 'ai_provider.dart';

class AiProviderMock extends AIProvider {
  @override
  Future<BillingInfo?> fetchBilling() {
    // TODO: implement fetchBilling
    throw UnimplementedError();
  }

  @override
  Future<String> fetchImageURL(String modelId) {
    // TODO: implement fetchImageURL
    throw UnimplementedError();
  }

  @override
  Future<List<LLModel>> getModels({bool forceRefresh = false}) {
    LLModel mod;
    // TODO: implement getModels
    throw UnimplementedError();
  }

  @override
  Stream<TokenEvent> streamResponse(String modelId, String question,
      Map<String, dynamic> params, List<String>? attachmentPaths) {
    // TODO: implement streamResponse
    throw UnimplementedError();
  }

  @override
  ProviderType type() {
    return ProviderType.mockProvider;
  }
}
