import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart';
import 'package:uuid/uuid.dart';

class EncryptionContext {
  final String folderId;
  final Key key;
  final List<int> salt;

  EncryptionContext({
    required this.folderId,
    required this.key,
    required this.salt,
  });
}

class SecureFolderStore {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Map<String, EncryptionContext> _activeContexts = {};
  static const int keyLength = 32;
  static const int ivLength = 16;
  static const int iterations = 100000;
  final Uuid _uuid = const Uuid();

  // Create new encrypted folder
  Future<String> createFolder(String password) async {
    final folderId = _uuid.v4();
    final salt = _generateSalt();

    await _secureStorage.write(
      key: _getSaltKey(folderId),
      value: base64Encode(salt),
    );

    final context = await _deriveKeyContext(folderId, password, salt);
    _activeContexts[folderId] = context;

    return folderId;
  }

  // Unlock an existing folder
  Future<void> unlockFolder(String folderId, String password) async {
    final salt = await _getStoredSalt(folderId);
    final context = await _deriveKeyContext(folderId, password, salt);
    _activeContexts[folderId] = context;
  }

  // Lock a folder (remove key from memory)
  void lockFolder(String folderId) {
    _activeContexts.remove(folderId);
  }

  // Encrypt data for specific folder
  String encryptData(String folderId, String plaintext) {
    final context = _activeContexts[folderId];
    if (context == null) throw Exception('Folder not unlocked');

    final iv = IV.fromSecureRandom(ivLength);
    final encrypter = Encrypter(AES(context.key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    return base64Encode([...iv.bytes, ...encrypted.bytes]);
  }

  // Decrypt data from specific folder
  String decryptData(String folderId, String encryptedData) {
    final context = _activeContexts[folderId];
    if (context == null) throw Exception('Folder not unlocked');

    final data = base64.decode(encryptedData);
    final iv = IV(Uint8List.fromList(data.sublist(0, ivLength)));
    final cipherText = Encrypted(Uint8List.fromList(data.sublist(ivLength)));

    return Encrypter(AES(context.key, mode: AESMode.cbc))
        .decrypt(cipherText, iv: iv);
  }

  // Generate new encryption context
  Future<EncryptionContext> _deriveKeyContext(
    String folderId, String password, List<int> salt) async {
    final pbkdf2 = Pbkdf2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, keyLength));

    final keyBytes = pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
    return EncryptionContext(
      folderId: folderId,
      key: Key(keyBytes),
      salt: salt,
    );
  }

  Uint8List _generateSalt() {
    return Uint8List.fromList(List.generate(32, (_) => Random.secure().nextInt(256)));
  }

  Future<List<int>> _getStoredSalt(String folderId) async {
    final salt = await _secureStorage.read(key: _getSaltKey(folderId));
    if (salt == null) throw Exception('Folder not found');
    return base64.decode(salt);
  }

  String _getSaltKey(String folderId) => 'salt_$folderId';
}
