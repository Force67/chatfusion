import 'ai_provider.dart';
import 'ai_provider_mock.dart';
import 'ai_provider_or.dart';

class ModelService {
  Map<ProviderType, AIProvider> providers = {};

  ModelService() {
    providers[ProviderType.mockProvider] = AiProviderMock();
    providers[ProviderType.openrouter] = AIProviderOpenrouter();
  }

  List<AIProvider> getAll() {
    return providers.values.toList();
  }

  AIProvider? getProvider(ProviderType type) {
    return providers[type];
  }
}
