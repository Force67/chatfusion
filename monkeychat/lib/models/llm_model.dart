class LLMModel {
  final String id;
  final String name;
  final String description;
  final String provider;
  final String iconUrl;
  final Map<String, dynamic> capabilities;

  LLMModel({
    required this.id,
    required this.name,
    required this.description,
    required this.provider,
    required this.iconUrl,
    required this.capabilities,
  });

  // Helper method to construct the image URL
  String _constructImageUrl(String name) {
    // Extract the first part of the name (before '/') or use the full name if no '/' exists
    String nameSubset = name.contains('/') ? name.split('/')[0] : name;

    // Convert the name to PascalCase
    String pascalCaseName = _toPascalCase(nameSubset);

    // Construct the URL
    return "https://openrouter.ai/images/icons/$pascalCaseName.png";
  }

  // Helper method to convert a string to PascalCase
  String _toPascalCase(String input) {
    // Split into parts (e.g., "deep_seek" -> ["deep", "seek"])
    List<String> parts = input.split(RegExp(r'[_\s]'));

    // Capitalize the first letter of each part and concatenate
    String pascalCase = parts.map((part) {
      if (part.isEmpty) return part;
      return part[0].toUpperCase() + part.substring(1).toLowerCase();
    }).join();

    return pascalCase;
  }

  // Factory constructor to create an LLMModel from JSON
  factory LLMModel.fromJson(Map<String, dynamic> json) {
    return LLMModel(
      id: json['id'],
      name: json['name'],
      description: (json['description'] as String).length > 20
          ? (json['description'] as String).substring(0, 20)
          : json['description'],
      provider: "NOPE",
      iconUrl: LLMModel._constructImageUrlStatically(json['id']), // Use static method
      capabilities: Map<String, dynamic>(),
    );
  }

  // Static method to allow access in factory constructor
  static String _constructImageUrlStatically(String name) {
    String nameSubset = name.contains('/') ? name.split('/')[0] : name;

    // Convert the name to PascalCase
    String pascalCaseName = _toPascalCaseStatic(nameSubset);
    print(pascalCaseName);

    // Construct the URL
    return "https://openrouter.ai/images/icons/$pascalCaseName.png";
  }

  // Static version of _toPascalCase
  static String _toPascalCaseStatic(String input) {
    List<String> parts = input.split(RegExp(r'[_\s]'));
    String pascalCase = parts.map((part) {
      if (part.isEmpty) return part;
      return part[0].toUpperCase() + part.substring(1).toLowerCase();
    }).join();
    return pascalCase;
  }

  // Convert the object to JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'provider': {'name': provider, 'icon_url': iconUrl},
        'capabilities': capabilities,
      };
}
