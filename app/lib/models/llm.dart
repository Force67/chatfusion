class LLModel {
  final String id;
  final String name;
  final String description;
  final String provider;
  final String iconUrl;

  final LLMCapabilities capabilities;
  final LLMPricing pricing;

  LLModel({
    required this.id,
    required this.name,
    required this.description,
    required this.provider,
    required this.iconUrl,
    required this.capabilities,
    required this.pricing,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LLModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  // fromJSON
  factory LLModel.fromJson(Map<String, dynamic> json) => LLModel(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        provider: json['provider']['name'] as String,
        iconUrl: json['provider']['icon_url'] as String,
        capabilities: LLMCapabilities.fromJson(
            json['capabilities'] as Map<String, dynamic>),
        pricing: LLMPricing.fromJson(json['pricing'] as Map<String, dynamic>),
      );

  // Convert the object to JSON, used by the database
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'provider': {'name': provider, 'icon_url': iconUrl},
        'capabilities': capabilities.toJson(),
        'pricing': pricing.toJson(),
      };
}

class LLMCapabilities {
  final bool supportsImageInput;
  final bool supportsImageOutput;
  final bool supportsReasoning;
  final bool supportsReasoningDisplay;
  final List<String> tunableParameters;

  LLMCapabilities({
    required this.supportsImageInput,
    required this.supportsImageOutput,
    required this.supportsReasoning,
    required this.supportsReasoningDisplay,
    required this.tunableParameters,
  });

  factory LLMCapabilities.fromJson(Map<String, dynamic> json) =>
      LLMCapabilities(
        supportsImageInput: json['supports_image_input'] as bool? ??
            false, // Default to false if missing
        supportsImageOutput: json['supports_image_output'] as bool? ??
            false, // Default to false if missing
        supportsReasoning: json['supports_reasoning'] as bool? ??
            false, // Default to false if missing
        supportsReasoningDisplay: json['supports_reasoning_display'] as bool? ??
            false, // Default to false if missing
        tunableParameters: (json['tunable_parameters'] as List<dynamic>?)
                ?.cast<String>()
                .toList() ??
            [], // Default to empty list if missing or not a list
      );

  Map<String, dynamic> toJson() => {
        'supports_image_input': supportsImageInput,
        'supports_image_output': supportsImageOutput,
        'supports_reasoning': supportsReasoning,
        'supports_reasoning_display': supportsReasoningDisplay,
        'tunable_parameters': tunableParameters,
      };
}

class LLMPricing {
  final double prompt;
  final double completion;
  final double image;
  final double request;
  final double inputCacheRead;
  final double inputCacheWrite;
  final double webSearch;
  final double internalReasoning;

  LLMPricing({
    required this.prompt,
    required this.completion,
    required this.image,
    required this.request,
    required this.inputCacheRead,
    required this.inputCacheWrite,
    required this.webSearch,
    required this.internalReasoning,
  });

  bool get isFree => prompt == 0.0 && completion == 0.0 && image == 0.0 && request == 0.0 && inputCacheRead == 0.0 && inputCacheWrite == 0.0 && webSearch == 0.0 && internalReasoning == 0.0;

  factory LLMPricing.fromJson(Map<String, dynamic> json) => LLMPricing(
        prompt: (json['prompt'] as num?)?.toDouble() ??
            0.0, // Default to 0.0 if missing
        completion: (json['completion'] as num?)?.toDouble() ??
            0.0, // Default to 0.0 if missing
        image: (json['image'] as num?)?.toDouble() ??
            0.0, // Default to 0.0 if missing
        request: (json['request'] as num?)?.toDouble() ??
            0.0, // Default to 0.0 if missing
        inputCacheRead: (json['input_cache_read'] as num?)?.toDouble() ?? 0.0,
        inputCacheWrite: (json['input_cache_write'] as num?)?.toDouble() ?? 0.0,
        webSearch: (json['web_search'] as num?)?.toDouble() ?? 0.0,
        internalReasoning:
            (json['internal_reasoning'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'prompt': prompt,
        'completion': completion,
        'image': image,
        'request': request,
        'input_cache_read': inputCacheRead,
        'input_cache_write': inputCacheWrite,
        'web_search': webSearch,
        'internal_reasoning': internalReasoning,
      };
}
