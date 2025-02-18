class LLModel {
  final String id;
  final String name;
  final String description;
  final String provider;
  final String iconUrl;
  final bool supportsImageInput;
  final bool supportsImageOutput;
  final bool supportsReasoning;
  final bool supportsReasoningDisplay;

  /*final double pricingPrompt;
  final double pricingCompletion;
  final double pricingImage;
  final double pricingRequest;*/

  final List<String> tunableParameters;

  LLModel({
    required this.id,
    required this.name,
    required this.description,
    required this.provider,
    required this.iconUrl,
    required this.supportsImageInput,
    required this.supportsImageOutput,
    required this.supportsReasoning,
    required this.supportsReasoningDisplay,
    required this.tunableParameters,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LLModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  // fromJSON
  factory LLModel.fromJson(Map<String, dynamic> json) => LLModel(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        provider: json['provider']['name'],
        iconUrl: json['provider']['icon_url'],
        supportsImageInput: json['capabilities']['supports_image_input'],
        supportsImageOutput: json['capabilities']['supports_image_output'],
        supportsReasoning: json['capabilities']['supports_reasoning'],
        supportsReasoningDisplay: json['capabilities']
            ['supports_reasoning_display'],
        tunableParameters: json['tunable_parameters'] != null
            ? List<String>.from(json['tunable_parameters'])
            : [],
      );

  // Convert the object to JSON, used by the database
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'provider': {'name': provider, 'icon_url': iconUrl},
        'capabilities': {
          'supports_image_input': supportsImageInput,
          'supports_image_output': supportsImageOutput,
          'supports_reasoning': supportsReasoning,
          'supports_reasoning_display': supportsReasoningDisplay,
        },
        'tunable_parameters': tunableParameters,
      };
}
