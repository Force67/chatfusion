class Folder {
  // Nullable because it's autoincrement
  int? id;

  // Folders are nestable, so we need to keep track of the parent folder
  int? parentId;

  String name;
  DateTime createdAt;

  Folder(
      {this.id,
      required this.parentId,
      required this.name,
      required this.createdAt});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parent_id': parentId ?? 0,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'],
      parentId: map['parent_id'],
      name: map['name'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
