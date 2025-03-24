import 'dart:typed_data';
import 'package:cryptography/cryptography.dart'; //For the Key type.

class Folder {
  // Nullable because it's autoincrement
  int? id;

  // Folders are nestable, so we need to keep track of the parent folder
  int? parentId;

  static const int _encryptedFlag = 1 << 0; // 0b00000001
  static const int _lockedFlag = 1 << 1; // 0b00000010
  static const int _passwordEnabledFlag = 1 << 2; // 0b00000100
  static const int _autolockFlag = 1 << 3; // 0b00001000
  final int flags;

  // User Password → [KDF + Salt] → Encryption Key → (Never stored)
  // Stored Data → [Salt (non-secret)]
  final Uint8List encryptionSalt;
  // Derived in memory when needed
  Key? _encryptionKey;

  // Nice feature for organizing the folders
  String hexColorCode;
  String name;
  DateTime createdAt;

  Folder({
    this.id,
    this.parentId,
    required this.name,
    required this.hexColorCode,
    required this.createdAt,
    this.flags = 0, // Default to no flags set
    Uint8List? encryptionSalt, // Make it optional in the constructor
  }) : this.encryptionSalt = encryptionSalt ?? Uint8List(0); // Initialize with an empty list if null

  bool get isEncrypted => (flags & _encryptedFlag) != 0;
  bool get isLocked => (flags & _lockedFlag) != 0;
  bool get hasPassword => (flags & _passwordEnabledFlag) != 0;
  bool get autoLockEnabled => (flags & _autolockFlag) != 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parent_id': parentId,
      'name': name,
      'color_code': hexColorCode,
      'flags': flags,
      'encryption_salt': encryptionSalt,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'],
      parentId: map['parent_id'],
      name: map['name'],
      hexColorCode: map['color_code'],
      flags: map['flags'] ?? 0, // Handle potential null values from the database
      encryptionSalt: map['encryption_salt'] is Uint8List
          ? map['encryption_salt']
          : Uint8List.fromList(List<int>.from(map['encryption_salt'])), // Ensure correct type.
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
