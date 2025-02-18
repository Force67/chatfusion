class Folder {
  int? id; // Nullable because it's autoincrement
  String name;
  DateTime createdAt;
  bool systemFolder;

  Folder(
      {this.id,
      required this.name,
      required this.createdAt,
      required this.systemFolder});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'system_folder': systemFolder,
    };
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'],
      name: map['name'],
      createdAt: DateTime.parse(map['created_at']),
      systemFolder: map['system_folder'] == 1,
    );
  }
}
