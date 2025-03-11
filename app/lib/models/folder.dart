class Folder {
  // Nullable because it's autoincrement
  int? id;

  // Folders are nestable, so we need to keep track of the parent folder
  int? parentId;

  String name;
  String hashedPassword;

  // Nice feature for organizing the folders
  String hexColorCode;

  DateTime createdAt;

  Folder(
      {this.id,
      required this.parentId,
      required this.name,
      required this.hashedPassword,
      required this.hexColorCode,
      required this.createdAt});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parent_id': parentId ?? 0,
      'name': name,
      'color_code': hexColorCode,
      'hashed_password': hashedPassword,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'],
      parentId: map['parent_id'],
      name: map['name'],
      hexColorCode: map['color_code'],
      hashedPassword: map['hashed_password'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
