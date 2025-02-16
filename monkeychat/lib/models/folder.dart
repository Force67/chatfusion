class Folder {
  int? id; // Nullable because it's autoincrement
  String name;
  DateTime createdAt;

  //TODO: Default folder for all Chats, Add setting for user to select Folders on chat creation

  Folder({this.id, required this.name, required this.createdAt});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'],
      name: map['name'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
