//enum LLMModelFlags 

class LLModel {
  final String id;
  final String name;
  final String description;
  final String provider;
  final String iconUrl;
  //final int flags;

  final Map<String, dynamic> capabilities;

  LLModel({
    required this.id,
    required this.name,
    required this.description,
    required this.provider,
    required this.iconUrl,
    required this.capabilities,
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
        capabilities: json['capabilities'],
      );

  // Convert the object to JSON, used by the database
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'provider': {'name': provider, 'icon_url': iconUrl},
        'capabilities': capabilities,
      };
}
