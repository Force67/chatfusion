import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2_parameters.dart';
import 'package:pointycastle/random/fortuna_random.dart';

class MessageCrypto {
  // Security parameters
  static const int _passwordHashIterations = 120000;
  static const int _keyDerivationIterations = 100000;
  static const int _saltLength = 16; // 128-bit salt
  static const int _keyLength = 32; // 256-bit key
  static const int _ivLength = 12; // 96-bit IV for AES-GCM

  // --- Secure Random Generation ---
  static Uint8List generateSalt() {
    final fortuna = FortunaRandom();
    final secureRandom = SecureRandom(fortuna);
    return secureRandom.seedBytes(_saltLength);
  }

  // --- Password Hashing (PBKDF2-HMAC-SHA256) ---
  static String hashPassword(String password, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256(), 64));
    final params = Pbkdf2Parameters(salt, _passwordHashIterations, _keyLength);
    final keyBytes = pbkdf2.process(utf8.encode(password), params);
    return base64.encode(keyBytes);
  }

  // --- Password Verification ---
  static bool verifyPassword(
      String password, String storedHash, Uint8List salt) {
    final newHash = hashPassword(password, salt);
    return constantTimeCompare(newHash, storedHash);
  }

  // --- Encryption Key Derivation (PBKDF2-HMAC-SHA256) ---
  static Key deriveEncryptionKey(String password, Uint8List keyDerivationSalt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256(), 64));
    final params = Pbkdf2Parameters(
        keyDerivationSalt, _keyDerivationIterations, _keyLength);
    final keyBytes = pbkdf2.process(utf8.encode(password), params);
    return Key(keyBytes);
  }

  // --- AES-GCM Encryption ---
  static Map<String, dynamic> encryptData(String plainText, Key encryptionKey) {
    final encrypter = Encrypter(AES(encryptionKey, mode: AESMode.gcm));
    final iv = IV.fromSecureRandom(_ivLength);
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    return {
      'cipherText': encrypted.base64,
      'iv': iv.base64,
      'authTag': encrypted.mac?.base64
    };
  }

  // --- AES-GCM Decryption ---
  static String decryptData(
      String cipherText, String iv, String authTag, Key decryptionKey) {
    final encrypter = Encrypter(AES(decryptionKey, mode: AESMode.gcm));
    final parsedIV = IV.fromBase64(iv);
    final encrypted = Encrypted.fromBase64(cipherText);
    return encrypter.decrypt(encrypted,
        iv: parsedIV, mac: Mac.fromBase64(authTag));
  }

  // --- Constant Time Comparison ---
  static bool constantTimeCompare(String a, String b) {
    final aBytes = utf8.encode(a);
    final bBytes = utf8.encode(b);
    if (aBytes.length != bBytes.length) return false;

    int result = 0;
    for (int i = 0; i < aBytes.length; i++) {
      result |= aBytes[i] ^ bBytes[i];
    }
    return result == 0;
  }
}

// --- User Data Management (Example Implementation) ---
class UserData {
  final String userId;
  final String hashedPassword;
  final Uint8List passwordSalt;
  final Uint8List keyDerivationSalt;

  UserData({
    required this.userId,
    required this.hashedPassword,
    required this.passwordSalt,
    required this.keyDerivationSalt,
  });

  static Future<UserData> createUser(String userId, String password) async {
    final passwordSalt = MessageCrypto.generateSalt();
    final keyDerivationSalt = MessageCrypto.generateSalt();
    final hashedPassword = MessageCrypto.hashPassword(password, passwordSalt);

    // In real implementation, store in database
    return UserData(
      userId: userId,
      hashedPassword: hashedPassword,
      passwordSalt: passwordSalt,
      keyDerivationSalt: keyDerivationSalt,
    );
  }

  static Future<UserData?> authenticateUser(
      String userId, String password) async {
    // Fetch user data from database
    final user = await _fetchUserFromDb(userId);
    if (user == null) return null;

    final valid = MessageCrypto.verifyPassword(
        password, user.hashedPassword, user.passwordSalt);

    return valid ? user : null;
  }

  Key getEncryptionKey(String password) {
    return MessageCrypto.deriveEncryptionKey(password, keyDerivationSalt);
  }

  // Simulated database fetch
  static Future<UserData?> _fetchUserFromDb(String userId) async {
    // Implementation would fetch from your database
    return UserData(
      userId: userId,
      hashedPassword: 'stored_hash',
      passwordSalt: Uint8List.fromList([/* stored salt bytes */]),
      keyDerivationSalt: Uint8List.fromList([/* stored salt bytes */]),
    );
  }
}
