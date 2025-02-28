import 'ai_provider.dart';
import 'ai_provider_mock.dart';
import 'ai_provider_or.dart';

enum ProviderType {
  mock,
  openrouter,
}

class ModelService {
  Map<ProviderType, AIProvider> providers = {};

  ModelService() {
    providers[ProviderType.mock] = AiProviderMock();
    providers[ProviderType.openrouter] = AIProviderOpenrouter();
  }

  List<AIProvider> getAll() {
    return providers.values.toList();
  }

  AIProvider? getProvider(ProviderType type) {
    return providers[type];
  }
}
